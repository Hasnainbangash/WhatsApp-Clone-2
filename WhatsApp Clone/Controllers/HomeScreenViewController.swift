//
//  HomeScreenViewController.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 05/11/2024.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class HomeScreenViewController: UIViewController {
    
    @IBOutlet weak var homeTableView: UITableView!
    @IBOutlet weak var addButtonLabel: UIButton!
    
    // Reference to firestore database
    let db = Firestore.firestore()
    
    // For showing the title of the chat
    var titleName = ""
    var recieverID = ""
    var nameOfReceiver = ""
    
    // Array to store chat data
    var homeChats: [HomeChats] = []
    
    var deletedChatsBy: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        homeTableView.dataSource = self
        homeTableView.delegate = self
        
        navigationItem.hidesBackButton = true
        
        // Resizing the add button
        addButtonLabel.layer.cornerRadius = addButtonLabel.frame.size.height / 3
        
        homeTableView.register(UINib(nibName: K.NibNames.homeCellNibName, bundle: nil), forCellReuseIdentifier: K.Identifiers.homeCellIdentifier)
        
        loadRecentChats()
        loadRecentGroups()
        
    }
    
    func loadRecentChats() {
        let authUserID = Auth.auth().currentUser?.uid ?? "Nil"
        
        db.collection(K.FStore.userCollection)
            .document(authUserID)
            .collection(K.FStore.recentChats)
            .addSnapshotListener { querySnapshot, error in
                self.homeChats = []
                
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                    return
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            print("Function get run")
                            let data = doc.data()
                            
                            if let receiverID = data[K.FStore.recieverID] as? String {
                                
                                // Here defining closure body
                                self.gettingNameOfReceiverID(for: receiverID) { receiverName in
                                    DispatchQueue.main.async {
                                        let senderName = HomeChats(name: receiverName, id: receiverID, type: ChatsType.simpleChat)
                                        self.homeChats.append(senderName)
                                        self.homeTableView.reloadData()
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
    
    func gettingNameOfReceiverID(for id: String, gettingName: @escaping (String) -> Void) {
        
        //        let db = Firestore.firestore()
        
        var receiverName = ""
        
        print("--------------------------------------------")
        print(id)
        print("--------------------------------------------")
        
        db.collection(K.FStore.userCollection)
            .whereField(K.FStore.userIDField, isEqualTo: id)
            .getDocuments { querySnapshot, error in
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                    return
                } else {
                    print("Coming in this section")
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let name = data[K.FStore.senderNameField] as? String {
                                print(name)
                                receiverName = name
                            }
                        }
                    }
                    
                    print("------------adsadsadasdasdas--------------------------------")
                    print(receiverName)
                    print("------------adsadsadasdasdas--------------------------------")
                    
                    gettingName(receiverName)
                }
            }
    }
    
    func loadRecentGroups() {
        let currentUserID = Auth.auth().currentUser?.uid ?? "Nil"
        
        db.collection(K.FStore.groupCollection)
            .whereField(K.FStore.userIDField, arrayContains: currentUserID)
            .addSnapshotListener { querySnapshot, error in
                
                self.homeChats = []
                
                if let e = error {
                    print("There was an issue retrieving data from Firestore: \(e)")
                    return
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            
                            if let groupName = data[K.FStore.groupNameField] as? String {
                                let groupID = doc.documentID
                                
                                let group = HomeChats(name: groupName, id: groupID, type: ChatsType.groupChat)
                                self.homeChats.append(group)
                                
                                DispatchQueue.main.async {
                                    self.homeTableView.reloadData()
                                }
                            }
                        }
                    }
                }
            }
    }
    
    @IBAction func logOutPressed(_ sender: UIBarButtonItem) {
        do {
            try Auth.auth().signOut()
            
            // Instantiate the storyboard and the login view controller
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let loginVC = storyboard.instantiateViewController(withIdentifier: "WelcomeViewController") as? WelcomeViewController {
                
                // Create a new UINavigationController with loginVC as the root
                let navController = UINavigationController(rootViewController: loginVC)
                
                // Set the new navigation controller as the root view controller of the app window
                if let window = UIApplication.shared.keyWindow {
                    window.rootViewController = navController
                    window.makeKeyAndVisible()
                }
            }
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }

    
}

