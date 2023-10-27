//
//  SceytChatUIKit+Bundle.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 24.03.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

final public class SCL10nBundleClass {
#if SWIFT_PACKAGE
    public static var bundle = Bundle.module
#else
    public static var bundle = Bundle(for: SCL10nBundleClass.self)
#endif
    
    public static var resourcesBundle: Bundle = {
        return bundle
    }()
}

final public class SCAssetsBundleClass {
    
#if SWIFT_PACKAGE
    public static var bundle = Bundle.module
#else
    public static var bundle = Bundle(for: SCAssetsBundleClass.self)
#endif
    
    public static var resourcesBundle: Bundle = {
        return bundle
    }()
}

internal extension Bundle {
    
    static func kit(for aClass: AnyClass) -> Bundle {
#if SWIFT_PACKAGE
    return Bundle.module
#else
    return Bundle(for: aClass)
#endif

    }
}


