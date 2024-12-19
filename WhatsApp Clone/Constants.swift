//
//  Constants.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 05/11/2024.
//

import Foundation

struct K {
    struct Segues {
        static let registerSegue = "RegisterToHomeScreen"
        static let loginSegue = "LoginToHomeScreen"
        static let homeSimpleChatScreenSegue = "HomeScreenToChatScreen"
        static let homeGroupChatScreenSegue = "HomeScreenToGroupChatScreen"
        static let newChatSegue = "NewChatToChatScreen"
        static let newGroupChatSegue = "NewGroupChatToHomeScreen"
    }
    
    struct Identifiers {
        static let homeCellIdentifier = "HomeReusableCell"
        static let chatCellIdentifier = "ChatReusableCell"
        static let groupChatCellIdentifier = "GroupChatReusableCell"
        static let newChatCellIdentifier = "NewChatReusableCell"
        static let newGroupChatCellIdentifier = "NewGroupChatReusableCell"
    }
    
    struct NibNames {
        static let homeCellNibName = "HomeScreenCell"
        static let chatCellNibName = "ChatCell"
        static let groupChatCellNibName = "GroupChatCell"
        static let newChatCellNibName = "NewChatCell"
        static let newGroupChatCellNibName = "NewGroupChatCell"
    }
    
    struct FStore {
//        static let twoUserMessageBucket = "sender:\(senderID)&receiver:\(recieverID)"
        static let twoUserMessageBucket = "Sender and Receiver Messages"
//        static let collectionName = "messages"
        static let userCollection = "Users"
        static let groupCollection = "Groups"
        static let messageCollection = "Messages"
        static let currentUserCollection = "CurrentUser"
        static let recentChats = "RecentChats"
//        static let homeCollectionName = "HomeChats"
//        static let chatCollectionName = "MessageChats"
//        static let newChatCollectionName = "NewChats"
        static let senderNameField = "senderName"
        static let emailField = "email"
        static let userIDField = "userID"
        static let senderID = "senderID"
        static let recieverID = "recieverID"
        static let bodyField = "body"
        static let messageField = "message"
        static let dateField = "date"
        static let messageIDField = "messageID"
        static let groupNameField = "GroupName"
        static let deletedByIDField = "deletedByIDField"
        static let deletedChatByIDField = "deletedChatByIDField"
    }
}