extension HomeScreenViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return homeChats.count // Return the number of chats
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Get the HomeChats object for this row
        let homeChat = homeChats[indexPath.row]
        
        // Dequeue the custom cell and set the name label
        let cell = tableView.dequeueReusableCell(withIdentifier: K.Identifiers.homeCellIdentifier, for: indexPath) as! HomeScreenCell
        cell.nameLabel.text = homeChat.name
        
        return cell
    }
}

extension HomeScreenViewController: UITableViewDelegate {
    
    // Handle the swipe action to delete a chat or group
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        guard indexPath.row < homeChats.count else {
            print("Index out of bounds for swipe action.")
            return nil
        }
        
        let homeChat = homeChats[indexPath.row]
        
        if homeChat.type == ChatsType.simpleChat {
            
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completionHandler in
                
                let alert = UIAlertController(title: "Delete", message: "Are you sure you want to delete?", preferredStyle: .alert)
                
                let deleteButton = UIAlertAction(title: "Delete", style: .destructive) { (action) in
                    print("DeleteButton pressed")
                    self.deleteChat(chatID: homeChat.id)
                    self.homeChats.remove(at: indexPath.row)
                    self.homeTableView.deleteRows(at: [indexPath], with: .automatic)
                }
                
                let cancelButton = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
                    print("Cancel Button pressed")
                }
                
                alert.addAction(deleteButton)
                alert.addAction(cancelButton)
                
                self.present(alert, animated: true, completion: nil)
                
                completionHandler(true)
            }
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }
        return nil
    }
    
    func deleteChat(chatID: String) {
        let currentUserID = Auth.auth().currentUser?.uid ?? "Nil"
        
        // First, fetch all messages
        db.collection(K.FStore.messageCollection)
            .document("All User Messages")
            .collection("sender_receiver:\([currentUserID, chatID].sorted())")
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error fetching messages: \(error)")
                    return
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            let docRef = doc.reference
                            
                            // Getting the existing deletedBy array or create new one
                            var deletedBy = doc.data()[K.FStore.deletedByIDField] as? [String] ?? []
                            
                            // Add the current user if not avaailable in the deletedBy array
                            if !deletedBy.contains(currentUserID) {
                                deletedBy.append(currentUserID)
                                docRef.updateData([
                                    K.FStore.deletedByIDField: deletedBy
                                ]) { error in
                                    if let error = error {
                                        print("Error updating deletedBy array: \(error)")
                                    } else {
                                        print("Successfully updated deletedBy array for message")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        
        // Delete from recent chats
        db.collection(K.FStore.userCollection)
            .document(currentUserID)
            .collection(K.FStore.recentChats)
            .document(chatID)
            .delete { error in
                if let error = error {
                    print("Error deleting recent chat: \(error)")
                } else {
                    print("Successfully deleted from recent chats")
                }
            }
    }
    
    // Handle cell selection and perform segue
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Row \(indexPath.row) selected")
        
        guard indexPath.row < homeChats.count else {
            print("Index out of bounds for swipe action.")
            return
        }
        
        let homeChat = homeChats[indexPath.row]
        
        titleName = homeChats[indexPath.row].name
        recieverID = homeChats[indexPath.row].id
        
        if homeChat.type == ChatsType.simpleChat {
            print("I am now in simple chat screen")
            self.performSegue(withIdentifier: K.Segues.homeSimpleChatScreenSegue, sender: self)
        }
        
        if homeChat.type == ChatsType.groupChat {
            print("I am now in group chat screen")
            self.performSegue(withIdentifier: K.Segues.homeGroupChatScreenSegue, sender: self)
        }
        
        // Deselect the row after selection
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == K.Segues.homeSimpleChatScreenSegue {
            
            let destinationVC = segue.destination as! ChatScreenViewController
            
            destinationVC.titleName = titleName
            destinationVC.recieverID = recieverID
        }
        
        if segue.identifier == K.Segues.homeGroupChatScreenSegue {
            
            let destinationVC = segue.destination as! GroupChatScreenViewController
            
            destinationVC.titleName = titleName
            destinationVC.groupID = recieverID
        }
    }
}
