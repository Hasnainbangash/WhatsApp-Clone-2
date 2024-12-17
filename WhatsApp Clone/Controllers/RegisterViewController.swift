//
//  RegisterViewController.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 05/11/2024.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class RegisterViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func registerPressed(_ sender: UIButton) {
        if let email = emailTextField.text, let password = passwordTextField.text, let name = nameTextField.text {
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let e = error {
                    print(e)
                } else {
                    print("User successfully get registered")
                    
                    if let userName = authResult?.user {
                        self.saveUserNameToFirestore(userId: userName.uid, name: name)
                    }
                    
                    self.performSegue(withIdentifier: K.Segues.registerSegue, sender: self)
                }
            }
        }
    }
    
    func saveUserNameToFirestore(userId: String, name: String) {
        if let senderEmail = Auth.auth().currentUser?.email {
            // Sending the user's name and email to Firestore
            
//            db.collection(K.FStore.collectionName).document(userId).setData(userId)
            
            db.collection(K.FStore.userCollection).addDocument(data: [
                K.FStore.senderNameField: name,
                K.FStore.emailField: senderEmail,
                K.FStore.userIDField: userId,
                K.FStore.dateField: Date().timeIntervalSince1970
            ]) { error in
                if let e = error {
                    print("There was an issue saving data to Firestore, \(e)")
                } else {
                    print("Successfully saved user's name to Firestore.")
                }
            }
            
//            db.collection(K.FStore.collectionName).document(userId).setData([
//                K.FStore.senderField: name,
//                K.FStore.emailField: emailSender,
//                K.FStore.userIDField: userId,
//                K.FStore.dateField: Date().timeIntervalSince1970
//            ]) { error in
//                if let e = error {
//                    print("There was an issue saving data to Firestore, \(e)")
//                } else {
//                    print("Successfully saved user's name to Firestore.")
//                }
//            }
        }
    }
    
}
