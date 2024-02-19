import UIKit

extension ChannelVC {
    open class SearchControlsView: View {
        open lazy var separatorView = UIView()
            .withoutAutoresizingMask
        
        open lazy var previousResultButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var nextResultButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var resultsCounterLabel = UILabel()
            .withoutAutoresizingMask
        
        open var onAction: ((Action) -> Void)?
        
        open override func setup() {
            super.setup()
            
            previousResultButton.setImage(.chevronUp.withRenderingMode(.alwaysTemplate), for: .normal)
            nextResultButton.setImage(.chevronDown.withRenderingMode(.alwaysTemplate), for: .normal)
            
            previousResultButton.addTarget(self, action: #selector(onPrevious), for: .touchUpInside)
            nextResultButton.addTarget(self, action: #selector(onNext), for: .touchUpInside)
        }
        
        open override func setupLayout() {
            super.setupLayout()
            
            addSubview(separatorView)
            addSubview(previousResultButton)
            addSubview(nextResultButton)
            addSubview(resultsCounterLabel)
            
            previousResultButton.resize(anchors: [.height(28), .width(28)])
            nextResultButton.resize(anchors: [.height(28), .width(28)])
            
            separatorView.resize(anchors: [.height(1)])
            separatorView.pin(to: self, anchors: [.leading, .top, .trailing])
            
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
            separatorView.backgroundColor = appearance.separatorColor
            previousResultButton.tintColor = appearance.buttonTintColor
            nextResultButton.tintColor = appearance.buttonTintColor
            resultsCounterLabel.textColor = appearance.textColor
            resultsCounterLabel.font = appearance.textFont
        }
        
        open func update(with searchResult: SearchResultModel, query: String?) {
            previousResultButton.isEnabled = searchResult.previousResult != nil
            nextResultButton.isEnabled = searchResult.nextResult != nil
            if let index = searchResult.lastViewedSearchResultReversedIndex {
                setCounterText(currentIndex: index, resultsCount: searchResult.searchResults?.count ?? 0)
            } else if query?.isEmpty == false {
                setNotFoundCounterText()
            } else {
                resultsCounterLabel.text = nil
            }
        }
        
        open func setCounterText(currentIndex: Int, resultsCount: Int) {
            resultsCounterLabel.text = L10n.Channel.Search.foundIndex(
                currentIndex,
                resultsCount
            )
        }
        
        open func setNotFoundCounterText() {
            resultsCounterLabel.text = L10n.Channel.Search.notFound
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
