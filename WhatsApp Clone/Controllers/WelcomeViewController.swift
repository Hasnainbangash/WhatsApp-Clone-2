//
//  ViewController.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 04/11/2024.
//

import UIKit

class WelcomeViewController: UIViewController {

    @IBOutlet weak var welcomeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        welcomeLabel.text = "Welcome to WhatsApp"
    }
}
