//
//  PanGesture.swift
//  DynamicIsland
//
//  Created by Richard Kunkli on 21/08/2024.
//

import AppKit
import SwiftUI

enum PanDirection {
    case left, right, up, down

    var isHorizontal: Bool { self == .left || self == .right }
    var sign: CGFloat { (self == .right || self == .down) ? 1 : -1 }

    func signed(from translation: CGSize) -> CGFloat { (isHorizontal ? translation.width : translation.height) * sign }
    func signed(deltaX: CGFloat, deltaY: CGFloat) -> CGFloat { (isHorizontal ? deltaX : deltaY) * sign }
}

extension View {
    func panGesture(direction: PanDirection, threshold: CGFloat = 4, action: @escaping (CGFloat, NSEvent.Phase) -> Void) -> some View {
        self
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let s = direction.signed(from: value.translation)
                        guard s > 0, s.magnitude >= threshold else { return }
                        action(s.magnitude, .changed)
                    }
                    .onEnded { _ in action(0, .ended) }
            )
            .background(ScrollMonitor(direction: direction, threshold: threshold, action: action))
    }
}

private struct ScrollMonitor: NSViewRepresentable {
    let direction: PanDirection
    let threshold: CGFloat
    let action: (CGFloat, NSEvent.Phase) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.installMonitor(on: view)
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.removeMonitor() }

    func makeCoordinator() -> Coordinator { 
        Coordinator(direction: direction, threshold: threshold, action: action) 
    }

    @MainActor final class Coordinator: NSObject {
        private let direction: PanDirection
        private let threshold: CGFloat
        private let action: (CGFloat, NSEvent.Phase) -> Void
        private var monitor: Any?
        private var globalMonitor: Any?
        private var accumulated: CGFloat = 0
        private var active = false
        private let noiseThreshold: CGFloat = 0.2
        private weak var observedView: NSView?
        private let hoverInset: CGFloat = 14
        private var lastEventTimestamp: TimeInterval = 0

        init(direction: PanDirection, threshold: CGFloat, action: @escaping (CGFloat, NSEvent.Phase) -> Void) {
            self.direction = direction
            self.threshold = threshold
            self.action = action
        }

        func installMonitor(on view: NSView) {
            removeMonitor()
            observedView = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
                guard let self else { return event }
                self.handleScroll(event)
                return event
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
                self?.handleScroll(event)
            }
        }

        func removeMonitor() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            if let globalMonitor = globalMonitor {
                NSEvent.removeMonitor(globalMonitor)
                self.globalMonitor = nil
            }
            accumulated = 0
            active = false
            observedView = nil
            lastEventTimestamp = 0
        }

        private func handleScroll(_ event: NSEvent) {
            guard lastEventTimestamp != event.timestamp else { return }
            lastEventTimestamp = event.timestamp
            guard isCursorNearObservedView(using: event) else { return }

            if event.phase == .ended || event.momentumPhase == .ended {
                if active {
                    action(accumulated.magnitude, .ended)
                } else {
                    action(0, .ended)
                }
                active = false
                accumulated = 0
                return
            }

            let s = direction.signed(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY)
            guard s.magnitude > noiseThreshold else { return }
            accumulated = s > 0 ? accumulated + s : 0

            if !active && accumulated >= threshold {
                active = true
                action(accumulated.magnitude, .began)
            } else if active {
                action(accumulated.magnitude, .changed)
            }
        }

        private func isCursorNearObservedView(using event: NSEvent) -> Bool {
            guard let view = observedView, let window = view.window else { return false }

            let screenPoint: NSPoint
            if let eventWindow = event.window {
                let rect = NSRect(origin: event.locationInWindow, size: .zero)
                screenPoint = eventWindow.convertToScreen(rect).origin
            } else {
                screenPoint = NSEvent.mouseLocation
            }

            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            let localPoint = view.convert(windowPoint, from: nil)
            let hitArea = view.bounds.insetBy(dx: -hoverInset, dy: -hoverInset)
            return hitArea.contains(localPoint)
        }
    }
}
