//
//  iMsgThingTableViewController.swift
//  iMessageApp
//
//  Created by Chad Etzel on 9/27/21.
//

import UIKit
import CoreData

class SwipeToDeleteDiffableDataSource: UITableViewDiffableDataSource<Int, NSManagedObjectID> {
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let thing = Thing.from(managedObjectID: snapshot().itemIdentifiers[indexPath.item])
            Thing.deleteThings([thing])
            CoreDataStack.shared.saveContext()
        }
    }
}

class iMsgThingTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    private var fetchedResultsController: NSFetchedResultsController<Thing> = {
        configureCoreDataStack(withConfig: kSharedCoreDataStackConfig)
        CoreDataStack.shared.authorName = "iMessageExt"

        return NSFetchedResultsController(
            fetchRequest: Thing.fetchedAllResultsRequest(),
            managedObjectContext: CoreDataStack.shared.managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }()

    private var diffableDatasource: SwipeToDeleteDiffableDataSource!
    private var diffableFetchedResultsHandler: CoreDataDiffableFetchedResultsHandler!

    override func viewDidLoad() {
        super.viewDidLoad()

        diffableDatasource = SwipeToDeleteDiffableDataSource(tableView: self.tableView, cellProvider: { tableView, indexPath, managedObjectID in
            var cell = tableView.dequeueReusableCell(withIdentifier: "ThingCell")
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: "ThingCell")
                cell?.textLabel?.textColor = .white
            }
            let thing = Thing.from(managedObjectID: managedObjectID)

            cell?.textLabel?.text = "\(thing.amount)"
            cell?.contentView.backgroundColor = thing.color

            return cell
        })

        tableView.dataSource = diffableDatasource
        diffableFetchedResultsHandler = CoreDataDiffableFetchedResultsHandler(dataSource: diffableDatasource, container: self.tableView)
        fetchedResultsController.delegate = diffableFetchedResultsHandler

        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("fetchedResultsController error: ", error as NSError)
        }

    }

    private func _thingFrom(indexPath: IndexPath) -> Thing? {
        if let managedObjectId = diffableDatasource.itemIdentifier(for: indexPath) {
            return Thing.from(managedObjectID: managedObjectId)
        }
        return nil
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        // randomly edit the Thing with a new amount and color
        if let thing = _thingFrom(indexPath: indexPath) {
            thing.amount = Int64.random(in: 0 ... 1000)
            thing.color = UIColor(hue: CGFloat.random(in: 0.0 ... 1.0), saturation: 1.0, brightness: 1.0, alpha: 1.0)
            CoreDataStack.shared.saveContext()

            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
