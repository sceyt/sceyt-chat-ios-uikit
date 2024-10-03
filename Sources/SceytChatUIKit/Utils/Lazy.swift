//
//  Lazy.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData

@propertyWrapper
public final class Lazy<T> {
    
    public var storage: T?
    
    var computeValue: (() -> T)!
    
    public init(wrappedValue computeValue: @autoclosure @escaping () -> T) {
        self.computeValue = computeValue
    }

    public var wrappedValue: T {
        if storage == nil {
            guard let computeValue = computeValue
            else { preconditionFailure() }
            storage = computeValue()
        }
        return storage!
    }

    public var projectedValue: (() -> T) {
        get {
            computeValue
        }
        set {
            computeValue = newValue
        }
    }
}


//@propertyWrapper
//public final class Trackable<R, V> {
//    private var hasSet = false
//    private var referencePath: KeyPath<R, V>!
//    private var reference: R!
//    private var value: V!
//    
//    public init(reference: R, referencePath: KeyPath<R, V>) {
//        self.referencePath = referencePath
//        self.reference = reference
//    }
//    
//    public init(value: V) { // may be removed also with ! on reference and path
//        hasSet = true
//        self.value = value
//    }
//    
//    public var wrappedValue: V {
//        get {
//            if hasSet {
//                value!
//            } else {
//                reference[keyPath: referencePath]
//            }
//        }
//        set {
//            hasSet = true
//            value = newValue
//        }
//    }
//}

//
//  MediaPickerViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

//import UIKit
//
//extension MediaPickerViewController: AppearanceProviding {
//    public static var appearance = Appearance()
//    
//    public class Appearance {
//        //        public var toolbarBackgroundColor: UIColor? = .background
//        //
//        
//        //        @Trackable<Appearance, UIColor>
//        public var backgroundColor: UIColor
//        //        @Trackable<Appearance, String>
//        public var titleText: String
//        //        @Trackable<Appearance, ButtonAppearance>
//        public var confirmButtonAppearance: ButtonAppearance
//        //        @Trackable<Appearance, LabelAppearance>
//        public var countLabelAppearance: LabelAppearance
//        //        @Trackable<Appearance, MediaPickerViewController.MediaCell.Appearance>
//        public var cellAppearance: MediaPickerViewController.MediaCell.Appearance
//        
//        
//        
//        public init(
//            //            parent: Appearance? = nil,
//            backgroundColor: UIColor = .background,
//            titleText: String = L10n.ImagePicker.title,
//            confirmButtonAppearance: ButtonAppearance = .init(
//                labelAppearance: .init(
//                    foregroundColor: .onPrimary,
//                    font: Fonts.semiBold.withSize(16)
//                ),
//                backgroundColor: .accent,
//                cornerRadius: 8
//            ),
//            countLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
//                                                          font: Fonts.semiBold.withSize(14),
//                                                          backgroundColor: .onPrimary),
//            cellAppearance: MediaPickerViewController.MediaCell.Appearance = SceytChatUIKit.Components.mediaPickerCell.appearance
//        ) {
//            //            _backgroundColor = Trackable(reference: appearance, referencePath: \.backgroundColor)
//            //            _titleText = Trackable(reference: appearance, referencePath: \.titleText)
//            //            _confirmButtonAppearance = Trackable(reference: appearance, referencePath: \.confirmButtonAppearance)
//            //            _countLabelAppearance = Trackable(reference: appearance, referencePath: \.countLabelAppearance)
//            //            _cellAppearance = Trackable(reference: appearance, referencePath: \.cellAppearance)
//            
//            //            if let parent {
//            self.backgroundColor = backgroundColor
//            self.titleText = titleText
//            self.confirmButtonAppearance = confirmButtonAppearance
//            self.countLabelAppearance = countLabelAppearance
//            self.cellAppearance = cellAppearance
//            //            }
//        }
//    }
//}
//
//
//extension MediaPickerViewController.MediaCell: AppearanceProviding {
//    public static var appearance = Appearance()
//    
//    public class Appearance {
//        //        @Trackable<Appearance, UIColor>
//        public var backgroundColor: UIColor
//        //        @Trackable<Appearance, LabelAppearance>
//        public var videoDurationLabelAppearance: LabelAppearance
//        public var videoDurationIcon: UIImage
//        //        @Trackable<Appearance, any TimeIntervalFormatting>
//        public var durationFormatter: any TimeIntervalFormatting
//        //        @Trackable<Appearance, CheckBoxView.Appearance>
//        public var checkboxAppearance: CheckBoxView.Appearance
//        
//        
//        public init(
//            //            parent: Appearance? = nil,
//            backgroundColor: UIColor = .surface1,
//            videoDurationLabelAppearance: LabelAppearance = .init(
//                foregroundColor: .onPrimary,
//                font: Fonts.regular.withSize(12),
//                backgroundColor: .overlayBackground2
//            ),
//            videoDurationIcon: UIImage = .galleryVideoAsset,
//            checkboxAppearance: CheckBoxView.Appearance = CheckBoxView.appearance,
//            durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
//        ) {
//            //            _backgroundColor = Trackable(reference: parent ?? appearance, referencePath: \.backgroundColor)
//            //            _videoDurationLabelAppearance = Trackable(reference: parent ?? appearance, referencePath: \.videoDurationLabelAppearance)
//            
//            //            _backgroundColor = Trackable(reference: appearance, referencePath: \.backgroundColor)
//            //            _videoDurationLabelAppearance = Trackable(reference: appearance, referencePath: \.videoDurationLabelAppearance)
//            //            _checkboxAppearance = Trackable(reference: appearance, referencePath: \.checkboxAppearance)
//            //            _durationFormatter = Trackable(reference: appearance, referencePath: \.durationFormatter)
//            
//            //            if let parent {
//            self.backgroundColor = backgroundColor
//            self.videoDurationLabelAppearance = videoDurationLabelAppearance
//            self.videoDurationIcon = videoDurationIcon
//            self.checkboxAppearance = checkboxAppearance
//            self.durationFormatter = durationFormatter
//            //            }
//        }
//    }
//}



