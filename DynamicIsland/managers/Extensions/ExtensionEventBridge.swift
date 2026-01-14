import Foundation

/// Bridges extension payload updates between Atoll processes (main app, helpers, XPC services).
/// Stores the latest snapshot on disk and delivers change notifications through DistributedNotificationCenter.
final class ExtensionEventBridge {
    static let shared = ExtensionEventBridge()

    private let notificationCenter = DistributedNotificationCenter.default()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let processIdentifier = ProcessInfo.processInfo.processIdentifier
    private let ioQueue = DispatchQueue(label: "com.ebullioscopic.Atoll.extensions.bridge", qos: .utility)

    private init() {}

    // MARK: - Public API

    func broadcastLiveActivitySnapshot(_ payloads: [ExtensionLiveActivityPayload]) {
        broadcast(payloads, channel: .liveActivities)
    }

    func broadcastLockScreenWidgetSnapshot(_ payloads: [ExtensionLockScreenWidgetPayload]) {
        broadcast(payloads, channel: .lockScreenWidgets)
    }

    func loadPersistedLiveActivities() -> [ExtensionLiveActivityPayload] {
        loadSnapshot(channel: .liveActivities)
    }

    func loadPersistedLockScreenWidgets() -> [ExtensionLockScreenWidgetPayload] {
        loadSnapshot(channel: .lockScreenWidgets)
    }

    func observeLiveActivitySnapshots(_ handler: @escaping ([ExtensionLiveActivityPayload], Int32) -> Void) -> NSObjectProtocol {
        observe(channel: .liveActivities, handler: handler)
    }

    func observeLockScreenWidgetSnapshots(_ handler: @escaping ([ExtensionLockScreenWidgetPayload], Int32) -> Void) -> NSObjectProtocol {
        observe(channel: .lockScreenWidgets, handler: handler)
    }

    func removeObserver(_ observer: NSObjectProtocol) {
        notificationCenter.removeObserver(observer)
    }

    // MARK: - Snapshot Storage

    private func broadcast<T: Codable>(_ payloads: [T], channel: Channel) {
        ioQueue.async { [weak self] in
            guard let self else { return }
            guard let data = try? self.encoder.encode(payloads) else { return }
            self.persistSnapshot(data, channel: channel)
            let userInfo: [String: Any] = [
                UserInfoKey.payloads: data,
                UserInfoKey.sourcePID: NSNumber(value: self.processIdentifier)
            ]
            self.notificationCenter.postNotificationName(
                channel.notificationName,
                object: nil,
                userInfo: userInfo,
                deliverImmediately: true
            )
        }
    }

    private func loadSnapshot<T: Codable>(channel: Channel) -> [T] {
        let url = snapshotURL(for: channel)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? decoder.decode([T].self, from: data)) ?? []
    }

    private func persistSnapshot(_ data: Data, channel: Channel) {
        let url = snapshotURL(for: channel)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            Logger.log("Failed to persist extension snapshot for \(channel): \(error.localizedDescription)", category: .extensions)
        }
    }

    private func snapshotURL(for channel: Channel) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = appSupport.appendingPathComponent("AtollExtensions", isDirectory: true)
        switch channel {
        case .liveActivities:
            return directory.appendingPathComponent("live_activities.json", isDirectory: false)
        case .lockScreenWidgets:
            return directory.appendingPathComponent("lock_screen_widgets.json", isDirectory: false)
        }
    }

    // MARK: - Observation

    private func observe<T: Codable>(channel: Channel,
                                     handler: @escaping ([T], Int32) -> Void) -> NSObjectProtocol {
        notificationCenter.addObserver(forName: channel.notificationName, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            let sourcePID = (notification.userInfo?[UserInfoKey.sourcePID] as? NSNumber)?.int32Value ?? 0
            guard sourcePID != self.processIdentifier else { return }

            if let data = notification.userInfo?[UserInfoKey.payloads] as? Data,
               let payloads = try? self.decoder.decode([T].self, from: data) {
                handler(payloads, sourcePID)
                return
            }

            let snapshot: [T] = self.loadSnapshot(channel: channel)
            handler(snapshot, sourcePID)
        }
    }

    // MARK: - Helpers

    private enum Channel: CustomStringConvertible {
        case liveActivities
        case lockScreenWidgets

        var notificationName: Notification.Name {
            switch self {
            case .liveActivities:
                return Notification.Name("com.ebullioscopic.Atoll.extensions.liveActivitySnapshot")
            case .lockScreenWidgets:
                return Notification.Name("com.ebullioscopic.Atoll.extensions.lockScreenWidgetSnapshot")
            }
        }

        var description: String {
            switch self {
            case .liveActivities:
                return "live-activities"
            case .lockScreenWidgets:
                return "lock-screen-widgets"
            }
        }
    }

    private enum UserInfoKey {
        static let payloads = "payloads"
        static let sourcePID = "sourcePID"
    }
}
