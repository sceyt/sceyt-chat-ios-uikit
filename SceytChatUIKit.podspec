Pod::Spec.new do |s|
  s.name         = "SceytChatUIKit"
  s.version      = "1.5.3"
  s.summary      = "Fully customizable UI Kit on top of SceytChat SDK"
  s.description  = "Messaging and Chat API for Mobile Apps and Websites"
  s.homepage     = "https://sceyt.com"
  s.license      = "Commercial"
  s.authors      = { 
	"Ovsep Keropian" => "ovsep@sceyt.com"
  }
  s.source       = { :git => "https://github.com/sceyt/sceyt-chat-ios-uikit.git", :tag => "v#{s.version}" }
  s.requires_arc = true
  s.platform = :ios, "13.0"
  s.vendored_frameworks = 'SceytChatUIKit.xcframework'
  s.ios.frameworks = ["UIKit", "Foundation", "CoreData"]
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.dependency "SceytChat", ">= 1.5.0"
end
