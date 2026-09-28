import Foundation
import ServiceManagement

/// Registers the app itself as a login item (System Settings → General → Login Items).
enum LaunchAtLogin {
    enum State: Equatable {
        case enabled
        case disabled
        /// Registered, but the user must allow it in System Settings.
        case requiresApproval
        /// SMAppService needs macOS 13 or later.
        case unsupported
    }

    static var state: State {
        guard #available(macOS 13.0, *) else { return .unsupported }
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        default: return .disabled
        }
    }

    /// Returns an error message when macOS refuses the change.
    static func setEnabled(_ enabled: Bool) -> String? {
        guard #available(macOS 13.0, *) else { return "开机自启动需要 macOS 13 或更高版本。" }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func openSystemSettings() {
        guard #available(macOS 13.0, *) else { return }
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Login items remember the app's path, so a copy in a build folder is fragile.
    static var isInApplicationsFolder: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }
}
