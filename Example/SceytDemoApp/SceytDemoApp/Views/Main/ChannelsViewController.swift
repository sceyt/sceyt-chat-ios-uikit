import UIKit
import SceytChatUIKit
import SceytChat

final class ChannelsViewController: ChannelListViewController {
    override func setup() {
        // The SDK's default is `.imperative`, which the demo app would otherwise
        // never exercise. The flag lets the UITests cover both update paths.
        dataSourceMode = ProcessInfo.processInfo.arguments.contains("--uitest-imperative")
            ? .imperative
            : .diffable
        globalSearchEnabled = true
        // Off by default in the SDK, so the UITests opt in explicitly.
        performsFirstActionWithFullSwipe =
            ProcessInfo.processInfo.arguments.contains("--uitest-full-swipe")
        super.setup()
        #if DEBUG
        UITestSupport.installMessageInjector(on: self)
        #endif
    }
}
