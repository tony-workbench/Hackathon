import Foundation
import Observation

@Observable
@MainActor
final class AppConfiguration {
    static let shared = AppConfiguration()

    private enum Keys {
        static let backendURL = "backendURL"
        static let useDemoCalls = "useDemoCalls"
    }

    var backendURLString: String {
        didSet { UserDefaults.standard.set(backendURLString, forKey: Keys.backendURL) }
    }

    var useDemoCalls: Bool {
        didSet { UserDefaults.standard.set(useDemoCalls, forKey: Keys.useDemoCalls) }
    }

    var backendURL: URL? {
        URL(string: backendURLString)
    }

    /// Backend base URL used by live translation and produce inspection.
    /// Replace it with your own backend's HTTPS URL (for example a Cloudflare tunnel).
    static let defaultBackendURL = "https://your-backend.example.com"

    private init() {
        self.backendURLString = UserDefaults.standard.string(forKey: Keys.backendURL)
            ?? Self.defaultBackendURL
        self.useDemoCalls = UserDefaults.standard.object(forKey: Keys.useDemoCalls) as? Bool ?? false
    }
}
