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
    
    func fetchMessagesFromCoreData(senderID: String, receiverID: String) {
        do {
            let request = Messages.fetchRequest() as NSFetchRequest<Messages>
            // Add isDelete == false to the predicate
            let pred = NSPredicate(format: "((senderID == %@ AND receiverID == %@) OR (senderID == %@ AND receiverID == %@)) AND isDelete == false",
                                   senderID, receiverID, receiverID, senderID)
            let sort = NSSortDescriptor(key: "date", ascending: true)
            
            request.predicate = pred
            request.sortDescriptors = [sort]
            
            let messages = try PersistentStorage.shared.context.fetch(request)
            messageChats = messages.map {
                MessageChat(
                    id: $0.messageID ?? UUID().uuidString,
                    senderID: $0.senderID!,
                    recieverID: $0.receiverID!,
                    message: $0.message!,
                    date: $0.date
                )
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
    
    // Modified saveMessageToCoreData function
    func saveMessageToCoreData(messageID: String, senderID: String, receiverID: String, message: String, date: TimeInterval) {
        // Check if message with this ID already exists
        let request = Messages.fetchRequest() as NSFetchRequest<Messages>
        let pred = NSPredicate(format: "messageID == %@", messageID)
        request.predicate = pred
        
        do {
            let existingMessages = try context.fetch(request)
            if existingMessages.isEmpty {
                let newMessage = Messages(context: self.context)
                newMessage.messageID = messageID
                newMessage.senderID = senderID
                newMessage.receiverID = receiverID
                newMessage.message = message
                newMessage.date = date
                newMessage.isDelete = false  // Add this field to your Core Data model
                
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
                    for doc in snapshotDocuments {
                        let data = doc.data()
                        let deletedByArray = data[K.FStore.deletedByIDField] as? [String] ?? []

                        if !deletedByArray.contains(senderID) {
                            if let messageBody = data[K.FStore.messageField] as? String,
                               let messageSenderID = data[K.FStore.senderID] as? String,
                               let messageReceiverID = data[K.FStore.recieverID] as? String {
                                
                                self.saveMessageToCoreData(
                                    messageID: doc.documentID,
                                    senderID: messageSenderID,
                                    receiverID: messageReceiverID,
                                    message: messageBody,
                                    date: data[K.FStore.dateField] as? TimeInterval ?? Date().timeIntervalSince1970
                                )
                            }
                        }
                    }
                    
                    // After saving data to Core Data, fetch and display all messages
                    self.fetchMessagesFromCoreData(senderID: senderID, receiverID: self.recieverID)
                }
            }
    }
    
    func loadMessages() {
        let senderID = Auth.auth().currentUser?.uid ?? "Nil"
        
        // Checking the messages are present in the core data or not
        fetchMessagesFromCoreData(senderID: senderID, receiverID: self.recieverID)
        
        // If there is no messages in the core data then fetch from the firestore
        fetchMessagesFromFirestore()
        //        if messageChats.isEmpty {
        //            fetchMessagesFromFirestore()
        //        }
    }
    
    private func deleteMessageFromFirestore(message: MessageChat, currentUserID: String) {
        // Use the message ID instead of message content
        db.collection(K.FStore.messageCollection)
            .document("All User Messages")
            .collection("sender_receiver:\([currentUserID, recieverID].sorted())")
            .document(message.id)  // Use the message ID directly
            .getDocument { (document, error) in
                if let error = error {
                    print("Error getting document for deletion: \(error)")
                    return
                }
                
                if let document = document, document.exists {
                    // Getting the deleted by array
                    var deletedByArray = document.data()?[K.FStore.deletedByIDField] as? [String] ?? []
                    
                    // Add current user if not already in array
                    if !deletedByArray.contains(currentUserID) {
                        deletedByArray.append(currentUserID)
                        
                        // Updating the document with new deletedBy array
                        document.reference.updateData([
                            K.FStore.deletedByIDField: deletedByArray
                        ]) { error in
                            if let error = error {
                                print("Error updating deletedBy field: \(error)")
                            } else {
                                print("Successfully updated deletedBy array in Firestore")
                            }
                        }
                    }
                }
            }
    }

    
    // Modified deleteMessageFromCoreData function
    private func deleteMessageFromCoreData(message: MessageChat) {
        let request = Messages.fetchRequest() as NSFetchRequest<Messages>
        let pred = NSPredicate(format: "messageID == %@", message.id)
        request.predicate = pred
        
        do {
            let messages = try context.fetch(request)
            for message in messages {
                message.isDelete = true
            }
            try PersistentStorage.shared.context.save()
            print("Successfully marked message as deleted in Core Data")
        } catch {
            print("Error marking message as deleted in Core Data: \(error)")
        }
    }
    
    @IBAction func deletePressed(_ sender: Any) {
        let alert = UIAlertController(title: "Delete", message: "Are you sure you want to delete?", preferredStyle: .alert)
        
        let deleteButton = UIAlertAction(title: "Delete", style: .destructive) { _ in
            guard let currentUserID = Auth.auth().currentUser?.uid,
                  let selectedRows = self.chatTableView.indexPathsForSelectedRows else { return }
            
            // For each selected message
            for indexPath in selectedRows {
                let message = self.messageChats[indexPath.row]
                
                // Delete from Firestore first
                self.deleteMessageFromFirestore(message: message, currentUserID: currentUserID)
                
                // Then delete from Core Data
                self.deleteMessageFromCoreData(message: message)
            }
            
            // Deselect all rows
            selectedRows.forEach { indexPath in
                self.chatTableView.deselectRow(at: indexPath, animated: true)
            }
            
            // Reset UI
            self.deleteBarButton.isHidden = true
            
            // Refresh messages from Core Data
            if let currentUserID = Auth.auth().currentUser?.uid {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.fetchMessagesFromCoreData(senderID: currentUserID, receiverID: self.recieverID)
                }
            }
        }
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(deleteButton)
        alert.addAction(cancelButton)
        
        self.present(alert, animated: true)
    }
    
    // Modified sendPressed function
    @IBAction func sendPressed(_ sender: UIButton) {
        if let messageBody = messageTextfield.text, let senderID = Auth.auth().currentUser?.uid {
            let newDocRef = db.collection(K.FStore.messageCollection)
                .document("All User Messages")
                .collection("sender_receiver:\([senderID, recieverID].sorted())")
                .document()  // Generate new document ID
            
            newDocRef.setData([
                K.FStore.senderID: senderID,
                K.FStore.recieverID: recieverID,
                K.FStore.messageField: messageBody,
                K.FStore.dateField: Date().timeIntervalSince1970,
                K.FStore.deletedByIDField: []
            ]) { error in
                if let e = error {
                    print("There was an issue saving messages to firestore, \(e)")
                } else {
                    print("Successfully saved data.")
                    self.messageTextfield.text = ""
                    self.updateCurrentUsers(messageBody: messageBody, senderID: senderID, recieverID: self.recieverID)
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
