import Foundation
import LocalAuthentication
import Observation

/// Face ID / Touch ID / passcode lock. The lock engages when Penny goes to the
/// background and must be cleared with the device owner's authentication.
@Observable
final class AppLock {
    var isLocked: Bool
    var isAuthenticating = false
    var message: String?

    init(enabled: Bool) {
        isLocked = enabled
    }

    /// True when Face ID, Touch ID or a device passcode is set up.
    static var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// "Face ID", "Touch ID", "Optic ID" or "Passcode".
    static var methodName: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    static var methodSymbol: String {
        switch methodName {
        case "Face ID": return "faceid"
        case "Touch ID": return "touchid"
        case "Optic ID": return "opticid"
        default: return "lock"
        }
    }

    /// Asks for Face ID / Touch ID, falling back to the device passcode.
    @MainActor
    func verify(reason: String) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        context.localizedCancelTitle = "Not now"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    @MainActor
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        if await verify(reason: "Unlock Penny to see your finances.") {
            isLocked = false
            message = nil
        } else {
            message = "Penny is still locked."
        }
    }
}
