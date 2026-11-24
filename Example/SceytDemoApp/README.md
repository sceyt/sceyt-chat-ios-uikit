# Sceyt Demo App

This example integrates Sceyt Chat UIKit and Sceyt Call UIKit in the demo app. The reusable Chat UIKit package does not depend on Call UIKit.

Keep `sceyt-call-ios-uikit` next to the `sceyt-chat-ios-uikit` checkout and open `SceytDemoApp.xcodeproj` with Xcode 16 or later. The app links the local Call UIKit package directly. Both packages must resolve the same Chat SDK version; Chat UIKit currently selects `v1.5.21-beta.1`.

`DemoCalling` initializes the Call SDK with the existing chat client and owns call state and logout cleanup. `CallChannelViewController` adds audio/video actions on the channel screen through Chat UIKit's component customization. Direct calls use P2P; group calls load all available members and use SFU.

The app builds CallKit at launch and enables PushKit for a signed-in user. `DemoPushService` owns APNs and VoIP token registration, uses the server subscriptions to avoid duplicates, retries APNs failures on connection, and unregisters both tokens on logout. The existing Call UIKit bridge receives VoIP pushes and reports incoming calls to CallKit synchronously; its push hook cancels pending socket teardown and reconnects signalling before answering. PushKit restarts after the next sign-in. The app also forwards call intents and keeps signalling connected during calls. Calling is skipped under the existing UI-test bootstrap. Microphone/camera usage descriptions and audio/VoIP background modes are configured in the demo target.

Run the `SceytDemoAppTests` target for call eligibility, roster pagination/cancellation, action availability, push token rotation, registration retry, and logout lifecycle tests. Sign in on two physical devices to verify outgoing/incoming calls, camera capture, and background/locked-device answering with push provisioning configured.

For remote delivery, enable Push Notifications for `com.sceyt.chat.demo` in the Apple developer account and use a matching provisioning profile. Configure the Sceyt application with the APNs VoIP credentials for that bundle ID; incoming calls must target the PushKit token using the `<bundle-id>.voip` APNs topic. The demo already declares the `aps-environment` entitlement and audio/VoIP/remote-notification background modes. Alert notification permission does not control VoIP registration.

The demo embeds `SceytChatBroadcastExtension` (`com.sceyt.chat.demo.BroadcastExtension`) for screen sharing. Its `SampleHandler` subclasses the SDK's `SceytSampleHandler`; Call UIKit opens the system broadcast picker and uses the shared transport automatically. Both the app and extension declare `group.com.sceyt.chat.demo` in their App Groups entitlement and `BroadcastAppGroupIdentifier` Info.plist key. The extension links the `SceytCall` package product.

For device screen sharing, register that App Group and the extension's App ID in the Apple developer account, enable the group for both App IDs, and regenerate both provisioning profiles. During an active call, tap the screen share control, select **Start Broadcast**, then verify the other device receives screen video and app audio. Stop sharing from the call UI or system recording control; ending the call also stops the broadcast. The app scheme builds and embeds the extension, and the `SceytChatBroadcastExtension` scheme supports debugging it separately.
