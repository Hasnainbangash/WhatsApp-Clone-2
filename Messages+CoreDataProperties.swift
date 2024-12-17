//
//  Messages+CoreDataProperties.swift
//  
//
//  Created by Elexoft on 17/12/2024.
//
//

import Foundation
import CoreData


extension Messages {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Messages> {
        return NSFetchRequest<Messages>(entityName: "Messages")
    }

    @NSManaged public var senderID: String?
    @NSManaged public var receiverID: String?
    @NSManaged public var message: String?
    @NSManaged public var date: Double

}
