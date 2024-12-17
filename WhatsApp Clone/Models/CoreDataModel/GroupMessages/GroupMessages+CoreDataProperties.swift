//
//  GroupMessages+CoreDataProperties.swift
//  
//
//  Created by Elexoft on 17/12/2024.
//
//

import Foundation
import CoreData


extension GroupMessages {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GroupMessages> {
        return NSFetchRequest<GroupMessages>(entityName: "GroupMessages")
    }

    @NSManaged public var senderID: String?
    @NSManaged public var message: String?
    @NSManaged public var date: Double

}
