//
//  CoreDataStack.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/24/21.
//

import Foundation
import CoreData
import UIKit

extension Notification.Name {
    static let coreDataUpdatedObjectIDs = Notification.Name(rawValue: "CoreDataUpdatedObjectIDsNotification")
}

// MARK: -

extension URL {
    static func storeURLForAppGroup(_ appGroup: String, databaseName: String) throws -> URL {
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        guard groupURL != nil else {
            throw NSError(domain: "com.example.CoreDataStack", code: -100, userInfo: nil)
        }
        let dbURL = groupURL!.appendingPathComponent("\(databaseName).sqlite")
        return dbURL
    }
}

// MARK: -

public struct CoreDataStackConfig {
    let appGroupIdentifier: String
    let iCloudContainerIdentifier: String
    let databaseName: String
    let managedObjectModelName: String
    let persistentContainerName: String
}

// MARK: -

private var stackConfig: CoreDataStackConfig? = nil

public func configureCoreDataStack(withConfig config: CoreDataStackConfig) {
    stackConfig = config
}

// MARK: -

class CoreDataStack {

    private var config: CoreDataStackConfig? = nil

    var authorName: String = "app" // used for bookkeeping transaction history. set appropriately on app/extension launch

    static var shared: CoreDataStack = { return CoreDataStack(withConfig: stackConfig) }()

    // this method is needed as a hack to assign a non-temporary objectID to an NSManagedObject even after a ManagedObjectContext.save() is called
    // ... the fact that temporary IDs can remain after a .save() seems like a bug, and this is a workaround to be called after you call .save() when creating new objects
    public class func coerceObjectIds(managedObjects: [NSManagedObject]) {
        for managedObject in managedObjects {
            print("coercing objectId for thing.objectId: %@", managedObject.objectID)
            CoreDataStack.shared.managedObjectContext.refresh(managedObject, mergeChanges: true)  // needed to fix temporary object ID issue :(
            if managedObject.objectID.isTemporaryID {
                print("thing.objectId is still temporary after MOC refresh...")
                do {
                    try CoreDataStack.shared.managedObjectContext.obtainPermanentIDs(for: [managedObject])
                    print("permanent objectId is: %@", managedObject.objectID)
                } catch {
                    print("!!! could not obtain permanent objectId for thing")
                }
            }
            print("thing.objectId is now: ", managedObject.objectID)
        }
    }

    lazy var persistentContainer: NSPersistentCloudKitContainer = {

        if let config = self.config {


            // register value transofrmers here!
            NSSecureCodingValueTransformer<UIColor>.registerTransformer()

            // Create a container that can load CloudKit-backed stores
            let managedObjectModelURL = Bundle.init(for: CoreDataStack.self).url(forResource: config.managedObjectModelName, withExtension: "momd")
            let managedObjectModel = NSManagedObjectModel(contentsOf: managedObjectModelURL!)
            let container = NSPersistentCloudKitContainer(name: config.persistentContainerName, managedObjectModel: managedObjectModel!)

            let storeURL = try! URL.storeURLForAppGroup(config.appGroupIdentifier, databaseName: config.databaseName)
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: config.iCloudContainerIdentifier)

            container.persistentStoreDescriptions = [storeDescription]

            // Enable history tracking and remote notifications
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("###\(#function): Failed to retrieve a persistent store description.")
            }
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            container.loadPersistentStores(completionHandler: { (_, error) in
                guard let error = error as NSError? else { return }
                fatalError("###\(#function): Failed to load persistent stores:\(error)")
            })

            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.transactionAuthor = self.authorName
            container.viewContext.stalenessInterval = 0

            do {
                try container.viewContext.setQueryGenerationFrom(.current)
            } catch {
                fatalError("###\(#function): Failed to pin viewContext to the current generation:\(error)")
            }

            //
            // Observe Core Data remote change notifications.
            NotificationCenter.default.addObserver(
                self, selector: #selector(type(of: self).storeRemoteChange(_:)),
                name: .NSPersistentStoreRemoteChange, object: container)

