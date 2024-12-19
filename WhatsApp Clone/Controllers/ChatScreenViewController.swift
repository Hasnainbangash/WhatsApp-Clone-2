//
//  ChatScreenViewController.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 05/11/2024.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import CoreData

class ChatScreenViewController: UIViewController {
    
    @IBOutlet weak var chatTableView: UITableView!
    @IBOutlet weak var messageTextfield: UITextField!
    @IBOutlet weak var deleteBarButton: UIBarButtonItem!
    
    let db = Firestore.firestore()
    
    // Reference to Imanaged object context
    let context = PersistentStorage.shared.context
    
    var titleName  = ""
    var recieverID = ""
    
    var messageChats: [MessageChat] = []
    var deletedByID: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        deleteBarButton.isHidden = true
        
        chatTableView.dataSource = self
        chatTableView.delegate = self
        
        title = titleName
        
        print(recieverID)
        
        chatTableView.register(UINib(nibName: K.NibNames.chatCellNibName, bundle: nil), forCellReuseIdentifier: K.Identifiers.chatCellIdentifier)
        
        loadMessages()
    }
    
    // Fetch messages from Core Data
    func fetchMessagesFromCoreData(senderID: String, receiverID: String) {
        do {
            let request = Messages.fetchRequest() as NSFetchRequest<Messages>
            let pred = NSPredicate(format: "(senderID == %@ AND receiverID == %@) OR (senderID == %@ AND receiverID == %@)", senderID, receiverID, receiverID, senderID)
            let sort = NSSortDescriptor(key: "date", ascending: true)
            
            request.predicate = pred
            request.sortDescriptors = [sort]
            
            let messages = try PersistentStorage.shared.context.fetch(request)
            messageChats = messages.map { MessageChat(senderID: $0.senderID!, recieverID: $0.receiverID!, message: $0.message!) }
            
            DispatchQueue.main.async {
                self.chatTableView.reloadData()
                
                if self.messageChats.count > 0 {
                    let indexPath = IndexPath(row: self.messageChats.count - 1, section: 0)
                    self.chatTableView.scrollToRow(at: indexPath, at: .top, animated: true)
                }
            }
        } catch {
            print("Error fetching messages from Core Data: \(error)")
        }
    }
    
    // Saving the messages to Core Data
    func saveMessageToCoreData(senderID: String, receiverID: String, message: String) {
        let newMessage = Messages(context: self.context)
        newMessage.senderID = senderID
        newMessage.receiverID = receiverID
        newMessage.message = message
        newMessage.date = Date().timeIntervalSince1970
        PersistentStorage.shared.saveContext()
        print("Messages saved succesfully to the core data")
    }
    
    func fetchMessagesFromFirestore() {
        let senderID = Auth.auth().currentUser?.uid ?? "Nil"
        
        db.collection(K.FStore.messageCollection)
            .document("All User Messages")
            .collection("sender_receiver:\([senderID, recieverID].sorted())")
            .order(by: K.FStore.dateField)
            .addSnapshotListener { querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                    // As the error is occured now fetching the data from the coreDatabase
                    self.fetchMessagesFromCoreData(senderID: senderID, receiverID: self.recieverID)
                } else {
                    self.messageChats.removeAll()
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            
                            // Check if message is deleted by current user
                            let deletedByArray = data[K.FStore.deletedByIDField] as? [String] ?? []
                            
                            // Only show message if not deleted by current user
                            if !deletedByArray.contains(senderID) {
                                if let messageBody = data[K.FStore.messageField] as? String {
                                    let newMessage = MessageChat(senderID: data[K.FStore.senderID] as! String,
                                                              recieverID: data[K.FStore.recieverID] as! String,
                                                              message: messageBody)
                                    self.messageChats.append(newMessage)
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.chatTableView.reloadData()
                            if self.messageChats.count > 0 {
                                let indexPath = IndexPath(row: self.messageChats.count - 1, section: 0)
                                self.chatTableView.scrollToRow(at: indexPath, at: .top, animated: true)
                            }
                        }
                    }
                }
            }
    }
    
    func loadMessages() {
        
        fetchMessagesFromFirestore()
        
        // Here checking if there is no internet connection and the model array is empty than fetch messages from the core data
//        if messageChats.isEmpty {
//            // Fetching the data from the core data
//            fetchMessagesFromCoreData(senderID: senderID, receiverID: recieverID)
//        }
    }
    
    @IBAction func deletePressed(_ sender: Any) {
        let alert = UIAlertController(title: "Delete", message: "Are you sure you want to delete?", preferredStyle: .alert)
        
        let deleteButton = UIAlertAction(title: "Delete", style: .destructive) { _ in
            guard let currentUserID = Auth.auth().currentUser?.uid, let selectedRows = self.chatTableView.indexPathsForSelectedRows else { return }
            
            // For each selected message
            for indexPath in selectedRows {
                let message = self.messageChats[indexPath.row]
                
                // Finding and updating the message in the Firestore as settinf the field
                self.db.collection(K.FStore.messageCollection)
                    .document("All User Messages")
                    .collection("sender_receiver:\([currentUserID, self.recieverID].sorted())")
                    .whereField(K.FStore.messageField, isEqualTo: message.message)
                    .getDocuments { (snapshot, error) in
                        if let document = snapshot?.documents.first {
                            // Add current user's ID to deletedByIDField
                            document.reference.updateData([
                                K.FStore.deletedByIDField: [currentUserID]
                            ])
                        }
                }
                
                if let cell = self.chatTableView.cellForRow(at: indexPath) as? ChatCell {
                    cell.rightCheckBoxImageView.isHidden = true
                }
                
            }
            
            // Deselect all selected rows
            selectedRows.forEach { indexPath in
                self.chatTableView.deselectRow(at: indexPath, animated: true)
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
        
        // Modified Code
        if let messageBody = messageTextfield.text, let senderID = Auth.auth().currentUser?.uid {
            
            db.collection(K.FStore.messageCollection)
                .document("All User Messages")
                .collection("sender_receiver:\([senderID, recieverID].sorted())")
                .addDocument(data: [
                    K.FStore.senderID: senderID,
                    K.FStore.recieverID: recieverID,
                    K.FStore.messageField: messageBody,
                    K.FStore.dateField: Date().timeIntervalSince1970
                ]) { error in
                    if let e = error {
                        print("There was an issue saving messages to firestore, \(e)")
                    } else {
                        print("Successfully saved data.")
                        
                        self.loadMessages()
                        
                        print("Id before update current user")
                        print("Sender id is: \(senderID)")
                        print("Receiver id is: \(self.recieverID)")
                        
                        self.updateCurrentUsers(messageBody: messageBody, senderID: senderID, recieverID: self.recieverID)
                        
                        // Setting the text field to empty after clicking the send button
                        DispatchQueue.main.async {
                            self.messageTextfield.text = ""
                        }
                        print("merge the loading of two chats")
                    }
                }
        }
    }
    
    func updateCurrentUsers(messageBody: String, senderID: String, recieverID: String) {
        print("Id after update current user")
        print("Sender id is: \(senderID)")
        print("Receiver id is: \(recieverID)")
        
        // Saving data to current user recent chat
        db.collection(K.FStore.userCollection)
            .document(senderID)
            .collection(K.FStore.recentChats)
            .document(recieverID)
            .setData ([
                K.FStore.recieverID: recieverID,
                K.FStore.messageField: messageBody,
                K.FStore.dateField: Date().timeIntervalSince1970
            ]) { error in
                if let error = error {
                    print("Error updating user's recent chat: \(error)")
                } else {
                    print("Successfully updated user's recent chat.")
                }
            }
        
        // Saving data to reciever user recent chat
        db.collection(K.FStore.userCollection)
            .document(recieverID)
            .collection(K.FStore.recentChats)
            .document(senderID)
            .setData ([
                K.FStore.recieverID: senderID,
                K.FStore.messageField: messageBody,
                K.FStore.dateField: Date().timeIntervalSince1970
            ]) { error in
                if let error = error {
                    print("Error updating user's recent chat: \(error)")
                } else {
                    print("Successfully updated user's recent chat.")
                }
            }
    }
}

extension ChatScreenViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageChats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            
            // Check if the index is within bounds of the messageChats array
            if indexPath.row < messageChats.count {
                let messageChat = messageChats[indexPath.row]
                
                // Dequeue the cell
                let cell = tableView.dequeueReusableCell(withIdentifier: K.Identifiers.chatCellIdentifier, for: indexPath) as! ChatCell
                
                // Set up the cell
                cell.labelName.text = messageChat.message
                
                if messageChat.senderID == Auth.auth().currentUser?.uid {
                    // This is the sender's message
                    cell.leftImageView.isHidden = true
                    cell.rightImageView.isHidden = false
                    cell.messageBubble.backgroundColor = UIColor(
                        red: CGFloat(160) / 255.0,
                        green: CGFloat(214) / 255.0,
                        blue: CGFloat(131) / 255.0,
                        alpha: 1.0
                    )
                } else {
                    // This is the receiver's message
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

extension ChatScreenViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        print("Row \(indexPath.row) selected")
        
        if let cell = tableView.cellForRow(at: indexPath) as? ChatCell {
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
        
        if let cell = tableView.cellForRow(at: indexPath) as? ChatCell {
//            deleteBarButton.isHidden = false
            cell.rightCheckBoxImageView.image = UIImage(systemName: "circle")
            print("I got deselected")
        } else {
            print("I wont get deseelcted")
        }
        
        // Checking if all the selected rows are nil or not
        if tableView.indexPathsForSelectedRows == nil {
            deleteBarButton.isHidden = true
            if let cell = tableView.cellForRow(at: indexPath) as? ChatCell {
                cell.rightCheckBoxImageView.isHidden = true
            }
        }
        
    }
}
