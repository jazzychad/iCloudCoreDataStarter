//
//  CoreDataUtilities.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/24/21.
//

import Foundation
import UIKit

// Make UIColor adopt CoreDataValueTransforming
extension UIColor: CoreDataValueTransforming {
    public static var valueTransformerName: NSValueTransformerName {

        .init("UIColorValueTransformer") // <-- this is the name of the transformer you set in the Core Data model file

    }
}

// GENERIC VALUE TRANSFORMING PROTOCOLS/HELPERS
// cribbed from: https://stackoverflow.com/questions/57304922/crash-when-adopting-nssecureunarchivefromdatatransformer-for-a-transformable-pro

public protocol CoreDataValueTransforming: NSSecureCoding {
    static var valueTransformerName: NSValueTransformerName { get }
}

public class NSSecureCodingValueTransformer<T: NSObject & CoreDataValueTransforming>: ValueTransformer {
    public override class func transformedValueClass() -> AnyClass { T.self }
    public override class func allowsReverseTransformation() -> Bool { true }

    public override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? T else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
    }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? NSData else { return nil }
        let result = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: T.self,
            from: data as Data
        )
        return result
    }

    // Registers the transformer by calling `ValueTransformer.setValueTransformer(_:forName:)`.
    public static func registerTransformer() {
        let transformer = NSSecureCodingValueTransformer<T>()
        ValueTransformer.setValueTransformer(transformer, forName: T.valueTransformerName)
    }
}
