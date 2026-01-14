import Foundation
import Defaults
import AtollExtensionKit

@MainActor
final class ExtensionLiveActivityManager: ObservableObject {
    static let shared = ExtensionLiveActivityManager()

    @Published private(set) var activeActivities: [ExtensionLiveActivityPayload] = []

    private let authorizationManager = ExtensionAuthorizationManager.shared
    private let maxCapacityKey = Defaults.Keys.extensionLiveActivityCapacity
    private let eventBridge = ExtensionEventBridge.shared
    private var liveActivityObserver: NSObjectProtocol?
    private var suppressBroadcast = false
    private let currentProcessID = ProcessInfo.processInfo.processIdentifier

    private init() {
        activeActivities = eventBridge.loadPersistedLiveActivities()
        sortActivities()
        liveActivityObserver = eventBridge.observeLiveActivitySnapshots { [weak self] payloads, sourcePID in
            self?.applySnapshot(payloads, sourcePID: sourcePID)
        }
    }

    deinit {
        if let token = liveActivityObserver {
            eventBridge.removeObserver(token)
        }
    }

    func present(descriptor: AtollLiveActivityDescriptor, bundleIdentifier: String) throws {
        guard authorizationManager.canProcessLiveActivityRequest(from: bundleIdentifier) else {
            logDiagnostics("Rejected live activity \(descriptor.id) from \(bundleIdentifier): scope disabled or bundle unauthorized")
            throw ExtensionValidationError.unauthorized
        }
        guard descriptor.isValid else {
            logDiagnostics("Rejected live activity \(descriptor.id) from \(bundleIdentifier): descriptor validation failed")
            throw ExtensionValidationError.invalidDescriptor("Structure validation failed")
        }

        if let index = activeActivities.firstIndex(where: { $0.descriptor.id == descriptor.id && $0.bundleIdentifier == bundleIdentifier }) {
            let payload = ExtensionLiveActivityPayload(
                bundleIdentifier: bundleIdentifier,
                descriptor: descriptor,
                receivedAt: activeActivities[index].receivedAt
            )
            activeActivities[index] = payload
            sortActivities()
            authorizationManager.recordActivity(for: bundleIdentifier, scope: .liveActivities)
            Logger.log("Replaced extension live activity \(descriptor.id) for \(bundleIdentifier)", category: .extensions)
            broadcastSnapshot()
            return
        }

        guard activeActivities.count < Defaults[maxCapacityKey] else {
            logDiagnostics("Rejected live activity \(descriptor.id) from \(bundleIdentifier): capacity limit \(Defaults[maxCapacityKey]) reached")
            throw ExtensionValidationError.exceedsCapacity
        }

        let payload = ExtensionLiveActivityPayload(
            bundleIdentifier: bundleIdentifier,
            descriptor: descriptor,
            receivedAt: .now
        )
        activeActivities.append(payload)
        sortActivities()
        authorizationManager.recordActivity(for: bundleIdentifier, scope: .liveActivities)
        logDiagnostics("Queued live activity \(descriptor.id) for \(bundleIdentifier); total activities: \(activeActivities.count)")
        broadcastSnapshot()
    }

    func update(descriptor: AtollLiveActivityDescriptor, bundleIdentifier: String) throws {
        guard descriptor.isValid else {
            logDiagnostics("Rejected live activity update \(descriptor.id) from \(bundleIdentifier): descriptor validation failed")
            throw ExtensionValidationError.invalidDescriptor("Structure validation failed")
        }
        guard let index = activeActivities.firstIndex(where: { $0.descriptor.id == descriptor.id && $0.bundleIdentifier == bundleIdentifier }) else {
            throw ExtensionValidationError.invalidDescriptor("Missing existing activity")
        }
        let payload = ExtensionLiveActivityPayload(
            bundleIdentifier: bundleIdentifier,
            descriptor: descriptor,
            receivedAt: activeActivities[index].receivedAt
        )
        activeActivities[index] = payload
        sortActivities()
        authorizationManager.recordActivity(for: bundleIdentifier, scope: .liveActivities)
        logDiagnostics("Updated live activity \(descriptor.id) for \(bundleIdentifier)")
        broadcastSnapshot()
    }

    func dismiss(activityID: String, bundleIdentifier: String) {
        let previousCount = activeActivities.count
        activeActivities.removeAll { $0.descriptor.id == activityID && $0.bundleIdentifier == bundleIdentifier }
        if previousCount != activeActivities.count {
            Logger.log("Dismissed extension live activity \(activityID) from \(bundleIdentifier)", category: .extensions)
            ExtensionXPCServiceHost.shared.notifyActivityDismiss(bundleIdentifier: bundleIdentifier, activityID: activityID)
            logDiagnostics("Removed live activity \(activityID) for \(bundleIdentifier); remaining: \(activeActivities.count)")
            broadcastSnapshot()
        }
    }

    func dismissAll(for bundleIdentifier: String) {
        let ids = activeActivities
            .filter { $0.bundleIdentifier == bundleIdentifier }
            .map { $0.descriptor.id }
        activeActivities.removeAll { $0.bundleIdentifier == bundleIdentifier }
        ids.forEach { ExtensionXPCServiceHost.shared.notifyActivityDismiss(bundleIdentifier: bundleIdentifier, activityID: $0) }
        if !ids.isEmpty {
            logDiagnostics("Removed all live activities for \(bundleIdentifier); ids: \(ids.joined(separator: ", "))")
            broadcastSnapshot()
        }
    }

    func sortedActivities(for coexistence: Bool = false) -> [ExtensionLiveActivityPayload] {
        activeActivities
            .filter { coexistence ? $0.descriptor.allowsMusicCoexistence : true }
            .sorted(by: descriptorComparator)
    }

    private func descriptorComparator(lhs: ExtensionLiveActivityPayload, rhs: ExtensionLiveActivityPayload) -> Bool {
        if lhs.descriptor.priority == rhs.descriptor.priority {
            return lhs.receivedAt < rhs.receivedAt
        }
        return lhs.descriptor.priority > rhs.descriptor.priority
    }

    private func sortActivities() {
        activeActivities.sort(by: descriptorComparator)
    }

    private func broadcastSnapshot() {
        guard !suppressBroadcast else { return }
        eventBridge.broadcastLiveActivitySnapshot(activeActivities)
        logDiagnostics("Broadcasted live activity snapshot (count: \(activeActivities.count))")
    }

    private func applySnapshot(_ payloads: [ExtensionLiveActivityPayload], sourcePID: Int32) {
        guard sourcePID != currentProcessID else { return }
        suppressBroadcast = true
        activeActivities = payloads.sorted(by: descriptorComparator)
        suppressBroadcast = false
        logDiagnostics("Applied external live activity snapshot from PID \(sourcePID) (count: \(payloads.count))")
    }

    private func logDiagnostics(_ message: String) {
        guard Defaults[.extensionDiagnosticsLoggingEnabled] else { return }
        Logger.log(message, category: .extensions)
    }
}
