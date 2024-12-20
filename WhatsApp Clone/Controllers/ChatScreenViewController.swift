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
            let pred = NSPredicate(format: "(senderID == %@ AND receiverID == %@) OR (senderID == %@ AND receiverID == %@)",
                                   senderID, receiverID, receiverID, senderID)
            let sort = NSSortDescriptor(key: "date", ascending: true)
            
            request.predicate = pred
            request.sortDescriptors = [sort]
            
            let messages = try PersistentStorage.shared.context.fetch(request)
            messageChats = messages.map {
                MessageChat(senderID: $0.senderID!,
                            recieverID: $0.receiverID!,
                            message: $0.message!)
            }
            
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
    func saveMessageToCoreData(senderID: String, receiverID: String, message: String, date: TimeInterval) {
        // Check if message already exists
        let fetchRequest = Messages.fetchRequest() as NSFetchRequest<Messages>
        fetchRequest.predicate = NSPredicate(format: "message == %@", message)
        
        do {
            let existingMessages = try context.fetch(fetchRequest)
            if existingMessages.isEmpty {
                // Only save if message doesn't exist
                let newMessage = Messages(context: self.context)
                newMessage.senderID = senderID
                newMessage.receiverID = receiverID
                newMessage.message = message
                newMessage.date = date
                
                try PersistentStorage.shared.context.save()
                print("Message saved successfully to Core Data")
            }
        } catch {
            print("Error saving message to Core Data: \(error)")
        }
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
                    return
                }
                
                if let snapshotDocuments = querySnapshot?.documents {
                    // Create a set to track existing messages
                    var existingMessages = Set<String>()
                    
                    // Get existing messages from Core Data
                    do {
                        let request = Messages.fetchRequest() as NSFetchRequest<Messages>
                        let messages = try self.context.fetch(request)
                        existingMessages = Set(messages.compactMap { $0.message })
                    } catch {
                        print("Error fetching existing messages: \(error)")
                    }
                    
                    for doc in snapshotDocuments {
                        let data = doc.data()
                        let deletedByArray = data[K.FStore.deletedByIDField] as? [String] ?? []
                        
                        // Only process message if not deleted by current user
                        if !deletedByArray.contains(senderID) {
                            if let messageBody = data[K.FStore.messageField] as? String,
                               let messageSenderID = data[K.FStore.senderID] as? String,
                               let messageReceiverID = data[K.FStore.recieverID] as? String {
                                
                                // Only save if message doesn't exist in Core Data
                                if !existingMessages.contains(messageBody) {
                                    self.saveMessageToCoreData(
                                        senderID: messageSenderID,
                                        receiverID: messageReceiverID,
                                        message: messageBody,
                                        date: data[K.FStore.dateField] as? TimeInterval ?? Date().timeIntervalSince1970
                                    )
                                }
                            }
                        }
                    }
                    
                    // After saving new messages to Core Data, fetch and display all messages
                    self.fetchMessagesFromCoreData(senderID: senderID, receiverID: self.recieverID)
                }
            }
    }
    
    func loadMessages() {
        let senderID = Auth.auth().currentUser?.uid ?? "Nil"
        
        // First check if we have messages in Core Data
        fetchMessagesFromCoreData(senderID: senderID, receiverID: self.recieverID)
        
        // If no messages in Core Data, then fetch from Firestore
        if messageChats.isEmpty {
            fetchMessagesFromFirestore()
        }
    }
    
    private func deleteMessageFromFirestore(message: MessageChat, currentUserID: String) {
        db.collection(K.FStore.messageCollection)
            .document("All User Messages")
            .collection("sender_receiver:\([currentUserID, recieverID].sorted())")
            .whereField(K.FStore.messageField, isEqualTo: message.message)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error getting document for deletion: \(error)")
                    return
                }
                
                if let document = querySnapshot?.documents.first {
                    // Get current deletedBy array
                    var deletedByArray = document.data()[K.FStore.deletedByIDField] as? [String] ?? []
                    
                    // Add current user if not already in array
                    if !deletedByArray.contains(currentUserID) {
                        deletedByArray.append(currentUserID)
                    }
                    
                    // Update document with new deletedBy array
                    document.reference.updateData([
                        K.FStore.deletedByIDField: deletedByArray
                    ]) { error in
                        if let error = error {
                            print("Error updating deletedBy field: \(error)")
                        }
                    }
                }
            }
    }
    
    private func deleteMessageFromCoreData(message: MessageChat) {
        let fetchRequest: NSFetchRequest<Messages> = Messages.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "message == %@", message.message)
        
        do {
            let messages = try context.fetch(fetchRequest)
            for message in messages {
                context.delete(message)
            }
            try PersistentStorage.shared.context.save()
            print("Successfully deleted message from Core Data")
        } catch {
            print("Error deleting message from Core Data: \(error)")
        }
    }
    
    @IBAction func deletePressed(_ sender: Any) {
        let alert = UIAlertController(title: "Delete", message: "Are you sure you want to delete?", preferredStyle: .alert)
        
        let deleteButton = UIAlertAction(title: "Delete", style: .destructive) { _ in
            guard let currentUserID = Auth.auth().currentUser?.uid, let selectedRows = self.chatTableView.indexPathsForSelectedRows else { return }
            
            // For each selected message
            for indexPath in selectedRows {
                let message = self.messageChats[indexPath.row]
                
                // 1. Delete from Firestore
                self.deleteMessageFromFirestore(message: message, currentUserID: currentUserID)
                
                // 2. Delete from Core Data
                self.deleteMessageFromCoreData(message: message)
                
                // 3. Update UI
                if let cell = self.chatTableView.cellForRow(at: indexPath) as? ChatCell {
                    cell.rightCheckBoxImageView.isHidden = true
                }
            }
            
            // Deselect all rows
            selectedRows.forEach { indexPath in
                self.chatTableView.deselectRow(at: indexPath, animated: true)
            }
            
            // Reset UI
            self.deleteBarButton.isHidden = true
            
            // Refresh messages from Core Data
            if let currentUserID = Auth.auth().currentUser?.uid {
                self.fetchMessagesFromCoreData(senderID: currentUserID, receiverID: self.recieverID)
            }
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
