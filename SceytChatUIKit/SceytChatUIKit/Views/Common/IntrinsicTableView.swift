//
//  IntrinsicTableView.swift
//  SceytChatUIKit
//

import UIKit

open class IntrinsicTableView: UITableView {

    override open var contentSize: CGSize {
        didSet {
            print("[IntrinsicTableView] contentSize", contentSize.height)
            invalidateIntrinsicContentSize()
        }
    }
    
    override open func reloadData() {
        super.reloadData()
        print("[IntrinsicTableView] reloadData", contentSize.height)
        invalidateIntrinsicContentSize()
    }

    override open var intrinsicContentSize: CGSize {
        setNeedsLayout()
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }
}
