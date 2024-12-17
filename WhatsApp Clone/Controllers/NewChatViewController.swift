//
//  NewChatViewController.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 05/11/2024.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class NewChatViewController: UIViewController {
    
    @IBOutlet weak var newChatTableView: UITableView!
    
    let db = Firestore.firestore()
    
    // For showing the title of the chat
    var titleName = ""
    var recieverID = ""
    
    var newChats: [NewChats] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        //        homeTableView.register(UINib(nibName: K.NibNames.homeCellNibName, bundle: nil), forCellReuseIdentifier: K.Identifiers.homeCellIdentifier)
        
        newChatTableView.dataSource = self
        newChatTableView.delegate = self
        
        newChatTableView.register(UINib(nibName: K.NibNames.newChatCellNibName, bundle: nil), forCellReuseIdentifier: K.Identifiers.newChatCellIdentifier)
        
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
                                    self.newChatTableView.reloadData()
                                }
                            }
                        }
                    }
                }
            }
    }
}

extension NewChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newChats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let newChat = newChats[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: K.Identifiers.newChatCellIdentifier, for: indexPath) as! NewChatCell
        cell.nameLabel.text = newChat.name
        
        return cell
    }
}

extension NewChatViewController: UITableViewDelegate {
    
    // Handle cell selection and perform segue
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Row \(indexPath.row) selected")
        
        titleName = newChats[indexPath.row].name
        recieverID = newChats[indexPath.row].id
        
        self.performSegue(withIdentifier: K.Segues.newChatSegue, sender: self)
        
        // Deselect the row after selection
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == K.Segues.newChatSegue {
            
            let destinationVC = segue.destination as! ChatScreenViewController
            
//            destinationVC.titleName = Auth.auth().currentUser?.displayName ?? "Nil"
            destinationVC.titleName = titleName
            destinationVC.recieverID = recieverID
        }
    }
}
