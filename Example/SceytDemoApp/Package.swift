// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SceytDemoCall",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "SceytDemoCall", targets: ["SceytDemoCall"])
    ],
    dependencies: [
        .package(path: "../../sceyt-chat-ios-uikit"),
        .package(path: "Vendor/SceytCallBinary")
    ],
    targets: [
        .target(
            name: "SceytDemoCall",
            dependencies: [
                .product(name: "SceytChatUIKit", package: "sceyt-chat-ios-uikit"),
                .product(name: "SceytCall", package: "SceytCallBinary")
            ],
            path: "SceytDemoApp/Call",
            exclude: [
                "Views/CallVC/CallVC+Constraints.swift",
                "Views/CallVC/CallVC+Helper.swift",
                "Views/CallVC/CallVC+Participant.swift",
                "Views/CallVC/CallVC+Timer.swift",
                "Views/CallVC/CallVC+Video.swift",
                "Views/CallVC/CallAvatarsView.swift",
                "Views/CallVC/CallBarView.swift",
                "Views/CallVC/CallMenuView.swift",
                "Views/CallVC/CallToolsView.swift",
                "Views/CallVC/IncomingToolsView.swift",
                "Views/CallVC/NoAnswerToolsView.swift",
                "Views/Video/CallVoiceAmplitudeView.swift",
                "Views/Video/ParticipantVideoContentView.swift",
                "Views/Video/ScreenshareContentView.swift",
                "Views/Video/UserVideoContentView.swift",
                "Views/Video/VideoThumbnailView.swift",
                "Views/Video/VideoView.swift",
                "Views/SwitchButton.swift"
            ]
        )
    ]
)
