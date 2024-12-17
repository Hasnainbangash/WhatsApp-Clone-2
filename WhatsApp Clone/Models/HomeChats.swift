//
//  HomeChats.swift
//  WhatsApp Clone
//
//  Created by Elexoft on 05/11/2024.
//

import Foundation

struct HomeChats {
    let name: String
    let id: String
    let type: ChatsType
}

enum ChatsType {
    case groupChat, simpleChat
}
