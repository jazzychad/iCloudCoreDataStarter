
# iCloudCoreDataStarter

Hello, I'm Chad. For the last several months I have been working on
[Sticker Doodle, an app you should go download right
now!](https://stickerdoodle.app)

In the course of building [Sticker Doodle](https://stickerdoodle.app)
(which you should go download right now), I ran into many brick walls
and learned way too much about Core Data, iCloud sync, Collection and
Table Views, and Diffable Data Sources.

There is documentation for each of those individually, but I could
find no clear and simple example project that ties them all together
in a neat little bow.

Well, that changes today.

**DISCLAIMER: This repo is for educational purposes. While I believe
  that the code inside is production-ready, you should always read and
  thoroughly audit any code you ship in a production application.**

This is an example Xcode iOS swift project that demonstrates using the
following technologies:

- [X] Core Data
- [X] iCloud sync
- [X] Collection Views
- [X] Table Views
- [X] App Groups

It aims to implement a working app with the minimum amount of code to
accomplish the following features:

- [X] UICollectionView/UITableView
- [X] ... using diffable data source
- [X] ... with Core Data's NSFetchedResultsController
- [X] Reloading cells on object update
- [X] Collection View cell context menu
- [X] Object insertion
- [X] Object deletion
- [X] Object updating
- [X] Collection View multi-selection toggling
- [X] Collection View drag-and-drop reordering of objects
- [X] Syncing Core Data state between app and extensions (in real time)
- [X] iCloud syncing of Core Data between devices
- [X] Core Data value transformers

### What this project is NOT:

- [ ] a Core Data tutorial
- [ ] an iCloud/CloudKit tutorial
- [ ] free tech support

### Training

If you are interested in having a focused (paid) training session for
your dev team about this topic, please contact:

**support at jazzychad dot net**

### Prerequisites

- A moderate familiarity with how Core Data works and how to setup a Core Data database/model
- A moderate familiarity with setting up and dealing with iCloud containers
- The various configuration and settings screens in Xcode

### SDK Requirements

This project uses only APIs available in **iOS 14 and earlier**
(i.e. there are _no_ iOS 15 APIs present in this project).

### Using this project

You should be able to clone this repo and compile/run the
`iCloudCoreDataStarter` scheme _after setting your Development Team_
in the `Signing & Capabilities` tab for the `iCloudCoreDataStarter`
and `iMessageApp` targets.

Building in the `DEBUG` configuration and using `Automatically manage
signing` should allow you to run this example on simulators and local
development devices.

Provisioning for a `RELEASE` build is beyond the scope of this project.

# Here We Go

## For New Projects

If you are creating a new project and want to use Core Data and iCloud
sync, make sure to check the two relevant boxes at the bottom of the
dialog:

![New Project](https://raw.githubusercontent.com/jazzychad/iCloudCoreDataStarter/main/screenshots/NewProject.png)

This has the advantage of creating the necessary `.xcdatamodeld` file
in your project to setup your database models, but it also creates
some boilerplate Core Data code in the `AppDelegate` which you can
remove if you plan on using the files in this example in other
projects.

## Core Data Model

In this example app, we are mainly concerned with the creation and
display of `Thing` objects. `Thing`s have two primary properties that
make a thing a thing:

- `amount: Int64` - represents some quantity, I leave it up to your imagination
- `color: UIColor` - makes the thing a little more visually appealing

Whenever I make a Core Data model, I _always always always always_ add the following properties to it:

- `createdAt: Date` - the date that this object was created (yes,
  there is also a creationDate field in the CKRecord object that backs
  this Core Data row, but in the cases where you are not backing your
  Core Data with iCloud, having this date readily available is
  extremely handy, so I have just made a habit of adding it).

- `displayOrder: Int64` - this is important for determining in what
  order to show objects in the UI and what we use to sort the fetch
  request (along with the `createdAt` date).

- `identifier: String` - some unique identifier for the object. This
  could also be a `UUID` instead. This isn't strictly necessary in all
  use-cases, but it comes in really handy when you eventually run into
  a situation where you need to have it.

Our final example `Thing` model looks like this:

![Thing object model](https://raw.githubusercontent.com/jazzychad/iCloudCoreDataStarter/main/screenshots/ThingModel.png)

## App Group

App Groups allow your apps and their extensions to (among other
things) have a shared space on disk to read and write data. This is
crucial for sharing data between apps and extensions, but it is
especially good for sharing a Core Data store between apps and
extensions.

An app group (`group.com.example.iCloudCoreDataStarter`) is created
and added to each app/extension target in the `Signing & Capabilities`
tab in Xcode.

App Group identifiers are scoped to your developer account, so you can
use the one in this example project if you like.


![App Group setup](https://raw.githubusercontent.com/jazzychad/iCloudCoreDataStarter/main/screenshots/AppGroup.png)

## iCloud container

To enable iCloud sync for Core Data, you must create an iCloud
container (`iCloud.com.example.iCloudCoreDataStarter.iCloud` in this
example project) and enable the CloudKit service in the `Signing &
Capabilities` tab in Xcode.

iCloud container identifiers are scoped to your developer account, so
you can use the one in this example project if you like.

Adding CloudKit will typically also enable the `Push Notification`
capability for you. There is _no other configuration you need to do
for push notifications to work with CloudKit_ - it just works.

_However_ you will also need to add the `Background Modes` capability
in the `Signing & Capabilities` tab and select `Remote notifications`.

**IMPORTANT!! Always remember to publish your iCloud container schema
  to _Production_ before you publish your app to TestFlight or the App
  Store!!**

![iCloud container](https://raw.githubusercontent.com/jazzychad/iCloudCoreDataStarter/main/screenshots/iCloudContainer.png)

### Note about provisioning

Xcode will typically take care of creating the App Group and iCloud
container and updating the provisioning profiles for you if you are
building in Debug mode, but in a Release build you will probably need
to create specific provisioning profiles for your apps/extensions that
have the right entitlements.


## CloudKit and Core Data logging

By default CloudKit will log _a giant amount_ of information to the
console and stderr. This can sometimes be useful to debug certain
issues, but there is so much text that it will get in the way of other
logging you may be doing in your app. You can suppress this output
with the following Run Arguments in your Scheme:

```
-com.apple.CoreData.CloudKitDebug 0
-com.apple.CoreData.Logging.stderr 0
-com.apple.CoreData.SQLDebug 0
```

![Run Arguments](https://raw.githubusercontent.com/jazzychad/iCloudCoreDataStarter/main/screenshots/RunArguments.png)


# CoreDataStack

The bulk of the Core Data logic lives in the `CoreDataStack` folder of
the project. These files were designed and written such that there is
nothing specific about them to this example project, i.e. they could
be copied into another project and re-used as-is.

Let's take a look at what each file does:

## CoreDataStack.swift

Handles the following jobs:

- [X] Provides a `CoreDataStack.shared` object for dealing with Core Data objects throughout the app
- [X] Create and configure an NSPersistentCloudKitContainer with appropriate settings
- [X] Creates the Core Data store file in the App Group on-disk location
- [X] Handles Core Data persistent history tracking and updating

Before using the `CoreDataStack.shared` object, you _must_ provide a
configuration object which will add proper configuration to the Core
Data stack. As early as you can in your app/extension lifecycle, you
must call:

```swift
let config = CoreDataStackConfig(...)
configureCoreDataStack(withConfig: config)
```

The `authorName` property on `CoreDataStack` is also very
important. It is a way to tell which app/extension generated
transactions into the Core Data store. You _must_ set this as early as
possible in the app/extension lifecycle. For example, in the main app:

```swift
CoreDataStack.shared.authorName = "app"
```

and in, for example, a Messages app extension:

```swift
CoreDataStack.shared.authorName = "iMessageApp"
```

The author name of the data store transactions help each process
filter out which persistent history transactions need to be replayed
into the current managed object context.

In this example project, you will see that both the configuration and
author name are set in
`AppDelegate.application(_:didFinishLaunchingWithOptions:)` in the
main app, and in the `fetchedResultController` initializer in
`iMsgThingTableViewController` of the Messages app extension.

---

Let's talk about the `CoreDataStack.coerceObjectIds(managedObjects:)`
function. In an ideal world, this method shouldn't be needed at all,
however I believe there is a nasty bug deep in the guts of the Core
Data framework which makes this function necessary.

When an `NSManagedObject` is created and added to its
`NSManagedObjectContext`, _but (crucially) before `.save()` is called
on the managed object context,_ the new managed object will have a
_temporary_ objectID (which can be checked with
`managedObject.objectID.isTemporaryID`).

Before `.save()` is called on the managed object context, this
temporary ID can be used to fetch the object, refer to it, etc... it
acts like a normal `NSManagedObjectID` -- _HOWEVER,_ after `.save()`
is called on the managed object context, 2 things are supposed to
happen:

1. `NSManagedObjects` with temporary IDs are supposed to be assigned a
permanent ID and those objects updated in memory with the new ID.

2. The managed object context _forgets all temporary IDs_ and
attempting to use them to identify an object will _fail._

There seems to be a bug (in iOS 14 and iOS 15 as of my latest testing)
where _sometimes_ Step 1 will _not actually happen_ and newly inserted
and saved objects will still have a temporary ID!! This has led to all
sorts of unexpected and frustrating behavior until I figured out what
was actually going on. There are several developer forum posts and
Stack Overflow questions regarding the same behavior, so I am not the
only one that has experienced this bug.

Thus, this evil but necessary `coerceObjectIds(managedObjects:)` has
come into existence and is called whenever a new `NSManagedObject` is
created and the managed object context is saved.

## CoreDataUtilities.swift

Contains helper code for creating value transformers for Core Data
"transformable" properties. There is an example of extending `UIColor`
to be a value transformer.

When you register a transformer in this way, make sure to set the
Transformer value in the property inspector to the
`valueTransformerName` you specify in the code:

![UIColor Value Transformer](https://raw.githubusercontent.com/jazzychad/iCloudCoreDataStarter/main/screenshots/ValueTransformer.png)

## CoreDataDistributedUpdateListener.swift

This class implements the CFNotification machinery needed to
communicate between your app and extensions to notify each other of
Core Data updates.

You should create one per process as early as possible. For example,
in an app you should create a property in the AppDelegate.

```swift
let coreDataDistributedUpdateListner = CoreDataDistributedUpdateListener()
```

## CoreDataDiffableFetchedResultsHandler.swift

`CoreDataDiffableFetchedResultsHandler` is designed to be a
`NSFetchedResultsController` delegate and handle the diffable
datasource machinery whether you are using
`UITableViewDiffableDataSource` or
`UICollectionViewDiffableDataSource`

It will take care of updating the diffable datasource snapshot from
the NSFetchedResultsController and deal with reloading cells for
objects which have been updated but not inserted or moved (which
otherwise do not automatically get reloaded).

See `ThingRootCollectionViewController.viewDidLoad()` and
`iMsgThingTableViewController.viewDidLoad()` for example usage.


# Other Files

The other project-specific files are covered here.

## Thing+Extras.swift

I find it very useful to have a file with Core Data object specific helper/utility methods.

Let's talk about `ThingPrimitive` -- I also find it very useful to have a plain struct which represents the important fields of a Core Data model. There are some advantages to having them around:

- NSManagedObjects are _not_ thread safe. They are _extremely thread
  unsafe,_ in fact. Having a struct which acts as a "bag of
  properties" that can be passed around threads as necessary can be
  handy.

- Creating a new NSManagedObject (a `Thing` for example) will fire off
  NSFetchedResultsController delegate callbacks because creating the
  object necessarily inserts the object into an
  NSManagedObjectContext. This can be undesirable. For example, if you
  had a screen to create or compose a new `Thing` object, and it is
  not fully configured while the creation flow is happening, the root
  collection view would show a half-baked or incomplete representation
  of the `Thing`! In these situations, I like to have a `Primitive`
  struct available to configure along the way, and then at the very
  end, create the real NSManagedObject with the Primitive properties.

## ThingRootCollectionViewController.swift

This is an example implementation of how to wire up the following
various features in a UICollectionViewController:

- [X] A `var fetchedResultController: NSFetchedResultsController<Thing>` to retrieve the Thing objects to display
- [X] A `UICollectionViewDiffableDataSource` to drive the collectionView's data
- [X] A `CoreDataDiffableFetchedResultsHandler` to deal with fetchedResultsController delegate updates
- [X] Drag and Drop re-ordering of Thing objects and the related bookkeeping
- [X] Long-press context menu generation for collectionView cells
- [X] An example of how to handle toggling `.allowsMultipleSelection` for selecting and manipulating multiple cells

If you wanted to use this in your own app with your own Core Data
model, I _think_ you should be able to find/replace `thing` and
`Thing` as appropriate and have a pretty good starting point!

## ThingViewController.swift

A very simple view controller for viewing and updating existing Thing
objects. Demonstrates the use of `ThingPrimitive` to do an upsert when
tapping the Save button.

## iMsgThingTableViewController.swift

This is a UITableViewController inside the Messages App Extension
which displays the Thing objects in the database in a tableView
(instead of a collectionView). This is to demonstrate how similar it
can be to use the same basic patterns and the
`CoreDataDiffableFetchedResultsHandler` to achieve the same behavior
as in the `ThingRootCollectionViewController` example.

You can swipe to delete objects, and tapping on a row will randomly
update the Thing object with new `amount` and `color` values (these
will be immediately reflected in the main app).

Likewise, if you create/update/delete/move a Thing object in the main
app, it will immediately be reflected in the Messages App
Extension. This can be viewed happening in real-time by launching the
main app and the Messages App Extension in split-view on an iPad
simulator.

![iPad Split View](https://raw.githubusercontent.com/jazzychad/iCloudCoreDataStarter/main/screenshots/iPadSplitView.png)

# Issues

There might be bugs, or unclear documentation, or better ways to do
something! Please open an issue (or send a PR) to help improve this
example project. I will also be updating it as I learn more.

# Resources

The following were very useful in helping me figure out all of the
knowledge included in this project. There are countless other websites
and stack overflow answers lost to the sand of frantic googling, but
if I happen to find them again I will add them here:

- https://www.avanderlee.com/swift/diffable-data-sources-core-data/
- https://developer.apple.com/videos/play/wwdc2019/202/
- https://developer.apple.com/documentation/coredata/synchronizing_a_local_store_to_the_cloud
- https://stackoverflow.com/questions/57304922/crash-when-adopting-nssecureunarchivefromdatatransformer-for-a-transformable-pro

# You Made It!

Let me know what you think - [@jazzychad](https://twitter.com/jazzychad) on twitter.

And don't forget to check out [Sticker Doodle!](https://stickerdoodle.app)
