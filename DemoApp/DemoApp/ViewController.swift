//
//  ViewController.swift
//  DemoApp
//
//

import UIKit
import SceytChatUIKit
import SceytChat

struct Config {
    static let sceytHost = "https://us-ohio-api.sceyt.com"
    static let sceytId = "8lwox2ge93"
    static let genTokenPrefix = "https://tlnig20qy7.execute-api.us-east-2.amazonaws.com/dev/user/genToken?user="
    static var user = "user1"
}


extension Config {
    enum UserDefaultsKeys {
        static let clientIdKey = "__demoapp__client__uuid__"
    }
    @UserDefaultsConfig(UserDefaultsKeys.clientIdKey, defaultValue: UUID().uuidString)
    static var clientId: String?
}

@propertyWrapper
struct UserDefaultsConfig<T> {
    let key: String
    let defaultValue: T?

    init(_ key: String, defaultValue: T? = nil) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T? {
        get { return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

class ViewController: UIViewController, ChatClientDelegate {

    lazy var connect: UIButton = {
        $0.setTitle("Connect", for: .normal)
        $0.setTitleColor(UIColor.blue, for: .normal)
        $0.addTarget(self, action: #selector(onConnect), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton(type: .custom))
    
    lazy var textField: UITextField = {
        $0.placeholder = "user id"
        $0.text = Config.user
        $0.textAlignment = .center
        $0.borderStyle = .roundedRect
        return $0.withoutAutoresizingMask
    }(UITextField())

    
    static var retainVC: UIViewController?
    
    let session = AWSSession.default
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Self.retainVC = self
        // Do any additional setup after loading the view.  
        connect.translatesAutoresizingMaskIntoConstraints = false
        connect.setTitle("Connect", for: .normal)
        connect.setTitleColor(UIColor.blue, for: .normal)
        connect.addTarget(self, action: #selector(onConnect), for: .touchUpInside)
        view.addSubview(textField)
        view.addSubview(connect)
        textField.pin(to: view, anchors: [.leading(16), .trailing(-16)])
        textField.bottomAnchor.pin(to: connect.topAnchor, constant: -16)
        connect.pin(to: view, anchors: [.centerX(), .centerY()])
        connect.resize(anchors: [.height(40), .width(200)])
        SCUIKitConfig.storageDirectory = URL(fileURLWithPath: FileStorage.default.storagePath)
        do {
//            ChannelCell.appearance.subjectLabelFont = UIFont.systemFont(ofSize: 30)
//            ChannelCell.appearance.unreadCountBackgroundColor = .cyan
//            ChannelCell.appearance.unreadCountTextColor = UIColor.blue
//            ChannelCell.appearance.dateLabelFont = UIFont.systemFont(ofSize: 20)
//            ChannelCell.appearance.unreadCountBackgroundColor = .blue
//            ChannelCell.appearance.unreadCountTextColor = UIColor.white

            SCUIKitComponents.dataSession = SCTSession.default
//            try ClassRepository.default.register(subClass: DemoChannelListView.self, for: ChannelListVC.self)
    //        ClassRepository.default.register(subClass: DemoChannelCell.self, for: ChannelCell.self)
            try ClassRepository.default.register(subClass: DemoStoringKey.self, for: SceytChatStoringKey.self)
//            try ClassRepository.default.register(subClass: DemoStorage.self, for: Storage.self)
//            try ClassRepository.default.register(subClass: DemoChatView.self, for: ChatVC.self)
//            try ClassRepository.default.register(subClass: DemoChatCell.self, for: MessageCollectionViewCell.self)
    //        ChannelListVM.queryListOrder = .createdAt
            
//            try ClassRepository.default.register(subClass: DemoChannelProfileVC.self, for: ChannelProfileVC.self)
//            SceytChatUIKit.Config.storageDirectory = nil
        } catch {
            debugPrint(error)
        }
        configure()
        
//        ChannelCollectionViewLayout.Defaults.default.estimatedFooterHeight = 10
//        var ma = MessageCell.Appearance()
//        ma.separatorViewBackgroundColor = .red
//        ma.separatorViewFont = .systemFont(ofSize: 8)
//        ma.separatorViewTextColor = .green
//        ma.separatorViewBorderColor = .clear
//        MessageCell.appearance = ma
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @objc func onConnect() {
        let tab = TabBarController()
        
        if let text = textField.text,
            !text.isEmpty,
            text != Config.user {
            Config.user = text
        }

        
        let nav = UINavigationController(rootViewController: SCUIKitComponents.channelListVC.init())
        nav.modalPresentationStyle = .fullScreen
        tab.viewControllers = [nav]
//        present(nav, animated: true)
        view.window?.rootViewController = tab
        getToken(user: Config.user) { token, error in
            guard let token = token else {
                fatalError(error!.localizedDescription)
            }
            SCUIKitConfig.connect(accessToken: token)
        }
    }

    func configure() {
        SCUIKitConfig.initialize(apiUrl: Config.sceytHost, appId: Config.sceytId, clientId: Config.clientId!)
        SCUIKitConfig.setLogLevel(.verbose)
        ChatClient.shared.add(delegate: self, identifier: "ViewControllertaskdelegate")
    }
    
    func chatClient(_ chatClient: ChatClient, didChange state: ConnectionState, error: SceytError?) {
        if state == .connected {
//            SyncService.syncChannels()
        }
    }

}

class TabBarController: UITabBarController {
    
}

func getToken(user: String, callback: @escaping (_ token: String?, _ error: Error?) -> Void) {

    let urlString = (Config.genTokenPrefix + user + "&app=staging")
    guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
    let url = URL(string: encoded) else {
        callback(nil, NSError(domain: "com.sceyt.uikit.demoapp", code: -1, userInfo: [NSLocalizedDescriptionKey: "\(Config.genTokenPrefix + user + "&app=staging")"]))
       return
   }
   URLSession.shared.dataTask(with: url) { (data, response, error) in
       func _callback(_ token: String?, _ error: Error?) {
           DispatchQueue.main.async {
               callback(token, error)
           }
       }
       if let data = data {
           if let token =  (try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: String])?["token"] {
               _callback(token, error)
           } else {
               _callback(nil, NSError(domain: "com.sceyt.demoapp", code: -2, userInfo: [NSLocalizedDescriptionKey: "\(String(describing: String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)))"]))
           }
       } else {
           _callback(nil, error)
       }
   }.resume()
}

class DemoChannelListView: ChannelListVC {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 14.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: .init(handler: {[weak self] _ in
                self?.dismiss(animated: true)
                SCUIKitConfig.disconnect()
            }))
        } else {
            // Fallback on earlier versions
        }
        
    }
    
    override var title: String? {
        get {
            "chat"
        }
        set {
            debugPrint(newValue as Any)
        }
    }
}


class DemoChannelCell: ChannelCell {
    
//    override func bind(_ data: Channel) {
//        nameLabel.text = appearance.formatters.channelDisplayName.format(data)
//
//        messageLabel.attributedText =  message(channel: data)
//        dateLabel.text = appearance.formatters.channelTimestamp.format(data.lastMessage?.createdAt ?? data.createdAt)
//        ticksView.image = deliveryStatusImage(message: data.lastMessage)?.withRenderingMode(.alwaysOriginal)
//        unreadCount.isHidden = data.unreadMessageCount == 0 && !data.markedAsUnread
//        unreadCount.value = unreadCount(channel: data)
//        muteView.isHidden = !data.muted
//
//        if let directChannel = data as? DirectChannel {
//            onlineStatusView.isHidden = directChannel.peer.presence.state != .online
//        } else {
//            onlineStatusView.isHidden = true
//        }
//        imageTask = avatarBuilder.loadAvatar(into: avatarView.imageView, for: data, appearance: appearance)
//    }
//
//    override func message(channel: Channel) -> NSAttributedString {
//        let str = NSMutableAttributedString(attributedString: super.message(channel: channel))
//        str.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: str.length))
//        return str
//    }
//
//    override func setupAppearance() {
//        super.setupAppearance()
//        nameLabel.textColor = .white
//        messageLabel.textColor = .red
//    }
}

class DemoStoringKey: SceytChatStoringKey {
    required init() {
        super.init()
        let fileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test6")
        do {
            try FileManager.default.createDirectory(at: fileUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        } catch  {
            debugPrint(#function, error)
        }
        storageFolderPath = fileUrl.path
    }
    
//    override var storageFolderPath: String {
//        set { }
//        get { NSTemporaryDirectory()}
//    }
}

class DemoStorage: Storage {
    
    override init() {
        super.init()
    }
    
    override class func storeFile(originalUrl url: URL, file srcUrl: URL, deleteFromSrc: Bool = false) -> URL {
        let fileUrl = URL(fileURLWithPath: storingKey.storingPath(url: url)).appendingPathComponent(storingKey.storingFilename(url: url))
        do {
            try? FileManager.default.removeItem(at: fileUrl)
            try? FileManager.default.createDirectory(at: fileUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.copyItem(at: srcUrl, to: fileUrl)
        } catch  {
            debugPrint(#function, error)
        }
        return fileUrl
    }
}

class DemoChatView: ChannelVC {
    
    override func setup() {
        super.setup()
//        Appearance.Colors.white = .green
//        Appearance.Colors.background = .black
//        Appearance.Colors.background2 = .white
//        Appearance.Fonts.regular = .monospacedSystemFont(ofSize: 0, weight: .medium)
//        collectionView.register(DemoSystemMessageCell.self)
    }

//    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        let item = viewModel.items[indexPath.row]
//        if let message = item.message, message.type == "system" {
//            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: DemoSystemMessageCell.self)
//            cell.label.text = message.body
//            return cell
//        }
//        return super.collectionView(collectionView, cellForItemAt: indexPath)
//    }
    
//    override func createMessage() -> UserSendMessage {
//        let m = super.createMessage()
//        m.text = m.text.trimmingCharacters(in: .whitespacesAndNewlines)
//        return m
//
//    }
}

class DemoSystemMessageCell: CollectionViewCell {
    
    lazy var label = UILabel()
        .withoutAutoresizingMask
    
    override func setupLayout() {
        super.setupLayout()
        addSubview(label)
        label.pin(to: self)
    }
    
    override func setupAppearance() {
        super.setupAppearance()
        label.font = .systemFont(ofSize: 20)
        label.textColor = .red
        label.textAlignment = .center
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let preferredAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        guard preferredAttributes.frame != layoutAttributes.frame else { return preferredAttributes }

        let targetSize = CGSize(width: layoutAttributes.frame.width, height: UIView.layoutFittingCompressedSize.height)

        preferredAttributes.frame.size = contentView
            .systemLayoutSizeFitting(targetSize,
                                     withHorizontalFittingPriority: .required,
                                     verticalFittingPriority: .fittingSizeLevel)

        return preferredAttributes
    }
}


class DemoChatCell: MessageCell {
    
    override func setup() {
        super.setup()
//        Appearance.Colors.white = .black
//        Appearance.Colors.background = .black
//        Appearance.Colors.background2 = .red
//        Appearance.Fonts.regular = .monospacedSystemFont(ofSize: 0, weight: .medium)
    }
}


extension MemberDTO {
    
}
