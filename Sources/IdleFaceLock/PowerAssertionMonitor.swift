import Foundation
import IOKit.pwr_mgt
import Darwin

final class PowerAssertionMonitor: @unchecked Sendable {
    private let ownProcessID: pid_t

    init() {
        ownProcessID = getpid()
    }

    struct ExternalAssertion {
        let processID: pid_t
        let processName: String
        let type: String
        let name: String
    }

    func externalDisplaySleepAssertions() -> [ExternalAssertion] {
        var assertionsByPID: Unmanaged<CFDictionary>?

        let result = IOPMCopyAssertionsByProcess(&assertionsByPID)

        guard result == kIOReturnSuccess, let assertionsByPID else {
            AppLogger.error("Unable to query power assertions:", result)
            return []
        }

        let dictionary = assertionsByPID.takeRetainedValue() as NSDictionary
        var resultAssertions: [ExternalAssertion] = []

        for (processKey, value) in dictionary {
            guard let processNumber = processKey as? NSNumber else {
                continue
            }

            let processID = pid_t(processNumber.int32Value)

            if processID == ownProcessID {
                continue
            }

            guard let assertions = value as? NSArray else {
                continue
            }

            let processName = processName(for: processID)

            for assertionObject in assertions {
                guard let assertion = assertionObject as? NSDictionary else {
                    continue
                }

                guard isActive(assertion) else {
                    continue
                }

                guard let type = assertion[kIOPMAssertionTypeKey] as? String else {
                    continue
                }

                guard isDisplaySleepPreventingType(type) else {
                    continue
                }

                let name = assertion[kIOPMAssertionNameKey] as? String ?? ""

                resultAssertions.append(
                    ExternalAssertion(
                        processID: processID,
                        processName: processName,
                        type: type,
                        name: name
                    )
                )
            }
        }

        return resultAssertions
    }

    private func isActive(_ assertion: NSDictionary) -> Bool {
        if let level = assertion[kIOPMAssertionLevelKey] as? NSNumber {
            return level.intValue != 0
        }
        return true
    }

    private func isDisplaySleepPreventingType(_ type: String) -> Bool {
        switch type {
        case kIOPMAssertionTypePreventUserIdleDisplaySleep,
             kIOPMAssertionTypeNoDisplaySleep:
            return true
        default:
            return false
        }
    }

    private func processName(for pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 1024)

        let result = proc_name(pid, &buffer, UInt32(buffer.count))

        guard result > 0 else {
            return "PID \(pid)"
        }

        return String(
            decoding: buffer
                .prefix(while: { $0 != 0 })
                .map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
    }
}
