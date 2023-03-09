//
//  ClassRepository.swift
//  SceytChatUIKit
//

import Foundation

public final class ClassRepository: NSObject {

    public static var `default` = ClassRepository()

    private class Object: NSObject {
        let type: Any
        init(type: Any) {
            self.type = type
        }
    }

    private let mapTable = NSMapTable<NSString, Object>(keyOptions: .strongMemory, valueOptions: .strongMemory)

    public func register<SubClass, BaseClass>(subClass: SubClass, for baseClass: BaseClass) throws {
        guard let anyClass = baseClass as? AnyClass,
                Bundle(for: anyClass.self).bundleIdentifier == Bundle(for: BundleClass.self).bundleIdentifier else {
            throw ClassRepositoryError.baseClassIsNotABundleClass
        }
        guard subClass as? BaseClass != nil else {
            throw ClassRepositoryError.wrongInheritance
        }
        mapTable.setObject(Object(type: subClass), forKey: Self.key(baseClass))
    }

    public func instance<Class>(of type: Class) -> Class? {
        mapTable.object(forKey: Self.key(type))?.type as? Class
    }

    private static func key<Class>(_ type: Class) -> NSString {
        String(reflecting: type) as NSString
    }
}

public enum ClassRepositoryError: Error {
    case baseClassIsNotABundleClass
    case wrongInheritance
}

private class BundleClass: NSObject { }
