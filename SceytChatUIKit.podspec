Pod::Spec.new do |s|
  s.swift_version = '5.7'
  s.name         = "SceytChatUIKit"
  s.version      = "1.6.1"
  s.summary      = "Fully customizable Chat UI Kit on top of SceytChat SDK."
  s.homepage     = "https://sceyt.com"
  s.license      = "MIT"
  s.authors      = { 
	"Ovsep Keropian" => "ovsep@sceyt.com"
  }
  s.source       = { :git => "https://github.com/sceyt/sceyt-chat-ios-uikit.git", :tag => "v#{s.version}" }
  s.requires_arc = true
  s.platform = :ios, "13.0"
  s.source_files  = ["Sources/SceytChatUIKit/**/*.swift"]
  s.resources = ["Sources/SceytChatUIKit/**/*.xcdatamodeld", "Sources/SceytChatUIKit/**/*.plist", "Sources/SceytChatUIKit/Resources/**/*.xcassets"]
  s.ios.frameworks = ["UIKit", "Foundation", "CoreData"]
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.dependency "SceytChat", ">= 1.5.8"
end
