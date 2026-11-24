# Sceyt Chat UIKit for iOS
The Sceyt Chat UIKit is a comprehensive toolkit designed for chat integration. With prebuilt and customizable UI components, it allows for quick integration of a fully-featured chat into your iOS application with minimal coding.

![Sceyt Chat UIKit](https://us-ohio-api.sceyt.com/user/api/v1/files/8lwox2ge93/cc7974d21fef0eee32fcce0abd1a16841b8828aabafbc808a0a12ad830090479b252b375cb4a93eac4f408950222/ios.webp)


## Table of Contents
* [Features](#features)
* [Requirements](#requirements)
* [Installation](#installation)
* [Usage](#usage)
* [Customization](#customization)
* [Development](#development)

## Features
- **Offline Support:** Automatically stores messages and new chats when offline, and synchronizes them upon reconnection.
- **Photo & Video resizer:** On-device Photo and Video resizer for faster delivery with adjustable quality parameters.
- **Voice Messages:** Built-in support for voice message recording and play back.
- **Light, Dark Mode:**  Supports both themes, adapting to user preferences for a consistent experience.

## Requirements
Minimal iOS and Swift version requirements:
- iOS 13+
- Swift 5.7+

## Installation
You can integrate Sceyt Chat UI Kit into your Swift iOS project using multiple dependency managers.

### Swift Package Manager
The Sceyt Chat UI Kit is available as a Swift Package. To add it to your project, follow these steps:

1. In Xcode, open your project.
2. Navigate to your project settings.
3. Go to the "Package Dependencies" tab.
4. Click the "+" button to add a new package dependency.
5. Enter the following URL: `https://github.com/sceyt/sceyt-chat-ios-uikit.git`.
6. Add the Sceyt Chat UI Kit package to your project.

### CocoaPods
To add Sceyt Chat UIKit as a dependency using CocoaPods, follow these steps:

1. Ensure you have CocoaPods installed on your system.
2. Create a Podfile in your project directory (if you don't have one already) by running:

```bash
pod init
```

3. Edit your Podfile to include Sceyt Chat UIKit:

```ruby
platform :ios, '13.0'  # Specify your minimum iOS version if different

target 'YourApp' do
  use_frameworks!

  # Add Sceyt Chat UIKit as a dependency
  pod 'SceytChatUIKit', :git => 'https://github.com/sceyt/sceyt-chat-ios-uikit.git'
end
```

4. Install the dependencies by running:

```bash
pod install
```

## Usage

Before starting the integration, it is highly recommended to explore our [example apps](https://github.com/sceyt/sceyt-chat-ios-uikit/tree/main/Example) to observe how Sceyt Chat UIKit is initialized and utilized in real applications. These examples provide valuable insights into the integration process.

1. Initialize the Sceyt Chat UIKit with the API URL and Application ID of your Sceyt application in your app's `AppDelegate` or an appropriate initialization point:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // The URL of the Sceyt Chat application where UIKit app connects.
        let apiUrl = "API_URL"
        // The ID of the Sceyt Chat application used by the UIKit app.
        let appId = "APP_ID"

        SceytChatUIKit.initialize(apiUrl: apiUrl, appId: appId)
        
        return true
    }
```

2. After initializing the Sceyt Chat UIKit and setting up the configuration, the next step is to establish a connection to Sceyt Chat API.

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        ...
        // The user's access token for the Sceyt Chat API.
        let accessToken = "USER_ACCESS_TOKEN"

        SceytChatUIKit.shared.connect(token: accessToken)

        return true
    }
```

## Customization

### Basic
Customizing the appearance of the Sceyt Chat UIKit is easy and allows you to tailor it to your application's design. You can customize fonts, colors, icons, and any component, including channel and message cells, message input text box, and many more. 

These following customizations can be applied during the Sceyt Chat UIKit initialization, ensuring that your preferred settings are in place from the start. Here's how you can customize various aspects:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        ...

        SceytChatUIKit.initialize(apiUrl: apiUrl, appId: appId)

        ...

        // Configure invite link settings
        SceytChatUIKit.shared.config.channelInviteDeepLinkConfig = SceytChatUIKit.Config.ChannelInviteDeepLinkConfig(
            scheme: "https",
            host: "link.sceyt.com",
            pathPrefix: "/join/"
        )
        
        // To change the fonts used in the UIKit, you can use the `Appearance.Fonts` property.
        // For example, to set a custom font:
        Appearance.Fonts.regular = UIFont(name: "CUSTOM_FONT", size: 10)

        // Customizing colors is straightforward with the Appearance.Colors property.
        // FOr instance to change only the accent color:
        SceytChatUIKit.shared.theme.colors = .init(accent: .blue)

        // You can also replace icons or images by using the Appearance.Images property.
        // For example, to change the chat action camera icon:
        Appearance.Images.chatActionCamera = UIImage(named: "camera")

        return true
    }
```

### Comprehensive
For comprehensive customization, create custom subclasses and override relevant functions during the UIKit initialization. This allows you to adjust default values and appearance according to your preferences.

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ...
    SceytChatUIKit.Components.channelCell = DemoChannelCell.self
    ...
    return true
}
```
```swift
class DemoChannelCell: ChannelCell {

    override func setupAppearance() {

        super.setupAppearance()

        dateLabel.textColor = .green
        subjectLabel.font = UIFont.systemFont(ofSize: 14)

    }

    override func deliveryStatusImage(message: ChatMessage?) -> UIImage? {

        guard let message = message, !message.incoming else { return nil }

        switch message.deliveryStatus {
        case .pending:
            return UIImage(named: "pendingMessage")
        case .sent:
            return UIImage(named: "sentMessage")
        case .received:
            return UIImage(named: "deliveredMessage")
        case .displayed:
            return UIImage(named: "readMessage")
        case .failed:
            return UIImage(named: "failedMessage")
        }
    }
}
```

## Development

For local setup, test commands, pull request checks, and submitting changes, see the [contributor guide](CONTRIBUTING.md). [AGENTS.md](AGENTS.md) holds the repository's review and verification rules, and [Sources/ARCHITECTURE.md](Sources/ARCHITECTURE.md) follows a channel's messages from SceytChat through the database to the screen. Report vulnerabilities as described in [SECURITY.md](SECURITY.md).

### Continuous integration

The `iOS CI` workflow in `.github/workflows/ios-ci.yml` runs for pull requests to `main` and `dev`, for pushes to `main`, `dev`, and `v*` release branches, and from **Actions → iOS CI → Run workflow**. It uses the latest stable Xcode on the `macos-latest` runner, builds without code signing, and resolves the Sceyt Chat iOS SDK from `Package.swift`. The demo app is not built, because it also needs a `sceyt-call-ios-uikit` checkout.

The `unit-tests` job:

1. Checks the size and the failure logging of the data transfer layer (`Sources/SceytChatUIKit/DataTransfer`).
2. Builds the package with complete concurrency checking and fails on any warning in the data transfer layer.
3. Runs the package unit tests on an iPhone simulator, except `GlobalSearchMessagesViewModelDBPerformanceTests`, with code coverage and complete concurrency checking (`SWIFT_STRICT_CONCURRENCY=complete`).
4. Compares the public Swift interface of `SceytChatUIKit` with `api/SceytChatUIKit.swiftinterface`.

For pull requests, it also tests the check scripts and checks changed-source formatting, compiler warnings on changed lines, and 80% coverage of changed lines in `Sources/SceytChatUIKit`. See the [contributor guide](CONTRIBUTING.md#check-changed-lines-before-pushing). When a step fails, the job writes the compile errors and failing tests to the run summary and uploads the test results, build log, and generated interface as the `test-results` artifact.

The **Thread Sanitizer** job runs the unit tests with Thread Sanitizer in parallel and uploads its result bundle and log when it fails. See [Check for data races](CONTRIBUTING.md#check-for-data-races).

To enforce the checks before merging, require `unit-tests` and **Thread Sanitizer** in the branch protection rule or ruleset for `main` and `dev`.

After both jobs finish, **Slack Alerts** posts the result to Slack. A failure alert names the failed check first, for example `🔴 Changed-line coverage failed`. The message includes the branch or pull request, commit, the passed and failed jobs, and a link to the run. Cancelled runs, outdated pull request commits, and fork pull requests do not send alerts. The alert uses the `SLACK_WEBHOOK_URL_CI_IOS` secret, a Slack incoming webhook URL set at the organization level or under **Settings → Secrets and variables → Actions**. Until the secret is available to this repository, the job skips the alert without failing. The sender does not check out pull request code, retry failed deliveries, or print the webhook URL. Delivery failures appear in the **Slack Alerts** job, which does not need to be required for merging.

Run the CI script tests locally with Python 3.9 or newer and Node.js 20 or newer:

```bash
python3 -B -m unittest discover -s scripts/tests
node --test .github/tests/slack-alerts.test.cjs
```

The Slack tests mock GitHub and Slack requests, including a missing or invalid webhook and delivery failures, without posting to Slack.
