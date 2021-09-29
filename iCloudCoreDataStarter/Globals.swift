//
//  Globals.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/28/21.
//

import Foundation

let kSharedCoreDataStackConfig: CoreDataStackConfig = CoreDataStackConfig(
    appGroupIdentifier: "group.com.example.iCloudCoreDataStarter", // the App Group identifier registered with your Capabailityes/provisioning profile
    iCloudContainerIdentifier: "iCloud.com.example.iCloudCoreDataStarter.iCloud", // the iCloud container identifier registered with your Capabilites/provisioning profile
    databaseName: "iCloudCoreDataStarter_iCloud", // this will be the .sqlite file created on disk for your database
    managedObjectModelName: "iCloudCoreDataStarter", // name of the .xcdatamodeld file in your project (minus .xcdatamodeld)
    persistentContainerName: "iCloudCoreDataStarterContainer" // an arbitrary name for the NSPersistentCloudKitContainer that will be created
)