//
//import UIKit
//
//public class AAA {
//    private var reference: AAA? = nil
//    @Trackable<AAA, UIColor> var color: UIColor
//    
//    init(reference: AAA) {
//        self.reference = reference
//        self._color = Trackable(reference: reference, referencePath: \.color)
//    }
//}
//
//public class BBB {
//    private var reference: BBB? = nil
//    @Trackable<BBB, UIColor> var color: UIColor
//    @Trackable<BBB, AAA> var aaa: AAA
//    
//    init(reference: BBB) {
//        self.reference = reference
//        self._color = Trackable(reference: reference, referencePath: \.color)
//        self._aaa = Trackable(reference: reference, referencePath: \.aaa)
//        color = .red
//    }
//}

//
//import UIKit
//
//// Property Wrapper
//@propertyWrapper
//class Inherited<Value> {
//    private var _value: Value?
//    weak var appearance: AAA?
//    let keyPath: KeyPath<AAA, Inherited<Value>>
//    
//    var wrappedValue: Value? {
//        get {
//            return _value ?? appearance?.parentValue(for: keyPath)
//        }
//        set {
//            _value = newValue
//        }
//    }
//    
//    init(keyPath: KeyPath<AAA, Inherited<Value>>, appearance: AAA) {
//        self.keyPath = keyPath
//        self.appearance = appearance
//    }
//}
//
//// AAA Class
//class AAA {
//    var parent: AAA?
//    
//    private var _backgroundColor: Inherited<UIColor>!
//    var backgroundColor: UIColor? {
//        get { _backgroundColor.wrappedValue }
//        set { _backgroundColor.wrappedValue = newValue }
//    }
//    
//    private var _textColor: Inherited<UIColor>!
//    var textColor: UIColor? {
//        get { _textColor.wrappedValue }
//        set { _textColor.wrappedValue = newValue }
//    }
//    
//    init(parent: AAA? = nil) {
//        self.parent = parent
//        _backgroundColor = Inherited(keyPath: \AAA._backgroundColor, appearance: self)
//        _textColor = Inherited(keyPath: \AAA._textColor, appearance: self)
//    }
//    
//    func parentValue<Value>(for keyPath: KeyPath<AAA, Inherited<Value>>) -> Value? {
//        return parent?._getInheritedProperty(keyPath).wrappedValue
//    }
//    
//    private func _getInheritedProperty<Value>(_ keyPath: KeyPath<AAA, Inherited<Value>>) -> Inherited<Value> {
//        return self[keyPath: keyPath]
//    }
//}
//
//
//protocol Inheritable: AnyObject {
//    var parent: Self? { get }
//    func parentValue<Value>(for keyPath: KeyPath<Self, Inherited<Value, Self>>) -> Value?
//    func _getInheritedProperty<Value>(_ keyPath: KeyPath<Self, Inherited<Value, Self>>) -> Inherited<Value, Self>
//}
