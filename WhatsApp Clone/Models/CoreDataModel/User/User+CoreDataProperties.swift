//
//  User+CoreDataProperties.swift
//  
//
//  Created by Elexoft on 17/12/2024.
//
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var date: Date?
    @NSManaged public var email: String?
    @NSManaged public var senderName: String?
    @NSManaged public var userID: String?

}
