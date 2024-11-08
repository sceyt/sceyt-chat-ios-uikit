import UIKit

extension MediaPickerViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        titleText: L10n.ImagePicker.title,
        confirmButtonAppearance: ButtonAppearance(
            reference: ButtonAppearance.appearance,
            labelAppearance: LabelAppearance(
                foregroundColor: .onPrimary,
                font: Fonts.semiBold.withSize(16)
            ),
            backgroundColor: .accent,
            cornerRadius: 8
        ),
        countLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(14),
            backgroundColor: .onPrimary
        ),
        cellAppearance: SceytChatUIKit.Components.mediaPickerCell.appearance
    )
    
    public class Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, String>
        public var titleText: String
        
        @Trackable<Appearance, ButtonAppearance>
        public var confirmButtonAppearance: ButtonAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var countLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, MediaPickerViewController.MediaCell.Appearance>
        public var cellAppearance: MediaPickerViewController.MediaCell.Appearance
        
        // Primary Initializer with all parameters
        public init(
            backgroundColor: UIColor,
            titleText: String,
            confirmButtonAppearance: ButtonAppearance,
            countLabelAppearance: LabelAppearance,
            cellAppearance: MediaPickerViewController.MediaCell.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._titleText = Trackable(value: titleText)
            self._confirmButtonAppearance = Trackable(value: confirmButtonAppearance)
            self._countLabelAppearance = Trackable(value: countLabelAppearance)
            self._cellAppearance = Trackable(value: cellAppearance)
        }
        
        public init(
            reference: MediaPickerViewController.Appearance,
            backgroundColor: UIColor? = nil,
            titleText: String? = nil,
            confirmButtonAppearance: ButtonAppearance? = nil,
            countLabelAppearance: LabelAppearance? = nil,
            cellAppearance: MediaPickerViewController.MediaCell.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._titleText = Trackable(reference: reference, referencePath: \.titleText)
            self._confirmButtonAppearance = Trackable(reference: reference, referencePath: \.confirmButtonAppearance)
            self._countLabelAppearance = Trackable(reference: reference, referencePath: \.countLabelAppearance)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let titleText { self.titleText = titleText }
            if let confirmButtonAppearance { self.confirmButtonAppearance = confirmButtonAppearance }
            if let countLabelAppearance { self.countLabelAppearance = countLabelAppearance }
            if let cellAppearance { self.cellAppearance = cellAppearance }
        }
    }
}
