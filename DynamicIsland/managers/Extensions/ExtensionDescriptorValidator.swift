import Foundation
import AtollExtensionKit

struct ExtensionDescriptorValidator {
    static func validate(_ descriptor: AtollLiveActivityDescriptor) throws {
        guard descriptor.isValid else {
            throw ExtensionValidationError.invalidDescriptor("Missing mandatory fields")
        }
        guard descriptor.leadingIcon.isValid else {
            throw ExtensionValidationError.invalidDescriptor("Invalid leading icon data")
        }
        if let badge = descriptor.badgeIcon {
            guard badge.isValid else {
                throw ExtensionValidationError.invalidDescriptor("Invalid badge icon data")
            }
        }
        if descriptor.metadata.count > 32 {
            throw ExtensionValidationError.invalidDescriptor("Metadata keys must be ≤ 32")
        }
    }

    static func validate(_ descriptor: AtollLockScreenWidgetDescriptor) throws {
        guard descriptor.isValid else {
            throw ExtensionValidationError.invalidDescriptor("Missing mandatory fields")
        }
        guard descriptor.content.count <= 12 else {
            throw ExtensionValidationError.invalidDescriptor("Too many content elements")
        }
        guard descriptor.size.width <= 480, descriptor.size.height <= 280 else {
            throw ExtensionValidationError.invalidDescriptor("Widget exceeds size limits")
        }
    }

    static func validate(_ descriptor: AtollNotchExperienceDescriptor) throws {
        guard descriptor.isValid else {
            throw ExtensionValidationError.invalidDescriptor("Missing mandatory fields")
        }
        if let durationHint = descriptor.durationHint {
            guard durationHint > 0, durationHint <= 21_600 else {
                throw ExtensionValidationError.invalidDescriptor("Duration hint must be between 0 and 6 hours")
            }
        }
    }
}
