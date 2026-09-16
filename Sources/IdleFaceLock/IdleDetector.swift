import Foundation
import IOKit

final class IdleDetector: @unchecked Sendable {
    func idleTime() -> TimeInterval {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem")
        )

        guard service != 0 else {
            return 0
        }

        defer {
            IOObjectRelease(service)
        }

        var properties: Unmanaged<CFMutableDictionary>?

        let result = IORegistryEntryCreateCFProperties(
            service,
            &properties,
            kCFAllocatorDefault,
            0
        )

        guard result == KERN_SUCCESS, let properties else {
            return 0
        }

        let dictionary = properties.takeRetainedValue() as NSDictionary

        guard let idle = dictionary["HIDIdleTime"] as? NSNumber else {
            return 0
        }

        return idle.doubleValue / 1_000_000_000
    }
}
