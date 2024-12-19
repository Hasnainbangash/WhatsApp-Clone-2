//
//  GroupChatScreenViewController.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 12/11/2024.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import CoreData

class GroupChatScreenViewController: UIViewController {
    
    @IBOutlet weak var groupChatTableView: UITableView!
    @IBOutlet weak var messageTextfield: UITextField!
    @IBOutlet weak var deleteBarButton: UIBarButtonItem!
    
    let db = Firestore.firestore()
    
    // Reference to Imanaged object context
    let context = PersistentStorage.shared.context
    
    var titleName  = ""
    var groupID = ""
    
    var groupMessageChats: [GroupMessageChat] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        groupChatTableView.dataSource = self
        groupChatTableView.delegate = self
        
        deleteBarButton.isHidden = true
        
        title = titleName
        
        print(groupID)
        
        groupChatTableView.register(UINib(nibName: K.NibNames.groupChatCellNibName, bundle: nil), forCellReuseIdentifier: K.Identifiers.groupChatCellIdentifier)
        
        loadMessages()
    }
    
    // Fetch messages from Core Data
    func fetchMessagesFromCoreData() {
        do {
            let request = GroupMessages.fetchRequest() as NSFetchRequest<GroupMessages>
            let messages = try context.fetch(request)
            self.groupMessageChats = messages.map { GroupMessageChat(message: $0.message ?? "Null", senderID: $0.senderID ?? "nil") }
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    // Save the message to Core Data
    func saveMessageToCoreData(message: String, senderID: String) {
        let newMessage = GroupMessages(context: self.context)
        newMessage.message = message
        newMessage.senderID = senderID
        newMessage.date = Date().timeIntervalSince1970
        
        PersistentStorage.shared.saveContext()
        print("group messages saved succesfully to core data")
    }
    
    func fetchMessagesFromFirestore() {
        db.collection(K.FStore.groupCollection)
            .document(groupID)
            .collection(K.FStore.messageCollection)
            .order(by: K.FStore.dateField)
            .addSnapshotListener { querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                    print("AS there is a error so fetching the data from the core data now")
                    self.fetchMessagesFromCoreData()
                } else {
                    self.groupMessageChats.removeAll()
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            
                            // Checking if the message is deleted by current user or not
                            let deletedByArray = data[K.FStore.deletedByIDField] as? [String] ?? []
                            let currentUserID = Auth.auth().currentUser?.uid ?? ""
                            
                            // Only showing that messages that are not deleted by current user
                            if !deletedByArray.contains(currentUserID) {
                                if let messageBody = data[K.FStore.messageField] as? String,
                                   let messageId = data[K.FStore.senderID] as? String {
                                    let newMessage = GroupMessageChat(message: messageBody, senderID: messageId)
                                    self.groupMessageChats.append(newMessage)
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.groupChatTableView.reloadData()
                            
                            if self.groupMessageChats.count > 0 {
                                let indexPath = IndexPath(row: self.groupMessageChats.count - 1, section: 0)
                                self.groupChatTableView.scrollToRow(at: indexPath, at: .top, animated: true)
                            }
                        }
                    }
                }
            }
    }
    
    func loadMessages() {
        fetchMessagesFromFirestore()
        
        //        if groupMessageChats.isEmpty {
        //            // Fetching the data from the core data
        //            fetchMessagesFromCoreData()
        //        }
    }
    
    @IBAction func deletePressed(_ sender: Any) {
        let alert = UIAlertController(title: "Delete", message: "Are you sure you want to delete?", preferredStyle: .alert)
        
        let deleteButton = UIAlertAction(title: "Delete", style: .destructive) { _ in
            guard let currentUserID = Auth.auth().currentUser?.uid, let selectedRows = self.groupChatTableView.indexPathsForSelectedRows else { return }
            
            // For each selected message
            for indexPath in selectedRows {
                let message = self.groupMessageChats[indexPath.row]
                
                // Finding and updating the messages in Firestore for the deleted by id field
                self.db.collection(K.FStore.groupCollection)
                    .document(self.groupID)
                    .collection(K.FStore.messageCollection)
                    .whereField(K.FStore.messageField, isEqualTo: message.message)
                    .whereField(K.FStore.senderID, isEqualTo: message.senderID)
                    .getDocuments { (snapshot, error) in
                        if let document = snapshot?.documents.first {
                            // Add current user's ID to deletedByIDField
                            document.reference.updateData([
                                K.FStore.deletedByIDField: [currentUserID]
                            ])
                        }
                    }
                
                if let cell = self.groupChatTableView.cellForRow(at: indexPath) as? GroupChatCell {
                    cell.rightCheckBoxImageView.isHidden = true
                }
                
            }
            
            // Deselect all selected rows
            selectedRows.forEach { indexPath in
                self.groupChatTableView.deselectRow(at: indexPath, animated: true)
            }
            
            // Reset UI
            self.deleteBarButton.isHidden = true
            self.loadMessages()
        }
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(deleteButton)
        alert.addAction(cancelButton)
        
        self.present(alert, animated: true)
    }
    
    @IBAction func sendPressed(_ sender: UIButton) {
        if let messageBody = messageTextfield.text, let senderID = Auth.auth().currentUser?.uid {
            
            db.collection(K.FStore.groupCollection)
                .document(groupID)
                .collection(K.FStore.messageCollection)
                .addDocument(data: [
                    K.FStore.senderID: senderID,
                    K.FStore.messageField: messageBody,
                    K.FStore.deletedByIDField: [], // Initialize empty array for deleted IDs
                    K.FStore.dateField: Date().timeIntervalSince1970
                ]) { error in
                    if let e = error {
                        print("There was an issue saving messages to firestore, \(e)")
                    } else {
                        print("Successfully saved data.")
                        
                        // Saving the messages to the core data
                        self.saveMessageToCoreData(message: messageBody, senderID: senderID)
                        
                        self.loadMessages()
                        
                        // Setting the text field to empty after clicking the send button
                        DispatchQueue.main.async {
                            self.messageTextfield.text = ""
                        }
                    }
                }
        }
    }
}

