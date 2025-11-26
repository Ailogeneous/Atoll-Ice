import AppKit
import Combine
import Defaults

enum ScreenCaptureScope: Int {
    case panelsOnly
    case entireInterface
}

final class ScreenCaptureVisibilityManager {
    static let shared = ScreenCaptureVisibilityManager()

    private let scopedWindows = NSMapTable<NSWindow, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let interfacePublisher = Defaults.publisher(.hideDynamicIslandFromScreenCapture)
            .map { _ in () }
            .eraseToAnyPublisher()

        interfacePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateAllWindows()
            }
            .store(in: &cancellables)
    }

    func register(_ window: NSWindow, scope: ScreenCaptureScope) {
        scopedWindows.setObject(NSNumber(value: scope.rawValue), forKey: window)
        applyVisibility(to: window, scope: scope)
    }

    func unregister(_ window: NSWindow) {
        scopedWindows.removeObject(forKey: window)
    }

    private func updateAllWindows() {
        guard let windows = scopedWindows.keyEnumerator().allObjects as? [NSWindow] else { return }
        for window in windows {
            guard let raw = scopedWindows.object(forKey: window)?.intValue,
                  let scope = ScreenCaptureScope(rawValue: raw) else { continue }
            applyVisibility(to: window, scope: scope)
        }
    }

    private func applyVisibility(to window: NSWindow, scope _: ScreenCaptureScope) {
        let shouldHide = Defaults[.hideDynamicIslandFromScreenCapture]
        window.sharingType = shouldHide ? .none : .readOnly
    }
}