            return container

        } else {
            fatalError("CoreDataStack.config must be set before calling `persistenContainer`")
        }
    }()

    var managedObjectContext: NSManagedObjectContext {
        get {
            return persistentContainer.viewContext
        }
    }
    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                CoreDataDistributedUpdateEvent.post()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // MARK: - History tracking

    // Track the last history token processed for a store, and write its value to file.
    // The historyQueue reads the token when executing operations, and updates it after processing is complete.
    private var lastHistoryToken: NSPersistentHistoryToken? = nil {
        didSet {
            guard let token = lastHistoryToken,
                  let data = try? NSKeyedArchiver.archivedData( withRootObject: token, requiringSecureCoding: true)
            else {
                return
            }

            do {
                try data.write(to: tokenFile)
            } catch {
                print("Failed to write token data. Error = \(error)")
            }
        }
    }

    // The file URL for persisting the persistent history token.
    private lazy var tokenFile: URL = {
        if let config = self.config {
            let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: config.appGroupIdentifier)!.appendingPathComponent("CoreDataHistory", isDirectory: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create persistent container URL. Error = \(error)")
                }
            }
            let bundleId = Bundle.main.bundleIdentifier!  // hope you have a bundleId!
            let tokenURL = url.appendingPathComponent(bundleId + ".token.data", isDirectory: false)
            print("tokenURL: ", tokenURL)

            return tokenURL
        } else {
            fatalError("CoreDataStack.config must be set before calling `tokenFile`")
        }
    }()


    // An operation queue for handling history processing tasks: watching changes and triggering UI updates if needed.
    private lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    required init(withConfig config: CoreDataStackConfig?) {
        if config == nil {
            fatalError("must call `configureCoreDataStack` before using CoreDataStack.shared")
        }
        self.config = config
        // Load the last token from the token file.
        if let tokenData = try? Data(contentsOf: tokenFile) {
            do {
                lastHistoryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: tokenData)
            } catch {
                print("Failed to unarchive NSPersistentHistoryToken. Error = \(error)")
            }
        }
    }
}


// MARK: - Notifications

extension CoreDataStack {

    // Handle remote store change notifications (.NSPersistentStoreRemoteChange).
    @objc func storeRemoteChange(_ notification: Notification) {
        // Process persistent history to merge changes from other coordinators.
        historyQueue.addOperation {
            self.processPersistentHistory()
        }
    }
}

// MARK: - Persistent history processing

extension CoreDataStack {

    func processPersistentHistory() {
        let taskContext = persistentContainer.newBackgroundContext()
        taskContext.performAndWait {

            // Fetch history received from outside the app since the last token
            let historyFetchRequest = NSPersistentHistoryTransaction.fetchRequest!
            historyFetchRequest.predicate = NSPredicate(format: "author != %@", self.authorName)
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: lastHistoryToken)
            request.fetchRequest = historyFetchRequest

            let result = (try? taskContext.execute(request)) as? NSPersistentHistoryResult
            guard let transactions = result?.result as? [NSPersistentHistoryTransaction],
                  !transactions.isEmpty
            else { return }

            // keep track of which objects have been udpated
            var updatedObjectIDs: [NSManagedObjectID] = []

            // the meat and potatoes
            transactions.forEach { transaction in
                guard let userInfo = transaction.objectIDNotification().userInfo else { return }
                print("transaction userInfo: ", userInfo)
                let viewContext = persistentContainer.viewContext
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [viewContext])

                transaction.changes?.forEach({ historyChange in
                    if historyChange.changeType == .update {
                        updatedObjectIDs.append(historyChange.changedObjectID)
                    }
                })
            }

            // inserts and deletes get magically handled very well by the
            // NSFetchedResultsController + DiffableDataSource machinery,
            // but updates don't do so well... need to apply a little more force
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .coreDataUpdatedObjectIDs, object: self, userInfo: ["updatedObjectIDs" : updatedObjectIDs])
            }

            // Update the history token using the last transaction.
            lastHistoryToken = transactions.last!.token
        }
    }
}