extension GroupChatScreenViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupMessageChats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.row < groupMessageChats.count {
            let groupMessageChat = groupMessageChats[indexPath.row]
            
            let cell = tableView.dequeueReusableCell(withIdentifier: K.Identifiers.groupChatCellIdentifier, for: indexPath) as! GroupChatCell
            
            cell.labelName.text = groupMessageChat.message
            
            print("Testing code starts from here")
            if groupMessageChat.senderID == Auth.auth().currentUser?.uid {
                print(Auth.auth().currentUser?.uid ?? "No id")
                cell.leftImageView.isHidden = true
                cell.rightImageView.isHidden = false
                cell.messageBubble.backgroundColor = UIColor(
                    red: CGFloat(160) / 255.0,
                    green: CGFloat(214) / 255.0,
                    blue: CGFloat(131) / 255.0,
                    alpha: 1.0
                )
            } else {
                cell.leftImageView.isHidden = false
                cell.rightImageView.isHidden = true
                cell.messageBubble.backgroundColor = UIColor(
                    red: CGFloat(114) / 255.0,
                    green: CGFloat(191) / 255.0,
                    blue: CGFloat(120) / 255.0,
                    alpha: 1.0
                )
            }
            return cell
        } else {
            return UITableViewCell()
        }
    }
}

extension GroupChatScreenViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        print("Row \(indexPath.row) selected")
        
        if let cell = tableView.cellForRow(at: indexPath) as? GroupChatCell {
            cell.rightCheckBoxImageView.isHidden = false
            cell.rightCheckBoxImageView.image = UIImage(systemName: "checkmark.circle.fill")
            deleteBarButton.isHidden = false
            print("I got selected")
        } else {
            print("I won't get selected")
        }
        
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
        print("Row \(indexPath.row) selected")
        
        if let cell = tableView.cellForRow(at: indexPath) as? GroupChatCell {
            //            deleteBarButton.isHidden = false
            cell.rightCheckBoxImageView.image = UIImage(systemName: "circle")
            print("I got deselected")
        } else {
            print("I wont get deseelcted")
        }
        
        // Checking if all the selected rows are nil or not
        if tableView.indexPathsForSelectedRows == nil {
            deleteBarButton.isHidden = true
            if let cell = tableView.cellForRow(at: indexPath) as? GroupChatCell {
                cell.rightCheckBoxImageView.isHidden = true
            }
        }
        
    }
}
