//
//  ContentView.swift
//  DynamicIslandApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @EnvironmentObject var webcamManager: WebcamManager

    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var reminderManager = ReminderLiveActivityManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var statsManager = StatsManager.shared
    @ObservedObject var recordingManager = ScreenRecordingManager.shared
    @ObservedObject var privacyManager = PrivacyIndicatorManager.shared
    @ObservedObject var doNotDisturbManager = DoNotDisturbManager.shared
    @ObservedObject var lockScreenManager = LockScreenManager.shared
    
    @Default(.enableStatsFeature) var enableStatsFeature
    @Default(.showCpuGraph) var showCpuGraph
    @Default(.showMemoryGraph) var showMemoryGraph
    @Default(.showGpuGraph) var showGpuGraph
    @Default(.showNetworkGraph) var showNetworkGraph
    @Default(.showDiskGraph) var showDiskGraph
    @Default(.enableReminderLiveActivity) var enableReminderLiveActivity
    
    // Dynamic sizing based on view type and graph count with smooth transitions
    var dynamicNotchSize: CGSize {
        var baseSize = Defaults[.enableMinimalisticUI] ? minimalisticOpenNotchSize : openNotchSize
        
        guard coordinator.currentView == .stats else {
            return baseSize
        }
        
        let rows = statsRowCount()
        if rows <= 1 {
            return baseSize
        }
        
        let additionalRows = max(rows - 1, 0)
        let extraHeight = CGFloat(additionalRows) * statsAdditionalRowHeight
        return CGSize(width: baseSize.width, height: baseSize.height + extraHeight)
    }
    

    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var lastHapticTime: Date = Date()

    @State private var gestureProgress: CGFloat = .zero
    @State private var isMusicControlWindowVisible = false
    @State private var pendingMusicControlTask: Task<Void, Never>?
    @State private var musicControlHideTask: Task<Void, Never>?
    @State private var musicControlVisibilityDeadline: Date?
    @State private var isMusicControlWindowSuppressed = false
    @State private var hasPendingMusicControlSync = false
    @State private var pendingMusicControlForceRefresh = false
    @State private var musicControlSuppressionTask: Task<Void, Never>?

    @State private var haptics: Bool = false

    @Namespace var albumArtNamespace

    @Default(.useMusicVisualizer) var useMusicVisualizer
    @Default(.musicControlWindowEnabled) var musicControlWindowEnabled
    @Default(.showNotHumanFace) var showNotHumanFace
    @Default(.useModernCloseAnimation) var useModernCloseAnimation
    @Default(.enableMinimalisticUI) var enableMinimalisticUI

    private static let musicControlLogFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func logMusicControlEvent(_ message: String) {
#if DEBUG
        let timestamp = Self.musicControlLogFormatter.string(from: Date())
        print("[MusicControl] \(timestamp): \(message)")
#endif
    }

    private func runAfter(_ delay: TimeInterval, _ action: @escaping @Sendable @MainActor () -> Void) {
        guard delay >= 0 else { return }
        Task { @MainActor in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            action()
        }
    }

    private func requestMusicControlWindowSyncIfHidden(forceRefresh: Bool = false, delay: TimeInterval = 0) {
        guard !isMusicControlWindowVisible else { return }
        enqueueMusicControlWindowSync(forceRefresh: forceRefresh, delay: delay)
    }
    private var dynamicNotchResizeAnimation: Animation? {
        if enableMinimalisticUI && reminderManager.activeWindowReminders.isEmpty == false {
            return nil
        }
        return .easeInOut(duration: 0.4)
    }
    
    private let zeroHeightHoverPadding: CGFloat = 10
    private let statsAdditionalRowHeight: CGFloat = 110
    private let musicControlPauseGrace: TimeInterval = 5
    private let musicControlResumeDelay: TimeInterval = 0.24
    
    // Use minimalistic corner radius ONLY when opened, keep normal when closed
    private var activeCornerRadiusInsets: (opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) {
        if enableMinimalisticUI {
            // Keep normal closed corner radius, use minimalistic when opened
            return (opened: minimalisticCornerRadiusInsets.opened, closed: cornerRadiusInsets.closed)
        }
        return cornerRadiusInsets
    }
    
    private var currentShadowPadding: CGFloat {
        notchShadowPaddingValue(isMinimalistic: enableMinimalisticUI)
    }

    private var currentNotchShape: NotchShape {
        let topRadius = (vm.notchState == .open && Defaults[.cornerRadiusScaling])
            ? activeCornerRadiusInsets.opened.top
            : activeCornerRadiusInsets.closed.top
        let bottomRadius = (vm.notchState == .open && Defaults[.cornerRadiusScaling])
            ? activeCornerRadiusInsets.opened.bottom
            : activeCornerRadiusInsets.closed.bottom
        return NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius)
    }

    var body: some View {
        let interactionsEnabled = !lockScreenManager.isLocked

        ZStack(alignment: .top) {
            let mainLayout = NotchLayout()
                .frame(alignment: .top)
                .padding(.horizontal, vm.notchState == .open
                         ? Defaults[.cornerRadiusScaling] ? (activeCornerRadiusInsets.opened.top - 5) : (activeCornerRadiusInsets.opened.bottom - 5)
                         : activeCornerRadiusInsets.closed.bottom
                )
                .padding([.horizontal, .bottom], vm.notchState == .open ? 12 : 0)
                .background(.black)
                .clipShape(currentNotchShape)
                .compositingGroup()
                .shadow(
                    color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                        ? .black.opacity(0.6)
                        : .clear,
                    radius: Defaults[.cornerRadiusScaling] ? 10 : 5
                )
                .padding(.bottom,
                    currentShadowPadding + (
                        vm.notchState == .open && Defaults[.extendHoverArea]
                            ? 0
                            : (vm.effectiveClosedNotchHeight == 0 ? zeroHeightHoverPadding : 0)
                    )
                )

            mainLayout
                .conditionalModifier(!useModernCloseAnimation) { view in
                    let hoverAnimation = Animation.bouncy.speed(1.2)
                    let notchStateAnimation = Animation.spring.speed(1.2)
                    let viewTransitionAnimation = Animation.easeInOut(duration: 0.4)
                    return view
                        .animation(hoverAnimation, value: isHovering)
                        .animation(notchStateAnimation, value: vm.notchState)
                        .animation(viewTransitionAnimation, value: coordinator.currentView)
                        .animation(.smooth, value: gestureProgress)
                        .transition(.blurReplace.animation(.interactiveSpring(dampingFraction: 1.2)))
                }
                .conditionalModifier(useModernCloseAnimation) { view in
                    let hoverAnimation = Animation.bouncy.speed(1.2)
                    let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
                    let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
                    let viewTransitionAnimation = Animation.easeInOut(duration: 0.4)
                    let notchAnimation = vm.notchState == .open ? openAnimation : closeAnimation
                    return view
                        .animation(hoverAnimation, value: isHovering)
                        .animation(notchAnimation, value: vm.notchState)
                        .animation(viewTransitionAnimation, value: coordinator.currentView)
                        .animation(.smooth, value: gestureProgress)
                }
                .conditionalModifier(interactionsEnabled) { view in
                    view
                        .onHover { hovering in
                            handleHover(hovering)
                        }
                        .onTapGesture {
                            if vm.notchState == .closed && Defaults[.enableHaptics] {
                                triggerHapticIfAllowed()
                            }
                            openNotch()
                        }
                        .conditionalModifier(Defaults[.enableGestures]) { view in
                            view
                                .panGesture(direction: .down) { translation, phase in
                                    handleDownGesture(translation: translation, phase: phase)
                                }
                        }
                }
                .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures] && interactionsEnabled) { view in
                    view
                        .panGesture(direction: .up) { translation, phase in
                            handleUpGesture(translation: translation, phase: phase)
                        }
                }
                .onAppear(perform: {
                    runAfter(1) {
                        withAnimation(vm.animation) {
                            if coordinator.firstLaunch {
                                openNotch()
                            }
                        }
                    }
                })
                .onChange(of: vm.notchState) { _, newState in
                    // Update smart monitoring based on notch state
                    if enableStatsFeature {
                        let currentViewString = coordinator.currentView == .stats ? "stats" : "other"
                        statsManager.updateMonitoringState(
                            notchIsOpen: newState == .open,
                            currentView: currentViewString
                        )
                    }
                    
                    // Reset hover state when notch state changes
                    if newState == .closed && isHovering {
                        withAnimation {
                            isHovering = false
                        }
                    }
                }
                .onChange(of: vm.isBatteryPopoverActive) { _, newPopoverState in
                    runAfter(0.1) {
                        if !newPopoverState && !isHovering && vm.notchState == .open && !vm.isStatsPopoverActive && !vm.isMediaOutputPopoverActive && !vm.isReminderPopoverActive {
                            vm.close()
                        }
                    }
                }
                .onChange(of: vm.isStatsPopoverActive) { _, newPopoverState in
                    runAfter(0.1) {
                        if !newPopoverState && !isHovering && vm.notchState == .open && !vm.isBatteryPopoverActive && !vm.isClipboardPopoverActive && !vm.isColorPickerPopoverActive && !vm.isMediaOutputPopoverActive && !vm.isReminderPopoverActive {
                            vm.close()
                        }
                    }
                }
                .onChange(of: vm.shouldRecheckHover) { _, _ in
                    // Recheck hover state when popovers are closed
                    runAfter(0.1) {
                        if vm.notchState == .open && !vm.isBatteryPopoverActive && !vm.isClipboardPopoverActive && !vm.isColorPickerPopoverActive && !vm.isStatsPopoverActive && !vm.isMediaOutputPopoverActive && !vm.isReminderPopoverActive && !isHovering {
                            vm.close()
                        }
                    }
                }
                .onChange(of: coordinator.sneakPeek.show) { _, sneakPeekShowing in
                    // When sneak peek finishes, check if user is still hovering and open notch if needed
                    if !sneakPeekShowing {
                        runAfter(0.2) {
                            if isHovering && vm.notchState == .closed {
                                openNotch()
                            }
                        }
                    }
                }
                .onChange(of: coordinator.currentView) { _, newValue in
                    if enableStatsFeature {
                        let currentViewString = newValue == .stats ? "stats" : "other"
                        statsManager.updateMonitoringState(
                            notchIsOpen: vm.notchState == .open,
                            currentView: currentViewString
                        )
                    }
                }
                .sensoryFeedback(.alignment, trigger: haptics)
                .contextMenu {
                    Button("Settings") {
                        SettingsWindowController.shared.showWindow()
                    }
//                    Button("Edit") { // Doesnt work....
//                        let dn = DynamicNotch(content: EditPanelView())
//                        dn.toggle()
//                    }
//                    #if DEBUG
//                    .disabled(false)
//                    #else
//                    .disabled(true)
//                    #endif
//                    .keyboardShortcut("E", modifiers: .command)
                }
        }
    .frame(
        maxWidth: dynamicNotchSize.width,
        maxHeight: dynamicNotchSize.height + currentShadowPadding,
        alignment: .top
    )
    .animation(dynamicNotchResizeAnimation, value: dynamicNotchSize)
        .animation(.easeInOut(duration: 0.4), value: coordinator.currentView)
        .environmentObject(privacyManager)
        .onChange(of: dynamicNotchSize) { oldSize, newSize in
            guard oldSize != newSize else { return }
            let delay: TimeInterval = dynamicNotchResizeAnimation == nil ? 0.25 : 1.0
            runAfter(delay) {
                vm.shouldRecheckHover.toggle()
            }
        }
        .background(dragDetector)
        .environmentObject(vm)
        .environmentObject(webcamManager)
        .onAppear {
            isMusicControlWindowSuppressed = vm.notchState != .closed || lockScreenManager.isLocked
            if musicManager.isPlaying || !musicManager.isPlayerIdle {
                clearMusicControlVisibilityDeadline()
            }
            if let deadline = musicControlVisibilityDeadline, Date() > deadline {
                clearMusicControlVisibilityDeadline()
            }
            enqueueMusicControlWindowSync(forceRefresh: true)
        }
        .onChange(of: vm.notchState) { _, state in
            if state == .open {
                suppressMusicControlWindowUpdates()
                cancelMusicControlWindowSync()
                hideMusicControlWindow()
            } else {
                releaseMusicControlWindowUpdates(after: musicControlResumeDelay)
                enqueueMusicControlWindowSync(forceRefresh: true, delay: 0.05)
            }
        }
        .onChange(of: musicControlWindowEnabled) { _, enabled in
            if enabled {
                if musicManager.isPlaying || !musicManager.isPlayerIdle {
                    clearMusicControlVisibilityDeadline()
                }
                enqueueMusicControlWindowSync(forceRefresh: true)
            } else {
                cancelMusicControlWindowSync()
                hideMusicControlWindow()
                clearMusicControlVisibilityDeadline()
                hasPendingMusicControlSync = false
                pendingMusicControlForceRefresh = false
            }
        }
        .onChange(of: coordinator.musicLiveActivityEnabled) { _, enabled in
            if enabled {
                enqueueMusicControlWindowSync(forceRefresh: true)
            } else {
                cancelMusicControlWindowSync()
                hideMusicControlWindow()
                clearMusicControlVisibilityDeadline()
                hasPendingMusicControlSync = false
                pendingMusicControlForceRefresh = false
            }
        }
        .onChange(of: vm.hideOnClosed) { _, hidden in
            if hidden {
                cancelMusicControlWindowSync()
                hideMusicControlWindow()
            } else {
                enqueueMusicControlWindowSync(forceRefresh: true, delay: 0.05)
            }
        }
        .onChange(of: lockScreenManager.isLocked) { _, locked in
            if locked {
                suppressMusicControlWindowUpdates()
                cancelMusicControlWindowSync()
                hideMusicControlWindow()
            } else {
                releaseMusicControlWindowUpdates(after: musicControlResumeDelay)
                enqueueMusicControlWindowSync(forceRefresh: true, delay: 0.05)
            }
        }
        .onChange(of: gestureProgress) { _, _ in
            if shouldShowMusicControlWindow() {
                enqueueMusicControlWindowSync(forceRefresh: true, delay: 0.05)
            }
        }
        .onChange(of: isHovering) { _, hovering in
            if shouldShowMusicControlWindow() {
                enqueueMusicControlWindowSync(forceRefresh: true, delay: hovering ? 0.05 : 0.12)
            }
        }
        .onChange(of: musicManager.isPlaying) { _, isPlaying in
            handleMusicControlPlaybackChange(isPlaying: isPlaying)
        }
        .onChange(of: musicManager.isPlayerIdle) { _, isIdle in
            handleMusicControlIdleChange(isIdle: isIdle)
        }
        .onChange(of: vm.closedNotchSize) { _, _ in
            if shouldShowMusicControlWindow() {
                enqueueMusicControlWindowSync(forceRefresh: true)
            }
        }
        .onChange(of: vm.effectiveClosedNotchHeight) { _, _ in
            if shouldShowMusicControlWindow() {
                enqueueMusicControlWindowSync(forceRefresh: true)
            }
        }
        .onDisappear {
            hoverTask?.cancel()
            cancelMusicControlWindowSync()
            hideMusicControlWindow()
            cancelMusicControlVisibilityTimer()
            clearMusicControlVisibilityDeadline()
            musicControlSuppressionTask?.cancel()
        }
    }

    @ViewBuilder
      func NotchLayout() -> some View {
          VStack(alignment: .leading) {
              VStack(alignment: .leading) {
                  if coordinator.firstLaunch {
                      Spacer()
                      HelloAnimation().frame(width: 200, height: 80).onAppear(perform: {
                          vm.closeHello()
                      })
                      .padding(.top, 40)
                      Spacer()
                  } else {
                      if coordinator.expandingView.type == .battery && coordinator.expandingView.show && vm.notchState == .closed && Defaults[.showPowerStatusNotifications] {
                        HStack(spacing: 0) {
                            HStack {
                                Text(batteryModel.statusText)
                                    .font(.subheadline)
                            }

                            Rectangle()
                                .fill(.black)
                                .frame(width: vm.closedNotchSize.width + 10)

                            HStack {
                                DynamicIslandBatteryView(
                                    batteryWidth: 30,
                                    isCharging: batteryModel.isCharging,
                                    isInLowPowerMode: batteryModel.isInLowPowerMode,
                                    isPluggedIn: batteryModel.isPluggedIn,
                                    levelBattery: batteryModel.levelBattery,
                                    isForNotification: true
                                )
                            }
                            .frame(width: 76, alignment: .trailing)
                        }
                        .frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0), alignment: .center)
                      } else if coordinator.sneakPeek.show && Defaults[.inlineHUD] && (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && (coordinator.sneakPeek.type != .timer) && (coordinator.sneakPeek.type != .reminder) && (coordinator.sneakPeek.type != .volume || vm.notchState == .closed) {
                          InlineHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon, hoverAnimation: $isHovering, gestureProgress: $gestureProgress)
                              .transition(.opacity)
                      } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music) && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle) && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed && !lockScreenManager.isLocked {
                          MusicLiveActivity()
                      } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .timer) && vm.notchState == .closed && timerManager.isTimerActive && coordinator.timerLiveActivityEnabled && !vm.hideOnClosed {
                          TimerLiveActivity()
                      } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .reminder) && vm.notchState == .closed && reminderManager.isActive && enableReminderLiveActivity && !vm.hideOnClosed {
                          ReminderLiveActivity()
                      } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .recording) && vm.notchState == .closed && (recordingManager.isRecording || !recordingManager.isRecorderIdle) && Defaults[.enableScreenRecordingDetection] && !vm.hideOnClosed {
                          RecordingLiveActivity()
                      } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .doNotDisturb) && vm.notchState == .closed && doNotDisturbManager.isDoNotDisturbActive && Defaults[.enableDoNotDisturbDetection] && Defaults[.showDoNotDisturbIndicator] && !vm.hideOnClosed && !lockScreenManager.isLocked {
                          DoNotDisturbLiveActivity()
                      } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .lockScreen) && vm.notchState == .closed && (lockScreenManager.isLocked || !lockScreenManager.isLockIdle) && Defaults[.enableLockScreenLiveActivity] && !vm.hideOnClosed {
                          LockScreenLiveActivity()
                      } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .privacy) && vm.notchState == .closed && privacyManager.hasAnyIndicator && (Defaults[.enableCameraDetection] || Defaults[.enableMicrophoneDetection]) && !vm.hideOnClosed {
                          PrivacyLiveActivity()
                      } else if !coordinator.expandingView.show && vm.notchState == .closed && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace] && !vm.hideOnClosed  {
                          DynamicIslandFaceAnimation().animation(.interactiveSpring, value: musicManager.isPlayerIdle)
                      } else if vm.notchState == .open {
                          DynamicIslandHeader()
                              .frame(height: max(24, vm.effectiveClosedNotchHeight))
                              .blur(radius: abs(gestureProgress) > 0.3 ? min(abs(gestureProgress), 8) : 0)
                              .animation(.spring(response: 1, dampingFraction: 1, blendDuration: 0.8), value: vm.notchState)
                       } else {
                           Rectangle().fill(.clear).frame(width: vm.closedNotchSize.width - 20, height: vm.effectiveClosedNotchHeight)
                       }
                      
                      if coordinator.sneakPeek.show {
                          if (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && (coordinator.sneakPeek.type != .timer) && !Defaults[.inlineHUD] && (coordinator.sneakPeek.type != .volume || vm.notchState == .closed) {
                              SystemEventIndicatorModifier(eventType: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon, sendEventBack: { _ in
                                  //
                              })
                              .padding(.bottom, 10)
                              .padding(.leading, 4)
                              .padding(.trailing, 8)
                          }
                          // Old sneak peek music
                          else if coordinator.sneakPeek.type == .music {
                              if vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard {
                                  HStack(alignment: .center) {
                                      Image(systemName: "music.note")
                                      GeometryReader { geo in
                                          MarqueeText(.constant(musicManager.songTitle + " - " + musicManager.artistName), textColor: .gray, minDuration: 1, frameWidth: geo.size.width)
                                      }
                                  }
                                  .foregroundStyle(.gray)
                                  .padding(.bottom, 10)
                              }
                          }
                          // Timer sneak peek
                          else if coordinator.sneakPeek.type == .timer {
                              if !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard {
                                  HStack(alignment: .center) {
                                      Image(systemName: "timer")
                                      GeometryReader { geo in
                                          MarqueeText(.constant(timerManager.timerName + " - " + timerManager.formattedRemainingTime()), textColor: timerManager.timerColor, minDuration: 1, frameWidth: geo.size.width)
                                      }
                                  }
                                  .foregroundStyle(timerManager.timerColor)
                                  .padding(.bottom, 10)
                              }
                          }
                          else if coordinator.sneakPeek.type == .reminder {
                              if !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard, let reminder = reminderManager.activeReminder {
                                  GeometryReader { geo in
                                      let chipColor = Color(nsColor: reminder.event.calendar.color).ensureMinimumBrightness(factor: 0.7)
                                      HStack(spacing: 6) {
                                          RoundedRectangle(cornerRadius: 2)
                                              .fill(chipColor)
                                              .frame(width: 8, height: 12)
                                          MarqueeText(
                                              .constant(reminderSneakPeekText(for: reminder, now: reminderManager.currentDate)),
                                              textColor: reminderColor(for: reminder, now: reminderManager.currentDate),
                                              minDuration: 1,
                                              frameWidth: max(0, geo.size.width - 14)
                                          )
                                      }
                                  }
                                  .padding(.bottom, 10)
                              }
                          }
                      }
                  }
              }
              .conditionalModifier((coordinator.sneakPeek.show && coordinator.sneakPeek.type == .music && vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard) || (coordinator.sneakPeek.show && coordinator.sneakPeek.type == .timer && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard) || (coordinator.sneakPeek.show && (coordinator.sneakPeek.type != .music && coordinator.sneakPeek.type != .timer) && (vm.notchState == .closed))) { view in
                  view
                      .fixedSize()
              }
              .zIndex(2)
              
              ZStack {
                  if vm.notchState == .open {
                      Group {
                          switch coordinator.currentView {
                              case .home:
                                  NotchHomeView(albumArtNamespace: albumArtNamespace)
                              case .shelf:
                                  NotchShelfView()
                              case .timer:
                                  NotchTimerView()
                              case .stats:
                                  NotchStatsView()
                              case .colorPicker:
                                  NotchColorPickerView()
                          }
                      }
                      .transition(.asymmetric(
                          insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.easeInOut(duration: 0.4)),
                          removal: .scale(scale: 0.8).combined(with: .opacity).animation(.easeInOut(duration: 0.4))
                      ))
                      .id(coordinator.currentView) // Force SwiftUI to treat each view as unique
                  }
              }
              .animation(.easeInOut(duration: 0.4), value: coordinator.currentView)
              .zIndex(1)
              .allowsHitTesting(vm.notchState == .open)
              .blur(radius: abs(gestureProgress) > 0.3 ? min(abs(gestureProgress), 8) : 0)
              .opacity(abs(gestureProgress) > 0.3 ? min(abs(gestureProgress * 2), 0.8) : 1)
          }
      }

    private func reminderColor(for reminder: ReminderLiveActivityManager.ReminderEntry, now: Date) -> Color {
        let window = TimeInterval(Defaults[.reminderSneakPeekDuration])
        let remaining = reminder.event.start.timeIntervalSince(now)
        if window > 0 && remaining > 0 && remaining <= window {
            return .red
        }
        return Color(nsColor: reminder.event.calendar.color).ensureMinimumBrightness(factor: 0.7)
    }

    private func reminderSneakPeekText(for entry: ReminderLiveActivityManager.ReminderEntry, now: Date) -> String {
        let title = entry.event.title.isEmpty ? "Upcoming Reminder" : entry.event.title
        let remaining = max(entry.event.start.timeIntervalSince(now), 0)
        let window = TimeInterval(Defaults[.reminderSneakPeekDuration])

        if window > 0 && remaining <= window {
            return "\(title) • now"
        }

        let minutes = Int(ceil(remaining / 60))
        let timeString = reminderTimeFormatter.string(from: entry.event.start)

        if minutes <= 0 {
            return "\(title) • now • \(timeString)"
        } else if minutes == 1 {
            return "\(title) • in 1 min • \(timeString)"
        } else {
            return "\(title) • in \(minutes) min • \(timeString)"
        }
    }

    private let reminderTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    @ViewBuilder
    func DynamicIslandFaceAnimation() -> some View {
        HStack {
            HStack {
                Rectangle()
                    .fill(.clear)
                    .frame(width: max(0, vm.effectiveClosedNotchHeight - 12), height: max(0, vm.effectiveClosedNotchHeight - 12))
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)
                IdleAnimationView()
            }
        }.frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0), alignment: .center)
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
        HStack {
            HStack {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .background(
                        Image(nsImage: musicManager.albumArt)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed))
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                    .albumArtFlip(angle: musicManager.flipAngle)
                    .frame(width: max(0, vm.effectiveClosedNotchHeight - 12), height: max(0, vm.effectiveClosedNotchHeight - 12))
            }
            .frame(width: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2), height: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12)))

            Rectangle()
                .fill(.black)
                .overlay(
                    HStack(alignment: .top){
                        if(coordinator.expandingView.show && coordinator.expandingView.type == .music) {
                            MarqueeText(
                                .constant(musicManager.songTitle),
                                textColor: Defaults[.coloredSpectrogram] ? Color(nsColor: musicManager.avgColor) : Color.gray,
                                minDuration: 0.4,
                                frameWidth: 100
                            )
                            .opacity((coordinator.expandingView.show && Defaults[.enableSneakPeek] && Defaults[.sneakPeekStyles] == .inline) ? 1 : 0)
                            Spacer(minLength: vm.closedNotchSize.width)
                            // Song Artist
                            Text(musicManager.artistName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(Defaults[.coloredSpectrogram] ? Color(nsColor: musicManager.avgColor) : Color.gray)
                                .opacity((coordinator.expandingView.show && coordinator.expandingView.type == .music && Defaults[.enableSneakPeek] && Defaults[.sneakPeekStyles] == .inline) ? 1 : 0)
                        } else if(coordinator.expandingView.show && coordinator.expandingView.type == .timer) {
                            MarqueeText(
                                .constant(timerManager.timerName),
                                textColor: timerManager.timerColor,
                                minDuration: 0.4,
                                frameWidth: 100
                            )
                            .opacity((coordinator.expandingView.show && Defaults[.enableSneakPeek] && Defaults[.sneakPeekStyles] == .inline) ? 1 : 0)
                            Spacer(minLength: vm.closedNotchSize.width)
                            // Timer Status
                            Text(timerManager.formattedRemainingTime())
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(timerManager.timerColor)
                                .opacity((coordinator.expandingView.show && coordinator.expandingView.type == .timer && Defaults[.enableSneakPeek] && Defaults[.sneakPeekStyles] == .inline) ? 1 : 0)
                        }
                    }
                )
                .frame(width: (coordinator.expandingView.show && (coordinator.expandingView.type == .music || coordinator.expandingView.type == .timer) && Defaults[.enableSneakPeek] && Defaults[.sneakPeekStyles] == .inline) ? 380 : vm.closedNotchSize.width + (isHovering ? 8 : 0))
            

            HStack {
                if useMusicVisualizer {
                    Rectangle()
                        .fill(Defaults[.coloredSpectrogram] ? Color(nsColor: musicManager.avgColor).gradient : Color.gray.gradient)
                        .frame(width: 50, alignment: .center)
                        .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                        .mask {
                            AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                                .frame(width: 16, height: 12)
                        }
                        .frame(width: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2),
                               height: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12)), alignment: .center)
                } else {
                    LottieAnimationView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2),
                   height: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12)), alignment: .center)
        }
        .frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0), alignment: .center)
    }
    
    @ViewBuilder
    var dragDetector: some View {
        if lockScreenManager.isLocked {
            EmptyView()
        } else if Defaults[.dynamicShelf] && !Defaults[.enableMinimalisticUI] {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onDrop(of: [.data], isTargeted: $vm.dragDetectorTargeting) { _ in true }
                .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
                    if isTargeted, vm.notchState == .closed {
                        coordinator.currentView = .shelf
                        openNotch()
                    } else if !isTargeted {
                        print("DROP EVENT", vm.dropEvent)
                        if vm.dropEvent {
                            vm.dropEvent = false
                            return
                        }

                        vm.dropEvent = false
                        vm.close()
                    }
                }
        } else {
            EmptyView()
        }
    }

    // MARK: - Private Methods
    private func openNotch() {
        withAnimation(.bouncy.speed(1.2)) {
            vm.open()
        }
    }

    // MARK: - Hover Management
    
    /// Handle hover state changes with debouncing
    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()

        if hovering {
            withAnimation(.bouncy.speed(1.2)) {
                isHovering = true
            }

            if vm.notchState == .closed && Defaults[.enableHaptics] {
                triggerHapticIfAllowed()
            }

            guard vm.notchState == .closed,
                  !coordinator.sneakPeek.show,
                  Defaults[.openNotchOnHover] else { return }

            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          !self.coordinator.sneakPeek.show else { return }

                    self.openNotch()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.bouncy.speed(1.2)) {
                        self.isHovering = false
                    }

                    if self.vm.notchState == .open && !self.hasAnyActivePopovers() {
                        self.vm.close()
                    }
                }
            }
        }
    }
    
    // Helper function to check if any popovers are active
    private func hasAnyActivePopovers() -> Bool {
     return vm.isBatteryPopoverActive || 
         vm.isClipboardPopoverActive || 
         vm.isColorPickerPopoverActive || 
         vm.isStatsPopoverActive ||
         vm.isTimerPopoverActive ||
         vm.isMediaOutputPopoverActive ||
         vm.isReminderPopoverActive
    }
    
    // Helper to prevent rapid haptic feedback
    private func triggerHapticIfAllowed() {
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) > 0.3 { // Minimum 300ms between haptics
            haptics.toggle()
            lastHapticTime = now
        }
    }
    
    // Helper to check if stats tab has 4+ graphs (needs expanded height)
    private func enabledStatsGraphCount() -> Int {
        var enabledCount = 0
        if showCpuGraph { enabledCount += 1 }
        if showMemoryGraph { enabledCount += 1 }
        if showGpuGraph { enabledCount += 1 }
        if showNetworkGraph { enabledCount += 1 }
        if showDiskGraph { enabledCount += 1 }
        return enabledCount
    }

    private func statsRowCount() -> Int {
        let count = enabledStatsGraphCount()
        if count == 0 { return 0 }
        return count <= 3 ? 1 : 2
    }
    
    // MARK: - Gesture Handling
    
    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }
        
        withAnimation(.smooth) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }
        
        if phase == .ended {
            withAnimation(.smooth) {
                gestureProgress = .zero
            }
        }
        
        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                triggerHapticIfAllowed()
            }
            withAnimation(.smooth) {
                gestureProgress = .zero
            }
            openNotch()
        }
    }
    
    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        if vm.notchState == .open && !vm.isHoveringCalendar {
            withAnimation(.smooth) {
                gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
            }
            
            if phase == .ended {
                withAnimation(.smooth) {
                    gestureProgress = .zero
                }
            }
            
            if translation > Defaults[.gestureSensitivity] {
                withAnimation(.smooth) {
                    gestureProgress = .zero
                    isHovering = false
                }
                vm.close()
                
                if Defaults[.enableHaptics] {
                    triggerHapticIfAllowed()
                }
            }
        }
    }

    private func handleMusicControlPlaybackChange(isPlaying: Bool) {
        guard musicControlWindowEnabled else { return }

        if isPlaying {
            clearMusicControlVisibilityDeadline()
            requestMusicControlWindowSyncIfHidden()
        } else {
            extendMusicControlVisibilityAfterPause()
        }
    }

    private func handleMusicControlIdleChange(isIdle: Bool) {
        guard musicControlWindowEnabled else { return }

        if isIdle {
            if musicControlVisibilityDeadline == nil {
                extendMusicControlVisibilityAfterPause()
            }
        } else if musicManager.isPlaying {
            clearMusicControlVisibilityDeadline()
        }
    }

    private func extendMusicControlVisibilityAfterPause() {
        let deadline = Date().addingTimeInterval(musicControlPauseGrace)
        musicControlVisibilityDeadline = deadline
        scheduleMusicControlVisibilityCheck(deadline: deadline)
        requestMusicControlWindowSyncIfHidden()
    }

    private func clearMusicControlVisibilityDeadline() {
        musicControlVisibilityDeadline = nil
        cancelMusicControlVisibilityTimer()
    }

    private func scheduleMusicControlVisibilityCheck(deadline: Date) {
        cancelMusicControlVisibilityTimer()

        let interval = max(0, deadline.timeIntervalSinceNow)

        musicControlHideTask = Task.detached(priority: .background) { [interval] in
            if interval > 0 {
                let nanoseconds = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                if let currentDeadline = musicControlVisibilityDeadline, currentDeadline <= Date() {
                    musicControlVisibilityDeadline = nil
                }

                enqueueMusicControlWindowSync(forceRefresh: false)

                musicControlHideTask = nil
            }
        }
    }

    private func cancelMusicControlVisibilityTimer() {
        musicControlHideTask?.cancel()
        musicControlHideTask = nil
    }

    private func musicControlVisibilityIsActive() -> Bool {
        if musicManager.isPlaying {
            return true
        }

        guard let deadline = musicControlVisibilityDeadline else { return false }
        return Date() <= deadline
    }

    private func suppressMusicControlWindowUpdates() {
        isMusicControlWindowSuppressed = true
        musicControlSuppressionTask?.cancel()
        musicControlSuppressionTask = nil
    }

    private func releaseMusicControlWindowUpdates(after delay: TimeInterval) {
        musicControlSuppressionTask?.cancel()
        musicControlSuppressionTask = Task { [delay] in
            if delay > 0 {
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                if vm.notchState == .closed && !lockScreenManager.isLocked {
                    isMusicControlWindowSuppressed = false
                    triggerPendingMusicControlSyncIfNeeded()
                } else {
                    isMusicControlWindowSuppressed = true
                }
                musicControlSuppressionTask = nil
            }
        }
    }

    private func triggerPendingMusicControlSyncIfNeeded() {
        guard hasPendingMusicControlSync else { return }

        let shouldForce = pendingMusicControlForceRefresh
        hasPendingMusicControlSync = false
        pendingMusicControlForceRefresh = false

        logMusicControlEvent("Flushing pending floating window sync (force: \(shouldForce))")
        scheduleMusicControlWindowSync(forceRefresh: shouldForce, bypassSuppression: true)
    }

    private func shouldDeferMusicControlSync() -> Bool {
        vm.notchState != .closed || lockScreenManager.isLocked || isMusicControlWindowSuppressed
    }

    private func enqueueMusicControlWindowSync(forceRefresh: Bool, delay: TimeInterval = 0) {
        if shouldDeferMusicControlSync() {
            hasPendingMusicControlSync = true
            if forceRefresh {
                pendingMusicControlForceRefresh = true
            }
            logMusicControlEvent("Queued floating window sync (force: \(forceRefresh)) while deferred")
            return
        }

        logMusicControlEvent("Scheduling floating window sync (force: \(forceRefresh), delay: \(delay))")
        scheduleMusicControlWindowSync(forceRefresh: forceRefresh, delay: delay)
    }

    private func shouldShowMusicControlWindow() -> Bool {
        guard musicControlWindowEnabled,
              coordinator.musicLiveActivityEnabled,
              vm.notchState == .closed,
              !vm.hideOnClosed,
              !lockScreenManager.isLocked,
              !isMusicControlWindowSuppressed else {
            return false
        }

        return musicControlVisibilityIsActive()
    }

    private func scheduleMusicControlWindowSync(forceRefresh: Bool, delay: TimeInterval = 0, bypassSuppression: Bool = false) {
        #if os(macOS)
        cancelMusicControlWindowSync()

        guard shouldShowMusicControlWindow() else {
            hasPendingMusicControlSync = false
            pendingMusicControlForceRefresh = false
            hideMusicControlWindow()
            return
        }

        if !bypassSuppression && (isMusicControlWindowSuppressed || lockScreenManager.isLocked) {
            hasPendingMusicControlSync = true
            if forceRefresh {
                pendingMusicControlForceRefresh = true
            }
            return
        }

        hasPendingMusicControlSync = false
        pendingMusicControlForceRefresh = false

        let syncDelay = max(0, delay)

        pendingMusicControlTask = Task.detached(priority: .userInitiated) { [forceRefresh, syncDelay] in
            if syncDelay > 0 {
                let nanoseconds = UInt64(syncDelay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                if shouldShowMusicControlWindow() {
                    logMusicControlEvent("Running floating window sync (force: \(forceRefresh))")
                    syncMusicControlWindow(forceRefresh: forceRefresh)
                } else {
                    logMusicControlEvent("Skipping floating window sync (conditions changed)")
                    hideMusicControlWindow()
                }

                pendingMusicControlTask = nil
            }
        }
        #endif
    }

    private func cancelMusicControlWindowSync() {
        pendingMusicControlTask?.cancel()
        pendingMusicControlTask = nil
    }

    #if os(macOS)
    private func currentMusicControlWindowMetrics() -> MusicControlWindowMetrics {
        MusicControlWindowMetrics(
            notchHeight: max(vm.closedNotchSize.height, vm.effectiveClosedNotchHeight),
            notchWidth: vm.closedNotchSize.width + (isHovering ? 8 : 0),
            rightWingWidth: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2),
            cornerRadius: activeCornerRadiusInsets.closed.bottom,
            spacing: 36
        )
    }

    private func syncMusicControlWindow(forceRefresh: Bool = false) {
        let notchAvailable = vm.effectiveClosedNotchHeight > 0 && vm.closedNotchSize.width > 0
        let targetVisible = shouldShowMusicControlWindow() && notchAvailable

        if targetVisible {
            let metrics = currentMusicControlWindowMetrics()
            if !isMusicControlWindowVisible {
                let didPresent = MusicControlWindowManager.shared.present(using: vm, metrics: metrics)
                isMusicControlWindowVisible = didPresent
            } else if forceRefresh {
                let didRefresh = MusicControlWindowManager.shared.refresh(using: vm, metrics: metrics)
                if !didRefresh {
                    MusicControlWindowManager.shared.hide()
                    isMusicControlWindowVisible = false
                }
            }
        } else if isMusicControlWindowVisible {
            MusicControlWindowManager.shared.hide()
            isMusicControlWindowVisible = false
        }
    }

    private func hideMusicControlWindow() {
        if isMusicControlWindowVisible {
            MusicControlWindowManager.shared.hide()
            isMusicControlWindowVisible = false
        }
    }
    #else
    private func syncMusicControlWindow(forceRefresh: Bool = false) {}

    private func hideMusicControlWindow() {}
    #endif
}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }
}
