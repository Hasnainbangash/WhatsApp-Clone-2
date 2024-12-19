//
//  GroupChatCell.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 12/11/2024.
//

import UIKit

class GroupChatCell: UITableViewCell {

    @IBOutlet weak var messageBubble: UIView!
    @IBOutlet weak var labelName: UILabel!
    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var rightImageView: UIImageView!
    @IBOutlet weak var rightCheckBoxImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        messageBubble.layer.cornerRadius = messageBubble.frame.size.height / 5
        
        // Rounding the image
        leftImageView.layer.cornerRadius = leftImageView.frame.size.height / 3
        
        rightImageView.layer.cornerRadius = rightImageView.frame.size.height / 3
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
