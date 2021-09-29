//
//  ViewController.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/24/21.
//

import UIKit
import CoreData

// DebugDiffableDataSourceReference is taken from: https://www.avanderlee.com/swift/diffable-data-sources-core-data/
// very handy for viewing what Diffable Data Source operations are happening, as they happen
// DO NOT SUBMIT THIS IN A PRODUCTION APP - IT USES PRIVATE APIs,
// THAT IS WHY IT IS SURROUNDED BY #if DEBUG
#if DEBUG
final class DebugDiffableDataSourceReference<SectionIdentifier, ItemIdentifier>: UICollectionViewDiffableDataSource<SectionIdentifier, ItemIdentifier> where SectionIdentifier: Hashable, ItemIdentifier: Hashable {

    @objc func _collectionView(_ collectionView: UICollectionView, willPerformUpdates updates: [UICollectionViewUpdateItem]) {
        print("DDS updates: \(updates)")
    }
}
#endif

enum ThingCollectionViewSelectionMode {
    case single
    case multi
}

class ThingRootCollectionViewController: UICollectionViewController,            // we are a UICollectionViewController subclass
                                         NSFetchedResultsControllerDelegate,    // we get NSFetchedResultsController callbacks to manipulate the diffable data source
                                         UICollectionViewDelegateFlowLayout,    // we tell the collectionView's flow layout how to size the cells
                                         UICollectionViewDragDelegate,          // we let users drag items in the collectionView
                                         UICollectionViewDropDelegate           // we let users drop items in the collectionView
{

    private var fetchedResultsController: NSFetchedResultsController<Thing> = NSFetchedResultsController(
        fetchRequest: Thing.fetchedAllResultsRequest(),
        managedObjectContext: CoreDataStack.shared.managedObjectContext,
        sectionNameKeyPath: nil,
        cacheName: nil
    )

    #if DEBUG
    private var diffableDatasource: DebugDiffableDataSourceReference<Int, NSManagedObjectID>!
    #else
    private var diffableDatasource: UICollectionViewDiffableDataSource<Int, NSManagedObjectID>!
    #endif

    var selectBarButtonItem: UIBarButtonItem!
    var addBarButtonItem: UIBarButtonItem!
    var selectionMenuBarButtonItem: UIBarButtonItem!

    var selectionMode: ThingCollectionViewSelectionMode = .single {
        didSet {
            if self.selectionMode == .single {
                self.collectionView.allowsMultipleSelection = false
            } else if self.selectionMode == .multi {
                self.collectionView.allowsMultipleSelection = true
            }
            let indexPaths = self.collectionView.indexPathsForVisibleItems
            for indexPath in indexPaths {
                if let cell = self.collectionView.cellForItem(at: indexPath) {
                    cell.isSelected = false
                }
            }
            self._deselectAllCells()
        }
    }

    private var diffableFetchedResultsHandler: CoreDataDiffableFetchedResultsHandler!

    override func viewDidLoad() {
        super.viewDidLoad()

        _setupNavigationItems()

        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.isAccessibilityElement = false
        collectionView.shouldGroupAccessibilityChildren = true
        collectionView.alwaysBounceVertical = true
        collectionView.register(ThingCollectionViewCell.self, forCellWithReuseIdentifier: "ThingCell")

        #if DEBUG
        diffableDatasource = DebugDiffableDataSourceReference<Int, NSManagedObjectID>(collectionView: collectionView, cellProvider: self._thingCellProvider())
        #else
        diffableDatasource = UICollectionViewDiffableDataSource<Int, NSManagedObjectID>(collectionView: collectionView, cellProvider: self._thingCellProvider())
        #endif
        collectionView.dataSource = diffableDatasource

        diffableFetchedResultsHandler = CoreDataDiffableFetchedResultsHandler(dataSource: diffableDatasource, container: self.collectionView)
        fetchedResultsController.delegate = diffableFetchedResultsHandler

        // we DO NOT setup an initial diffableDatasource snapshot (this may seem counter-intuitive).
        // when we perform a fetch, it will load in all the objects and cause the fetchedResultsController to apply
        // the snapshot automatically in the `controller(_:didChangeContentWith:)` delegate method

        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("fetchedResultsController error: ", error as NSError)
        }

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _updateCollectionViewCellSize(forViewWidth: collectionView.bounds.width)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate { _ in
            self._updateCollectionViewCellSize(forViewWidth: size.width)
        } completion: { _ in

        }
    }

    // MARK: - Private Methods

    private func _setupNavigationItems() {
        addBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(_didTapAddBarButtonItem(_:)))
        selectionMenuBarButtonItem = UIBarButtonItem(
            title: nil,
            image: UIImage(systemName: "ellipsis.circle.fill"),
            primaryAction: nil,
            menu: UIMenu(title: "",
                         image: nil,
                         identifier: nil, options: [], children: [
                            UIAction(title: "Select None", image: UIImage(systemName: "circle"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { _ in
                                self._deselectAllCells()
                            }),
                            UIAction(title: "Duplicate", image: UIImage(systemName: "doc.on.doc"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { _ in
                                self._duplicateSelectedThings()
                            }),
                            UIAction(title: "Delete", image: UIImage(systemName: "trash"), identifier: nil, discoverabilityTitle: nil, attributes: .destructive, state: .off, handler: { _ in
                                self._deleteSelectedThings()
                            }),
                         ]
            )
        )
        selectBarButtonItem = UIBarButtonItem(title: "Select", image: nil, primaryAction: UIAction(handler: { _ in
            if self.selectionMode == .single {
                self.selectBarButtonItem.title = "Done"
                self.selectBarButtonItem.style = .done
                self.selectionMode = .multi
                self.navigationItem.setRightBarButton(self.selectionMenuBarButtonItem, animated: false)
            } else if self.selectionMode == .multi {
                self.selectBarButtonItem.title = "Select"
                self.selectBarButtonItem.style = .plain
                self.selectionMode = .single
                self.navigationItem.setRightBarButton(self.addBarButtonItem, animated: false)
            }
        }), menu: nil)
        self.navigationItem.setRightBarButton(addBarButtonItem, animated: false)
        self.navigationItem.setLeftBarButton(selectBarButtonItem, animated: false)
        self.navigationItem.title = "Things"
    }

    private func _updateCollectionViewCellSize(forViewWidth width: CGFloat) {
        let flowLayout = self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        flowLayout.minimumLineSpacing = 16
        flowLayout.minimumInteritemSpacing = 16
        flowLayout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    }

    @objc private func _didTapAddBarButtonItem(_ sender: Any) {
        let color = UIColor(hue: CGFloat.random(in: 0.0 ... 1.0), saturation: 1.0, brightness: 1.0, alpha: 1.0)
        let amount = Int64.random(in: 0 ... 1000)

        let thingPrimitive = ThingPrimitive(amount: amount, color: color, thing: nil)

        let _ = Thing.upsertThingFromPrimitive(thingPrimitive)
    }

    private func _duplicateSelectedThings() {
        let objectIDs = self._thingObjectIDsForSelection()
        if objectIDs.count > 0 {
            let things: [Thing] = objectIDs.map { objectID in
                return Thing.from(managedObjectID: objectID)
            }

            let newThings: [Thing] = things.reversed().map { thing in
                return Thing.duplicate(thing: thing)
            }
            CoreDataStack.shared.saveContext()
            CoreDataStack.coerceObjectIds(managedObjects: newThings) // needed to fix temporary object ID issue :(
        }

    }

    private func _deleteSelectedThings() {
        let objectIDs = self._thingObjectIDsForSelection()
        if objectIDs.count > 0 {
            let things: [Thing] = objectIDs.map { objectID in
                return Thing.from(managedObjectID: objectID)
            }
            Thing.deleteThings(things)
            CoreDataStack.shared.saveContext()
        }

    }

    private func _deselectAllCells() {
        self.collectionView.indexPathsForSelectedItems?.forEach({ indexPath in
            self.collectionView.deselectItem(at: indexPath, animated: false)
        })
    }

    private func _thingObjectIDsForSelection() -> [NSManagedObjectID] {
        if let selectedItems = self.collectionView.indexPathsForSelectedItems {
            // sort selection by indexPaths
            let sortedSelectedItems = selectedItems.sorted { indexPath1, indexPath2 in
                // this assumes one section in the the collection view... so we just sort ascending by item index
                return indexPath1.item < indexPath2.item
            }
            let objectIDs: [NSManagedObjectID] = sortedSelectedItems.compactMap { indexPath in
                return diffableDatasource.itemIdentifier(for: indexPath)
            }
            return objectIDs
        } else {
            return []
        }
    }

    private func _thingFrom(indexPath: IndexPath) -> Thing? {
        if let managedObjectId = diffableDatasource.itemIdentifier(for: indexPath) {
            return Thing.from(managedObjectID: managedObjectId)
        }
        return nil
    }

    private func _thingCellProvider() -> UICollectionViewDiffableDataSource<Int, NSManagedObjectID>.CellProvider {
        return { collectionView, indexPath, managedObjectID in
            let cell: ThingCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "ThingCell", for: indexPath) as! ThingCollectionViewCell
            var objectID: NSManagedObjectID = managedObjectID

            // sanity checking for rogue temporaryIDs
            if managedObjectID.isTemporaryID {
                print("managedObjectID is TEMPORARY in cell provider! ", managedObjectID)
                if let obj = self._thingFrom(indexPath: indexPath) {
                    print("isInserted == \(obj.isInserted)")
                    if !obj.isInserted {
                        objectID = obj.objectID
                        if objectID.isTemporaryID {
                            print("after checking diffableDataSource, managedObjectID is STILL TEMPORARY... this will probably cause a fault/crash. managedObjectId: ", objectID)
                        }
                    }
                }
            }

            let thing = Thing.from(managedObjectID: objectID)
            #if DEBUG
            if thing.isFault {
                print("IS FAULT")
            }
            #endif
            cell.thingView.backgroundColor = thing.color
            cell.thingView.amountLabel.text = "\(thing.amount)"

            // accessibility
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = "Amount: \(thing.amount)"

            cell.collectionViewController = self

            return cell
        }
    }


    // MARK: - UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch selectionMode {

        case .single:
            return true
        case .multi:
            // as an example, we might limit multi-selections to 10.. but your logic will probably be different
            // if collectionView.indexPathsForSelectedItems?.count ?? 0 < 10 {
            //     return true
            // } else {
            //     return false
            // }

            // for this example project we just allow unlimited selections in .multi mode
            return true
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if self.selectionMode == .single {
            if let thing = _thingFrom(indexPath: indexPath) {
                if let thingViewController = ThingViewController(thing: thing) {
                    self.present(thingViewController, animated: true, completion: nil)
                }
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        switch selectionMode {
        case .single:
            return true
        case .multi:
            return false
        }
    }

    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        switch selectionMode {
        case .single:

            if let thing = _thingFrom(indexPath: indexPath) {
                return _cellContextMenuConfiguration(for: thing)
            }
            return nil

        case .multi:
            // no context menu configuration in mult-select mode
            return nil
        }

    }

    override func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        switch selectionMode {
        case .single:
            return _cellContextMenuTargetedPreview(configuration: configuration)
        case .multi:
            // no context menu in mult-select mode
            return nil
        }

    }

    override func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        switch selectionMode {
        case .single:
            return _cellContextMenuTargetedPreview(configuration: configuration)
        case .multi:
            // no context menu in mult-select mode
            return nil
        }
    }

    // MARK: - Context Menu Helpers

    private func _cellContextMenuTargetedPreview(configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        let index = diffableDatasource.snapshot().indexOfItem(configuration.identifier as! NSManagedObjectID)
        if let index = index,
           let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) {
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear

            // we are returing the whole cell view here,
            // but you can generate or return whatever view you want to pop out when the menu is shown
            return UITargetedPreview(view: (cell as! ThingCollectionViewCell), parameters: parameters)
        }
        return nil

    }

    private func _cellContextMenuConfiguration(for thing: Thing) -> UIContextMenuConfiguration? {
        let editAction = UIAction.init(title: NSLocalizedString("Edit", comment: "Title for editing a thing"), image: UIImage(systemName: "pencil"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { action in

            if let thingViewController = ThingViewController(thing: thing) {
                self.present(thingViewController, animated: true, completion: nil)
            }
        }

        let duplicateAction = UIAction.init(title: NSLocalizedString("Duplicate", comment: "Title for duplicating a thing"), image: UIImage(systemName: "doc.on.doc"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { action in

            let newThing = Thing.duplicate(thing: thing)
            CoreDataStack.shared.saveContext()
            CoreDataStack.coerceObjectIds(managedObjects: [newThing])
        }

        let deleteAction = UIAction.init(title: NSLocalizedString("Delete", comment: "Title for deleting a thing"), image: UIImage(systemName: "checkmark"), identifier: nil, discoverabilityTitle: nil, attributes: .destructive, state: .off) { action in
            Thing.deleteThings([thing])
        }

        let deleteCancelAction = UIAction(title: NSLocalizedString("Cancel", comment: "Title for canceling an action"), image: UIImage(systemName: "xmark")) { action in }

        let deleteMenu = UIMenu(title: NSLocalizedString("Delete", comment: "Title for deleting a thing"), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteCancelAction, deleteAction])

        let mainMenu = UIMenu(title: NSLocalizedString("Options", comment: "Title for list of options you can perform on a thing"), image: nil, identifier: nil, options: .displayInline, children: [editAction, duplicateAction])

        let menu = UIMenu(title: "", image: nil, identifier: nil, options: .displayInline, children: [mainMenu, deleteMenu])

        let configuration = UIContextMenuConfiguration(identifier: thing.objectID, previewProvider: nil) { _ in
            return menu
        }
        return configuration
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 103, height: 103)
    }

    // MARK: - UICollectionViewDragDelegate

    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        switch selectionMode {

        case .single:

            if let thing = _thingFrom(indexPath: indexPath) {
                let itemProvider = NSItemProvider(object: thing.identifier! as NSString)
                let dragItem = UIDragItem(itemProvider: itemProvider)
                dragItem.localObject = thing
                return [dragItem]
            }
            return []
        case .multi:
            // in this example, we don't allow dragging multiple items
            return []
        }
    }


    // MARK: - UICollectionViewDropDelegate

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        var destIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destIndexPath = indexPath
        } else {
            // we are going to drop at the last indexPath,
            // the coordinator won't tell us this... for some reason
            let itemIndex = collectionView.numberOfItems(inSection: 0)
            destIndexPath = IndexPath(item: itemIndex - 1, section: 0)
        }

        if coordinator.proposal.operation == .move {
            _reorderItems(coordinator: coordinator, destIndexPath: destIndexPath)
        }
    }

    // this method does the heavy lifting for re-assigning proper displayOrder values for
    // the objects, calling the appropriate bookkeeping methods on the diffable datasource
    // to cause a move operation, and handling the drop operation
    private func _reorderItems(coordinator: UICollectionViewDropCoordinator, destIndexPath: IndexPath) {
        if let item = coordinator.items.first,
           let srcIndexPath = item.sourceIndexPath,
           let dropThing = item.dragItem.localObject as? Thing {

            var i: Int64 = 0
            let managedObjectIdentifiers = diffableDatasource.snapshot().itemIdentifiers
            for managedObjectId in managedObjectIdentifiers {
                let thing = Thing.from(managedObjectID: managedObjectId)
                let newOrder = Int64(i)
                if thing.displayOrder != newOrder {
                    thing.displayOrder = newOrder
                }
                i += 1
            }

            if destIndexPath.item < srcIndexPath.item {
                for i: Int in destIndexPath.item ... srcIndexPath.item {
                    let thing = Thing.from(managedObjectID: managedObjectIdentifiers[i])
                    let newOrder = Int64(i + 1)
                    if thing.displayOrder != newOrder {
                        thing.displayOrder = newOrder
                    }
                }
                dropThing.displayOrder = Int64(destIndexPath.item)
            } else if destIndexPath.item > srcIndexPath.item {
                for i: Int in srcIndexPath.item ... destIndexPath.item {
                    let thing = Thing.from(managedObjectID: managedObjectIdentifiers[i])
                    let newOrder = Int64(i - 1)
                    if thing.displayOrder != newOrder {
                        thing.displayOrder = newOrder
                    }
                }
                dropThing.displayOrder = Int64(destIndexPath.item)
            }

            var snapshot = diffableDatasource.snapshot()
            let srcObjectID = managedObjectIdentifiers[srcIndexPath.item]
            let destObjectID = managedObjectIdentifiers[destIndexPath.item]

            // only move if src and dest are different, or else NSInternalInconsistencyException crash :(
            if !(srcIndexPath.section == destIndexPath.section && srcIndexPath.item == destIndexPath.item) {
                snapshot.moveItem(srcObjectID, beforeItem: destObjectID)
            }

            CoreDataStack.shared.saveContext()
            coordinator.drop(item.dragItem, toItemAt: destIndexPath)
        }
    }
}

