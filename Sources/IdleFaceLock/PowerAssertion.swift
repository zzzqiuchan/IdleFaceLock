import Foundation
import IOKit.pwr_mgt

final class PowerAssertion: @unchecked Sendable {
    private var assertionID = IOPMAssertionID(kIOPMNullAssertionID)
    private var active = false

    var isActive: Bool { active }

    @discardableResult
    func acquire() -> Bool {
        guard !active else {
            return true
        }

        var id = IOPMAssertionID(kIOPMNullAssertionID)

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "IdleFaceLock - User presence monitoring" as CFString,
            &id
        )

        guard result == kIOReturnSuccess else {
            AppLogger.error("Failed to acquire power assertion:", result)
            return false
        }

        assertionID = id
        active = true

        AppLogger.log("Power assertion acquired:", assertionID)
        return true
    }

    func release() {
        guard active else {
            return
        }

        let result = IOPMAssertionRelease(assertionID)

        if result == kIOReturnSuccess {
            AppLogger.log("Power assertion released:", assertionID)
        } else {
            AppLogger.error("Failed to release power assertion:", result)
        }

        assertionID = IOPMAssertionID(kIOPMNullAssertionID)
        active = false
    }

    deinit {
        release()
    }
}
