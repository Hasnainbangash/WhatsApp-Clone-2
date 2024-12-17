//
//  ChatScreenViewController.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 05/11/2024.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ChatScreenViewController: UIViewController {

    @IBOutlet weak var chatTableView: UITableView!
    @IBOutlet weak var messageTextfield: UITextField!
    
    let db = Firestore.firestore()
    
    var titleName  = ""
    var recieverID = ""
    
    var messageChats: [MessageChat] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        chatTableView.dataSource = self
        
        title = titleName
        
        print(recieverID)
        
        chatTableView.register(UINib(nibName: K.NibNames.chatCellNibName, bundle: nil), forCellReuseIdentifier: K.Identifiers.chatCellIdentifier)
        
        loadMessages()
    }
    
    func loadMessages() {
        // Modified Code
        let senderID = Auth.auth().currentUser?.uid ?? "Nil"
        
        db.collection(K.FStore.messageCollection)
            .document("All User Messages")
            .collection("sender_receiver:\([senderID, recieverID].sorted())")
            .order(by: K.FStore.dateField)
            .addSnapshotListener { querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                } else {
                    self.messageChats.removeAll()
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            
                            if let messageBody = data[K.FStore.messageField] as? String {
                                let newMessage = MessageChat(senderID: data[K.FStore.senderID] as! String, recieverID: data[K.FStore.recieverID] as! String, message: messageBody)
                                
                                // Appending data to the database
                                if (data[K.FStore.senderID] as? String == senderID && data[K.FStore.recieverID] as? String == self.recieverID) || (data[K.FStore.recieverID] as? String == senderID && data[K.FStore.senderID] as? String == self.recieverID) {
                                    
                                    self.messageChats.append(newMessage)
                                }
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
        let messageChat = messageChats[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: K.Identifiers.chatCellIdentifier, for: indexPath) as! ChatCell
        
        cell.labelName.text = messageChat.message
        
        if messageChat.senderID == Auth.auth().currentUser?.uid {
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
    }
}
