//
//  CoreDataDiffableFetchedResultsHandler.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/28/21.
//

import Foundation
import CoreData
import UIKit

// MARK: - Protocol Definitions

protocol CoreDataDiffableDataSourceSnapshotingApplying: NSObject  {
    func snapshot() -> NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
    func apply(_ snapshot: NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>, animatingDifferences: Bool, completion: (() -> Void)?)
}

protocol SectionContaining {
    var numberOfSections: Int { get }
}

// MARK: - Protocol Conformance

extension UITableView: SectionContaining {}
extension UICollectionView: SectionContaining {}

extension UITableViewDiffableDataSource: CoreDataDiffableDataSourceSnapshotingApplying where SectionIdentifierType == Int, ItemIdentifierType == NSManagedObjectID {}
extension UICollectionViewDiffableDataSource: CoreDataDiffableDataSourceSnapshotingApplying where SectionIdentifierType == Int, ItemIdentifierType == NSManagedObjectID {}

// MARK: -

class CoreDataDiffableFetchedResultsHandler: NSObject, NSFetchedResultsControllerDelegate {

    let diffableDatasource: CoreDataDiffableDataSourceSnapshotingApplying
    let sectionContiner: SectionContaining

    init(dataSource: CoreDataDiffableDataSourceSnapshotingApplying, container: SectionContaining) {
        diffableDatasource = dataSource
        sectionContiner = container
        super.init()

        // observe for `.coreDataUpdatedObjectIDs` notifcations so we can reload relevant cells
        NotificationCenter.default.addObserver(forName: .coreDataUpdatedObjectIDs, object: nil, queue: OperationQueue.main) { notification in
            if let objectIDs = notification.userInfo?["updatedObjectIDs"] as? [NSManagedObjectID] {
                self ._reloadUpdatedObjectIDs(objectIDs)
            }
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshotReference: NSDiffableDataSourceSnapshotReference) {
        var snapshot = snapshotReference as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
        let currentSnapshot = diffableDatasource.snapshot()

        // we find the identifiers of objects which are updated, so we can tell the snapshot to reload them
        // (they will not be automatically reloaded otherwise...)
        let reloadIdentifiers: [NSManagedObjectID] = snapshot.itemIdentifiers.compactMap { itemIdentifier in
            guard let currentIndex = currentSnapshot.indexOfItem(itemIdentifier), let index = snapshot.indexOfItem(itemIdentifier), index == currentIndex else {
                return nil
            }

            #if DEBUG
            if itemIdentifier.isTemporaryID == true {
                print("temp id detected in controller(didChangeContentWith:) !!!!! this may be bad")
            }
            #endif
            guard CoreDataStack.shared.managedObjectContext.object(with: itemIdentifier).isUpdated else { return nil }

            return itemIdentifier
        }
        snapshot.reloadItems(reloadIdentifiers)

        // collectionView.numberOfSections is 0 on initial load, so we don't
        // animate them the first time. That way the cells just appear immediately
        let shouldAnimate = sectionContiner.numberOfSections != 0

        // finally, we apply the snapshot and let the data source do its magic to the collection view
        diffableDatasource.apply(snapshot, animatingDifferences: shouldAnimate, completion: nil)
    }

    // called when we receive a `.coreDataUpdatedObjectIDs` notification
    private func _reloadUpdatedObjectIDs(_ objectIDs: [NSManagedObjectID]) {
        var currentSnapshot = diffableDatasource.snapshot() as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
        let reloadIdentifiers = objectIDs.compactMap { objectID in
            return (currentSnapshot.itemIdentifiers.contains(objectID) ? objectID : nil)
        }
        currentSnapshot.reloadItems(reloadIdentifiers)
        diffableDatasource.apply(currentSnapshot, animatingDifferences: true, completion: nil)

    }
}
