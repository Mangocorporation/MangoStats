import Foundation

/// The XPC interface of the fan helper (S-024 to S-026). The app calls
/// `request` every sample: it sets the mode and proves the app is alive.
@objc public protocol FanHelperProtocol {
    /// Asks for a mode (FanMode raw value). Replies with the mode in effect
    /// (the hot override can turn Cool into Max) and an error, or nil.
    func request(_ mode: Int, reply: @escaping @Sendable (Int, String?) -> Void)
    /// The helper's build, so the app can replace an outdated one.
    func version(reply: @escaping @Sendable (Int) -> Void)
}

public enum FanHelper {
    public static let label = "com.mangocorp.mangostats.helper"
    public static let plistName = "\(label).plist"
    /// Bump when the helper's behavior changes; the app re-registers an older one.
    public static let version = 1
    public static let appIdentifier = "com.mangocorp.mangostats"
}
