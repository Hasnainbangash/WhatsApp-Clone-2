//
//  NewGroupChatViewController.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 11/11/2024.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class NewGroupChatViewController: UIViewController {

    @IBOutlet weak var newGroupChatTableView: UITableView!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var newGroupNameTextField: UITextField!
    
    let db = Firestore.firestore()
    
    // For showing the title of the chat
    var titleName = ""
    var recieverID = ""
    
    var newChats: [NewChats] = []
    var newGroupChats: [NewGroupChats] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        doneButton.isHidden = true
        newGroupNameTextField.isHidden = true
        
        newGroupChatTableView.dataSource = self
        newGroupChatTableView.delegate = self
        newGroupChatTableView.allowsMultipleSelection = true
        
        newGroupChatTableView.register(UINib(nibName: K.NibNames.newGroupChatCellNibName, bundle: nil), forCellReuseIdentifier: K.Identifiers.newGroupChatCellIdentifier)

        
        loadNewChats()
    }
    
    func loadNewChats() {
        let senderID = Auth.auth().currentUser?.uid ?? "Nil"
        db.collection(K.FStore.userCollection)
            .whereField(K.FStore.userIDField, isNotEqualTo: senderID)
            .addSnapshotListener { querySnapshot, error in
                
                self.newChats = []
                
                if let e = error {
                    print(print("There was an issue retrieving data from Firestore: \(e)"))
                    return
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let senderName = data[K.FStore.senderNameField] as? String, let userID = data[K.FStore.userIDField] as? String{
                                
                                let senderName = NewChats(name: senderName, id: userID)
                                self.newChats.append(senderName)
                                
                                DispatchQueue.main.async {
                                    self.newGroupChatTableView.reloadData()
                                }
                            }
                        }
                    }
                }
            }
    }

    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        if let groupName = newGroupNameTextField.text {
            
            let senderID = Auth.auth().currentUser?.uid ?? "Nil"
            let senderName = Auth.auth().currentUser?.displayName ?? "Nil"
            newGroupChats.append(NewGroupChats(name: senderName, id: senderID))
            
            let selectedIds = newGroupChats.map { $0.id }
            
            db.collection(K.FStore.groupCollection).addDocument(data: [
                K.FStore.groupNameField: groupName,
                K.FStore.userIDField: selectedIds,
                K.FStore.dateField: Date().timeIntervalSince1970
            ]) { error in
                if let e = error {
                    print("There was an issue saving the group to firestore, \(e)")
                } else {
                    print("Successfully saved group name to firestore.")
                    self.newGroupNameTextField.text = ""
                    
                    self.performSegue(withIdentifier: K.Segues.newGroupChatSegue, sender: self)
                }
            }
        }
    }
    
}

extension NewGroupChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newChats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let newChat = newChats[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: K.Identifiers.newGroupChatCellIdentifier, for: indexPath) as! NewGroupChatCell
        cell.nameLabel.text = newChat.name
        
        return cell
    }
}

extension NewGroupChatViewController: UITableViewDelegate {

    // Handle cell selection and perform segue
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Row \(indexPath.row) selected")
        
        if let cell = tableView.cellForRow(at: indexPath) as? NewGroupChatCell {
            cell.rightCheckBoxImageView.image = UIImage(systemName: "checkmark.circle.fill")
            doneButton.isHidden = false
            newGroupNameTextField.isHidden = false
            print("I got selected")
            
            let newChat = newChats[indexPath.row]
            let selectedOne = NewGroupChats(name: newChat.name, id: newChat.id)
            newGroupChats.append(selectedOne)
            
            print(newGroupChats)
            
        } else {
            print("No image here")
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? NewGroupChatCell {
            cell.rightCheckBoxImageView.image = UIImage(systemName: "circle")
            print("i got deselect")
            
            // Removing the deselected row from the array
            newGroupChats.remove(at: indexPath.row)
            print(newGroupChats)
            
        } else {
            print("No image here")
        }
        
        // Checking if all the selected rows are nil or not
        if tableView.indexPathsForSelectedRows == nil {
            doneButton.isHidden = true
            newGroupNameTextField.isHidden = true
        }
    }
}
