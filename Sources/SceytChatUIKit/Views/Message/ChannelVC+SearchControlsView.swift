import UIKit

extension ChannelVC {
    open class SearchControlsView: View {
        open lazy var previousResultButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var nextResultButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var resultsCounterLabel = UILabel()
            .withoutAutoresizingMask
        
        open var onAction: ((Action) -> Void)?
        
        open override func setup() {
            super.setup()
            
            previousResultButton.setImage(.chevronUp, for: .normal)
            nextResultButton.setImage(.chevronDown, for: .normal)
            
            previousResultButton.addTarget(self, action: #selector(onPrevious), for: .touchUpInside)
            nextResultButton.addTarget(self, action: #selector(onNext), for: .touchUpInside)
        }
        
        open override func setupLayout() {
            super.setupLayout()
            
            addSubview(previousResultButton)
            addSubview(nextResultButton)
            addSubview(resultsCounterLabel)
            
            previousResultButton.resize(anchors: [.height(28), .width(28)])
            nextResultButton.resize(anchors: [.height(28), .width(28)])
            
            previousResultButton.pin(
                to: self,
                anchors: [.leading(12), .top(12), .bottom(-12)]
            )
            previousResultButton.trailingAnchor.pin(to: nextResultButton.leadingAnchor, constant: -12)
            
            nextResultButton.pin(
                to: self,
                anchors: [.top(12), .bottom(-12)]
            )
            nextResultButton.trailingAnchor.pin(lessThanOrEqualTo: resultsCounterLabel.leadingAnchor, constant: -12)
            
            resultsCounterLabel.pin(
                to: self,
                anchors: [.top(12), .bottom(-12), .trailing(-16)]
            )
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            previousResultButton.tintColor = appearance.buttonTintColor
            nextResultButton.tintColor = appearance.buttonTintColor
            resultsCounterLabel.textColor = appearance.textColor
            resultsCounterLabel.font = appearance.textFont
        }
        
        open func update(with searchResult: SearchResultModel, query: String?) {
            previousResultButton.isEnabled = searchResult.previousResult != nil
            nextResultButton.isEnabled = searchResult.nextResult != nil
            if let index = searchResult.lastViewedSearchResultReversedIndex {
                resultsCounterLabel.text = L10n.Channel.Search.foundIndex(
                    index,
                    searchResult.searchResults.count
                )
            } else if query?.isEmpty == false {
                resultsCounterLabel.text = L10n.Channel.Search.notFound
            } else {
                resultsCounterLabel.text = nil
            }
        }
        
        @objc open func onPrevious() {
            onAction?(.previousResult)
        }
        
        @objc open func onNext() {
            onAction?(.nextResult)
        }
    }
}

public extension ChannelVC.SearchControlsView {
    enum Action {
        case previousResult
        case nextResult
    }
}
