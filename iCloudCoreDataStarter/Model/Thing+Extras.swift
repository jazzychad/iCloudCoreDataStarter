//
//  Thing+Extras.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/24/21.
//

import Foundation
import CoreData
import UIKit

extension Thing {

    // I like to have a helper method that creates a new Thing with all the boilerplate values setup as necessary
    public class func newThing() -> Thing {
        let thing = Thing(context: CoreDataStack.shared.managedObjectContext)
        thing.identifier = UUID().uuidString
        thing.createdAt = Date()
        thing.displayOrder = -1

        return thing
    }

    // returns Thing object from Managed Object Context
    public class func from(managedObjectID: NSManagedObjectID) -> Thing {
        do {
            return try CoreDataStack.shared.managedObjectContext.existingObject(with: managedObjectID) as! Thing
        } catch {
            fatalError("error getting existing object with objectID: \(managedObjectID) - \(error as NSError)")
        }
    }

    // get count of Thing objects
    @nonobjc public class func count() -> Int {
        let fetchRequest: NSFetchRequest<Thing> = Thing.fetchRequest()
        fetchRequest.resultType = .countResultType
        do {
            let count = try CoreDataStack.shared.managedObjectContext.count(for: fetchRequest)
            return count
        } catch {
            print("error getting Thing count: %@", error as NSError)
            return 0
        }
    }

    @nonobjc public class func fetchedAllResultsRequest() -> NSFetchRequest<Thing> {
        let fetchRequest = NSFetchRequest<Thing>(entityName: "Thing")
        fetchRequest.returnsObjectsAsFaults = true
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "displayOrder", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        return fetchRequest
    }

    public class func duplicate(thing: Thing) -> Thing {
        let newThing = Thing.newThing()
        newThing.displayOrder = thing.displayOrder
        newThing.color = thing.color
        newThing.amount = thing.amount
        return thing
    }

    public class func upsertThingFromPrimitive(_ primitive: ThingPrimitive) -> Thing {
        // might be handy to know if you need to do any logic depending on whether this is a new Thing or not
        // let isNewThing: Bool = primitive.thing == nil

        let thing: Thing = primitive.thing ?? Thing.newThing()

        thing.amount = primitive.amount
        thing.color = primitive.color

        CoreDataStack.shared.saveContext()
        #if DEBUG
        print("new thing objectID: %@", (thing.objectID))
        #endif

        CoreDataStack.coerceObjectIds(managedObjects: [thing]) // needed to fix temporary object ID issue =/

        return thing
    }

    public class func deleteThings(_ things: [Thing]) {
        CoreDataStack.shared.managedObjectContext.performAndWait {
            for thing in things {
                // delete thing from data store
                CoreDataStack.shared.managedObjectContext.delete(thing)
            }
        }
        CoreDataStack.shared.saveContext()
    }

    public class func randomThing() -> Thing? {
        let fetchRequest: NSFetchRequest<Thing> = Thing.fetchRequest()
        fetchRequest.fetchOffset = Int.random(in: 0..<(Thing.count()))

        fetchRequest.fetchLimit = 1

        var fetchResults: [Thing]?
        CoreDataStack.shared.managedObjectContext.performAndWait {
            fetchResults = try? fetchRequest.execute()
        }

        if let fetchResults = fetchResults {
            if fetchResults.count > 0 {
                return fetchResults.first
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}


// MARK: - ThingPrimitive

public struct ThingPrimitive {
    let amount: Int64
    let color: UIColor?

    let thing: Thing? // if editing/updating an existing thing
}
