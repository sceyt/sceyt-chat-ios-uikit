import Foundation

public class SelfChannelMetadata: Codable {
    public let s: Bool

    public init(s: Bool) {
        self.s = s
    }
}
