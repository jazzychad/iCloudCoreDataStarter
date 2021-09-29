//
//  ExtensionCoreDataUpdateListener.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/24/21.
//

import Foundation

extension Notification.Name {
    static let externalCoreDataUpdate = Notification.Name(rawValue: "ExternalCoreDataUpdateNotification")
}

final public class CoreDataDistributedUpdateListener: NSObject {

    // the inter-process NotificationCenter
    private let center = CFNotificationCenterGetDarwinNotifyCenter()
    private var listenersStarted = false
    fileprivate static let notificationName = "com.example.iCloudCoreDataStarter.CoreDataExtensionUpdate" as CFString

    public override init() {
        super.init()
        // listen for an action in extension(s)
        startListeners()
    }

    deinit {
        // don't listen anymore
        stopListeners()
    }

    fileprivate func startListeners() {
        if !listenersStarted {
            self.listenersStarted = true
            CFNotificationCenterAddObserver(center, Unmanaged.passRetained(self).toOpaque(), { (center, observer, name, object, userInfo) in

                // do the thing
                DispatchQueue.main.async {
                    #if DEBUG
                    print("GOT CORE DATA UPDATE CFNOTIF")
                    #endif
                    CoreDataStack.shared.processPersistentHistory()
                    NotificationCenter.default.post(name: .externalCoreDataUpdate, object: nil)
                }

            }, Self.notificationName, nil, .deliverImmediately)
        }
    }

    fileprivate func stopListeners() {
        if listenersStarted {
            CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passRetained(self).toOpaque())
            listenersStarted = false
        }
    }
}

// MARK: -

final public class CoreDataDistributedUpdateEvent: NSObject {
    public static func post() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(rawValue: CoreDataDistributedUpdateListener.notificationName), nil, nil, true)
    }
}
