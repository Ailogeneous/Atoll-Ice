//
//  SettingsView.swift
//  DynamicIsland
//
//  Created by Richard Kunkli on 07/08/2024.
//
import AppKit
import AVFoundation
import Combine
import Defaults
import EventKit
import KeyboardShortcuts
import LaunchAtLogin
import LottieUI
import Sparkle
import SwiftUI
import SwiftUIIntrospect
import UniformTypeIdentifiers

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case liveActivities
    case appearance
    case lockScreen
    case media
    case devices
    case extensions
    case timer
    case calendar
    case hudAndOSD
    case battery
    case stats
    case clipboard
    case screenAssistant
    case colorPicker
    case downloads
    case shelf
    case shortcuts
    case notes
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return String(localized: "General")
        case .liveActivities: return String(localized: "Live Activities")
        case .appearance: return String(localized: "Appearance")
        case .lockScreen: return String(localized: "Lock Screen")
        case .media: return String(localized: "Media")
        case .devices: return String(localized: "Devices")
        case .extensions: return String(localized: "Extensions")
        case .timer: return String(localized: "Timer")
        case .calendar: return String(localized: "Calendar")
        case .hudAndOSD: return String(localized: "Controls")
        case .battery: return String(localized: "Battery")
        case .stats: return String(localized: "Stats")
        case .clipboard: return String(localized: "Clipboard")
        case .screenAssistant: return String(localized: "Screen Assistant")
        case .colorPicker: return String(localized: "Color Picker")
        case .downloads: return String(localized: "Downloads")
        case .shelf: return String(localized: "Shelf")
        case .shortcuts: return String(localized: "Shortcuts")
        case .notes: return String(localized: "Notes")
        case .about: return String(localized: "About")
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gear"
        case .liveActivities: return "waveform.path.ecg"
        case .appearance: return "paintpalette"
        case .lockScreen: return "lock.laptopcomputer"
        case .media: return "play.laptopcomputer"
        case .devices: return "headphones"
        case .extensions: return "puzzlepiece.extension"
        case .timer: return "timer"
        case .calendar: return "calendar"
        case .hudAndOSD: return "dial.medium.fill"
        case .battery: return "battery.100.bolt"
        case .stats: return "chart.xyaxis.line"
        case .clipboard: return "clipboard"
        case .screenAssistant: return "brain.head.profile"
        case .colorPicker: return "eyedropper"
        case .downloads: return "square.and.arrow.down"
        case .shelf: return "books.vertical"
        case .shortcuts: return "keyboard"
        case .notes: return "note.text"
        case .about: return "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: return .blue
        case .liveActivities: return .pink
        case .appearance: return .purple
        case .lockScreen: return .orange
        case .media: return .green
        case .devices: return Color(red: 0.1, green: 0.11, blue: 0.12)
        case .extensions: return Color(red: 0.557, green: 0.353, blue: 0.957)
        case .timer: return .red
        case .calendar: return .cyan
        case .hudAndOSD: return .indigo
        case .battery: return Color(red: 0.202, green: 0.783, blue: 0.348, opacity: 1.000)
        case .stats: return .teal
        case .clipboard: return .mint
        case .screenAssistant: return .pink
        case .colorPicker: return .accentColor
        case .downloads: return .gray
        case .shelf: return .brown
        case .shortcuts: return .orange
        case .notes: return Color(red: 0.979, green: 0.716, blue: 0.153, opacity: 1.000)
        case .about: return .secondary
        }
    }

    func highlightID(for title: String) -> String {
        "\(rawValue)-\(title)"
    }
}

private struct SettingsSearchEntry: Identifiable {
    let tab: SettingsTab
    let title: String
    let keywords: [String]
    let highlightID: String?

    var id: String { "\(tab.rawValue)-\(title)" }
}

final class SettingsHighlightCoordinator: ObservableObject {
    struct ScrollRequest: Identifiable, Equatable {
        let id: String
        fileprivate let tab: SettingsTab
    }

    @Published fileprivate var pendingScrollRequest: ScrollRequest?
    @Published private(set) var activeHighlightID: String?

    private var clearWorkItem: DispatchWorkItem?

    fileprivate func focus(on entry: SettingsSearchEntry) {
        guard let highlightID = entry.highlightID else { return }
        pendingScrollRequest = ScrollRequest(id: highlightID, tab: entry.tab)
        activateHighlight(id: highlightID)
    }

    func consumeScrollRequest(_ request: ScrollRequest) {
        guard pendingScrollRequest?.id == request.id else { return }
        pendingScrollRequest = nil
    }

    private func activateHighlight(id: String) {
        activeHighlightID = id
        clearWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard self?.activeHighlightID == id else { return }
            self?.activeHighlightID = nil
        }

        clearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
}

private struct SettingsHighlightModifier: ViewModifier {
    let id: String
    @EnvironmentObject private var highlightCoordinator: SettingsHighlightCoordinator
    @State private var animatePulse = false

    private var isActive: Bool {
        highlightCoordinator.activeHighlightID == id
    }

    func body(content: Content) -> some View {
        content
            .id(id)
            .background(highlightBackground)
            .onChange(of: isActive) { _, active in
                animatePulse = active
            }
            .onAppear {
                if isActive {
                    animatePulse = true
                }
            }
    }

    private var highlightBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
                Color.accentColor.opacity(isActive ? (animatePulse ? 0.95 : 0.4) : 0),
                lineWidth: 2
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(isActive ? 0.08 : 0))
            )
            .padding(-4)
            .shadow(color: Color.accentColor.opacity(isActive ? 0.25 : 0), radius: animatePulse ? 8 : 2)
            .animation(
                isActive ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: animatePulse
            )
    }
}

extension View {
    func settingsHighlight(id: String) -> some View {
        modifier(SettingsHighlightModifier(id: id))
    }

    @ViewBuilder
    func settingsHighlightIfPresent(_ id: String?) -> some View {
        if let id {
            settingsHighlight(id: id)
        } else {
            self
        }
    }
}

private struct SettingsForm<Content: View>: View {
    let tab: SettingsTab
    @ViewBuilder var content: () -> Content

    @EnvironmentObject private var highlightCoordinator: SettingsHighlightCoordinator

    var body: some View {
        ScrollViewReader { proxy in
            content()
                .onReceive(highlightCoordinator.$pendingScrollRequest.compactMap { request -> SettingsHighlightCoordinator.ScrollRequest? in
                    guard let request, request.tab == tab else { return nil }
                    return request
                }) { request in
                    withAnimation(.easeInOut(duration: 0.45)) {
                        proxy.scrollTo(request.id, anchor: .center)
                    }
                    highlightCoordinator.consumeScrollRequest(request)
                }
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var searchText: String = ""
    @StateObject private var highlightCoordinator = SettingsHighlightCoordinator()
    @Default(.enableMinimalisticUI) var enableMinimalisticUI
    
    let updaterController: SPUStandardUpdaterController?
    
    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                SettingsSidebarSearchBar(
                    text: $searchText,
                    suggestions: searchSuggestions,
                    onSuggestionSelected: handleSearchSuggestionSelection
                )
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                Divider()
                    .padding(.horizontal, 12)
                
                List(filteredTabs, selection: selectionBinding) { tab in
                    NavigationLink(value: tab) {
                        HStack(spacing: 10) {
                            sidebarIcon(for: tab)
                            Text(tab.title)
                            if tab == .downloads || tab == .hudAndOSD {
                                Spacer()
                                Text("BETA")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue)
                                    )
                            } else if tab == .extensions {
                                Spacer()
                                Text("ALPHA")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.orange)
                                    )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewColumnWidth(min: 200, ideal: 210, max: 240)
                .environment(\.defaultMinListRowHeight, 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } detail: {
            detailView(for: resolvedSelection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbarSpacingShim }
        .environmentObject(highlightCoordinator)
        .formStyle(.grouped)
        .frame(width: 700)
        .onChange(of: searchText) { _, newValue in
            let matches = tabsMatchingSearch(newValue)
            guard let firstMatch = matches.first else { return }
            if !matches.contains(resolvedSelection) {
                selectedTab = firstMatch
            }
        }
        .background {
            Group {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .glassEffect(
                            .clear
                                .tint(Color.white.opacity(0.1))
                                .interactive(),
                            in: .rect(cornerRadius: 18)
                        )
                } else {
                    ZStack {
                        Color(NSColor.windowBackgroundColor)
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
    
    private var resolvedSelection: SettingsTab {
        availableTabs.contains(selectedTab) ? selectedTab : (availableTabs.first ?? .general)
    }
    
    @ToolbarContentBuilder
    private var toolbarSpacingShim: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .primaryAction) {
                toolbarSpacerView
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .primaryAction) {
                toolbarSpacerView
            }
        }
    }
    
    @ViewBuilder
    private var toolbarSpacerView: some View {
        Color.clear
            .frame(width: 96, height: 32)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
    
    private var filteredTabs: [SettingsTab] {
        tabsMatchingSearch(searchText)
    }
    
    private var selectionBinding: Binding<SettingsTab> {
        Binding(
            get: { resolvedSelection },
            set: { newValue in
                selectedTab = newValue
            }
        )
    }
    
    @ViewBuilder
    private func sidebarIcon(for tab: SettingsTab) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(tab.tint)
            .frame(width: 26, height: 26)
            .overlay {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
    }
    
    private var availableTabs: [SettingsTab] {
        let ordered: [SettingsTab] = [
            .general,
            .liveActivities,
            .appearance,
            .lockScreen,
            .media,
            .devices,
            .timer,
            .calendar,
            .hudAndOSD,
            .battery,
            .stats,
            .notes,
            .clipboard,
            .screenAssistant,
            .colorPicker,
            .downloads,
            .shelf,
            .shortcuts,
            .extensions,
            .about
        ]
        
        return ordered.filter { isTabVisible($0) }
    }
    
    private func tabsMatchingSearch(_ query: String) -> [SettingsTab] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return availableTabs }
        
        let entryMatches = searchEntries(matching: trimmed)
        let matchingTabs = Set(entryMatches.map(\.tab))
        
        return availableTabs.filter { tab in
            tab.title.localizedCaseInsensitiveContains(trimmed) || matchingTabs.contains(tab)
        }
    }
    
    private var searchSuggestions: [SettingsSearchEntry] {
        Array(searchEntries(matching: searchText).filter { $0.tab != .downloads }.prefix(8))
    }
    
    private func handleSearchSuggestionSelection(_ suggestion: SettingsSearchEntry) {
        guard suggestion.tab != .downloads else { return }
        highlightCoordinator.focus(on: suggestion)
        selectedTab = suggestion.tab
    }
    
    private struct SettingsSidebarSearchBar: View {
        @Binding var text: String
        let suggestions: [SettingsSearchEntry]
        let onSuggestionSelected: (SettingsSearchEntry) -> Void
        
        @FocusState private var isFocused: Bool
        @State private var hoveredSuggestionID: SettingsSearchEntry.ID?
        
        var body: some View {
            VStack(spacing: 6) {
                searchField
                if showSuggestions {
                    suggestionList
                }
            }
            .animation(.easeInOut(duration: 0.15), value: showSuggestions)
        }
        
        private var showSuggestions: Bool {
            isFocused && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !suggestions.isEmpty
        }
        
        private var searchField: some View {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.secondary)
                
                TextField("Search Settings", text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(triggerFirstSuggestion)
                
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08))
            )
        }
        
        private var suggestionList: some View {
            VStack(spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button {
                        selectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(suggestion.tab.tint)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Image(systemName: suggestion.tab.systemImage)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.white)
                                }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Text(suggestion.tab.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .background(rowBackground(for: suggestion))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredSuggestionID = hovering ? suggestion.id : (hoveredSuggestionID == suggestion.id ? nil : hoveredSuggestionID)
                    }
                    
                    if suggestion.id != suggestions.last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08))
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        
        private func rowBackground(for suggestion: SettingsSearchEntry) -> some View {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hoveredSuggestionID == suggestion.id ? Color.white.opacity(0.08) : Color.clear)
        }
        
        private func selectSuggestion(_ suggestion: SettingsSearchEntry) {
            onSuggestionSelected(suggestion)
            isFocused = false
        }
        
        private func triggerFirstSuggestion() {
            guard let first = suggestions.first else { return }
            selectSuggestion(first)
        }
    }
    
    private func searchEntries(matching query: String) -> [SettingsSearchEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        return settingsSearchIndex
            .filter { availableTabs.contains($0.tab) }
            .filter { entry in
                entry.title.localizedCaseInsensitiveContains(trimmed) ||
                entry.keywords.contains { $0.localizedCaseInsensitiveContains(trimmed) }
            }
    }
    
    private var settingsSearchIndex: [SettingsSearchEntry] {
        [
            // General
            SettingsSearchEntry(
                tab: .general,
                title: String(localized: "Enable Minimalistic UI"),
                keywords: [ String(localized: "minimalistic"), String(localized: "ui mode"), String(localized: "general") ],
                highlightID: SettingsTab.general.highlightID(for: "Enable Minimalistic UI")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized:"Menubar icon"),
                keywords: [ String(localized:"menu bar"), String(localized:"status bar"), String(localized:"icon") ],
                highlightID: SettingsTab.general.highlightID(for: "Menubar icon")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized:"Launch at login"),
                keywords: [ String(localized:"autostart"), String(localized:"startup")],
                highlightID: SettingsTab.general.highlightID(for: "Launch at login")
            ),
            SettingsSearchEntry(tab: .general, title: "Show on all displays", keywords: ["multi-display", "external monitor"], highlightID: SettingsTab.general.highlightID(for: "Show on all displays")),
            SettingsSearchEntry(
                tab: .general,
                title: "Show on a specific display",
                keywords: ["preferred screen", "display picker"],
                highlightID: SettingsTab.general.highlightID(for: "Show on a specific display")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized:"Automatically switch displays"),
                keywords: [String(localized:"auto switch"), String(localized:"displays")],
                highlightID: SettingsTab.general.highlightID(for: "Automatically switch displays")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized:"Hide Dynamic Island during screenshots & recordings"),
                keywords: [String(localized:"privacy"), String(localized:"screenshot"), String(localized:"recording")],
                highlightID: SettingsTab.general.highlightID(for: "Hide Dynamic Island during screenshots & recordings")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized: "Enable gestures"),
                keywords: [String(localized: "gestures"), String(localized: "trackpad")],
                highlightID: SettingsTab.general.highlightID(for: "Enable gestures")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized: "Close gesture"),
                keywords: [String(localized: "pinch"), String(localized: "swipe")],
                highlightID: SettingsTab.general.highlightID(for: "Close gesture")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized: "Reverse swipe gestures"),
                keywords: [String(localized: "reverse"), String(localized: "swipe"), String(localized: "media")],
                highlightID: SettingsTab.general.highlightID(for: "Reverse swipe gestures")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized: "Reverse scroll gestures"),
                keywords: [String(localized: "reverse"), String(localized: "scroll"), String(localized: "open"), String(localized: "close")],
                highlightID: SettingsTab.general.highlightID(for: "Reverse scroll gestures")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized: "Extend hover area"),
                keywords: [String(localized: "hover"), String(localized: "cursor")],
                highlightID: SettingsTab.general.highlightID(for: "Extend hover area")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized: "Enable haptics"),
                keywords: [String(localized: "haptic"), String(localized: "feedback")],
                highlightID: SettingsTab.general.highlightID(for: "Enable haptics")
            ),
            SettingsSearchEntry(
                tab: .general,
                title: String(localized: "Open notch on hover"),
                keywords: [String(localized: "hover to open"), String(localized: "auto open")],
                highlightID: SettingsTab.general.highlightID(for: "Open notch on hover")
            ),
                    SettingsSearchEntry(
                        tab: .general,
                        title: String(localized: "Notch display height"),
                        keywords: [String(localized: "display height"), String(localized: "menu bar size")],
                        highlightID: SettingsTab.general.highlightID(for: "Notch display height")
                    ),
                    
                    // Battery (Charge)
                    SettingsSearchEntry(
                        tab: .battery,
                        title: String(localized: "Show battery indicator"),
                        keywords: [String(localized: "battery hud"), String(localized: "charge")],
                        highlightID: SettingsTab.battery.highlightID(for: "Show battery indicator")
                    ),
                    SettingsSearchEntry(
                        tab: .battery,
                        title: String(localized: "Show battery percentage"),
                        keywords: [String(localized: "battery percent")],
                        highlightID: SettingsTab.battery.highlightID(for: "Show battery percentage")
                    ),
                    SettingsSearchEntry(
                        tab: .battery,
                        title: String(localized: "Show power status notifications"),
                        keywords: [String(localized: "notifications"), String(localized: "power")],
                        highlightID: SettingsTab.battery.highlightID(for: "Show power status notifications")
                    ),
                    SettingsSearchEntry(
                        tab: .battery,
                        title: String(localized: "Show power status icons"),
                        keywords: [String(localized: "power icons"), String(localized: "charging icon")],
                        highlightID: SettingsTab.battery.highlightID(for: "Show power status icons")
                    ),
                    SettingsSearchEntry(
                        tab: .battery,
                        title: String(localized: "Play low battery alert sound"),
                        keywords: [String(localized: "low battery"), String(localized: "alert"), String(localized: "sound")],
                        highlightID: SettingsTab.battery.highlightID(for: "Play low battery alert sound")
                    ),
                    
                    // HUDs
                    SettingsSearchEntry(
                        tab: .devices,
                        title: String(localized: "Show Bluetooth device connections"),
                        keywords: [String(localized: "bluetooth"), String(localized: "hud")],
                        highlightID: SettingsTab.devices.highlightID(for: "Show Bluetooth device connections")
                    ),
                    SettingsSearchEntry(
                        tab: .devices,
                        title: String(localized: "Use circular battery indicator"),
                        keywords: [String(localized: "battery"), String(localized: "circular")],
                        highlightID: SettingsTab.devices.highlightID(for: "Use circular battery indicator")
                    ),
                    SettingsSearchEntry(
                        tab: .devices,
                        title: String(localized: "Show battery percentage text in HUD"),
                        keywords: [String(localized: "battery text")],
                        highlightID: SettingsTab.devices.highlightID(for: "Show battery percentage text in HUD")
                    ),
                    SettingsSearchEntry(
                        tab: .devices,
                        title: String(localized: "Scroll device name in HUD"),
                        keywords: [String(localized: "marquee"), String(localized: "device name")],
                        highlightID: SettingsTab.devices.highlightID(for: "Scroll device name in HUD")
                    ),
                    SettingsSearchEntry(
                        tab: .devices,
                        title: String(localized: "Color-coded battery display"),
                        keywords: [String(localized: "color"), String(localized: "battery")],
                        highlightID: SettingsTab.devices.highlightID(for: "Color-coded battery display")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Color-coded volume display"),
                        keywords: [String(localized: "volume"), String(localized: "color")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Color-coded volume display")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Smooth color transitions"),
                        keywords: [String(localized: "gradient"), String(localized: "smooth")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Smooth color transitions")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Show percentages beside progress bars"),
                        keywords: [String(localized: "percentages"), String(localized: "progress")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Show percentages beside progress bars")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "HUD style"),
                        keywords: [String(localized: "inline"), String(localized: "compact")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "HUD style")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Progressbar style"),
                        keywords: [String(localized: "progress"), String(localized: "style")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Progressbar style")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Enable glowing effect"),
                        keywords: [String(localized: "glow"), String(localized: "indicator")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Enable glowing effect")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Use accent color"),
                        keywords: [String(localized: "accent"), String(localized: "color")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Use accent color")
                    ),
                    
                    // Custom OSD
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Enable Custom OSD"),
                        keywords: [String(localized: "osd"), String(localized: "on-screen display"), String(localized: "custom osd")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Enable Custom OSD")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Volume OSD"),
                        keywords: [String(localized: "volume"), String(localized: "osd")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Volume OSD")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Brightness OSD"),
                        keywords: [String(localized: "brightness"), String(localized: "osd")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Brightness OSD")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Keyboard Backlight OSD"),
                        keywords: [String(localized: "keyboard"), String(localized: "backlight"), String(localized: "osd")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Keyboard Backlight OSD")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Material"),
                        keywords: [String(localized: "material"), String(localized: "frosted"), String(localized: "liquid"), String(localized: "glass"), String(localized: "solid"), String(localized: "osd")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Material")
                    ),
                    SettingsSearchEntry(
                        tab: .hudAndOSD,
                        title: String(localized: "Icon & Progress Color"),
                        keywords: [String(localized: "color"), String(localized: "icon"), String(localized: "white"), String(localized: "black"), String(localized: "gray"), String(localized: "osd")],
                        highlightID: SettingsTab.hudAndOSD.highlightID(for: "Icon & Progress Color")
                    ),
                    
                    // Media
                    SettingsSearchEntry(
                        tab: .media,
                        title: String(localized: "Music Source"),
                        keywords: [String(localized: "media source"), String(localized: "controller")],
                        highlightID: SettingsTab.media.highlightID(for: "Music Source")
                    ),
                    SettingsSearchEntry(
                        tab: .media,
                        title: String(localized: "Skip buttons"),
                        keywords: [String(localized: "skip"), String(localized: "controls"), String(localized: "±10")],
                        highlightID: SettingsTab.media.highlightID(for: "Skip buttons")
                    ),
                    SettingsSearchEntry(
                        tab: .media,
                        title: String(localized: "Sneak Peek Style"),
                        keywords: [String(localized: "sneak peek"), String(localized: "preview")],
                        highlightID: SettingsTab.media.highlightID(for: "Sneak Peek Style")
                    ),
                    SettingsSearchEntry(
                        tab: .media,
                        title: String(localized: "Enable lyrics"),
                        keywords: [String(localized: "lyrics"), String(localized: "song text")],
                        highlightID: SettingsTab.media.highlightID(for: "Enable lyrics")
                    ),
                    SettingsSearchEntry(
                        tab: .media,
                        title: String(localized: "Show Change Media Output control"),
                        keywords: [String(localized: "airplay"), String(localized: "route picker"), String(localized: "media output")],
                        highlightID: SettingsTab.media.highlightID(for: "Show Change Media Output control")
                    ),
                    SettingsSearchEntry(
                        tab: .media,
                        title: String(localized: "Enable album art parallax"),
                        keywords: [String(localized: "parallax"), String(localized: "lock screen"), String(localized: "album art")],
                        highlightID: SettingsTab.media.highlightID(for: "Enable album art parallax")
                    ),
                    SettingsSearchEntry(
                        tab: .media,
                        title: String(localized: "Enable album art parallax effect"),
                        keywords: [String(localized: "parallax"), String(localized: "parallax effect"), String(localized: "album art")],
                        highlightID: SettingsTab.media.highlightID(for: "Enable album art parallax effect")
                    ),
                    
                    // Calendar
                    SettingsSearchEntry(
                        tab: .calendar,
                        title: String(localized: "Show calendar"),
                        keywords: [String(localized: "calendar"), String(localized: "events")],
                        highlightID: SettingsTab.calendar.highlightID(for: "Show calendar")
                    ),
                    SettingsSearchEntry(
                        tab: .calendar,
                        title: String(localized: "Enable reminder live activity"),
                        keywords: [String(localized: "reminder"), String(localized: "live activity")],
                        highlightID: SettingsTab.calendar.highlightID(for: "Enable reminder live activity")
                    ),
                    SettingsSearchEntry(
                        tab: .calendar,
                        title: String(localized: "Countdown style"),
                        keywords: [String(localized: "reminder countdown")],
                        highlightID: SettingsTab.calendar.highlightID(for: "Countdown style")
                    ),
                    SettingsSearchEntry(
                        tab: .calendar,
                        title: String(localized: "Show lock screen reminder"),
                        keywords: [String(localized: "lock screen"), String(localized: "reminder widget")],
                        highlightID: SettingsTab.calendar.highlightID(for: "Show lock screen reminder")
                    ),
                    SettingsSearchEntry(
                        tab: .calendar,
                        title: String(localized: "Chip color"),
                        keywords: [String(localized: "reminder chip"), String(localized: "color")],
                        highlightID: SettingsTab.calendar.highlightID(for: "Chip color")
                    ),
                    SettingsSearchEntry(
                        tab: .calendar,
                        title: String(localized: "Hide all-day events"),
                        keywords: [String(localized: "calendar"), String(localized: "all-day")],
                        highlightID: SettingsTab.calendar.highlightID(for: "Hide all-day events")
                    ),
                    SettingsSearchEntry(
                        tab: .calendar,
                        title: String(localized: "Hide completed reminders"),
                        keywords: [String(localized: "reminder"), String(localized: "completed")],
                        highlightID: SettingsTab.calendar.highlightID(for: "Hide completed reminders")
                    ),
                    SettingsSearchEntry(
                        tab: .calendar,
                        title: String(localized: "Show full event titles"),
                        keywords: [String(localized: "calendar"), String(localized: "titles")],
                        highlightID: SettingsTab.calendar.highlightID(for: "Show full event titles")
                    ),
                    SettingsSearchEntry(
                        tab: .calendar,
                        title: String(localized: "Auto-scroll to next event"),
                        keywords: [String(localized: "calendar"), String(localized: "scroll")],
                        highlightID: SettingsTab.calendar.highlightID(for: "Auto-scroll to next event")
                    ),
                    
                    // Shelf
                    SettingsSearchEntry(
                        tab: .shelf,
                        title: String(localized: "Enable shelf"),
                        keywords: [String(localized: "shelf"), String(localized: "dock")],
                        highlightID: SettingsTab.shelf.highlightID(for: "Enable shelf")
                    ),
                    SettingsSearchEntry(
                        tab: .shelf,
                        title: String(localized: "Open shelf tab by default if items added"),
                        keywords: [String(localized: "auto open"), String(localized: "shelf tab")],
                        highlightID: SettingsTab.shelf.highlightID(for: "Open shelf tab by default if items added")
                    ),
                    SettingsSearchEntry(
                        tab: .shelf,
                        title: String(localized: "Expanded drag detection area"),
                        keywords: [String(localized: "shelf"), String(localized: "drag")],
                        highlightID: SettingsTab.shelf.highlightID(for: "Expanded drag detection area")
                    ),
                    SettingsSearchEntry(
                        tab: .shelf,
                        title: String(localized: "Copy items on drag"),
                        keywords: [String(localized: "shelf"), String(localized: "drag"), String(localized: "copy")],
                        highlightID: SettingsTab.shelf.highlightID(for: "Copy items on drag")
                    ),
                    SettingsSearchEntry(
                        tab: .shelf,
                        title: String(localized: "Remove from shelf after dragging"),
                        keywords: [String(localized: "shelf"), String(localized: "drag"), String(localized: "remove")],
                        highlightID: SettingsTab.shelf.highlightID(for: "Remove from shelf after dragging")
                    ),
                    SettingsSearchEntry(
                        tab: .shelf,
                        title: String(localized: "Quick Share Service"),
                        keywords: [String(localized: "shelf"), String(localized: "share"), String(localized: "airdrop")],
                        highlightID: SettingsTab.shelf.highlightID(for: "Quick Share Service")
                    ),
                    
                    // Appearance
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Settings icon in notch"),
                        keywords: [String(localized: "settings button"), String(localized: "toolbar")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Settings icon in notch")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Enable window shadow"),
                        keywords: [String(localized: "shadow"), String(localized: "appearance")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Enable window shadow")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Corner radius scaling"),
                        keywords: [String(localized: "corner radius"), String(localized: "shape")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Corner radius scaling")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Use simpler close animation"),
                        keywords: [String(localized: "close animation"), String(localized: "notch")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Use simpler close animation")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Notch Width"),
                        keywords: [String(localized: "expanded notch"), String(localized: "width"), String(localized: "resize")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Expanded notch width")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Enable colored spectrograms"),
                        keywords: [String(localized: "spectrogram"), String(localized: "audio")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Enable colored spectrograms")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Enable blur effect behind album art"),
                        keywords: [String(localized: "blur"), String(localized: "album art")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Enable blur effect behind album art")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Slider color"),
                        keywords: [String(localized: "slider"), String(localized: "accent")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Slider color")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Enable Dynamic mirror"),
                        keywords: [String(localized: "mirror"), String(localized: "reflection")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Enable Dynamic mirror")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Mirror shape"),
                        keywords: [String(localized: "mirror shape"), String(localized: "circle"), String(localized: "rectangle")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Mirror shape")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "Show cool face animation while inactivity"),
                        keywords: [String(localized: "face animation"), String(localized: "idle")],
                        highlightID: SettingsTab.appearance.highlightID(for: "Show cool face animation while inactivity")
                    ),
                    SettingsSearchEntry(
                        tab: .appearance,
                        title: String(localized: "App icon"),
                        keywords: [String(localized: "app icon"), String(localized: "custom icon")],
                        highlightID: SettingsTab.appearance.highlightID(for: "App icon")
                    ),
                    
                    // Lock Screen
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Enable lock screen live activity"),
                        keywords: [String(localized: "lock screen"), String(localized: "live activity")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Enable lock screen live activity")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Play lock/unlock sounds"),
                        keywords: [String(localized: "chime"), String(localized: "sound")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Play lock/unlock sounds")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Material"),
                        keywords: [String(localized: "glass"), String(localized: "frosted"), String(localized: "liquid")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Material")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show lock screen media panel"),
                        keywords: [String(localized: "media panel"), String(localized: "lock screen media")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show lock screen media panel")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show media app icon"),
                        keywords: [String(localized: "app icon"), String(localized: "media")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show media app icon")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show panel border"),
                        keywords: [String(localized: "panel border")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show panel border")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Enable media panel blur"),
                        keywords: [String(localized: "blur"), String(localized: "media panel")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Enable media panel blur")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show lock screen timer"),
                        keywords: [String(localized: "timer widget"), String(localized: "lock screen timer")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show lock screen timer")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Timer surface"),
                        keywords: [String(localized: "timer glass"), String(localized: "classic"), String(localized: "blur")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Timer surface")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Timer glass material"),
                        keywords: [String(localized: "frosted"), String(localized: "liquid"), String(localized: "timer material")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Timer glass material")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Timer liquid mode"),
                        keywords: [String(localized: "timer"), String(localized: "standard"), String(localized: "custom")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Timer liquid mode")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Timer widget variant"),
                        keywords: [String(localized: "timer variant"), String(localized: "liquid")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Timer widget variant")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show lock screen weather"),
                        keywords: [String(localized: "weather widget")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show lock screen weather")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Layout"),
                        keywords: [String(localized: "inline"), String(localized: "circular"), String(localized: "weather layout")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Layout")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Weather data provider"),
                        keywords: [String(localized: "wttr"), String(localized: "open meteo")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Weather data provider")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Temperature unit"),
                        keywords: [String(localized: "celsius"), String(localized: "fahrenheit")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Temperature unit")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show location label"),
                        keywords: [String(localized: "location"), String(localized: "weather")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show location label")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show charging status"),
                        keywords: [String(localized: "charging"), String(localized: "weather")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show charging status")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show charging percentage"),
                        keywords: [String(localized: "charging percentage")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show charging percentage")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show battery indicator"),
                        keywords: [String(localized: "battery gauge"), String(localized: "weather")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show battery indicator")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Use MacBook icon when on battery"),
                        keywords: [String(localized: "laptop icon"), String(localized: "battery")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Use MacBook icon when on battery")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show Bluetooth battery"),
                        keywords: [String(localized: "bluetooth"), String(localized: "gauge")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show Bluetooth battery")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Show AQI widget"),
                        keywords: [String(localized: "air quality"), String(localized: "aqi")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Show AQI widget")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Air quality scale"),
                        keywords: [String(localized: "aqi"), String(localized: "scale")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Air quality scale")
                    ),
                    SettingsSearchEntry(
                        tab: .lockScreen,
                        title: String(localized: "Use colored gauges"),
                        keywords: [String(localized: "gauge tint"), String(localized: "monochrome")],
                        highlightID: SettingsTab.lockScreen.highlightID(for: "Use colored gauges")
                    ),
                    
                    // Extensions
                    SettingsSearchEntry(
                        tab: .extensions,
                        title: String(localized: "Enable third-party extensions"),
                        keywords: [String(localized: "extensions"), String(localized: "authorization"), String(localized: "third party")],
                        highlightID: SettingsTab.extensions.highlightID(for: "Enable third-party extensions")
                    ),
                    SettingsSearchEntry(
                        tab: .extensions,
                        title: String(localized: "Allow extension live activities"),
                        keywords: [String(localized: "extensions"), String(localized: "live activities"), String(localized: "permissions")],
                        highlightID: SettingsTab.extensions.highlightID(for: "Allow extension live activities")
                    ),
                    SettingsSearchEntry(
                        tab: .extensions,
                        title: String(localized: "Allow extension lock screen widgets"),
                        keywords: [String(localized: "extensions"), String(localized: "lock screen"), String(localized: "widgets")],
                        highlightID: SettingsTab.extensions.highlightID(for: "Allow extension lock screen widgets")
                    ),
                    SettingsSearchEntry(
                        tab: .extensions,
                        title: String(localized: "Enable extension diagnostics logging"),
                        keywords: [String(localized: "extensions"), String(localized: "diagnostics"), String(localized: "logging")],
                        highlightID: SettingsTab.extensions.highlightID(for: "Enable extension diagnostics logging")
                    ),
                    SettingsSearchEntry(
                        tab: .extensions,
                        title: String(localized: "Manage app permissions"),
                        keywords: [String(localized: "extensions"), String(localized: "permissions"), String(localized: "apps")],
                        highlightID: SettingsTab.extensions.highlightID(for: "App permissions list")
                    ),
                    
                    // Shortcuts
                    SettingsSearchEntry(
                        tab: .shortcuts,
                        title: String(localized: "Enable global keyboard shortcuts"),
                        keywords: [String(localized: "keyboard"), String(localized: "shortcut")],
                        highlightID: SettingsTab.shortcuts.highlightID(for: "Enable global keyboard shortcuts")
                    ),
                    
                    // Timer
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Enable timer feature"),
                        keywords: [String(localized: "timer"), String(localized: "enable")],
                        highlightID: SettingsTab.timer.highlightID(for: "Enable timer feature")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Mirror macOS Clock timers"),
                        keywords: [String(localized: "system timer"), String(localized: "clock app")],
                        highlightID: SettingsTab.timer.highlightID(for: "Mirror macOS Clock timers")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Show lock screen timer widget"),
                        keywords: [String(localized: "lock screen"), String(localized: "timer widget")],
                        highlightID: SettingsTab.timer.highlightID(for: "Show lock screen timer widget")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Timer surface"),
                        keywords: [String(localized: "timer glass"), String(localized: "classic"), String(localized: "blur")],
                        highlightID: SettingsTab.timer.highlightID(for: "Timer surface")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Timer glass material"),
                        keywords: [String(localized: "frosted"), String(localized: "liquid"), String(localized: "timer material")],
                        highlightID: SettingsTab.timer.highlightID(for: "Timer glass material")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Timer liquid mode"),
                        keywords: [String(localized: "timer"), String(localized: "standard"), String(localized: "custom")],
                        highlightID: SettingsTab.timer.highlightID(for: "Timer liquid mode")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Timer widget variant"),
                        keywords: [String(localized: "timer variant"), String(localized: "liquid")],
                        highlightID: SettingsTab.timer.highlightID(for: "Timer widget variant")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Timer tint"),
                        keywords: [String(localized: "timer colour"), String(localized: "preset")],
                        highlightID: SettingsTab.timer.highlightID(for: "Timer tint")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Solid colour"),
                        keywords: [String(localized: "timer colour"), String(localized: "custom")],
                        highlightID: SettingsTab.timer.highlightID(for: "Solid colour")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Progress style"),
                        keywords: [String(localized: "progress"), String(localized: "bar"), String(localized: "ring")],
                        highlightID: SettingsTab.timer.highlightID(for: "Progress style")
                    ),
                    SettingsSearchEntry(
                        tab: .timer,
                        title: String(localized: "Accent colour"),
                        keywords: [String(localized: "accent"), String(localized: "timer")],
                        highlightID: SettingsTab.timer.highlightID(for: "Accent colour")
                    ),
                    
                    // Stats
                    SettingsSearchEntry(
                        tab: .stats,
                        title: String(localized: "Enable system stats monitoring"),
                        keywords: [String(localized: "stats"), String(localized: "monitoring")],
                        highlightID: SettingsTab.stats.highlightID(for: "Enable system stats monitoring")
                    ),
                    SettingsSearchEntry(
                        tab: .stats,
                        title: String(localized: "Stop monitoring after closing the notch"),
                        keywords: [String(localized: "stats"), String(localized: "auto stop")],
                        highlightID: SettingsTab.stats.highlightID(for: "Stop monitoring after closing the notch")
                    ),
                    SettingsSearchEntry(
                        tab: .stats,
                        title: String(localized: "CPU Usage"),
                        keywords: [String(localized: "cpu"), String(localized: "graph")],
                        highlightID: SettingsTab.stats.highlightID(for: "CPU Usage")
                    ),
                    SettingsSearchEntry(
                        tab: .stats,
                        title: String(localized: "Memory Usage"),
                        keywords: [String(localized: "memory"), String(localized: "ram")],
                        highlightID: SettingsTab.stats.highlightID(for: "Memory Usage")
                    ),
                    SettingsSearchEntry(
                        tab: .stats,
                        title: String(localized: "GPU Usage"),
                        keywords: [String(localized: "gpu"), String(localized: "graphics")],
                        highlightID: SettingsTab.stats.highlightID(for: "GPU Usage")
                    ),
                    SettingsSearchEntry(
                        tab: .stats,
                        title: String(localized: "Network Activity"),
                        keywords: [String(localized: "network"), String(localized: "graph")],
                        highlightID: SettingsTab.stats.highlightID(for: "Network Activity")
                    ),
                    SettingsSearchEntry(
                        tab: .stats,
                        title: String(localized: "Disk I/O"),
                        keywords: [String(localized: "disk"), String(localized: "io")],
                        highlightID: SettingsTab.stats.highlightID(for: "Disk I/O")
                    ),
                    
                    // Clipboard
                    SettingsSearchEntry(
                        tab: .clipboard,
                        title: String(localized: "Enable Clipboard Manager"),
                        keywords: [String(localized: "clipboard"), String(localized: "manager")],
                        highlightID: SettingsTab.clipboard.highlightID(for: "Enable Clipboard Manager")
                    ),
                    SettingsSearchEntry(
                        tab: .clipboard,
                        title: String(localized: "Show Clipboard Icon"),
                        keywords: [String(localized: "icon"), String(localized: "clipboard")],
                        highlightID: SettingsTab.clipboard.highlightID(for: "Show Clipboard Icon")
                    ),
                    SettingsSearchEntry(
                        tab: .clipboard,
                        title: String(localized: "Display Mode"),
                        keywords: [String(localized: "list"), String(localized: "grid"), String(localized: "clipboard")],
                        highlightID: SettingsTab.clipboard.highlightID(for: "Display Mode")
                    ),
                    SettingsSearchEntry(
                        tab: .clipboard,
                        title: String(localized: "History Size"),
                        keywords: [String(localized: "history"), String(localized: "clipboard")],
                        highlightID: SettingsTab.clipboard.highlightID(for: "History Size")
                    ),
                    
                    // Screen Assistant
                    SettingsSearchEntry(
                        tab: .screenAssistant,
                        title: String(localized: "Enable Screen Assistant"),
                        keywords: [String(localized: "screen assistant"), String(localized: "ai")],
                        highlightID: SettingsTab.screenAssistant.highlightID(for: "Enable Screen Assistant")
                    ),
                    SettingsSearchEntry(
                        tab: .screenAssistant,
                        title: String(localized: "Display Mode"),
                        keywords: [String(localized: "screen assistant"), String(localized: "mode")],
                        highlightID: SettingsTab.screenAssistant.highlightID(for: "Display Mode")
                    ),
                    
                    // Color Picker
                    SettingsSearchEntry(
                        tab: .colorPicker,
                        title: String(localized: "Enable Color Picker"),
                        keywords: [String(localized: "color picker"), String(localized: "eyedropper")],
                        highlightID: SettingsTab.colorPicker.highlightID(for: "Enable Color Picker")
                    ),
                    SettingsSearchEntry(
                        tab: .colorPicker,
                        title: String(localized: "Show Color Picker Icon"),
                        keywords: [String(localized: "color icon"), String(localized: "toolbar")],
                        highlightID: SettingsTab.colorPicker.highlightID(for: "Show Color Picker Icon")
                    ),
                    SettingsSearchEntry(
                        tab: .colorPicker,
                        title: String(localized: "Display Mode"),
                        keywords: [String(localized: "color"), String(localized: "list")],
                        highlightID: SettingsTab.colorPicker.highlightID(for: "Display Mode")
                    ),
                    SettingsSearchEntry(
                        tab: .colorPicker,
                        title: String(localized: "History Size"),
                        keywords: [String(localized: "color history")],
                        highlightID: SettingsTab.colorPicker.highlightID(for: "History Size")
                    ),
                    SettingsSearchEntry(
                        tab: .colorPicker,
                        title: String(localized: "Show All Color Formats"),
                        keywords: [String(localized: "hex"), String(localized: "hsl"), String(localized: "color formats")],
                        highlightID: SettingsTab.colorPicker.highlightID(for: "Show All Color Formats")
                    )
                ]
            }
    private func isTabVisible(_ tab: SettingsTab) -> Bool {
        switch tab {
        case .timer, .stats, .clipboard, .screenAssistant, .colorPicker, .shelf, .notes:
            return !enableMinimalisticUI
        default:
            return true
        }
    }

    @ViewBuilder
    private func detailView(for tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            SettingsForm(tab: .general) {
                GeneralSettings()
            }
        case .liveActivities:
            SettingsForm(tab: .liveActivities) {
                LiveActivitiesSettings()
            }
        case .appearance:
            SettingsForm(tab: .appearance) {
                Appearance()
            }
        case .lockScreen:
            SettingsForm(tab: .lockScreen) {
                LockScreenSettings()
            }
        case .media:
            SettingsForm(tab: .media) {
                Media()
            }
        case .devices:
            SettingsForm(tab: .devices) {
                DevicesSettingsView()
            }
        case .extensions:
            SettingsForm(tab: .extensions) {
                ExtensionsSettingsView()
            }
        case .timer:
            SettingsForm(tab: .timer) {
                TimerSettings()
            }
        case .calendar:
            SettingsForm(tab: .calendar) {
                CalendarSettings()
            }
        case .hudAndOSD:
            SettingsForm(tab: .hudAndOSD) {
                HUDAndOSDSettingsView()
            }
        case .battery:
            SettingsForm(tab: .battery) {
                Charge()
            }
        case .stats:
            SettingsForm(tab: .stats) {
                StatsSettings()
            }
        case .clipboard:
            SettingsForm(tab: .clipboard) {
                ClipboardSettings()
            }
        case .screenAssistant:
            SettingsForm(tab: .screenAssistant) {
                ScreenAssistantSettings()
            }
        case .colorPicker:
            SettingsForm(tab: .colorPicker) {
                ColorPickerSettings()
            }
        case .downloads:
            SettingsForm(tab: .downloads) {
                Downloads()
            }
        case .shelf:
            SettingsForm(tab: .shelf) {
                Shelf()
            }
        case .shortcuts:
            SettingsForm(tab: .shortcuts) {
                Shortcuts()
            }
        case .notes:
            SettingsForm(tab: .notes) {
                NotesSettingsView()
            }
        case .about:
            if let controller = updaterController {
                SettingsForm(tab: .about) {
                    About(updaterController: controller)
                }
            } else {
                SettingsForm(tab: .about) {
                    About(updaterController: SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil))
                }
            }
        }
    }
}

struct GeneralSettings: View {
    @State private var screens: [String] = NSScreen.screens.compactMap { $0.localizedName }
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @Default(.mirrorShape) var mirrorShape
    @Default(.showEmojis) var showEmojis
    @Default(.gestureSensitivity) var gestureSensitivity
    @Default(.minimumHoverDuration) var minimumHoverDuration
    @Default(.nonNotchHeight) var nonNotchHeight
    @Default(.nonNotchHeightMode) var nonNotchHeightMode
    @Default(.notchHeight) var notchHeight
    @Default(.notchHeightMode) var notchHeightMode
    @Default(.showOnAllDisplays) var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) var automaticallySwitchDisplay
    @Default(.enableGestures) var enableGestures
    @Default(.openNotchOnHover) var openNotchOnHover
    @Default(.enableMinimalisticUI) var enableMinimalisticUI
    @Default(.enableHorizontalMusicGestures) var enableHorizontalMusicGestures
    @Default(.musicGestureBehavior) var musicGestureBehavior
    @Default(.reverseSwipeGestures) var reverseSwipeGestures
    @Default(.reverseScrollGestures) var reverseScrollGestures

    private func highlightID(_ title: String) -> String {
        SettingsTab.general.highlightID(for: title)
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(String(localized: "Enable Minimalistic UI"), key: .enableMinimalisticUI)
                    .onChange(of: enableMinimalisticUI) { _, newValue in
                        if newValue {
                            // Auto-enable simpler animation mode
                            Defaults[.useModernCloseAnimation] = true
                        }
                    }
                    .settingsHighlight(id: highlightID("Enable Minimalistic UI"))
            } header: {
                Text("UI Mode")
            } footer: {
                Text("Minimalistic mode focuses on media controls and system HUDs, hiding all extra features for a clean, focused experience. Automatically enables simpler animations.")
            }
            
            Section {
                Defaults.Toggle(String(localized:"Menubar icon"), key: .menubarIcon)
                    .settingsHighlight(id: highlightID("Menubar icon"));
                LaunchAtLogin.Toggle(String(localized:"Launch at login"))
                    .settingsHighlight(id: highlightID("Launch at login"))
                Defaults.Toggle(key: .showOnAllDisplays) {
                    Text("Show on all displays")
                }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(name: Notification.Name.showOnAllDisplaysChanged, object: nil)
                }
                .settingsHighlight(id: highlightID("Show on all displays"))
                Picker("Show on a specific display", selection: $coordinator.preferredScreen) {
                    ForEach(screens, id: \.self) { screen in
                        Text(screen)
                    }
                }
                .onChange(of: NSScreen.screens) {
                    screens =  NSScreen.screens.compactMap({$0.localizedName})
                }
                .disabled(showOnAllDisplays)
                .settingsHighlight(id: highlightID("Show on a specific display"))
                Defaults.Toggle(String(localized:"Automatically switch displays"), key: .automaticallySwitchDisplay)
                .onChange(of: automaticallySwitchDisplay) {
                    NotificationCenter.default.post(name: Notification.Name.automaticallySwitchDisplayChanged, object: nil)
                }
                .disabled(showOnAllDisplays)
                .settingsHighlight(id: highlightID("Automatically switch displays"))
                Defaults.Toggle(String(localized:"Hide Dynamic Island during screenshots & recordings"), key: .hideDynamicIslandFromScreenCapture)
                    .settingsHighlight(id: highlightID("Hide Dynamic Island during screenshots & recordings"))
            } header: {
                Text("System features")
            }
            
            Section {
                Picker(selection: $notchHeightMode, label:
                    Text("Notch display height")) {
                        Text("Match real notch size")
                            .tag(WindowHeightMode.matchRealNotchSize)
                        Text("Match menubar height")
                            .tag(WindowHeightMode.matchMenuBar)
                        Text("Custom height")
                            .tag(WindowHeightMode.custom)
                    }
                    .onChange(of: notchHeightMode) {
                        switch notchHeightMode {
                        case .matchRealNotchSize:
                            notchHeight = 38
                        case .matchMenuBar:
                            notchHeight = 44
                        case .custom:
                            notchHeight = 38
                        }
                        NotificationCenter.default.post(name: Notification.Name.notchHeightChanged, object: nil)
                    }
                    .settingsHighlight(id: highlightID("Notch display height"))
                if notchHeightMode == .custom {
                    Slider(value: $notchHeight, in: 15...45, step: 1) {
                        Text("Custom notch size - \(notchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: notchHeight) {
                        NotificationCenter.default.post(name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
                Picker("Non-notch display height", selection: $nonNotchHeightMode) {
                    Text("Match menubar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Match real notch size")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: nonNotchHeightMode) {
                    switch nonNotchHeightMode {
                    case .matchMenuBar:
                        nonNotchHeight = 24
                    case .matchRealNotchSize:
                        nonNotchHeight = 32
                    case .custom:
                        nonNotchHeight = 32
                    }
                    NotificationCenter.default.post(name: Notification.Name.notchHeightChanged, object: nil)
                }
                if nonNotchHeightMode == .custom {
                    Slider(value: $nonNotchHeight, in: 0...40, step: 1) {
                        Text("Custom notch size - \(nonNotchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: nonNotchHeight) {
                        NotificationCenter.default.post(name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
            } header: {
                Text("Notch Height")
            }

            NotchBehaviour()

            gestureControls()
        }
        .toolbar {
            Button("Quit app") {
                NSApp.terminate(self)
            }
            .controlSize(.extraLarge)
        }
        .navigationTitle("General")
        .onChange(of: openNotchOnHover) {
            if !openNotchOnHover {
                enableGestures = true
            }
        }
    }
    
    @ViewBuilder
    func gestureControls() -> some View {
        Section {
            Defaults.Toggle(String(localized:"Enable gestures"), key: .enableGestures)
                .disabled(!openNotchOnHover)
                .settingsHighlight(id: highlightID("Enable gestures"))
            if enableGestures {
                Defaults.Toggle(String(localized:"Media change with horizontal gestures"), key: .enableHorizontalMusicGestures)
                    .settingsHighlight(id: highlightID("Horizontal media gestures"))

                if enableHorizontalMusicGestures {
                    Picker("Gesture skip behavior", selection: $musicGestureBehavior) {
                        ForEach(MusicSkipBehavior.allCases) { behavior in
                            Text(behavior.displayName)
                                .tag(behavior)
                        }
                    }
                    .pickerStyle(.segmented)
                    .settingsHighlight(id: highlightID("Gesture skip behavior"))

                    Text(musicGestureBehavior.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Defaults.Toggle(String(localized:"Reverse swipe gestures"), key: .reverseSwipeGestures)
                        .settingsHighlight(id: highlightID("Reverse swipe gestures"))
                }

                Defaults.Toggle(String(localized:"Close gesture"), key: .closeGestureEnabled)
                    .settingsHighlight(id: highlightID("Close gesture"))
                Slider(value: $gestureSensitivity, in: 100...300, step: 100) {
                    HStack {
                        Text("Gesture sensitivity")
                        Spacer()
                        Text(Defaults[.gestureSensitivity] == 100 ? "High" : Defaults[.gestureSensitivity] == 200 ? "Medium" : "Low")
                            .foregroundStyle(.secondary)
                    }
                }

                Defaults.Toggle(String(localized:"Reverse open/close scroll gestures"), key: .reverseScrollGestures)
                    .settingsHighlight(id: highlightID("Reverse scroll gestures"))
            }
        } header: {
            HStack {
                Text("Gesture control")
                customBadge(text: "Beta")
            }
        } footer: {
            Text("Two-finger swipe up on notch to close, two-finger swipe down on notch to open when **Open notch on hover** option is disabled")
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    @ViewBuilder
    func NotchBehaviour() -> some View {
        Section {
            Defaults.Toggle(String(localized:"Extend hover area"), key: .extendHoverArea)
                .settingsHighlight(id: highlightID("Extend hover area"))
            Defaults.Toggle(String(localized:"Enable haptics"), key: .enableHaptics)
                .settingsHighlight(id: highlightID("Enable haptics"))
            Defaults.Toggle(String(localized:"Open notch on hover"), key: .openNotchOnHover)
                .settingsHighlight(id: highlightID("Open notch on hover"))
            Toggle("Remember last tab", isOn: $coordinator.openLastTabByDefault)
            if openNotchOnHover {
                Slider(value: $minimumHoverDuration, in: 0...1, step: 0.1) {
                    HStack {
                        Text("Minimum hover duration")
                        Spacer()
                        Text("\(minimumHoverDuration, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: minimumHoverDuration) {
                    NotificationCenter.default.post(name: Notification.Name.notchHeightChanged, object: nil)
                }
            }
        } header: {
            Text("Notch behavior")
        }
    }
}

struct Charge: View {
    private func highlightID(_ title: String) -> String {
        SettingsTab.battery.highlightID(for: title)
    }

    var body: some View {
        Form {
            if BatteryActivityManager.shared.hasBattery() {
                Section {
                    Defaults.Toggle(String(localized: "Show battery indicator"), key: .showBatteryIndicator)
                        .settingsHighlight(id: highlightID("Show battery indicator"))
                    Defaults.Toggle(String(localized: "Show power status notifications"), key: .showPowerStatusNotifications)
                        .settingsHighlight(id: highlightID("Show power status notifications"))
                    Defaults.Toggle(String(localized: "Play low battery alert sound"), key: .playLowBatteryAlertSound)
                        .settingsHighlight(id: highlightID("Play low battery alert sound"))
                } header: {
                    Text("General")
                }
                Section {
                    Defaults.Toggle(String(localized: "Show battery percentage"), key: .showBatteryPercentage)
                        .settingsHighlight(id: highlightID("Show battery percentage"))
                    Defaults.Toggle(String(localized: "Show power status icons"), key: .showPowerStatusIcons)
                        .settingsHighlight(id: highlightID("Show power status icons"))
                } header: {
                    Text("Battery Information")
                }
            } else {
                ContentUnavailableView {
                    VStack(spacing: 16) {
                        Image("battery.100percent.slash")
                            .font(.title)
                        Text("Battery settings and informations are only available on MacBooks")
                            .font(.title3)
                    }
                }
            }
        }
        .navigationTitle("Battery")
    }
}

struct Downloads: View {
    @Default(.selectedDownloadIndicatorStyle) var selectedDownloadIndicatorStyle
    @Default(.selectedDownloadIconStyle) var selectedDownloadIconStyle

    private func highlightID(_ title: String) -> String {
        SettingsTab.downloads.highlightID(for: title)
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(String(localized: "Enable download detection"), key: .enableDownloadListener)
                    .settingsHighlight(id: highlightID("Enable download detection"))
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "Download indicator style"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 16) {
                        DownloadStyleButton(
                            style: .progress,
                            isSelected: selectedDownloadIndicatorStyle == .progress,
                            disabled: !Defaults[.enableDownloadListener]
                        ) {
                            selectedDownloadIndicatorStyle = .progress
                        }
                        
                        DownloadStyleButton(
                            style: .circle,
                            isSelected: selectedDownloadIndicatorStyle == .circle,
                            disabled: !Defaults[.enableDownloadListener]
                        ) {
                            selectedDownloadIndicatorStyle = .circle
                        }
                    }
                }
                .settingsHighlight(id: highlightID("Download indicator style"))
            } header: {
                Text("Download Detection")
            } footer: {
                Text("Monitor your Downloads folder for Chromium-style downloads (.crdownload files) and show a live activity in the Dynamic Island while downloads are in progress.")
            }
        }
        .navigationTitle("Downloads")
    }
    
    struct DownloadStyleButton: View {
        let style: DownloadIndicatorStyle
        let isSelected: Bool
        let disabled: Bool
        let action: () -> Void
        
        @State private var isHovering = false
        
        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
                        )
                    
                    if style == .progress {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(.accentColor)
                            .frame(width: 40)
                    } else {
                        SpinningCircleDownloadView()
                    }
                }
                .frame(width: 80, height: 60)
                .onHover { hovering in
                    if !disabled {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovering = hovering
                        }
                    }
                }
                
                Text(style.localizedName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
                    .foregroundStyle(disabled ? .secondary : .primary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !disabled {
                    action()
                }
            }
            .opacity(disabled ? 0.5 : 1.0)
        }
        
        private var backgroundColor: Color {
            if disabled { return Color(nsColor: .controlBackgroundColor) }
            if isSelected { return Color.accentColor.opacity(0.1) }
            if isHovering { return Color.primary.opacity(0.05) }
            return Color(nsColor: .controlBackgroundColor)
        }
        
        private var borderColor: Color {
            if isSelected { return Color.accentColor }
            if isHovering { return Color.primary.opacity(0.1) }
            return Color.clear
        }
    }
}

final class HUDPreviewViewModel: ObservableObject {
    @Published var level: Float = 0
    @Published var iconName: String = "speaker.wave.3.fill"
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setup()
    }
    
    private func setup() {
        // Ensure controllers are active
        SystemVolumeController.shared.start()
        SystemBrightnessController.shared.start()
        SystemKeyboardBacklightController.shared.start()
        
        // Initial state from volume
        let vol = SystemVolumeController.shared.currentVolume
        self.level = vol
        if vol <= 0.01 { self.iconName = "speaker.slash.fill" }
        else if vol < 0.33 { self.iconName = "speaker.wave.1.fill" }
        else if vol < 0.66 { self.iconName = "speaker.wave.2.fill" }
        else { self.iconName = "speaker.wave.3.fill" }
        
        // Listeners
        NotificationCenter.default.publisher(for: .systemVolumeDidChange)
            .compactMap { $0.userInfo }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                guard let self else { return }
                if let vol = info["value"] as? Float {
                    self.level = vol
                    if vol <= 0.01 { self.iconName = "speaker.slash.fill" }
                    else if vol < 0.33 { self.iconName = "speaker.wave.1.fill" }
                    else if vol < 0.66 { self.iconName = "speaker.wave.2.fill" }
                    else { self.iconName = "speaker.wave.3.fill" }
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .systemBrightnessDidChange)
            .compactMap { $0.userInfo }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                guard let self else { return }
                if let val = info["value"] as? Float {
                    self.level = val
                    self.iconName = "sun.max.fill"
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .keyboardBacklightDidChange)
            .compactMap { $0.userInfo }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                guard let self else { return }
                if let val = info["value"] as? Float {
                    self.level = val
                    self.iconName = val > 0.5 ? "light.max" : "light.min"
                }
            }
            .store(in: &cancellables)
    }
}

private struct HUDAndOSDSettingsView: View {
    @State private var selectedTab: Tab = {
        if Defaults[.enableSystemHUD] { return .hud }
        if Defaults[.enableCustomOSD] { return .osd }
        if Defaults[.enableVerticalHUD] { return .vertical }
        if Defaults[.enableCircularHUD] { return .circular }
        return .hud
    }()
    @Default(.enableSystemHUD) var enableSystemHUD
    @Default(.enableCustomOSD) var enableCustomOSD
    @Default(.enableVerticalHUD) var enableVerticalHUD
    @Default(.enableCircularHUD) var enableCircularHUD
    @Default(.verticalHUDPosition) var verticalHUDPosition
    @Default(.enableVolumeHUD) var enableVolumeHUD
    @Default(.enableBrightnessHUD) var enableBrightnessHUD
    @Default(.enableKeyboardBacklightHUD) var enableKeyboardBacklightHUD
    
    // Vertical HUD Props
    @Default(.verticalHUDShowValue) var verticalHUDShowValue
    @Default(.verticalHUDInteractive) var verticalHUDInteractive
    @Default(.verticalHUDHeight) var verticalHUDHeight
    @Default(.verticalHUDWidth) var verticalHUDWidth
    @Default(.verticalHUDPadding) var verticalHUDPadding
    @Default(.verticalHUDUseAccentColor) var verticalHUDUseAccentColor
    
    // Circular HUD Props
    @Default(.circularHUDShowValue) var circularHUDShowValue
    @Default(.circularHUDSize) var circularHUDSize
    @Default(.circularHUDStrokeWidth) var circularHUDStrokeWidth
    @Default(.circularHUDUseAccentColor) var circularHUDUseAccentColor
    @StateObject private var previewModel = HUDPreviewViewModel()
    @ObservedObject private var accessibilityPermission = AccessibilityPermissionStore.shared

    private enum Tab: String, CaseIterable, Identifiable {
        case hud = "Dynamic Island HUD"
        case osd = "Custom OSD"
        case vertical = "Vertical Bar"
        case circular = "Circular"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
                case .hud: return String(localized: "Dynamic Island HUD")
                case .osd: return String(localized: "Custom OSD")
                case .vertical: return String(localized: "Vertical Bar")
                case .circular: return String(localized: "Circular")
            }
        }
    }

    private var paneBackgroundColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                HUDSelectionCard(
                    title: String(localized: "Dynamic Island"),
                    isSelected: selectedTab == .hud,
                    action: {
                        selectedTab = .hud
                        enableSystemHUD = true
                        enableCustomOSD = false
                        enableVerticalHUD = false
                        enableCircularHUD = false
                    }
                ) {
                    VStack {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 64, height: 20)
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            .overlay {
                                HStack(spacing: 6) {
                                    Image(systemName: previewModel.iconName)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 12)
                                    
                                    GeometryReader { geo in
                                        Capsule()
                                            .fill(Color.white.opacity(0.2))
                                            .overlay(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color.white)
                                                    .frame(width: geo.size.width * CGFloat(previewModel.level))
                                                    .animation(.spring(response: 0.3), value: previewModel.level)
                                            }
                                    }
                                    .frame(height: 4)
                                }
                                .padding(.horizontal, 8)
                            }
                    }
                }
                
                HUDSelectionCard(
                    title: String(localized: "Custom OSD"),
                    isSelected: selectedTab == .osd,
                    action: {
                        selectedTab = .osd
                        enableCustomOSD = true
                        enableSystemHUD = false
                        enableVerticalHUD = false
                        enableCircularHUD = false
                    }
                ) {
                   RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: previewModel.iconName)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                                    .symbolRenderingMode(.hierarchical)
                                    .contentTransition(.symbolEffect(.replace))
                                
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.2))
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.primary)
                                                .frame(width: geo.size.width * CGFloat(previewModel.level))
                                                .animation(.spring(response: 0.3), value: previewModel.level)
                                        }
                                }
                                .frame(width: 36, height: 4)
                            }
                        }
                        .frame(width: 44, height: 44)
                }
                
                HUDSelectionCard(
                    title: String(localized: "Vertical Bar"),
                    isSelected: selectedTab == .vertical,
                    action: {
                        selectedTab = .vertical
                        enableVerticalHUD = true
                        enableSystemHUD = false
                        enableCustomOSD = false
                        enableCircularHUD = false
                    }
                ) {
                    RoundedRectangle(cornerRadius: 8)
                         .fill(.ultraThinMaterial)
                         .overlay {
                             RoundedRectangle(cornerRadius: 8)
                                 .stroke(.white.opacity(0.1), lineWidth: 1)
                         }
                         .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                         .overlay {
                             VStack {
                                 GeometryReader { geo in
                                     VStack {
                                         Spacer()
                                         RoundedRectangle(cornerRadius: 6, style: .continuous)
                                             .fill(Color.white)
                                             .frame(height: max(0, geo.size.height * CGFloat(previewModel.level)))
                                             .animation(.spring(response: 0.3), value: previewModel.level)
                                     }
                                 }
                                 .mask(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                 .padding(.bottom, 2)
                                 
                                 Image(systemName: previewModel.iconName)
                                     .font(.system(size: 9))
                                     .foregroundStyle(previewModel.level > 0.15 ? .black : .secondary)
                                     .symbolRenderingMode(.hierarchical)
                                     .contentTransition(.symbolEffect(.replace))
                             }
                             .padding(4)
                         }
                         .frame(width: 22, height: 54)
                }

                HUDSelectionCard(
                    title: String(localized: "Circular"),
                    isSelected: selectedTab == .circular,
                    action: {
                        selectedTab = .circular
                        enableCircularHUD = true
                        enableSystemHUD = false
                        enableCustomOSD = false
                        enableVerticalHUD = false
                    }
                ) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: CGFloat(previewModel.level))
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.3), value: previewModel.level)
                        Image(systemName: previewModel.iconName)
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                            .symbolRenderingMode(.hierarchical)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: 44, height: 44)
                }
            }
            .padding(.top, 8)

            switch selectedTab {
            case .hud:
                HUD()
            case .osd:
                 if #available(macOS 15.0, *) {
                    CustomOSDSettings()
                } else {
                     VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        
                        Text("macOS 15 or later required")
                            .font(.headline)
                        
                        Text("Custom OSD feature requires macOS 15 or later.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            case .vertical:
                Form {
                    if !accessibilityPermission.isAuthorized {
                        Section {
                            SettingsPermissionCallout(
                                message: "Accessibility permission is needed to intercept system controls for the Vertical HUD.",
                                requestAction: {
                                    accessibilityPermission.requestAuthorizationPrompt()
                                },
                                openSettingsAction: {
                                    accessibilityPermission.openSystemSettings()
                                }
                            )
                        } header: {
                            Text("Accessibility")
                        }
                    }

                    if accessibilityPermission.isAuthorized {
                        Section {
                            Toggle("Volume HUD", isOn: $enableVolumeHUD)
                            Toggle("Brightness HUD", isOn: $enableBrightnessHUD)
                            Toggle("Keyboard Backlight HUD", isOn: $enableKeyboardBacklightHUD)
                        } header: {
                            Text("Controls")
                        } footer: {
                            Text("Choose which system controls should display HUD notifications.")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Section {
                        Toggle("Show Percentage", isOn: $verticalHUDShowValue)
                        Toggle("Use Accent Color", isOn: $verticalHUDUseAccentColor)
                        Toggle("Interactive (Drag to Change)", isOn: $verticalHUDInteractive)
                        Defaults.Toggle("Color-coded Volume", key: .useColorCodedVolumeDisplay)
                        if Defaults[.useColorCodedVolumeDisplay] {
                            Defaults.Toggle("Smooth color transitions", key: .useSmoothColorGradient)
                        }
                    } header: {
                        Text("Behavior & Style")
                    }
                    
                    Section {
                        Picker("HUD Position", selection: $verticalHUDPosition) {
                            Text("Left").tag("left")
                            Text("Right").tag("right")
                        }
                        .pickerStyle(.menu)
                        
                        VStack(alignment: .leading) {
                            Text("Screen Padding: \(Int(verticalHUDPadding))px")
                            Slider(value: $verticalHUDPadding, in: 0...100, step: 4)
                        }
                    } header: {
                        Text("Position")
                    } footer: {
                        Text("Choose directly on which side of the screen the vertical bar appears.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    
                    Section {
                        VStack(alignment: .leading) {
                            Text("Width: \(Int(verticalHUDWidth))px")
                            Slider(value: $verticalHUDWidth, in: 24...80, step: 2)
                        }
                        VStack(alignment: .leading) {
                            Text("Height: \(Int(verticalHUDHeight))px")
                            Slider(value: $verticalHUDHeight, in: 100...500, step: 10)
                        }
                        Button("Reset to Default") {
                            verticalHUDWidth = 36
                            verticalHUDHeight = 160
                            verticalHUDPadding = 24
                        }
                    } header: {
                        Text("Dimensions")
                    }
                }

            case .circular:
                Form {
                    if !accessibilityPermission.isAuthorized {
                        Section {
                            SettingsPermissionCallout(
                                message: "Accessibility permission is needed to intercept system controls for the Circular HUD.",
                                requestAction: {
                                    accessibilityPermission.requestAuthorizationPrompt()
                                },
                                openSettingsAction: {
                                    accessibilityPermission.openSystemSettings()
                                }
                            )
                        } header: {
                            Text("Accessibility")
                        }
                    }

                    if accessibilityPermission.isAuthorized {
                        Section {
                            Toggle("Volume HUD", isOn: $enableVolumeHUD)
                            Toggle("Brightness HUD", isOn: $enableBrightnessHUD)
                            Toggle("Keyboard Backlight HUD", isOn: $enableKeyboardBacklightHUD)
                        } header: {
                            Text("Controls")
                        } footer: {
                            Text("Choose which system controls should display HUD notifications.")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Section {
                        Toggle("Show Percentage", isOn: $circularHUDShowValue)
                        Toggle("Use Accent Color", isOn: $circularHUDUseAccentColor)
                        Defaults.Toggle("Color-coded Volume", key: .useColorCodedVolumeDisplay)
                        if Defaults[.useColorCodedVolumeDisplay] {
                            Defaults.Toggle("Smooth color transitions", key: .useSmoothColorGradient)
                        }
                    } header: {
                        Text("Style")
                    }
                    
                    Section {
                        VStack(alignment: .leading) {
                            Text("Size: \(Int(circularHUDSize))px")
                            Slider(value: $circularHUDSize, in: 40...200, step: 5)
                        }
                        VStack(alignment: .leading) {
                            Text("Line Width: \(Int(circularHUDStrokeWidth))px")
                            Slider(value: $circularHUDStrokeWidth, in: 2...16, step: 1)
                        }
                        Button("Reset to Default") {
                            circularHUDSize = 65
                            circularHUDStrokeWidth = 4
                        }
                    } header: {
                        Text("Dimensions")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(paneBackgroundColor)
        .navigationTitle("Controls")
    }
}

private struct HUDSelectionCard<Preview: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let preview: Preview
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isSelected ? Color.accentColor : Color.clear,
                                    lineWidth: 2.5
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    
                    preview
                }
                .frame(width: 110, height: 80)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 4)
                    } else {
                        Color.clear
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

private struct DevicesSettingsView: View {
    @Default(.progressBarStyle) var progressBarStyle

    private func highlightID(_ title: String) -> String {
        SettingsTab.devices.highlightID(for: title)
    }

    private var colorCodingDisabled: Bool {
        progressBarStyle == .segmented
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle("Show Bluetooth device connections", key: .showBluetoothDeviceConnections)
                    .settingsHighlight(id: highlightID("Show Bluetooth device connections"))
                Defaults.Toggle("Use circular battery indicator", key: .useCircularBluetoothBatteryIndicator)
                    .settingsHighlight(id: highlightID("Use circular battery indicator"))
                Defaults.Toggle("Show battery percentage text in HUD", key: .showBluetoothBatteryPercentageText)
                    .settingsHighlight(id: highlightID("Show battery percentage text in HUD"))
                Defaults.Toggle("Scroll device name in HUD", key: .showBluetoothDeviceNameMarquee)
                    .settingsHighlight(id: highlightID("Scroll device name in HUD"))
            } header: {
                Text("Bluetooth Audio Devices")
            } footer: {
                Text("Displays a HUD notification when Bluetooth audio devices (headphones, AirPods, speakers) connect, showing device name and battery level.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle("Color-coded battery display", key: .useColorCodedBatteryDisplay)
                    .disabled(colorCodingDisabled)
                    .settingsHighlight(id: highlightID("Color-coded battery display"))
            } header: {
                Text("Battery Indicator Styling")
            } footer: {
                if progressBarStyle == .segmented {
                    Text("Color-coded fills are unavailable in Segmented mode. Switch to Hierarchical or Gradient inside Controls › Dynamic Island to adjust advanced options.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else if Defaults[.useSmoothColorGradient] {
                    Text("Smooth transitions blend Green (0–60%), Yellow (60–85%), and Red (85–100%) through the entire fill. Adjust gradient behavior from Controls › Dynamic Island.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text("Discrete transitions snap between Green (0–60%), Yellow (60–85%), and Red (85–100%).")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Devices")
    }
}

struct HUD: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @Default(.inlineHUD) var inlineHUD
    @Default(.progressBarStyle) var progressBarStyle
    @Default(.enableSystemHUD) var enableSystemHUD
    @Default(.enableVolumeHUD) var enableVolumeHUD
    @Default(.enableBrightnessHUD) var enableBrightnessHUD
    @Default(.enableKeyboardBacklightHUD) var enableKeyboardBacklightHUD
    @Default(.systemHUDSensitivity) var systemHUDSensitivity
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @ObservedObject private var accessibilityPermission = AccessibilityPermissionStore.shared

    private func highlightID(_ title: String) -> String {
        SettingsTab.hudAndOSD.highlightID(for: title)
    }

    private var hasAccessibilityPermission: Bool {
        accessibilityPermission.isAuthorized
    }

    private var colorCodingDisabled: Bool {
        progressBarStyle == .segmented
    }
    
    var body: some View {
        Form {
            if !hasAccessibilityPermission {
                Section {
                    SettingsPermissionCallout(
                        message: String(localized: "Accessibility permission lets Dynamic Island replace the native volume, brightness, and keyboard HUDs."),
                        requestAction: { accessibilityPermission.requestAuthorizationPrompt() },
                        openSettingsAction: { accessibilityPermission.openSystemSettings() }
                    )
                } header: {
                    Text("Accessibility")
                }
            }


            
            if enableSystemHUD && !Defaults[.enableCustomOSD] && hasAccessibilityPermission {
                Section {
                    Toggle("Volume HUD", isOn: $enableVolumeHUD)
                    Toggle("Brightness HUD", isOn: $enableBrightnessHUD)
                    Toggle("Keyboard Backlight HUD", isOn: $enableKeyboardBacklightHUD)
                } header: {
                    Text("Controls")
                } footer: {
                    Text("Choose which system controls should display HUD notifications.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            Section {
                Defaults.Toggle(String(localized: "Play feedback when volume is changed"), key: .playVolumeChangeFeedback)
                    .settingsHighlight(id: highlightID("Play feedback when volume is changed"))
                    .help("Plays the supplied feedback clip whenever you press the hardware volume keys.")
            } header: {
                Text("Audio feedback")
            } footer: {
                Text("Requires Accessibility permission so Dynamic Island can intercept the hardware volume keys.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle(String(localized: "Color-coded volume display"), key: .useColorCodedVolumeDisplay)
                    .disabled(colorCodingDisabled)
                    .settingsHighlight(id: highlightID("Color-coded volume display"))

                if !colorCodingDisabled && (Defaults[.useColorCodedBatteryDisplay] || Defaults[.useColorCodedVolumeDisplay]) {
                    Defaults.Toggle(String(localized: "Smooth color transitions"), key: .useSmoothColorGradient)
                        .settingsHighlight(id: highlightID("Smooth color transitions"))
                }

                Defaults.Toggle(String(localized: "Show percentages beside progress bars"), key: .showProgressPercentages)
                    .settingsHighlight(id: highlightID("Show percentages beside progress bars"))
            } header: {
                Text("Dynamic Island Progress Bars")
            } footer: {
                if colorCodingDisabled {
                    Text("Color-coded fills and smooth gradients are unavailable in Segmented mode. Switch to Hierarchical or Gradient to adjust these options.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else if Defaults[.useSmoothColorGradient] {
                    Text("Smooth transitions blend Green (0–60%), Yellow (60–85%), and Red (85–100%) through the entire fill.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text("Discrete transitions snap between Green (0–60%), Yellow (60–85%), and Red (85–100%).")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            
            Section {
                Picker("HUD style", selection: $inlineHUD) {
                    Text("Default")
                        .tag(false)
                    Text("Inline")
                        .tag(true)
                }
                .settingsHighlight(id: highlightID("HUD style"))
                .onChange(of: Defaults[.inlineHUD]) {
                    if Defaults[.inlineHUD] {
                        withAnimation {
                            Defaults[.systemEventIndicatorShadow] = false
                            Defaults[.progressBarStyle] = .hierarchical
                        }
                    }
                }
                Picker("Progressbar style", selection: $progressBarStyle) {
                    Text("Hierarchical")
                        .tag(ProgressBarStyle.hierarchical)
                    Text("Gradient")
                        .tag(ProgressBarStyle.gradient)
                    Text("Segmented")
                        .tag(ProgressBarStyle.segmented)
                }
                .settingsHighlight(id: highlightID("Progressbar style"))
                Defaults.Toggle(String(localized: "Enable glowing effect"), key: .systemEventIndicatorShadow)
                    .settingsHighlight(id: highlightID("Enable glowing effect"))
                Defaults.Toggle(String(localized: "Use accent color"), key: .systemEventIndicatorUseAccent)
                    .settingsHighlight(id: highlightID("Use accent color"))
            } header: {
                HStack {
                    Text("Appearance")
                }
            }
        }
        .navigationTitle("Controls")
        .onAppear {
            accessibilityPermission.refreshStatus()
        }
        .onChange(of: accessibilityPermission.isAuthorized) { _, granted in
            if !granted {
                enableSystemHUD = false
            }
        }
    }
}

struct Media: View {
    @Default(.waitInterval) var waitInterval
    @Default(.mediaController) var mediaController
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @Default(.hideNotchOption) var hideNotchOption
    @Default(.enableSneakPeek) private var enableSneakPeek
    @Default(.sneakPeekStyles) var sneakPeekStyles
    @Default(.enableMinimalisticUI) var enableMinimalisticUI
    @Default(.showShuffleAndRepeat) private var showShuffleAndRepeat
    @Default(.musicSkipBehavior) private var musicSkipBehavior
    @Default(.musicControlWindowEnabled) private var musicControlWindowEnabled
    @Default(.enableLockScreenMediaWidget) private var enableLockScreenMediaWidget
    @Default(.showSneakPeekOnTrackChange) private var showSneakPeekOnTrackChange
    @Default(.lockScreenGlassStyle) private var lockScreenGlassStyle
    @Default(.lockScreenGlassCustomizationMode) private var lockScreenGlassCustomizationMode
    @Default(.lockScreenMusicAlbumParallaxEnabled) private var lockScreenMusicAlbumParallaxEnabled
    @Default(.showStandardMediaControls) private var showStandardMediaControls

    private func highlightID(_ title: String) -> String {
        SettingsTab.media.highlightID(for: title)
    }

    private var standardControlsSuppressed: Bool {
        !showStandardMediaControls && !enableMinimalisticUI
    }

    var body: some View {
        Form {
            Section {
                Picker("Music Source", selection: $mediaController) {
                    ForEach(availableMediaControllers) { controller in
                        Text(controller.rawValue).tag(controller)
                    }
                }
                .onChange(of: mediaController) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.mediaControllerChanged,
                        object: nil
                    )
                }
                .settingsHighlight(id: highlightID("Music Source"))
            } header: {
                Text("Media Source")
            } footer: {
                if MusicManager.shared.isNowPlayingDeprecated {
                    HStack {
                        Text("YouTube Music requires this third-party app to be installed: ")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Link("https://github.com/th-ch/youtube-music", destination: URL(string: "https://github.com/th-ch/youtube-music")!)
                            .font(.caption)
                            .foregroundColor(.blue) // Ensures it's visibly a link
                    }
                } else {
                    Text("'Now Playing' was the only option on previous versions and works with all media apps.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            Section {
                Defaults.Toggle("Show media controls in Dynamic Island", key: .showStandardMediaControls)
                    .disabled(enableMinimalisticUI)
                    .settingsHighlight(id: highlightID("Show media controls in Dynamic Island"))

                if enableMinimalisticUI {
                    Text("Disable Minimalistic UI to configure the standard notch media controls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if standardControlsSuppressed {
                    Text("Standard notch media controls are hidden. Re-enable the toggle above to restore them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Dynamic Island Visibility")
            }
            Section {
                Defaults.Toggle(key: .showShuffleAndRepeat) {
                    HStack {
                        Text("Enable customizable controls")
                        customBadge(text: "Beta")
                    }
                }
                if showShuffleAndRepeat {
                    Defaults.Toggle("Show \"Change Media Output\" control", key: .showMediaOutputControl)
                        .settingsHighlight(id: highlightID("Show Change Media Output control"))
                        .help("Adds the AirPlay/route picker button back to the customizable controls palette.")
                    MusicSlotConfigurationView()
                } else {
                    Text("Turn on customizable controls to rearrange media buttons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
            } header: {
                Text("Media controls")
            }

            Section(header: Text("Lock Screen Media")) {
                Defaults.Toggle("Enable album art parallax", key: .lockScreenMusicAlbumParallaxEnabled)
                    .settingsHighlight(id: highlightID("Enable album art parallax"))
                Text("Applies the notch-style parallax effect to the lock screen media widget album art.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if musicControlWindowEnabled {
                Section {
                    Picker("Skip buttons", selection: $musicSkipBehavior) {
                        ForEach(MusicSkipBehavior.allCases) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .pickerStyle(.segmented)
                    .settingsHighlight(id: highlightID("Skip buttons"))

                    Text(musicSkipBehavior.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Floating window panel skip behaviour")
                }
            }
            Section {
                Toggle(
                    "Enable music live activity",
                    isOn: $coordinator.musicLiveActivityEnabled.animation()
                )
                .disabled(standardControlsSuppressed)
                .help(standardControlsSuppressed ? "Standard notch media controls are hidden while this toggle is off." : "")
                Defaults.Toggle(
                    "Show floating media controls",
                    key: .musicControlWindowEnabled
                )
                .disabled(!coordinator.musicLiveActivityEnabled || standardControlsSuppressed)
                .help("Displays play/pause and skip buttons beside the notch while music is active. Disabled by default.")
                Toggle("Enable sneak peek", isOn: $enableSneakPeek)
                Toggle("Show sneak peek on playback changes", isOn: $showSneakPeekOnTrackChange)
                    .disabled(!enableSneakPeek)
                Defaults.Toggle("Enable lyrics", key: .enableLyrics)
                    .settingsHighlight(id: highlightID("Enable lyrics"))
                Defaults.Toggle("Enable album art parallax effect", key: .enableParallaxEffect)
                    .settingsHighlight(id: highlightID("Enable album art parallax effect"))
                Picker("Sneak Peek Style", selection: $sneakPeekStyles){
                    ForEach(SneakPeekStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .disabled(!enableSneakPeek || enableMinimalisticUI)
                .onChange(of: enableMinimalisticUI) { _, isMinimalistic in
                    // Force standard sneak peek style when minimalistic UI is enabled
                    if isMinimalistic {
                        sneakPeekStyles = .standard
                    }
                }
                .settingsHighlight(id: highlightID("Sneak Peek Style"))
                
                if enableMinimalisticUI {
                    Text("Sneak peek style is locked to Standard in minimalistic mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Stepper(value: $waitInterval, in: 0...10, step: 1) {
                        HStack {
                            Text("Media inactivity timeout")
                            Spacer()
                            Text("\(Defaults[.waitInterval], specifier: "%.0f") seconds")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Media playback live activity")
            }

            Section {
                Defaults.Toggle("Show lock screen media panel", key: .enableLockScreenMediaWidget)
                Defaults.Toggle("Show media app icon", key: .lockScreenShowAppIcon)
                    .disabled(!enableLockScreenMediaWidget)
                Defaults.Toggle("Show panel border", key: .lockScreenPanelShowsBorder)
                    .disabled(!enableLockScreenMediaWidget)
                if lockScreenGlassCustomizationMode == .customLiquid {
                    customLiquidBlurRow
                        .opacity(enableLockScreenMediaWidget ? 1 : 0.5)
                        .settingsHighlight(id: highlightID("Enable media panel blur"))
                } else if lockScreenGlassStyle == .frosted {
                    Defaults.Toggle("Enable media panel blur", key: .lockScreenPanelUsesBlur)
                        .disabled(!enableLockScreenMediaWidget)
                        .settingsHighlight(id: highlightID("Enable media panel blur"))
                } else {
                    unavailableBlurRow
                        .opacity(enableLockScreenMediaWidget ? 1 : 0.5)
                        .settingsHighlight(id: highlightID("Enable media panel blur"))
                }
            } header: {
                Text("Lock Screen Integration")
            } footer: {
                Text("These controls mirror the Lock Screen tab so you can tune the media overlay while focusing on playback settings.")
            }
            .disabled(!showStandardMediaControls)
            .opacity(showStandardMediaControls ? 1 : 0.5)

            Picker(selection: $hideNotchOption, label:
                HStack {
                    Text("Hide DynamicIsland Options")
                    customBadge(text: "Beta")
                }) {
                    Text("Always hide in fullscreen").tag(HideNotchOption.always)
                    Text("Hide only when NowPlaying app is in fullscreen").tag(HideNotchOption.nowPlayingOnly)
                    Text("Never hide").tag(HideNotchOption.never)
                }
                .onChange(of: hideNotchOption) {
                    Defaults[.enableFullscreenMediaDetection] = hideNotchOption != .never
                }
        }
        .navigationTitle("Media")
    }

    // Only show controller options that are available on this macOS version
    private var availableMediaControllers: [MediaControllerType] {
        if MusicManager.shared.isNowPlayingDeprecated {
            return MediaControllerType.allCases.filter { $0 != .nowPlaying }
        } else {
            return MediaControllerType.allCases
        }
    }

    private var unavailableBlurRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Enable media panel blur")
                .foregroundStyle(.secondary)
            Text("Only applies when Material is set to Frosted Glass.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var customLiquidBlurRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Enable media panel blur")
                .foregroundStyle(.secondary)
            Text("Custom liquid glass already renders with Apple's liquid material, so this option is managed automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CalendarSettings: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) var showCalendar: Bool
    @Default(.enableReminderLiveActivity) var enableReminderLiveActivity
    @Default(.reminderPresentationStyle) var reminderPresentationStyle
    @Default(.reminderLeadTime) var reminderLeadTime
    @Default(.reminderSneakPeekDuration) var reminderSneakPeekDuration
    @Default(.enableLockScreenReminderWidget) var enableLockScreenReminderWidget
    @Default(.lockScreenReminderChipStyle) var lockScreenReminderChipStyle
    @Default(.hideAllDayEvents) var hideAllDayEvents
    @Default(.hideCompletedReminders) var hideCompletedReminders
    @Default(.showFullEventTitles) var showFullEventTitles
    @Default(.autoScrollToNextEvent) var autoScrollToNextEvent

    private func highlightID(_ title: String) -> String {
        SettingsTab.calendar.highlightID(for: title)
    }

    var body: some View {
        Form {
            if !calendarManager.hasCalendarAccess || !calendarManager.hasReminderAccess {
                Text("Calendar or Reminder access is denied. Please enable it in System Settings.")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                
                HStack {
                    Button("Request Access") {
                        Task {
                            await calendarManager.checkCalendarAuthorization()
                            await calendarManager.checkReminderAuthorization()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Open System Settings") {
                        if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(settingsURL)
                        }
                    }
                }
            } else {
                // Permissions status
                Section {
                    HStack {
                        Text("Calendars")
                        Spacer()
                        Text(statusText(for: calendarManager.calendarAuthorizationStatus))
                            .foregroundColor(color(for: calendarManager.calendarAuthorizationStatus))
                    }
                    HStack {
                        Text("Reminders")
                        Spacer()
                        Text(statusText(for: calendarManager.reminderAuthorizationStatus))
                            .foregroundColor(color(for: calendarManager.reminderAuthorizationStatus))
                    }
                } header: {
                    Text("Permissions")
                }
                
                Defaults.Toggle(String(localized:"Show calendar"), key: .showCalendar)
                    .settingsHighlight(id: highlightID("Show calendar"))

                Section(header: Text("Event List")) {
                    Toggle("Hide completed reminders", isOn: $hideCompletedReminders)
                        .settingsHighlight(id: highlightID("Hide completed reminders"))
                    Toggle("Show full event titles", isOn: $showFullEventTitles)
                        .settingsHighlight(id: highlightID("Show full event titles"))
                    Toggle("Auto-scroll to next event", isOn: $autoScrollToNextEvent)
                        .settingsHighlight(id: highlightID("Auto-scroll to next event"))
                }

                Section(header: Text("All-Day Events")) {
                    Toggle("Hide all-day events", isOn: $hideAllDayEvents)
                        .settingsHighlight(id: highlightID("Hide all-day events"))
                        .disabled(!showCalendar)

                    Text("Turn this off to include all-day entries in the notch calendar and reminder live activity.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Section(header: Text("Reminder Live Activity")) {
                    Defaults.Toggle(String(localized:"Enable reminder live activity"), key: .enableReminderLiveActivity)
                        .settingsHighlight(id: highlightID("Enable reminder live activity"))

                    Picker("Countdown style", selection: $reminderPresentationStyle) {
                        ForEach(ReminderPresentationStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!enableReminderLiveActivity)
                    .settingsHighlight(id: highlightID("Countdown style"))

                    HStack {
                        Text("Notify before")
                        Slider(
                            value: Binding(
                                get: { Double(reminderLeadTime) },
                                set: { reminderLeadTime = Int($0) }
                            ),
                            in: 1...60,
                            step: 1
                        )
                        .disabled(!enableReminderLiveActivity)
                        Text("\(reminderLeadTime) min")
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }

                    HStack {
                        Text("Sneak peek duration")
                        Slider(
                            value: $reminderSneakPeekDuration,
                            in: 3...20,
                            step: 1
                        )
                        .disabled(!enableReminderLiveActivity)
                        Text("\(Int(reminderSneakPeekDuration)) s")
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }

                Section(header: Text("Lock Screen Reminder Widget")) {
                    Defaults.Toggle(String(localized:"Show lock screen reminder"), key: .enableLockScreenReminderWidget)
                        .settingsHighlight(id: highlightID("Show lock screen reminder"))

                    Picker(String(localized: "Chip color"), selection: $lockScreenReminderChipStyle) {
                        ForEach(LockScreenReminderChipStyle.allCases) { style in

                            Text(style.localizedName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!enableLockScreenReminderWidget || !enableReminderLiveActivity)
                    .settingsHighlight(id: highlightID("Chip color"))
                }

                Section(header: Text("Select Calendars")) {
                    List {
                        ForEach(calendarManager.allCalendars, id: \.id) { calendar in
                            Toggle(isOn: Binding(
                                get: { calendarManager.getCalendarSelected(calendar) },
                                set: { isSelected in
                                    Task {
                                        await calendarManager.setCalendarSelected(calendar, isSelected: isSelected)
                                    }
                                }
                            )) {
                                Text(calendar.title)
                            }
                            .disabled(!showCalendar)
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await calendarManager.checkCalendarAuthorization()
                await calendarManager.checkReminderAuthorization()
            }
        }
        .navigationTitle("Calendar")
    }
    
    private func statusText(for status: EKAuthorizationStatus) -> String {
        switch status {
        case .fullAccess, .authorized: return String(localized:"Full Access")
        case .writeOnly: return String(localized:"Write Only")
        case .denied: return String(localized:"Denied")
        case .restricted: return String(localized:"Restricted")
        case .notDetermined: return String(localized:"Not Determined")
        @unknown default: return String(localized:"Unknown")
        }
    }
    
    private func color(for status: EKAuthorizationStatus) -> Color {
        switch status {
        case .fullAccess, .authorized: return .green
        case .writeOnly: return .yellow
        case .denied, .restricted: return .red
        case .notDetermined: return .secondary
        @unknown default: return .secondary
        }
    }
}

struct About: View {
    @State private var showBuildNumber: Bool = false
    let updaterController: SPUStandardUpdaterController
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack {
            Form {
                Section {
                    HStack {
                        Text("Release name")
                        Spacer()
                        Text(Defaults[.releaseName])
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        if showBuildNumber {
                            Text("(\(Bundle.main.buildVersionNumber ?? ""))")
                                .foregroundStyle(.secondary)
                        }
                        Text(Bundle.main.releaseVersionNumber ?? "unkown")
                            .foregroundStyle(.secondary)
                    }
                    .onTapGesture {
                        withAnimation {
                            showBuildNumber.toggle()
                        }
                    }
                } header: {
                    Text("Version info")
                }

                UpdaterSettingsView(updater: updaterController.updater)

                HStack(spacing: 30) {
                    Spacer(minLength: 0)
                    Button {
                        NSWorkspace.shared.open(sponsorPage)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Donate")
                                .foregroundStyle(.white)
                        }
                        .contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                    Button {
                        NSWorkspace.shared.open(productPage)
                    } label: {
                        VStack(spacing: 5) {
                            Image("Github")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18)
                            Text("GitHub")
                                .foregroundStyle(.white)
                        }
                        .contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                }
                .buttonStyle(PlainButtonStyle())
                Text("Your support funds software development learning for students in 9th–12th grade.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            VStack(spacing: 0) {
                Divider()
                Text("Made with ❤️ by Ebullioscopic")
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
                    .padding(.bottom, 7)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .background(.regularMaterial)
        }
        .toolbar {
//            Button("Welcome window") {
//                openWindow(id: "onboarding")
//            }
//            .controlSize(.extraLarge)
            CheckForUpdatesView(updater: updaterController.updater)
        }
        .navigationTitle("About")
    }
}

struct Shelf: View {
    @Default(.quickShareProvider) var quickShareProvider
    @Default(.expandedDragDetection) var expandedDragDetection
    @Default(.copyOnDrag) var copyOnDrag
    @Default(.autoRemoveShelfItems) var autoRemoveShelfItems
    @StateObject private var quickShareService = QuickShareService.shared
    @ObservedObject private var fullDiskAccessPermission = FullDiskAccessPermissionStore.shared

    private var selectedProvider: QuickShareProvider? {
        quickShareService.availableProviders.first(where: { $0.id == quickShareProvider })
    }

    init() {
        Task { await QuickShareService.shared.discoverAvailableProviders() }
    }

    private func highlightID(_ title: String) -> String {
        SettingsTab.shelf.highlightID(for: title)
    }

    var body: some View {
        Form {
            if !fullDiskAccessPermission.isAuthorized {
                Section {
                    SettingsPermissionCallout(
                        title: String(localized: "Full Disk Access required"),
                        message: String(localized: "Grant Full Disk Access so the Shelf can index and move files outside the app sandbox."),
                        icon: "externaldrive.fill",
                        iconColor: .purple,
                        requestButtonTitle: String(localized: "Request Full Disk Access"),
                        openSettingsButtonTitle: String(localized: "Open Privacy & Security"),
                        requestAction: { fullDiskAccessPermission.requestAccessPrompt() },
                        openSettingsAction: { fullDiskAccessPermission.openSystemSettings() }
                    )
                } header: {
                    Text("Permissions")
                }
            }

            Section {
                Defaults.Toggle(String(localized: "Enable shelf"), key: .dynamicShelf)
                    .disabled(!fullDiskAccessPermission.isAuthorized)
                    .settingsHighlight(id: highlightID("Enable shelf"))

                Defaults.Toggle(String(localized: "Open shelf tab by default if items added"), key: .openShelfByDefault)
                    .settingsHighlight(id: highlightID("Open shelf tab by default if items added"))

                Defaults.Toggle(key: .expandedDragDetection) {
                    Text("Expanded drag detection area")
                }
                .settingsHighlight(id: highlightID("Expanded drag detection area"))

                Defaults.Toggle(key: .copyOnDrag) {
                    Text("Copy items on drag")
                }
                .settingsHighlight(id: highlightID("Copy items on drag"))

                Defaults.Toggle(key: .autoRemoveShelfItems) {
                    Text("Remove from shelf after dragging")
                }
                .settingsHighlight(id: highlightID("Remove from shelf after dragging"))
            } header: {
                HStack {
                    Text("General")
                }
            }

            Section {
                Picker("Quick Share Service", selection: $quickShareProvider) {
                    ForEach(quickShareService.availableProviders, id: \.id) { provider in
                        HStack {
                            Group {
                                if let imgData = provider.imageData, let nsImg = NSImage(data: imgData) {
                                    Image(nsImage: nsImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                            .frame(width: 16, height: 16)
                            .foregroundColor(.accentColor)
                            Text(provider.id)
                        }
                        .tag(provider.id)
                    }
                }
                .pickerStyle(.menu)
                .settingsHighlight(id: highlightID("Quick Share Service"))

                if let selectedProvider {
                    HStack {
                        Group {
                            if let imgData = selectedProvider.imageData, let nsImg = NSImage(data: imgData) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .frame(width: 16, height: 16)
                        .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Currently selected: \(selectedProvider.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Files dropped on the shelf will be shared via this service")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Quick Share")
                }
            } footer: {
                Text("Choose which service to use when sharing files from the shelf. Drag files onto the shelf or click the shelf button to pick files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shelf")
        .onAppear {
            fullDiskAccessPermission.refreshStatus()
        }
    }
}

struct LiveActivitiesSettings: View {
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @ObservedObject var recordingManager = ScreenRecordingManager.shared
    @ObservedObject var privacyManager = PrivacyIndicatorManager.shared
    @ObservedObject var doNotDisturbManager = DoNotDisturbManager.shared
    @ObservedObject private var fullDiskAccessPermission = FullDiskAccessPermissionStore.shared

    @Default(.enableScreenRecordingDetection) var enableScreenRecordingDetection
    @Default(.enableDoNotDisturbDetection) var enableDoNotDisturbDetection
    @Default(.focusIndicatorNonPersistent) var focusIndicatorNonPersistent
    @Default(.capsLockIndicatorTintMode) var capsLockTintMode

    private func highlightID(_ title: String) -> String {
        SettingsTab.liveActivities.highlightID(for: title)
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(String(localized: "Enable Screen Recording Detection"), key: .enableScreenRecordingDetection)
                    .settingsHighlight(id: highlightID("Enable Screen Recording Detection"))

                Defaults.Toggle(String(localized: "Show Recording Indicator"), key: .showRecordingIndicator)
                    .disabled(!enableScreenRecordingDetection)
                    .settingsHighlight(id: highlightID("Show Recording Indicator"))

                if recordingManager.isMonitoring {
                    HStack {
                        Text("Detection Status")
                        Spacer()
                        if recordingManager.isRecording {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("Recording Detected")
                                    .foregroundColor(.red)
                            }
                        } else {
                            Text("Active - No Recording")
                                .foregroundColor(.green)
                        }
                    }
                }
            } header: {
                Text("Screen Recording")
            } footer: {
                Text("Uses event-driven private API for real-time screen recording detection")
            }

            Section {
                if !fullDiskAccessPermission.isAuthorized {
                    SettingsPermissionCallout(
                        title: String(localized: "Custom Focus metadata"),
                        message: String(localized: "Full Disk Access unlocks custom Focus icons, colors, and labels. Standard Focus detection still works without it—grant access only if you need personalized indicators."),
                        icon: "externaldrive.fill",
                        iconColor: .purple,
                        requestButtonTitle: String(localized: "Request Full Disk Access"),
                        openSettingsButtonTitle: String(localized: "Open Privacy & Security"),
                        requestAction: { fullDiskAccessPermission.requestAccessPrompt() },
                        openSettingsAction: { fullDiskAccessPermission.openSystemSettings() }
                    )
                }

                Defaults.Toggle(String(localized: "Enable Focus Detection"), key: .enableDoNotDisturbDetection)
                    .settingsHighlight(id: highlightID("Enable Focus Detection"))

                Defaults.Toggle(String(localized: "Show Focus Indicator"), key: .showDoNotDisturbIndicator)
                    .disabled(!enableDoNotDisturbDetection)
                    .settingsHighlight(id: highlightID("Show Focus Indicator"))

                Defaults.Toggle(String(localized: "Show Focus Label"), key: .showDoNotDisturbLabel)
                    .disabled(!enableDoNotDisturbDetection || focusIndicatorNonPersistent)
                    .help(focusIndicatorNonPersistent ? "Labels are forced to compact on/off text while brief toast mode is enabled." : "Show the active Focus name inside the indicator.")
                    .settingsHighlight(id: highlightID("Show Focus Label"))

                Defaults.Toggle(String(localized: "Show Focus as brief toast"), key: .focusIndicatorNonPersistent)
                    .disabled(!enableDoNotDisturbDetection)
                    .settingsHighlight(id: highlightID("Show Focus as brief toast"))
                    .help("When enabled, Focus appears briefly (on/off) and then collapses instead of staying visible.")

                if doNotDisturbManager.isMonitoring {
                    HStack {
                        Text("Focus Status")
                        Spacer()
                        if doNotDisturbManager.isDoNotDisturbActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 8, height: 8)
                                Text(doNotDisturbManager.currentFocusModeName.isEmpty ? "Focus Enabled" : doNotDisturbManager.currentFocusModeName)
                                    .foregroundColor(.purple)
                            }
                        } else {
                            Text("Active - No Focus")
                                .foregroundColor(.green)
                        }
                    }
                } else {
                    HStack {
                        Text("Focus Status")
                        Spacer()
                        Text("Disabled")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Do Not Disturb")
            } footer: {
                Text("Listens for Focus session changes via distributed notifications")
            }

            Section {
                Defaults.Toggle(String(localized: "Show Caps Lock Indicator"), key: .enableCapsLockIndicator)
                    .settingsHighlight(id: highlightID("Show Caps Lock Indicator"))

                Defaults.Toggle(String(localized: "Show Caps Lock label"), key: .showCapsLockLabel)
                    .disabled(!Defaults[.enableCapsLockIndicator])
                    .settingsHighlight(id: highlightID("Show Caps Lock label"))

                Picker("Caps Lock color", selection: $capsLockTintMode) {
                    ForEach(CapsLockIndicatorTintMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!Defaults[.enableCapsLockIndicator])
                .settingsHighlight(id: highlightID("Caps Lock color"))
            } header: {
                Text("Caps Lock Indicator")
            } footer: {
                Text("Adds a notch HUD when Caps Lock is enabled, with optional label and tint controls.")
            }

            Section {
                Defaults.Toggle(String(localized: "Enable Camera Detection"), key: .enableCameraDetection)
                    .settingsHighlight(id: highlightID("Enable Camera Detection"))
                Defaults.Toggle(String(localized: "Enable Microphone Detection"), key: .enableMicrophoneDetection)
                    .settingsHighlight(id: highlightID("Enable Microphone Detection"))

                if privacyManager.isMonitoring {
                    HStack {
                        Text("Camera Status")
                        Spacer()
                        if privacyManager.cameraActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Camera Active")
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text("Inactive")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Microphone Status")
                        Spacer()
                        if privacyManager.microphoneActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.yellow)
                                    .frame(width: 8, height: 8)
                                Text("Microphone Active")
                                    .foregroundColor(.yellow)
                            }
                        } else {
                            Text("Inactive")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Privacy Indicators")
            } footer: {
                Text("Shows green camera icon and yellow microphone icon when in use. Uses event-driven CoreAudio and CoreMediaIO APIs.")
            }

            Section {
                Toggle(
                    "Enable music live activity",
                    isOn: $coordinator.musicLiveActivityEnabled.animation()
                )
                .settingsHighlight(id: highlightID("Enable music live activity"))
            } header: {
                Text("Media Live Activity")
            } footer: {
                Text("Use the Media tab to configure sneak peek, lyrics, and floating media controls.")
            }

            Section {
                Defaults.Toggle(String(localized: "Enable reminder live activity"), key: .enableReminderLiveActivity)
                    .settingsHighlight(id: highlightID("Enable reminder live activity"))
            } header: {
                Text("Reminder Live Activity")
            } footer: {
                Text("Configure countdown style and lock screen widgets in the Calendar tab.")
            }
        }
        .navigationTitle("Live Activities")
        .onAppear {
            fullDiskAccessPermission.refreshStatus()
        }
    }
}

struct Appearance: View {
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @Default(.mirrorShape) var mirrorShape
    @Default(.sliderColor) var sliderColor
    @Default(.useMusicVisualizer) var useMusicVisualizer
    @Default(.customVisualizers) var customVisualizers
    @Default(.selectedVisualizer) var selectedVisualizer
    @Default(.customAppIcons) private var customAppIcons
    @Default(.selectedAppIconID) private var selectedAppIconID
    @Default(.openNotchWidth) var openNotchWidth
    @Default(.enableMinimalisticUI) var enableMinimalisticUI
    @Default(.lockScreenGlassCustomizationMode) private var lockScreenGlassCustomizationMode
    @Default(.lockScreenGlassStyle) private var lockScreenGlassStyle
    @Default(.lockScreenMusicLiquidGlassVariant) private var lockScreenMusicLiquidGlassVariant
    @Default(.lockScreenTimerLiquidGlassVariant) private var lockScreenTimerLiquidGlassVariant
    @Default(.lockScreenTimerGlassStyle) private var lockScreenTimerGlassStyle
    @Default(.lockScreenTimerGlassCustomizationMode) private var lockScreenTimerGlassCustomizationMode
    @Default(.lockScreenTimerWidgetUsesBlur) private var timerGlassModeIsGlass
    @Default(.enableLockScreenMediaWidget) private var enableLockScreenMediaWidget
    @Default(.enableLockScreenTimerWidget) private var enableLockScreenTimerWidget
    @State private var selectedListVisualizer: CustomVisualizer? = nil

    @State private var isIconImporterPresented = false
    @State private var isIconDropTarget = false
    @State private var iconImportError: String?

    @State private var isPresented: Bool = false
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var speed: CGFloat = 1.0

    private let notchWidthRange: ClosedRange<Double> = 640...900
    private let defaultOpenNotchWidth: CGFloat = 640

    private func highlightID(_ title: String) -> String {
        SettingsTab.appearance.highlightID(for: title)
    }

    private var liquidVariantRange: ClosedRange<Double> {
        Double(LiquidGlassVariant.supportedRange.lowerBound)...Double(LiquidGlassVariant.supportedRange.upperBound)
    }

    private var appearanceMusicVariantBinding: Binding<Double> {
        Binding(
            get: { Double(lockScreenMusicLiquidGlassVariant.rawValue) },
            set: { newValue in
                let raw = Int(newValue.rounded())
                lockScreenMusicLiquidGlassVariant = LiquidGlassVariant.clamped(raw)
            }
        )
    }

    private var appearanceTimerVariantBinding: Binding<Double> {
        Binding(
            get: { Double(lockScreenTimerLiquidGlassVariant.rawValue) },
            set: { newValue in
                let raw = Int(newValue.rounded())
                lockScreenTimerLiquidGlassVariant = LiquidGlassVariant.clamped(raw)
            }
        )
    }

    private var timerSurfaceBinding: Binding<LockScreenTimerSurfaceMode> {
        Binding(
            get: { timerGlassModeIsGlass ? .glass : .classic },
            set: { mode in timerGlassModeIsGlass = (mode == .glass) }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Always show tabs", isOn: $coordinator.alwaysShowTabs)
                Defaults.Toggle(String(localized:"Settings icon in notch"), key: .settingsIconInNotch)
                    .settingsHighlight(id: highlightID("Settings icon in notch"))
                Defaults.Toggle(String(localized:"Enable window shadow"), key: .enableShadow)
                    .settingsHighlight(id: highlightID("Enable window shadow"))
                Defaults.Toggle(String(localized:"Corner radius scaling"), key: .cornerRadiusScaling)
                    .settingsHighlight(id: highlightID("Corner radius scaling"))
                Defaults.Toggle(String(localized:"Use simpler close animation"), key: .useModernCloseAnimation)
                    .settingsHighlight(id: highlightID("Use simpler close animation"))
            } header: {
                Text("General")
            }

            notchWidthControls()

            Section {
                if #available(macOS 26.0, *) {
                    Picker("Material", selection: $lockScreenGlassStyle) {
                        ForEach(LockScreenGlassStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .settingsHighlight(id: highlightID("Lock screen material"))
                } else {
                    Picker("Material", selection: $lockScreenGlassStyle) {
                        ForEach(LockScreenGlassStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .disabled(true)
                    .settingsHighlight(id: highlightID("Lock screen material"))
                    Text("Liquid Glass requires macOS 26 or later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if lockScreenGlassStyle == .liquid {
                    Picker(String(localized: "Lock screen glass mode"), selection: $lockScreenGlassCustomizationMode) {
                        ForEach(LockScreenGlassCustomizationMode.allCases) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .settingsHighlight(id: highlightID("Lock screen glass mode"))

                    if lockScreenGlassCustomizationMode == .customLiquid {
                        Text("Pick per-widget liquid-glass variants below. Changes mirror the Lock Screen tab.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Music panel variant")
                                Spacer()
                                Text("v\(lockScreenMusicLiquidGlassVariant.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: appearanceMusicVariantBinding, in: liquidVariantRange, step: 1)
                        }
                        .settingsHighlight(id: highlightID("Music panel variant (appearance)"))
                        .disabled(!enableLockScreenMediaWidget)
                        .opacity(enableLockScreenMediaWidget ? 1 : 0.4)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Timer widget variant")
                                Spacer()
                                Text("v\(lockScreenTimerLiquidGlassVariant.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: appearanceTimerVariantBinding, in: liquidVariantRange, step: 1)
                        }
                        .settingsHighlight(id: highlightID("Timer widget variant (appearance)"))
                        .disabled(!enableLockScreenTimerWidget)
                        .opacity(enableLockScreenTimerWidget ? 1 : 0.4)
                    }
                } else {
                    Text("Custom Liquid settings require the Liquid Glass material.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Lock Screen Glass")
            } footer: {
                Text("Configure lock screen materials from the Appearance tab. Custom Liquid unlocks variant sliders for both widgets whenever Liquid Glass is selected.")
            }

            Section {
                Defaults.Toggle(String(localized:"Enable colored spectrograms"), key: .coloredSpectrogram)
                    .settingsHighlight(id: highlightID("Enable colored spectrograms"))
                Defaults.Toggle(String(localized:"Player tinting"), key: .playerColorTinting)
                Defaults.Toggle(String(localized:"Enable blur effect behind album art"), key: .lightingEffect)
                    .settingsHighlight(id: highlightID("Enable blur effect behind album art"))
                Picker(String(localized: "Slider color"), selection: $sliderColor) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { option in
                        
                        Text(option.localizedName).tag(option)
                    }
                }
                .settingsHighlight(id: highlightID("Slider color"))
            } header: {
                Text("Media")
            }

            Section {
                Toggle(
                    "Use music visualizer spectrogram",
                    isOn: $useMusicVisualizer.animation()
                )
                .disabled(true)
                if !useMusicVisualizer {
                    if customVisualizers.count > 0 {
                        Picker(
                            "Selected animation",
                            selection: $selectedVisualizer
                        ) {
                            ForEach(
                                customVisualizers,
                                id: \.self
                            ) { visualizer in
                                Text(visualizer.name)
                                    .tag(visualizer)
                            }
                        }
                    } else {
                        HStack {
                            Text("Selected animation")
                            Spacer()
                            Text("No custom animation available")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Custom music live activity animation")
                    customBadge(text: String(localized: "Coming soon"))
                }
            }

            Section {
                List {
                    ForEach(customVisualizers, id: \.self) { visualizer in
                        HStack {
                            LottieView(state: LUStateData(type: .loadedFrom(visualizer.url), speed: visualizer.speed, loopMode: .loop))
                                .frame(width: 30, height: 30, alignment: .center)
                            Text(visualizer.name)
                            Spacer(minLength: 0)
                            if selectedVisualizer == visualizer {
                                Text("selected")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 8)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 2)
                        .background(
                            selectedListVisualizer != nil ? selectedListVisualizer == visualizer ? Color.accentColor : Color.clear : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedListVisualizer == visualizer {
                                selectedListVisualizer = nil
                                return
                            }
                            selectedListVisualizer = visualizer
                        }
                    }
                }
                .safeAreaPadding(
                    EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
                )
                .frame(minHeight: 120)
                .actionBar {
                    HStack(spacing: 5) {
                        Button {
                            name = ""
                            url = ""
                            speed = 1.0
                            isPresented.toggle()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                        Divider()
                        Button {
                            if selectedListVisualizer != nil {
                                let visualizer = selectedListVisualizer!
                                selectedListVisualizer = nil
                                customVisualizers.remove(at: customVisualizers.firstIndex(of: visualizer)!)
                                if visualizer == selectedVisualizer && customVisualizers.count > 0 {
                                    selectedVisualizer = customVisualizers[0]
                                }
                            }
                        } label: {
                            Image(systemName: "minus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .controlSize(.small)
                .buttonStyle(PlainButtonStyle())
                .overlay {
                    if customVisualizers.isEmpty {
                        Text("No custom visualizer")
                            .foregroundStyle(Color(.secondaryLabelColor))
                            .padding(.bottom, 22)
                    }
                }
                .sheet(isPresented: $isPresented) {
                    VStack(alignment: .leading) {
                        Text("Add new visualizer")
                            .font(.largeTitle.bold())
                            .padding(.vertical)
                        TextField("Name", text: $name)
                        TextField("Lottie JSON URL", text: $url)
                        HStack {
                            Text("Speed")
                            Spacer(minLength: 80)
                            Text("\(speed, specifier: "%.1f")s")
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                            Slider(value: $speed, in: 0...2, step: 0.1)
                        }
                        .padding(.vertical)
                        HStack {
                            Button {
                                isPresented.toggle()
                            } label: {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            Button {
                                let visualizer: CustomVisualizer = .init(
                                    UUID: UUID(),
                                    name: name,
                                    url: URL(string: url)!,
                                    speed: speed
                                )

                                if !customVisualizers.contains(visualizer) {
                                    customVisualizers.append(visualizer)
                                }

                                isPresented.toggle()
                            } label: {
                                Text("Add")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .controlSize(.extraLarge)
                    .padding()
                }
            } header: {
                HStack(spacing: 0) {
                    Text("Custom vizualizers (Lottie)")
                    if !Defaults[.customVisualizers].isEmpty {
                        Text(" – \(Defaults[.customVisualizers].count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Defaults.Toggle(String(localized:"Enable Dynamic mirror"), key: .showMirror)
                    .disabled(!checkVideoInput())
                    .settingsHighlight(id: highlightID("Enable Dynamic mirror"))
                Picker("Mirror shape", selection: $mirrorShape) {
                    Text("Circle")
                        .tag(MirrorShapeEnum.circle)
                    Text("Square")
                        .tag(MirrorShapeEnum.rectangle)
                }
                .settingsHighlight(id: highlightID("Mirror shape"))
                Defaults.Toggle(String(localized:"Show cool face animation while inactivity"), key: .showNotHumanFace)
                    .settingsHighlight(id: highlightID("Show cool face animation while inactivity"))
            } header: {
                HStack {
                    Text("Additional features")
                }
            }
            
            // MARK: - Custom Idle Animations Section
            IdleAnimationsSettingsSection()

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        appIconCard(
                            title: String(localized:"Default"),
                            image: defaultAppIconImage(),
                            isSelected: selectedAppIconID == nil
                        ) {
                            selectedAppIconID = nil
                            applySelectedAppIcon()
                        }

                        ForEach(customAppIcons) { icon in
                            appIconCard(
                                title: icon.name,
                                image: customIconImage(for: icon),
                                isSelected: selectedAppIconID == icon.id.uuidString
                            ) {
                                selectedAppIconID = icon.id.uuidString
                                applySelectedAppIcon()
                            }
                            .contextMenu {
                                Button("Remove") {
                                    removeCustomIcon(icon)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(isIconDropTarget ? 0.18 : 0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(isIconDropTarget ? 0.8 : 0), lineWidth: 2)
                    )
                    .onDrop(of: [UTType.fileURL], isTargeted: $isIconDropTarget) { providers in
                        handleIconDrop(providers)
                    }

                    HStack(spacing: 8) {
                        Button("Add icon") {
                            iconImportError = nil
                            isIconImporterPresented = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Remove selected") {
                            if let id = selectedAppIconID,
                               let icon = customAppIcons.first(where: { $0.id.uuidString == id }) {
                                removeCustomIcon(icon)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedAppIconID == nil)
                    }

                    if let iconImportError {
                        Text(iconImportError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Drop a PNG, JPEG, TIFF, or ICNS file to add it to your icon library.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .settingsHighlight(id: highlightID("App icon"))
            } header: {
                HStack {
                    Text("App icon")
                }
            }
        }
        .onAppear(perform: enforceLockScreenGlassConsistency)
        .onChange(of: lockScreenGlassStyle) { _, _ in enforceLockScreenGlassConsistency() }
        .onChange(of: lockScreenGlassCustomizationMode) { _, _ in enforceLockScreenGlassConsistency() }
        .fileImporter(
            isPresented: $isIconImporterPresented,
            allowedContentTypes: [.png, .jpeg, .tiff, .icns, .image]
        ) { result in
            switch result {
            case .success(let url):
                importCustomIcon(from: url)
            case .failure:
                iconImportError = "Icon import was canceled or failed."
            }
        }
        .navigationTitle("Appearance")
    }

    private func defaultAppIconImage() -> NSImage? {
        let fallbackName = Bundle.main.iconFileName ?? "AppIcon"
        return NSImage(named: fallbackName)
    }

    private func customIconImage(for icon: CustomAppIcon) -> NSImage? {
        NSImage(contentsOf: icon.fileURL)
    }

    private func appIconCard(title: String, image: NSImage?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Group {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                )

                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(isSelected ? Color.accentColor : .clear)
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func handleIconDrop(_ providers: [NSItemProvider]) -> Bool {
        let matching = providers.first { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard let provider = matching else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let directURL = item as? URL {
                url = directURL
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }
            guard let url else { return }
            Task { @MainActor in importCustomIcon(from: url) }
        }
        return true
    }

    private func importCustomIcon(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            iconImportError = "That file could not be loaded as an image."
            return
        }
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
        let id = UUID()
        let fileName = "custom-icon-\(id.uuidString).\(ext)"
        let destination = CustomAppIcon.iconDirectory.appendingPathComponent(fileName)

        do {
            let data = try Data(contentsOf: url)
            try data.write(to: destination, options: [.atomic])
        } catch {
            iconImportError = "Unable to save the icon file."
            return
        }

        let newIcon = CustomAppIcon(id: id, name: name.isEmpty ? "Custom Icon" : name, fileName: fileName)
        if !customAppIcons.contains(newIcon) {
            customAppIcons.append(newIcon)
        }
        selectedAppIconID = newIcon.id.uuidString
        NSApp.applicationIconImage = image
        iconImportError = nil
    }

    private func removeCustomIcon(_ icon: CustomAppIcon) {
        if let index = customAppIcons.firstIndex(of: icon) {
            customAppIcons.remove(at: index)
        }
        if FileManager.default.fileExists(atPath: icon.fileURL.path) {
            try? FileManager.default.removeItem(at: icon.fileURL)
        }
        if selectedAppIconID == icon.id.uuidString {
            selectedAppIconID = nil
            applySelectedAppIcon()
        }
    }

    func checkVideoInput() -> Bool {
        if let _ = AVCaptureDevice.default(for: .video) {
            return true
        }

        return false
    }

    @ViewBuilder
    private func notchWidthControls() -> some View {
        Section {
            let widthBinding = Binding<Double>(
                get: { Double(openNotchWidth) },
                set: { newValue in
                    let clamped = min(max(newValue, notchWidthRange.lowerBound), notchWidthRange.upperBound)
                    let value = CGFloat(clamped)
                    if openNotchWidth != value {
                        openNotchWidth = value
                    }
                }
            )

            VStack(alignment: .leading, spacing: 10) {
                Slider(
                    value: widthBinding,
                    in: notchWidthRange,
                    step: 10
                ) {
                    HStack {
                        Text("Expanded notch width")
                        Spacer()
                        Text("\(Int(openNotchWidth)) px")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(enableMinimalisticUI)
                .settingsHighlight(id: highlightID("Expanded notch width"))

                HStack {
                    Spacer()
                    Button("Reset Width") {
                        openNotchWidth = defaultOpenNotchWidth
                    }
                    .disabled(abs(openNotchWidth - defaultOpenNotchWidth) < 0.5)
                    .buttonStyle(.bordered)
                }

                let description = enableMinimalisticUI
                ? String(localized:"Width adjustments apply only to the standard notch layout. Disable Minimalistic UI to edit this value.")
                : String(localized:"Extend the notch span so the clipboard, colour picker, and other trailing icons remain visible on scaled displays (e.g. More Space).")

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("Notch Width")
                customBadge(text: "Beta")
            }
        }
    }

    private func enforceLockScreenGlassConsistency() {
        if lockScreenGlassStyle == .frosted && lockScreenGlassCustomizationMode != .standard {
            lockScreenGlassCustomizationMode = .standard
        }
        if lockScreenGlassCustomizationMode == .customLiquid && lockScreenGlassStyle != .liquid {
            lockScreenGlassStyle = .liquid
        }
    }
}

struct LockScreenSettings: View {
    @Default(.lockScreenGlassStyle) private var lockScreenGlassStyle
    @Default(.lockScreenGlassCustomizationMode) private var lockScreenGlassCustomizationMode
    @Default(.lockScreenMusicLiquidGlassVariant) private var lockScreenMusicLiquidGlassVariant
    @Default(.lockScreenTimerLiquidGlassVariant) private var lockScreenTimerLiquidGlassVariant
    @Default(.lockScreenTimerGlassStyle) private var lockScreenTimerGlassStyle
    @Default(.lockScreenTimerGlassCustomizationMode) private var lockScreenTimerGlassCustomizationMode
    @Default(.lockScreenTimerWidgetUsesBlur) private var timerGlassModeIsGlass
    @Default(.enableLockScreenMediaWidget) private var enableLockScreenMediaWidget
    @Default(.enableLockScreenTimerWidget) private var enableLockScreenTimerWidget
    @Default(.enableLockScreenWeatherWidget) private var enableLockScreenWeatherWidget
    @Default(.enableLockScreenFocusWidget) private var enableLockScreenFocusWidget
    @Default(.lockScreenWeatherWidgetStyle) private var lockScreenWeatherWidgetStyle
    @Default(.lockScreenWeatherProviderSource) private var lockScreenWeatherProviderSource
    @Default(.lockScreenWeatherTemperatureUnit) private var lockScreenWeatherTemperatureUnit
    @Default(.lockScreenBatteryShowsCharging) private var lockScreenWeatherShowsCharging
    @Default(.lockScreenBatteryShowsBatteryGauge) private var lockScreenWeatherShowsBatteryGauge
    @Default(.lockScreenWeatherShowsAQI) private var lockScreenWeatherShowsAQI
    @Default(.lockScreenWeatherShowsSunrise) private var lockScreenWeatherShowsSunrise
    @Default(.lockScreenWeatherAQIScale) private var lockScreenWeatherAQIScale
    @Default(.showStandardMediaControls) private var showStandardMediaControls

    private func highlightID(_ title: String) -> String {
        SettingsTab.lockScreen.highlightID(for: title)
    }

    private var liquidVariantRange: ClosedRange<Double> {
        Double(LiquidGlassVariant.supportedRange.lowerBound)...Double(LiquidGlassVariant.supportedRange.upperBound)
    }

    private var musicVariantBinding: Binding<Double> {
        Binding(
            get: { Double(lockScreenMusicLiquidGlassVariant.rawValue) },
            set: { newValue in
                let raw = Int(newValue.rounded())
                lockScreenMusicLiquidGlassVariant = LiquidGlassVariant.clamped(raw)
            }
        )
    }

    private var timerVariantBinding: Binding<Double> {
        Binding(
            get: { Double(lockScreenTimerLiquidGlassVariant.rawValue) },
            set: { newValue in
                let raw = Int(newValue.rounded())
                lockScreenTimerLiquidGlassVariant = LiquidGlassVariant.clamped(raw)
            }
        )
    }

    private var timerSurfaceBinding: Binding<LockScreenTimerSurfaceMode> {
        Binding(
            get: { timerGlassModeIsGlass ? .glass : .classic },
            set: { mode in timerGlassModeIsGlass = (mode == .glass) }
        )
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(String(localized: "Enable lock screen live activity"), key: .enableLockScreenLiveActivity)
                    .settingsHighlight(id: highlightID("Enable lock screen live activity"))
                Defaults.Toggle(String(localized: "Play lock/unlock sounds"), key: .enableLockSounds)
                    .settingsHighlight(id: highlightID("Play lock/unlock sounds"))
            } header: {
                Text("Live Activity & Feedback")
            } footer: {
                Text("Controls whether Dynamic Island mirrors lock/unlock events with its own live activity and audible chimes.")
            }

            Section {
                if #available(macOS 26.0, *) {
                    Picker("Material", selection: $lockScreenGlassStyle) {
                        ForEach(LockScreenGlassStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .settingsHighlight(id: highlightID("Material"))
                } else {
                    Picker("Material", selection: $lockScreenGlassStyle) {
                        ForEach(LockScreenGlassStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .disabled(true)
                    .settingsHighlight(id: highlightID("Material"))
                    Text("Liquid Glass requires macOS 26 or later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if lockScreenGlassStyle == .liquid {
                    Picker(String(localized: "Glass mode"), selection: $lockScreenGlassCustomizationMode) {
                        ForEach(LockScreenGlassCustomizationMode.allCases) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .settingsHighlight(id: highlightID("Glass mode"))

                    if lockScreenGlassCustomizationMode == .customLiquid {
                        Text("Use the sliders below to pick unique Apple liquid-glass variants for each widget.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Custom Liquid settings require the Liquid Glass material.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Lock Screen Glass")
            } footer: {
                Text("Choose the global material mode for lock screen widgets. Custom Liquid unlocks per-widget variant sliders while Standard sticks to the classic frosted/liquid options.")
            }

            Section {
                Defaults.Toggle(String(localized: "Show lock screen media panel"), key: .enableLockScreenMediaWidget)
                    .settingsHighlight(id: highlightID("Show lock screen media panel"))
                Defaults.Toggle(String(localized: "Show media app icon"), key: .lockScreenShowAppIcon)
                    .disabled(!enableLockScreenMediaWidget)
                    .settingsHighlight(id: highlightID("Show media app icon"))
                Defaults.Toggle(String(localized: "Show panel border"), key: .lockScreenPanelShowsBorder)
                    .disabled(!enableLockScreenMediaWidget)
                    .settingsHighlight(id: highlightID("Show panel border"))
                if lockScreenGlassCustomizationMode == .customLiquid {
                    variantSlider(
                        title: "Music panel variant",
                        value: musicVariantBinding,
                        currentValue: lockScreenMusicLiquidGlassVariant.rawValue,
                        isEnabled: enableLockScreenMediaWidget,
                        highlight: highlightID("Music panel variant")
                    )
                } else if lockScreenGlassStyle == .frosted {
                    Defaults.Toggle("Enable media panel blur", key: .lockScreenPanelUsesBlur)
                        .disabled(!enableLockScreenMediaWidget)
                        .settingsHighlight(id: highlightID("Enable media panel blur"))
                } else {
                    blurSettingUnavailableRow
                        .opacity(enableLockScreenMediaWidget ? 1 : 0.5)
                        .settingsHighlight(id: highlightID("Enable media panel blur"))
                }

                if !showStandardMediaControls {
                    Text("Enable Dynamic Island media controls to manage the lock screen panel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                Text("Media Panel")
            } footer: {
                Text("Enable and style the media controls that appear above the system clock when the screen is locked.")
            }
            .disabled(!showStandardMediaControls)
            .opacity(showStandardMediaControls ? 1 : 0.5)

            Section {
                Defaults.Toggle(String(localized: "Show lock screen timer"), key: .enableLockScreenTimerWidget)
                    .settingsHighlight(id: highlightID("Show lock screen timer"))
                Picker("Timer surface", selection: timerSurfaceBinding) {
                    ForEach(LockScreenTimerSurfaceMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!enableLockScreenTimerWidget)
                .opacity(enableLockScreenTimerWidget ? 1 : 0.5)
                .settingsHighlight(id: highlightID("Timer surface"))

                if timerGlassModeIsGlass {
                    Picker("Timer glass material", selection: $lockScreenTimerGlassStyle) {
                        ForEach(LockScreenGlassStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .disabled(!enableLockScreenTimerWidget)
                    .opacity(enableLockScreenTimerWidget ? 1 : 0.5)
                    .settingsHighlight(id: highlightID("Timer glass material"))

                    if lockScreenTimerGlassStyle == .liquid {
                        Picker(String(localized: "Timer liquid mode"), selection: $lockScreenTimerGlassCustomizationMode) {
                            ForEach(LockScreenGlassCustomizationMode.allCases) { mode in
                                Text(mode.localizedName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(!enableLockScreenTimerWidget)
                        .opacity(enableLockScreenTimerWidget ? 1 : 0.5)
                        .settingsHighlight(id: highlightID("Timer liquid mode"))

                        if lockScreenTimerGlassCustomizationMode == .customLiquid {
                            variantSlider(
                                title: "Timer widget variant",
                                value: timerVariantBinding,
                                currentValue: lockScreenTimerLiquidGlassVariant.rawValue,
                                isEnabled: enableLockScreenTimerWidget,
                                highlight: highlightID("Timer widget variant")
                            )
                        }
                    } else {
                        Text("Uses the frosted blur treatment while glass mode is enabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("Classic mode keeps the original translucent black background.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(enableLockScreenTimerWidget ? 1 : 0.5)
                }
            } header: {
                Text("Timer Widget")
            } footer: {
                Text("Controls the optional timer widget that floats above the media panel, including its classic, frosted, or liquid glass surface independent of the global material setting.")
            }

            Section {
                Defaults.Toggle(String(localized: "Show lock screen weather"), key: .enableLockScreenWeatherWidget)
                    .settingsHighlight(id: highlightID("Show lock screen weather"))

                if enableLockScreenWeatherWidget {
                    Picker("Layout", selection: $lockScreenWeatherWidgetStyle) {
                        ForEach(LockScreenWeatherWidgetStyle.allCases) { style in
                            Text(style.localizedName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .settingsHighlight(id: highlightID("Layout"))

                    Picker("Weather data provider", selection: $lockScreenWeatherProviderSource) {
                        ForEach(LockScreenWeatherProviderSource.allCases) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .settingsHighlight(id: highlightID("Weather data provider"))

                    Picker("Temperature unit", selection: $lockScreenWeatherTemperatureUnit) {
                        ForEach(LockScreenWeatherTemperatureUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .settingsHighlight(id: highlightID("Temperature unit"))

                    Defaults.Toggle(String(localized: "Show location label"), key: .lockScreenWeatherShowsLocation)
                        .disabled(lockScreenWeatherWidgetStyle == .circular)
                        .settingsHighlight(id: highlightID("Show location label"))

                    Defaults.Toggle(String(localized: "Show sunrise time"), key: .lockScreenWeatherShowsSunrise)
                        .disabled(lockScreenWeatherWidgetStyle != .inline)
                        .settingsHighlight(id: highlightID("Show sunrise time"))

                    Defaults.Toggle(String(localized: "Show AQI widget"), key: .lockScreenWeatherShowsAQI)
                        .disabled(!lockScreenWeatherProviderSource.supportsAirQuality)
                        .settingsHighlight(id: highlightID("Show AQI widget"))

                    if lockScreenWeatherShowsAQI && lockScreenWeatherProviderSource.supportsAirQuality {
                        Picker("Air quality scale", selection: $lockScreenWeatherAQIScale) {
                            ForEach(LockScreenWeatherAirQualityScale.allCases) { scale in
                                Text(scale.displayName).tag(scale)
                            }
                        }
                        .pickerStyle(.segmented)
                        .settingsHighlight(id: highlightID("Air quality scale"))
                    }

                    if !lockScreenWeatherProviderSource.supportsAirQuality {
                        Text("Air quality requires the Open Meteo provider.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Defaults.Toggle(String(localized: "Use colored gauges"), key: .lockScreenWeatherUsesGaugeTint)
                        .settingsHighlight(id: highlightID("Use colored gauges"))
                }
            } header: {
                Text("Weather Widget")
            } footer: {
                Text("Enable the weather capsule and configure its layout, provider, units, and optional battery/AQI indicators.")
            }
            
            if BatteryActivityManager.shared.hasBattery() {
                Section {
                    Defaults.Toggle(String(localized: "Show battery indicator"), key: .lockScreenBatteryShowsBatteryGauge)
                        .settingsHighlight(id: highlightID("Show battery indicator"))
                    
                    if lockScreenWeatherShowsBatteryGauge {
                        Defaults.Toggle(String(localized: "Use MacBook icon when on battery"), key: .lockScreenBatteryUsesLaptopSymbol)
                            .settingsHighlight(id: highlightID("Use MacBook icon when on battery"))
                        
                        Defaults.Toggle(String(localized: "Show charging status"), key: .lockScreenBatteryShowsCharging)
                            .settingsHighlight(id: highlightID("Show charging status"))
                        
                        if lockScreenWeatherShowsCharging {
                            Defaults.Toggle(String(localized: "Show charging percentage"), key: .lockScreenBatteryShowsChargingPercentage)
                                .settingsHighlight(id: highlightID("Show charging percentage"))
                        }
                        
                        Defaults.Toggle(String(localized: "Show Bluetooth battery"), key: .lockScreenBatteryShowsBluetooth)
                            .settingsHighlight(id: highlightID("Show Bluetooth battery"))
                    }
                } header: {
                    Text("Battery Widget")
                } footer: {
                    Text("Enable the battery capsule and configure its layout.")
                }
            }

            Section {
                Defaults.Toggle(String(localized: "Show focus widget"), key: .enableLockScreenFocusWidget)
                    .settingsHighlight(id: highlightID("Show focus widget"))
            } header: {
                Text("Focus Widget")
            } footer: {
                Text("Displays the current Focus state above the weather capsule whenever Focus detection is enabled.")
            }

            LockScreenPositioningControls()

            Section {
                Button("Copy Latest Crash Report") {
                    copyLatestCrashReport()
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("Collect the latest crash report to share with the developer when reporting lock screen or overlay issues.")
            }
        }
        .onAppear(perform: enforceLockScreenGlassConsistency)
        .onChange(of: lockScreenGlassStyle) { _, _ in enforceLockScreenGlassConsistency() }
        .onChange(of: lockScreenGlassCustomizationMode) { _, _ in enforceLockScreenGlassConsistency() }
        .navigationTitle("Lock Screen")
    }
}

extension LockScreenSettings {
    private func enforceLockScreenGlassConsistency() {
        if lockScreenGlassStyle == .frosted && lockScreenGlassCustomizationMode != .standard {
            lockScreenGlassCustomizationMode = .standard
        }
        if lockScreenGlassCustomizationMode == .customLiquid && lockScreenGlassStyle != .liquid {
            lockScreenGlassStyle = .liquid
        }
    }

    private var blurSettingUnavailableRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Enable media panel blur")
                .foregroundStyle(.secondary)
            Text("Only available when Material is set to Frosted Glass.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func variantSlider(
        title: String,
        value: Binding<Double>,
        currentValue: Int,
        isEnabled: Bool,
        highlight: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("v\(currentValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: liquidVariantRange, step: 1)
        }
        .settingsHighlight(id: highlight)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

private struct LockScreenPositioningControls: View {
    @Default(.lockScreenWeatherVerticalOffset) private var weatherOffset
    @Default(.lockScreenMusicVerticalOffset) private var musicOffset
    @Default(.lockScreenTimerVerticalOffset) private var timerOffset
    @Default(.lockScreenMusicPanelWidth) private var musicWidth
    @Default(.lockScreenTimerWidgetWidth) private var timerWidth
    private let offsetRange: ClosedRange<Double> = -160...160
    private let musicWidthRange: ClosedRange<Double> = 320...Double(LockScreenMusicPanel.defaultCollapsedWidth)
    private let timerWidthRange: ClosedRange<Double> = 320...LockScreenTimerWidget.defaultWidth

    var body: some View {
        Section {
            let weatherBinding = Binding<Double>(
                get: { weatherOffset },
                set: { newValue in
                    let clampedValue = clampOffset(newValue)
                    if weatherOffset != clampedValue {
                        weatherOffset = clampedValue
                    }
                    propagateWeatherOffsetChange(animated: false)
                }
            )

            let timerBinding = Binding<Double>(
                get: { timerOffset },
                set: { newValue in
                    let clampedValue = clampOffset(newValue)
                    if timerOffset != clampedValue {
                        timerOffset = clampedValue
                    }
                    propagateTimerOffsetChange(animated: false)
                }
            )

            let musicBinding = Binding<Double>(
                get: { musicOffset },
                set: { newValue in
                    let clampedValue = clampOffset(newValue)
                    if musicOffset != clampedValue {
                        musicOffset = clampedValue
                    }
                    propagateMusicOffsetChange(animated: false)
                }
            )

            let musicWidthBinding = Binding<Double>(
                get: { musicWidth },
                set: { newValue in
                    let clampedValue = clamp(newValue, within: musicWidthRange)
                    if musicWidth != clampedValue {
                        musicWidth = clampedValue
                        propagateMusicWidthChange(animated: false)
                    }
                }
            )

            let timerWidthBinding = Binding<Double>(
                get: { timerWidth },
                set: { newValue in
                    let clampedValue = clamp(newValue, within: timerWidthRange)
                    if timerWidth != clampedValue {
                        timerWidth = clampedValue
                        propagateTimerWidthChange(animated: false)
                    }
                }
            )

            LockScreenPositioningPreview(
                weatherOffset: weatherBinding,
                timerOffset: timerBinding,
                musicOffset: musicBinding,
                musicWidth: musicWidthBinding,
                timerWidth: timerWidthBinding
            )
                .frame(height: 260)
                .padding(.vertical, 8)

            HStack(alignment: .top, spacing: 24) {
                offsetColumn(
                    title: String(localized: "Weather"),
                    value: weatherOffset,
                    resetTitle: String(localized: "Reset Weather"),
                    resetAction: resetWeatherOffset
                )

                Divider()
                    .frame(height: 64)

                offsetColumn(
                    title: String(localized: "Timer"),
                    value: timerOffset,
                    resetTitle: String(localized: "Reset Timer"),
                    resetAction: resetTimerOffset
                )

                Divider()
                    .frame(height: 64)

                offsetColumn(
                    title: String(localized: "Music"),
                    value: musicOffset,
                    resetTitle: String(localized: "Reset Music"),
                    resetAction: resetMusicOffset
                )

                Spacer()
            }

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 16) {
                widthSlider(
                    title: String(localized: "Media Panel Width"),
                    value: musicWidthBinding,
                    range: musicWidthRange,
                    resetTitle: String(localized: "Reset Media Width"),
                    resetAction: resetMusicWidth,
                    helpText: String(localized: "Shrinks the lock screen media panel while keeping the expanded view full width.")
                )

                widthSlider(
                    title: String(localized: "Timer Widget Width"),
                    value: timerWidthBinding,
                    range: timerWidthRange,
                    resetTitle: String(localized: "Reset Timer Width"),
                    resetAction: resetTimerWidth,
                    helpText: String(localized: "Adjusts the lock screen timer widget width without affecting button sizing.")
                )
            }
        } header: {
            Text("Lock Screen Positioning")
        } footer: {
            Text("Drag the previews to adjust vertical placement. Positive values lift the panel; negative values lower it. Use the width sliders below to narrow the media and timer widgets without exceeding their default size. Changes apply instantly while the widgets are visible.")
                .textCase(nil)
        }
    }

    private func clampOffset(_ value: Double) -> Double {
        min(max(value, offsetRange.lowerBound), offsetRange.upperBound)
    }

    private func clamp(_ value: Double, within range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func resetWeatherOffset() {
        weatherOffset = 0
        propagateWeatherOffsetChange(animated: true)
    }

    private func resetTimerOffset() {
        timerOffset = 0
        propagateTimerOffsetChange(animated: true)
    }

    private func resetMusicOffset() {
        musicOffset = 0
        propagateMusicOffsetChange(animated: true)
    }

    private func resetMusicWidth() {
        musicWidth = Double(LockScreenMusicPanel.defaultCollapsedWidth)
        propagateMusicWidthChange(animated: true)
    }

    private func resetTimerWidth() {
        timerWidth = LockScreenTimerWidget.defaultWidth
        propagateTimerWidthChange(animated: true)
    }

    private func propagateWeatherOffsetChange(animated: Bool) {
        Task { @MainActor in
            LockScreenWeatherPanelManager.shared.refreshPositionForOffsets(animated: animated)
        }
    }

    private func propagateTimerOffsetChange(animated: Bool) {
        Task { @MainActor in
            LockScreenTimerWidgetManager.shared.refreshPositionForOffsets(animated: animated)
        }
    }

    private func propagateMusicOffsetChange(animated: Bool) {
        Task { @MainActor in
            LockScreenPanelManager.shared.applyOffsetAdjustment(animated: animated)
        }
    }

    private func propagateMusicWidthChange(animated: Bool) {
        Task { @MainActor in
            LockScreenPanelManager.shared.applyOffsetAdjustment(animated: animated)
        }
    }

    private func propagateTimerWidthChange(animated: Bool) {
        Task { @MainActor in
            LockScreenTimerWidgetPanelManager.shared.refreshPosition(animated: animated)
        }
    }

    @ViewBuilder
    private func offsetColumn(title: String, value: Double, resetTitle: String, resetAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) Offset")
                .font(.subheadline.weight(.semibold))

            Text("\(formattedPoints(value)) pt")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(resetTitle) {
                resetAction()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func widthSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        resetTitle: String,
        resetAction: @escaping () -> Void,
        helpText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedWidth(value.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range)

            HStack(alignment: .top) {
                Button(resetTitle) {
                    resetAction()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func formattedPoints(_ value: Double) -> String {
        String(format: "%+.0f", value)
    }

    private func formattedWidth(_ value: Double) -> String {
        String(format: "%.0f pt", value)
    }
}

private struct LockScreenPositioningPreview: View {
    @Binding var weatherOffset: Double
    @Binding var timerOffset: Double
    @Binding var musicOffset: Double
    @Binding var musicWidth: Double
    @Binding var timerWidth: Double

    @State private var weatherStartOffset: Double = 0
    @State private var timerStartOffset: Double = 0
    @State private var musicStartOffset: Double = 0
    @State private var isWeatherDragging = false
    @State private var isTimerDragging = false
    @State private var isMusicDragging = false

    private let offsetRange: ClosedRange<Double> = -160...160

    var body: some View {
        GeometryReader { geometry in
            let screenPadding: CGFloat = 26
            let screenCornerRadius: CGFloat = 28
            let screenRect = CGRect(
                x: screenPadding,
                y: screenPadding,
                width: geometry.size.width - (screenPadding * 2),
                height: geometry.size.height - (screenPadding * 2)
            )
            let centerX = screenRect.midX
            let weatherBaseY = screenRect.minY + (screenRect.height * 0.28)
            let timerBaseY = screenRect.minY + (screenRect.height * 0.5)
            let musicBaseY = screenRect.minY + (screenRect.height * 0.78)
            let weatherSize = CGSize(width: screenRect.width * 0.42, height: screenRect.height * 0.22)
            let defaultMusicWidth = Double(LockScreenMusicPanel.defaultCollapsedWidth)
            let musicWidthScale = CGFloat(musicWidth / defaultMusicWidth)
            let timerWidthScale = CGFloat(timerWidth / LockScreenTimerWidget.defaultWidth)
            let timerSize = CGSize(
                width: (screenRect.width * 0.5) * timerWidthScale,
                height: screenRect.height * 0.2
            )
            let musicSize = CGSize(
                width: (screenRect.width * 0.56) * musicWidthScale,
                height: screenRect.height * 0.34
            )

            ZStack {
                RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.55))
                    .frame(width: screenRect.width, height: screenRect.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 18)
                    .position(x: screenRect.midX, y: screenRect.midY)

                weatherPanel(size: weatherSize)
                    .position(x: centerX, y: weatherBaseY - CGFloat(weatherOffset))
                    .gesture(weatherDragGesture(in: screenRect, baseY: weatherBaseY, panelSize: weatherSize))

                timerPanel(size: timerSize)
                    .position(x: centerX, y: timerBaseY - CGFloat(timerOffset))
                    .gesture(timerDragGesture(in: screenRect, baseY: timerBaseY, panelSize: timerSize))

                musicPanel(size: musicSize)
                    .position(x: centerX, y: musicBaseY - CGFloat(musicOffset))
                    .gesture(musicDragGesture(in: screenRect, baseY: musicBaseY, panelSize: musicSize))
            }
        }
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.82), value: weatherOffset)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.82), value: musicOffset)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.82), value: timerOffset)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.82), value: musicWidth)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.82), value: timerWidth)
    }

    private func weatherPanel(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.78), Color.blue.opacity(0.52)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Weather", systemImage: "cloud.sun.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Text("Inline snapshot preview")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                .padding(.horizontal, 16)
            }
            .shadow(color: Color.blue.opacity(0.22), radius: 10, x: 0, y: 8)
    }

    private func musicPanel(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.68), Color.pink.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Media", systemImage: "play.square.stack")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Text("Lock screen panel preview")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                .padding(.horizontal, 18)
            }
            .shadow(color: Color.purple.opacity(0.24), radius: 12, x: 0, y: 9)
    }

    private func timerPanel(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.orange.opacity(0.75), Color.purple.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.width, height: size.height)
            .overlay {
                VStack(spacing: 6) {
                    Text("Timer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("00:05:00")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: Color.orange.opacity(0.3), radius: 12, x: 0, y: 8)
    }

    private func weatherDragGesture(in screenRect: CGRect, baseY: CGFloat, panelSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isWeatherDragging {
                    isWeatherDragging = true
                    weatherStartOffset = weatherOffset
                }

                let proposed = weatherStartOffset - Double(value.translation.height)
                weatherOffset = clampedOffset(
                    proposed,
                    baseCenterY: baseY,
                    panelHeight: panelSize.height,
                    screenRect: screenRect
                )
            }
            .onEnded { _ in
                isWeatherDragging = false
            }
    }

    private func musicDragGesture(in screenRect: CGRect, baseY: CGFloat, panelSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isMusicDragging {
                    isMusicDragging = true
                    musicStartOffset = musicOffset
                }

                let proposed = musicStartOffset - Double(value.translation.height)
                musicOffset = clampedOffset(
                    proposed,
                    baseCenterY: baseY,
                    panelHeight: panelSize.height,
                    screenRect: screenRect
                )
            }
            .onEnded { _ in
                isMusicDragging = false
            }
    }

    private func timerDragGesture(in screenRect: CGRect, baseY: CGFloat, panelSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isTimerDragging {
                    isTimerDragging = true
                    timerStartOffset = timerOffset
                }

                let proposed = timerStartOffset - Double(value.translation.height)
                timerOffset = clampedOffset(
                    proposed,
                    baseCenterY: baseY,
                    panelHeight: panelSize.height,
                    screenRect: screenRect
                )
            }
            .onEnded { _ in
                isTimerDragging = false
            }
    }

    private func clampedOffset(
        _ proposed: Double,
        baseCenterY: CGFloat,
        panelHeight: CGFloat,
        screenRect: CGRect
    ) -> Double {
        let halfHeight = panelHeight / 2
        let minCenterY = screenRect.minY + halfHeight
        let maxCenterY = screenRect.maxY - halfHeight
        let proposedCenter = baseCenterY - CGFloat(proposed)
        let clampedCenter = min(max(proposedCenter, minCenterY), maxCenterY)
        let derivedOffset = Double(baseCenterY - clampedCenter)
        return min(max(derivedOffset, offsetRange.lowerBound), offsetRange.upperBound)
    }
}

private func copyLatestCrashReport() {
    let crashReportsPath = NSString(string: "~/Library/Logs/DiagnosticReports").expandingTildeInPath
    let fileManager = FileManager.default

    do {
        let files = try fileManager.contentsOfDirectory(atPath: crashReportsPath)
        let crashFiles = files.filter { $0.contains("DynamicIsland") && $0.hasSuffix(".crash") }

        guard let latestCrash = crashFiles.sorted(by: >).first else {
            let alert = NSAlert()
            alert.messageText = "No Crash Reports Found"
            alert.informativeText = "No crash reports found for DynamicIsland"
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let crashPath = (crashReportsPath as NSString).appendingPathComponent(latestCrash)
        let crashContent = try String(contentsOfFile: crashPath, encoding: .utf8)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(crashContent, forType: .string)

        let alert = NSAlert()
        alert.messageText = "Crash Report Copied"
        alert.informativeText = "Crash report '\(latestCrash)' has been copied to clipboard"
        alert.alertStyle = .informational
        alert.runModal()
    } catch {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = "Failed to read crash reports: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}

struct Shortcuts: View {
    @Default(.enableTimerFeature) var enableTimerFeature
    @Default(.enableClipboardManager) var enableClipboardManager
    @Default(.enableShortcuts) var enableShortcuts
    @Default(.enableStatsFeature) var enableStatsFeature
    @Default(.enableColorPickerFeature) var enableColorPickerFeature
    
    private func highlightID(_ title: String) -> String {
        SettingsTab.shortcuts.highlightID(for: title)
    }
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(String(localized: "Enable global keyboard shortcuts"), key: .enableShortcuts)
                    .settingsHighlight(id: highlightID("Enable global keyboard shortcuts"))
            } header: {
                Text("General")
            } footer: {
                Text("When disabled, all keyboard shortcuts will be inactive. You can still use the UI controls.")
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            
            if enableShortcuts {
                Section {
                    KeyboardShortcuts.Recorder("Toggle Sneak Peek:", name: .toggleSneakPeek)
                        .disabled(!enableShortcuts)
                } header: {
                    Text("Media")
                } footer: {
                    Text("Sneak Peek shows the media title and artist under the notch for a few seconds.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                Section {
                    KeyboardShortcuts.Recorder("Toggle Notch Open:", name: .toggleNotchOpen)
                        .disabled(!enableShortcuts)
                } header: {
                    Text("Navigation")
                } footer: {
                    Text("Toggle the Dynamic Island open or closed from anywhere.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            KeyboardShortcuts.Recorder("Start Demo Timer:", name: .startDemoTimer)
                                .disabled(!enableShortcuts || !enableTimerFeature)
                            if !enableTimerFeature {
                                Text("Timer feature is disabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                        Spacer()
                    }
                } header: {
                    Text("Timer")
                } footer: {
                    Text("Starts a 5-minute demo timer to test the timer live activity feature. Only works when timer feature is enabled.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            KeyboardShortcuts.Recorder("Clipboard History:", name: .clipboardHistoryPanel)
                                .disabled(!enableShortcuts || !enableClipboardManager)
                            if !enableClipboardManager {
                                Text("Clipboard feature is disabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                        Spacer()
                    }
                } header: {
                    Text("Clipboard")
                } footer: {
                    Text("Opens the clipboard history panel. Default is Cmd+Shift+V (similar to Windows+V on PC). Only works when clipboard feature is enabled.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            KeyboardShortcuts.Recorder("Screen Assistant:", name: .screenAssistantPanel)
                                .disabled(!enableShortcuts || !Defaults[.enableScreenAssistant])
                            if !Defaults[.enableScreenAssistant] {
                                Text("Screen Assistant feature is disabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                        Spacer()
                    }
                } header: {
                    Text("AI Assistant")
                } footer: {
                    Text("Opens the AI assistant panel for file analysis and conversation. Default is Cmd+Shift+A. Only works when screen assistant feature is enabled.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            KeyboardShortcuts.Recorder("Color Picker Panel:", name: .colorPickerPanel)
                                .disabled(!enableShortcuts || !enableColorPickerFeature)
                            if !enableColorPickerFeature {
                                Text("Color Picker feature is disabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                        Spacer()
                    }
                } header: {
                    Text("Color Picker")
                } footer: {
                    Text("Opens the color picker panel for screen color capture. Default is Cmd+Shift+P. Only works when color picker feature is enabled.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keyboard shortcuts are disabled")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Enable global keyboard shortcuts above to customize your shortcuts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Shortcuts")
    }
}

func proFeatureBadge() -> some View {
    Text("Upgrade to Pro")
        .foregroundStyle(Color(red: 0.545, green: 0.196, blue: 0.98))
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.545, green: 0.196, blue: 0.98), lineWidth: 1))
}

func comingSoonTag() -> some View {
    Text("Coming soon")
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func customBadge(text: String) -> some View {
    Text(text)
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func alphaBadge() -> some View {
    Text("ALPHA")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.9))
        )
}

func warningBadge(_ text: String, _ description: String) -> some View {
    Section {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading) {
                Text(text)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct TimerSettings: View {
    @ObservedObject private var coordinator = DynamicIslandViewCoordinator.shared
    @Default(.enableTimerFeature) var enableTimerFeature
    @Default(.timerPresets) private var timerPresets
    @Default(.timerIconColorMode) private var colorMode
    @Default(.timerSolidColor) private var solidColor
    @Default(.timerShowsCountdown) private var showsCountdown
    @Default(.timerShowsLabel) private var showsLabel
    @Default(.timerShowsProgress) private var showsProgress
    @Default(.timerProgressStyle) private var progressStyle
    @Default(.showTimerPresetsInNotchTab) private var showTimerPresetsInNotchTab
    @Default(.timerControlWindowEnabled) private var controlWindowEnabled
    @Default(.mirrorSystemTimer) private var mirrorSystemTimer
    @Default(.timerDisplayMode) private var timerDisplayMode
    @Default(.enableLockScreenTimerWidget) private var enableLockScreenTimerWidget
    @Default(.lockScreenTimerWidgetUsesBlur) private var timerGlassModeIsGlass
    @Default(.lockScreenTimerGlassStyle) private var lockScreenTimerGlassStyle
    @Default(.lockScreenTimerGlassCustomizationMode) private var lockScreenTimerGlassCustomizationMode
    @Default(.lockScreenTimerLiquidGlassVariant) private var lockScreenTimerLiquidGlassVariant
    @AppStorage("customTimerDuration") private var customTimerDuration: Double = 600
    @State private var customHours: Int = 0
    @State private var customMinutes: Int = 10
    @State private var customSeconds: Int = 0
    @State private var showingResetConfirmation = false
    
    private func highlightID(_ title: String) -> String {
        SettingsTab.timer.highlightID(for: title)
    }

    private var liquidVariantRange: ClosedRange<Double> {
        Double(LiquidGlassVariant.supportedRange.lowerBound)...Double(LiquidGlassVariant.supportedRange.upperBound)
    }

    private var timerVariantBinding: Binding<Double> {
        Binding(
            get: { Double(lockScreenTimerLiquidGlassVariant.rawValue) },
            set: { newValue in
                let raw = Int(newValue.rounded())
                lockScreenTimerLiquidGlassVariant = LiquidGlassVariant.clamped(raw)
            }
        )
    }

    private var timerSurfaceBinding: Binding<LockScreenTimerSurfaceMode> {
        Binding(
            get: { timerGlassModeIsGlass ? .glass : .classic },
            set: { mode in timerGlassModeIsGlass = (mode == .glass) }
        )
    }
    
    var body: some View {
        Form {
            timerFeatureSection

            if enableTimerFeature {
                timerConfigurationSections
            }
        }
        .navigationTitle("Timer")
        .onAppear { syncCustomDuration() }
        .onChange(of: customTimerDuration) { _, newValue in syncCustomDuration(newValue) }
    }

    @ViewBuilder
    private var timerFeatureSection: some View {
        Section {
            Defaults.Toggle(String(localized: "Enable timer feature"), key: .enableTimerFeature)
                .settingsHighlight(id: highlightID("Enable timer feature"))

            if enableTimerFeature {
                Toggle("Enable timer live activity", isOn: $coordinator.timerLiveActivityEnabled)
                    .animation(.easeInOut, value: coordinator.timerLiveActivityEnabled)
                Defaults.Toggle(key: .mirrorSystemTimer) {
                    HStack(spacing: 8) {
                        Text("Mirror macOS Clock timers")
                        alphaBadge()
                    }
                }
                    .help("Shows the system Clock timer in the notch when available. Requires Accessibility permission to read the status item.")
                    .settingsHighlight(id: highlightID("Mirror macOS Clock timers"))

                Picker("Timer controls appear as", selection: $timerDisplayMode) {
                    ForEach(TimerDisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help(timerDisplayMode.description)
                .settingsHighlight(id: highlightID("Timer controls appear as"))
            }
        } header: {
            Text("Timer Feature")
        } footer: {
            Text("Control timer availability, live activity behaviour, and whether the app mirrors timers started from the macOS Clock app.")
        }
    }

    @ViewBuilder
    private var timerConfigurationSections: some View {
        Group {
            lockScreenIntegrationSection
            customTimerSection
            appearanceSection
            timerPresetsSection
            timerSoundSection
        }
        .onAppear {
            if showsLabel {
                controlWindowEnabled = false
            }
        }
        .onChange(of: showsLabel) { _, show in
            if show {
                controlWindowEnabled = false
            }
        }
    }

    @ViewBuilder
    private var lockScreenIntegrationSection: some View {
        Section {
            Defaults.Toggle(String(localized:"Show lock screen timer widget"), key: .enableLockScreenTimerWidget)
                .settingsHighlight(id: highlightID("Show lock screen timer widget"))
            Picker("Timer surface", selection: timerSurfaceBinding) {
                ForEach(LockScreenTimerSurfaceMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!enableLockScreenTimerWidget)
            .opacity(enableLockScreenTimerWidget ? 1 : 0.5)
            .settingsHighlight(id: highlightID("Timer surface"))

            if timerGlassModeIsGlass {
                Picker("Timer glass material", selection: $lockScreenTimerGlassStyle) {
                    ForEach(LockScreenGlassStyle.allCases) { style in
                        Text(style.localizedName).tag(style)
                    }
                }
                .disabled(!enableLockScreenTimerWidget)
                .opacity(enableLockScreenTimerWidget ? 1 : 0.5)
                .settingsHighlight(id: highlightID("Timer glass material"))

                if lockScreenTimerGlassStyle == .liquid {
                    Picker("Timer liquid mode", selection: $lockScreenTimerGlassCustomizationMode) {
                        ForEach(LockScreenGlassCustomizationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!enableLockScreenTimerWidget)
                    .opacity(enableLockScreenTimerWidget ? 1 : 0.5)
                    .settingsHighlight(id: highlightID("Timer liquid mode"))

                    if lockScreenTimerGlassCustomizationMode == .customLiquid {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Timer widget variant")
                                Spacer()
                                Text("v\(lockScreenTimerLiquidGlassVariant.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: timerVariantBinding, in: liquidVariantRange, step: 1)
                        }
                        .settingsHighlight(id: highlightID("Timer widget variant"))
                        .disabled(!enableLockScreenTimerWidget)
                        .opacity(enableLockScreenTimerWidget ? 1 : 0.4)
                    }
                } else {
                    Text("Uses the frosted blur treatment while glass mode is enabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("Classic mode keeps the original translucent black background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(enableLockScreenTimerWidget ? 1 : 0.5)
            }
        } header: {
            Text("Lock Screen Integration")
        } footer: {
            Text("Mirrors the toggle found under Lock Screen settings so timer-specific workflows can enable or disable the widget without switching tabs.")
        }
    }

    @ViewBuilder
    private var customTimerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Default Custom Timer")
                    .font(.headline)

                TimerDurationStepperRow(title: String(localized:"Hours"), value: $customHours, range: 0...23)
                TimerDurationStepperRow(title: String(localized:"Minutes"), value: $customMinutes, range: 0...59)
                TimerDurationStepperRow(title: String(localized:"Seconds"), value: $customSeconds, range: 0...59)

                HStack {
                    Text("Current default:")
                        .foregroundStyle(.secondary)
                    Text(customDurationDisplay)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .padding(.vertical, 4)
            .onChange(of: customHours) { _, _ in updateCustomDuration() }
            .onChange(of: customMinutes) { _, _ in updateCustomDuration() }
            .onChange(of: customSeconds) { _, _ in updateCustomDuration() }
        } header: {
            Text("Custom Timer")
        } footer: {
            Text("This duration powers the \"Custom\" option inside the timer popover for quick access.")
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section {
            Picker("Timer tint", selection: $colorMode) {
                ForEach(TimerIconColorMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .settingsHighlight(id: highlightID("Timer tint"))

            if colorMode == .solid {
                ColorPicker("Solid colour", selection: $solidColor, supportsOpacity: false)
                    .settingsHighlight(id: highlightID("Solid colour"))
            }

            Toggle("Show timer name", isOn: $showsLabel)
            Toggle("Show countdown", isOn: $showsCountdown)
            Toggle("Show progress", isOn: $showsProgress)
            Toggle("Show preset list in timer tab", isOn: $showTimerPresetsInNotchTab)
                .settingsHighlight(id: highlightID("Show preset list in timer tab"))

            Toggle("Show floating pause/stop controls", isOn: $controlWindowEnabled)
                .disabled(showsLabel)
                .help("These controls sit beside the notch while a timer runs. They require the timer name to stay hidden for spacing.")

            Picker("Progress style", selection: $progressStyle) {
                ForEach(TimerProgressStyle.allCases) { style in
                    Text(style.localizedName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!showsProgress)
            .settingsHighlight(id: highlightID("Progress style"))
        } header: {
            Text("Appearance")
        } footer: {
            Text("Configure how the timer looks inside the closed notch. Progress can render as a ring around the icon or as horizontal bars.")
        }
    }

    @ViewBuilder
    private var timerPresetsSection: some View {
        Section {
            if timerPresets.isEmpty {
                Text("No presets configured. Add a preset to make it appear in the timer popover.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                TimerPresetListView(
                    presets: $timerPresets,
                    highlightProvider: highlightID,
                    moveUp: movePresetUp,
                    moveDown: movePresetDown,
                    remove: removePreset
                )
            }

            HStack {
                Button(action: addPreset) {
                    Label("Add Preset", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive, action: { showingResetConfirmation = true }) {
                    Label("Restore Defaults", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .confirmationDialog("Restore default timer presets?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                    Button("Restore", role: .destructive, action: resetPresets)
                }
            }
        } header: {
            Text("Timer Presets")
        } footer: {
            Text("Presets show up inside the timer popover with the configured name, duration, and accent colour. Reorder them to change the display order.")
        }
    }

    @ViewBuilder
    private var timerSoundSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Timer Sound")
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    Button("Choose File", action: selectCustomTimerSound)
                        .buttonStyle(.bordered)
                }

                if let customTimerSoundPath = UserDefaults.standard.string(forKey: "customTimerSoundPath") {
                    Text("Custom: \(URL(fileURLWithPath: customTimerSoundPath).lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Default: dynamic.m4a")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button("Reset to Default") {
                    UserDefaults.standard.removeObject(forKey: "customTimerSoundPath")
                }
                .buttonStyle(.bordered)
                .disabled(UserDefaults.standard.string(forKey: "customTimerSoundPath") == nil)
            }
        } header: {
            Text("Timer Sound")
        } footer: {
            Text("Select a custom sound to play when a timer ends. Supported formats include MP3, M4A, WAV, and AIFF.")
        }
    }
    
    private var customDurationDisplay: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = customTimerDuration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: customTimerDuration) ?? "0:00"
    }
    
    private func syncCustomDuration(_ value: Double? = nil) {
        let baseValue = value ?? customTimerDuration
        let components = TimerPreset.components(for: baseValue)
        customHours = components.hours
        customMinutes = components.minutes
        customSeconds = components.seconds
    }
    
    private func updateCustomDuration() {
        let duration = TimeInterval(customHours * 3600 + customMinutes * 60 + customSeconds)
        customTimerDuration = duration
    }
    
    private func addPreset() {
        let nextIndex = timerPresets.count + 1
        let defaultColor = Defaults[.accentColor]
        let newPreset = TimerPreset(name: "Preset \(nextIndex)", duration: 5 * 60, color: defaultColor)
        withAnimation(.smooth) {
            timerPresets.append(newPreset)
        }
    }
    
    private func movePresetUp(_ index: Int) {
        guard index > timerPresets.startIndex else { return }
        withAnimation(.smooth) {
            timerPresets.swapAt(index, index - 1)
        }
    }
    
    private func movePresetDown(_ index: Int) {
        guard index < timerPresets.index(before: timerPresets.endIndex) else { return }
        withAnimation(.smooth) {
            timerPresets.swapAt(index, index + 1)
        }
    }
    
    private func removePreset(_ index: Int) {
        guard timerPresets.indices.contains(index) else { return }
        withAnimation(.smooth) {
            timerPresets.remove(at: index)
        }
    }
    
    private func resetPresets() {
        withAnimation(.smooth) {
            timerPresets = TimerPreset.defaultPresets
        }
    }
    
    private func selectCustomTimerSound() {
        let panel = NSOpenPanel()
        panel.title = "Select Timer Sound"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                UserDefaults.standard.set(url.path, forKey: "customTimerSoundPath")
            }
        }
    }
}

private struct TimerDurationStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        }
    }
}

private struct TimerPresetListView: View {
    @Binding var presets: [TimerPreset]
    let highlightProvider: (String) -> String
    let moveUp: (Int) -> Void
    let moveDown: (Int) -> Void
    let remove: (Int) -> Void

    var body: some View {
        ForEach(presets.indices, id: \.self) { index in
            presetRow(at: index)
        }
    }

    @ViewBuilder
    private func presetRow(at index: Int) -> some View {
        TimerPresetEditorRow(
            preset: $presets[index],
            isFirst: index == presets.startIndex,
            isLast: index == presets.index(before: presets.endIndex),
            highlightID: highlightID(for: index),
            moveUp: { moveUp(index) },
            moveDown: { moveDown(index) },
            remove: { remove(index) }
        )
    }

    private func highlightID(for index: Int) -> String? {
        index == presets.startIndex ? highlightProvider("Accent colour") : nil
    }
}

private struct TimerPresetEditorRow: View {
    @Binding var preset: TimerPreset
    let isFirst: Bool
    let isLast: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void
    let highlightID: String?

    init(
        preset: Binding<TimerPreset>,
        isFirst: Bool,
        isLast: Bool,
        highlightID: String? = nil,
        moveUp: @escaping () -> Void,
        moveDown: @escaping () -> Void,
        remove: @escaping () -> Void
    ) {
        _preset = preset
        self.isFirst = isFirst
        self.isLast = isLast
        self.highlightID = highlightID
        self.moveUp = moveUp
        self.moveDown = moveDown
        self.remove = remove
    }
    
    private var components: TimerPreset.DurationComponents {
        TimerPreset.components(for: preset.duration)
    }
    
    private var hoursBinding: Binding<Int> {
        Binding(
            get: { components.hours },
            set: { updateDuration(hours: $0) }
        )
    }
    
    private var minutesBinding: Binding<Int> {
        Binding(
            get: { components.minutes },
            set: { updateDuration(minutes: $0) }
        )
    }
    
    private var secondsBinding: Binding<Int> {
        Binding(
            get: { components.seconds },
            set: { updateDuration(seconds: $0) }
        )
    }
    
    private var colorBinding: Binding<Color> {
        Binding(
            get: { preset.color },
            set: { preset.updateColor($0) }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(preset.color.gradient)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                TextField("Preset name", text: $preset.name)
                    .textFieldStyle(.roundedBorder)
                
                Spacer()
                
                Text(preset.formattedDuration)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 16) {
                TimerPresetComponentControl(title: String(localized:"Hours"), value: hoursBinding, range: 0...23)
                TimerPresetComponentControl(title: String(localized:"Minutes"), value: minutesBinding, range: 0...59)
                TimerPresetComponentControl(title: String(localized:"Seconds"), value: secondsBinding, range: 0...59)
            }
            
            ColorPicker("Accent colour", selection: colorBinding, supportsOpacity: false)
                .frame(maxWidth: 240, alignment: .leading)
            
            HStack(spacing: 12) {
                Button(action: moveUp) {
                    Label("Move Up", systemImage: "chevron.up")
                }
                .buttonStyle(.bordered)
                .disabled(isFirst)
                
                Button(action: moveDown) {
                    Label("Move Down", systemImage: "chevron.down")
                }
                .buttonStyle(.bordered)
                .disabled(isLast)
                
                Spacer()
                
                Button(role: .destructive, action: remove) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 12, weight: .medium))
        }
        .padding(.vertical, 6)
        .settingsHighlightIfPresent(highlightID)
    }
    
    private func updateDuration(hours: Int? = nil, minutes: Int? = nil, seconds: Int? = nil) {
        var values = components
        if let hours { values.hours = hours }
        if let minutes { values.minutes = minutes }
        if let seconds { values.seconds = seconds }
        preset.duration = TimerPreset.duration(from: values)
    }
}

private struct TimerPresetComponentControl: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        Stepper(value: $value, in: range) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
        }
        .frame(width: 110, alignment: .leading)
    }
}

struct StatsSettings: View {
    @ObservedObject var statsManager = StatsManager.shared
    @Default(.enableStatsFeature) var enableStatsFeature
    @Default(.statsStopWhenNotchCloses) var statsStopWhenNotchCloses
    @Default(.statsUpdateInterval) var statsUpdateInterval
    @Default(.showCpuGraph) var showCpuGraph
    @Default(.showMemoryGraph) var showMemoryGraph
    @Default(.showGpuGraph) var showGpuGraph
    @Default(.showNetworkGraph) var showNetworkGraph
    @Default(.showDiskGraph) var showDiskGraph
    
    private func highlightID(_ title: String) -> String {
        SettingsTab.stats.highlightID(for: title)
    }
    
    var enabledGraphsCount: Int {
        [showCpuGraph, showMemoryGraph, showGpuGraph, showNetworkGraph, showDiskGraph].filter { $0 }.count
    }

    private var formattedUpdateInterval: String {
        let seconds = Int(statsUpdateInterval.rounded())
        if seconds >= 60 {
            return "60 s (1 min)"
        } else if seconds == 1 {
            return "1 s"
        } else {
            return "\(seconds) s"
        }
    }

    private var shouldShowStatsBatteryWarning: Bool {
        !statsStopWhenNotchCloses && statsUpdateInterval <= 5
    }
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(String(localized: "Enable system stats monitoring"), key: .enableStatsFeature)
                    .settingsHighlight(id: highlightID("Enable system stats monitoring"))
                    .onChange(of: enableStatsFeature) { _, newValue in
                        if !newValue {
                            statsManager.stopMonitoring()
                        }
                        // Note: Smart monitoring will handle starting when switching to stats tab
                    }
                
            } header: {
                Text("General")
            } footer: {
                Text("When enabled, the Stats tab will display real-time system performance graphs. This feature requires system permissions and may use additional battery.")
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            
            if enableStatsFeature {
                Section {
                    Defaults.Toggle(String(localized: "Stop monitoring after closing the notch"), key: .statsStopWhenNotchCloses)
                        .settingsHighlight(id: highlightID("Stop monitoring after closing the notch"))
                        .help("When enabled, stats monitoring stops a few seconds after the notch closes.")

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Update interval")
                            Spacer()
                            Text(formattedUpdateInterval)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $statsUpdateInterval, in: 1...60, step: 1)
                            .accessibilityLabel("Stats update interval")

                        Text("Controls how often system metrics refresh while monitoring is active.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if shouldShowStatsBatteryWarning {
                        Label {
                            Text("High-frequency updates without a timeout can increase battery usage.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Monitoring Behavior")
                } footer: {
                    Text("Sampling can continue while the notch is closed when the timeout is disabled.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Section {
                    Defaults.Toggle(String(localized: "CPU Usage"), key: .showCpuGraph)
                        .settingsHighlight(id: highlightID("CPU Usage"))
                    Defaults.Toggle(String(localized: "Memory Usage"), key: .showMemoryGraph)
                        .settingsHighlight(id: highlightID("Memory Usage"))
                    Defaults.Toggle(String(localized: "GPU Usage"), key: .showGpuGraph)
                        .settingsHighlight(id: highlightID("GPU Usage"))
                    Defaults.Toggle(String(localized: "Network Activity"), key: .showNetworkGraph)
                        .settingsHighlight(id: highlightID("Network Activity"))
                    Defaults.Toggle(String(localized: "Disk I/O"), key: .showDiskGraph)
                        .settingsHighlight(id: highlightID("Disk I/O"))
                } header: {
                    Text("Graph Visibility")
                } footer: {
                    if enabledGraphsCount >= 4 {
                        Text("With \(enabledGraphsCount) graphs enabled, the Dynamic Island will expand horizontally to accommodate all graphs in a single row.")
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        Text("Each graph can be individually enabled or disabled. Network activity shows download/upload speeds, and disk I/O shows read/write speeds.")
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                
                Section {
                    HStack {
                        Text("Monitoring Status")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statsManager.isMonitoring ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(statsManager.isMonitoring ? "Active" : "Stopped")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if statsManager.isMonitoring {
                        if showCpuGraph {
                            HStack {
                                Text(String(localized: "CPU Usage"))
                                Spacer()
                                Text(statsManager.cpuUsageString)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if showMemoryGraph {
                            HStack {
                                Text(String(localized: "Memory Usage"))
                                Spacer()
                                Text(statsManager.memoryUsageString)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if showGpuGraph {
                            HStack {
                                Text(String(localized: "GPU Usage"))
                                Spacer()
                                Text(statsManager.gpuUsageString)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if showNetworkGraph {
                            HStack {
                                Text(String(localized: "Network Download"))
                                Spacer()
                                Text(String(format: "%.1f MB/s", statsManager.networkDownload))
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text(String(localized: "Network Upload"))
                                Spacer()
                                Text(String(format: "%.1f MB/s", statsManager.networkUpload))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if showDiskGraph {
                            HStack {
                                Text(String(localized: "Disk Read"))
                                Spacer()
                                Text(String(format: "%.1f MB/s", statsManager.diskRead))
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text(String(localized: "Disk Write"))
                                Spacer()
                                Text(String(format: "%.1f MB/s", statsManager.diskWrite))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Text(String(localized: "Last Updated"))
                            Spacer()
                            Text(statsManager.lastUpdated, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Live Performance Data")
                }
                
                Section {
                    HStack {
                        Button(statsManager.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                            if statsManager.isMonitoring {
                                statsManager.stopMonitoring()
                            } else {
                                statsManager.startMonitoring()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundColor(statsManager.isMonitoring ? .red : .blue)
                        
                        Spacer()
                        
                        Button("Clear Data") {
                            statsManager.clearHistory()
                        }
                        .buttonStyle(.bordered)
                        .disabled(statsManager.isMonitoring)
                    }
                } header: {
                    Text("Controls")
                }
            }
        }
        .navigationTitle("Stats")
    }
}

struct ClipboardSettings: View {
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @Default(.enableClipboardManager) var enableClipboardManager
    @Default(.clipboardHistorySize) var clipboardHistorySize
    @Default(.showClipboardIcon) var showClipboardIcon
    @Default(.clipboardDisplayMode) var clipboardDisplayMode
    
    private func highlightID(_ title: String) -> String {
        SettingsTab.clipboard.highlightID(for: title)
    }
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(String(localized: "Enable Clipboard Manager"), key: .enableClipboardManager)
                    .settingsHighlight(id: highlightID("Enable Clipboard Manager"))
                    .onChange(of: enableClipboardManager) { _, enabled in
                        if enabled {
                            clipboardManager.startMonitoring()
                        } else {
                            clipboardManager.stopMonitoring()
                        }
                    }
            } header: {
                Text("Clipboard Manager")
            } footer: {
                Text("Monitor clipboard changes and keep a history of recent copies. Use Cmd+Shift+V to quickly access clipboard history.")
            }
            
            if enableClipboardManager {
                Section {
                    Defaults.Toggle(String(localized: "Show Clipboard Icon"), key: .showClipboardIcon)
                        .settingsHighlight(id: highlightID("Show Clipboard Icon"))
                    
                    HStack {
                        Text("Display Mode")
                        Spacer()
                        Picker("Display Mode", selection: $clipboardDisplayMode) {
                            ForEach(ClipboardDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    .settingsHighlight(id: highlightID("Display Mode"))
                    
                    HStack {
                        Text("History Size")
                        Spacer()
                        Picker("History Size", selection: $clipboardHistorySize) {
                            Text("3 items").tag(3)
                            Text("5 items").tag(5)
                            Text("7 items").tag(7)
                            Text("10 items").tag(10)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    .settingsHighlight(id: highlightID("History Size"))
                    
                    HStack {
                        Text("Current Items")
                        Spacer()
                        Text("\(clipboardManager.clipboardHistory.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Pinned Items")
                        Spacer()
                        Text("\(clipboardManager.pinnedItems.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Monitoring Status")
                        Spacer()
                        Text(clipboardManager.isMonitoring ? "Active" : "Stopped")
                            .foregroundColor(clipboardManager.isMonitoring ? .green : .secondary)
                    }
                } header: {
                    Text("Settings")
                } footer: {
                    switch clipboardDisplayMode {
                    case .popover:
                        Text("Popover mode shows clipboard as a dropdown attached to the clipboard button.")
                    case .panel:
                        Text("Panel mode shows clipboard in a floating window near the notch.")
                    case .separateTab:
                        Text("Separate Tab mode integrates Copied Items and Notes into a single view. If both are enabled, Notes appear on the right and Clipboard on the left.")
                    }
                }
                
                Section {
                    Button("Clear Clipboard History") {
                        clipboardManager.clearHistory()
                    }
                    .foregroundColor(.red)
                    .disabled(clipboardManager.clipboardHistory.isEmpty)
                    
                    Button("Clear Pinned Items") {
                        clipboardManager.pinnedItems.removeAll()
                        clipboardManager.savePinnedItemsToDefaults()
                    }
                    .foregroundColor(.red)
                    .disabled(clipboardManager.pinnedItems.isEmpty)
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Clear clipboard history removes recent copies. Clear pinned items removes your favorites. Both actions are permanent.")
                }
                
                if !clipboardManager.clipboardHistory.isEmpty {
                    Section {
                        ForEach(clipboardManager.clipboardHistory) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: item.type.icon)
                                        .foregroundColor(.blue)
                                        .frame(width: 16)
                                    Text(item.type.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(timeAgoString(from: item.timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(item.preview)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Current History")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Clipboard")
        .onAppear {
            if enableClipboardManager && !clipboardManager.isMonitoring {
                clipboardManager.startMonitoring()
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return String(localized: "Just now")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(localized: "\(minutes)m ago")
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return String(localized: "\(hours)h ago")
        } else {
            let days = Int(interval / 86400)
            return String(localized: "\(days)d ago")
        }
    }
}

struct ScreenAssistantSettings: View {
    @ObservedObject var screenAssistantManager = ScreenAssistantManager.shared
    @Default(.enableScreenAssistant) var enableScreenAssistant
    @Default(.screenAssistantDisplayMode) var screenAssistantDisplayMode
    @Default(.geminiApiKey) var geminiApiKey
    @State private var apiKeyText = ""
    @State private var showingApiKey = false
    
    private func highlightID(_ title: String) -> String {
        SettingsTab.screenAssistant.highlightID(for: title)
    }
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(String(localized: "Enable Screen Assistant"), key: .enableScreenAssistant)
                    .settingsHighlight(id: highlightID("Enable Screen Assistant"))
            } header: {
                Text("AI Assistant")
            } footer: {
                Text("AI-powered assistant that can analyze files, images, and provide conversational help. Use Cmd+Shift+A to quickly access the assistant.")
            }
            
            if enableScreenAssistant {
                Section {
                    HStack {
                        Text("Gemini API Key")
                        Spacer()
                        if geminiApiKey.isEmpty {
                            Text("Not Set")
                                .foregroundColor(.red)
                        } else {
                            Text("••••••••")
                                .foregroundColor(.green)
                        }
                        
                        Button(showingApiKey ? "Hide" : (geminiApiKey.isEmpty ? "Set" : "Change")) {
                            if showingApiKey {
                                showingApiKey = false
                                if !apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Defaults[.geminiApiKey] = apiKeyText
                                }
                                apiKeyText = ""
                            } else {
                                showingApiKey = true
                                apiKeyText = geminiApiKey
                            }
                        }
                    }
                    
                    if showingApiKey {
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Enter your Gemini API Key", text: $apiKeyText)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Get your free API key from Google AI Studio")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("Open Google AI Studio") {
                                    NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/app/apikey")!)
                                }
                                .buttonStyle(.link)
                                
                                Spacer()
                                
                                Button("Save") {
                                    Defaults[.geminiApiKey] = apiKeyText
                                    showingApiKey = false
                                    apiKeyText = ""
                                }
                                .disabled(apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Display Mode")
                        Spacer()
                        Picker("Display Mode", selection: $screenAssistantDisplayMode) {
                            ForEach(ScreenAssistantDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    .settingsHighlight(id: highlightID("Display Mode"))
                    
                    HStack {
                        Text("Attached Files")
                        Spacer()
                        Text("\(screenAssistantManager.attachedFiles.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Recording Status")
                        Spacer()
                        Text(screenAssistantManager.isRecording ? "Recording" : "Ready")
                            .foregroundColor(screenAssistantManager.isRecording ? .red : .secondary)
                    }
                } header: {
                    Text("Configuration")
                } footer: {
                    switch screenAssistantDisplayMode {
                    case .popover:
                        Text("Popover mode shows the assistant as a dropdown attached to the AI button. Panel mode shows the assistant in a floating window near the notch.")
                    case .panel:
                        Text("Panel mode shows the assistant in a floating window near the notch. Popover mode shows the assistant as a dropdown attached to the AI button.")
                    }
                }
                
                Section {
                    Button("Clear All Files") {
                        screenAssistantManager.clearAllFiles()
                    }
                    .foregroundColor(.red)
                    .disabled(screenAssistantManager.attachedFiles.isEmpty)
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Clear all files removes all attached files and audio recordings. This action is permanent.")
                }
                
                if !screenAssistantManager.attachedFiles.isEmpty {
                    Section {
                        ForEach(screenAssistantManager.attachedFiles) { file in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: file.type.iconName)
                                        .foregroundColor(.blue)
                                        .frame(width: 16)
                                    Text(file.type.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(timeAgoString(from: file.timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(file.name)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Attached Files")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Screen Assistant")
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return String(localized: "Just now")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(localized: "\(minutes)m ago")
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return String(localized: "\(hours)h ago")
        } else {
            let days = Int(interval / 86400)
            return String(localized: "\(days)d ago")
        }
    }
}

struct ColorPickerSettings: View {
    @ObservedObject var colorPickerManager = ColorPickerManager.shared
    @Default(.enableColorPickerFeature) var enableColorPickerFeature
    @Default(.showColorFormats) var showColorFormats
    @Default(.colorPickerDisplayMode) var colorPickerDisplayMode
    @Default(.colorHistorySize) var colorHistorySize
    @Default(.showColorPickerIcon) var showColorPickerIcon
    
    private func highlightID(_ title: String) -> String {
        SettingsTab.colorPicker.highlightID(for: title)
    }
    
    var body: some View {
        Form {
            Section {
                    Defaults.Toggle(String(localized: "Enable Color Picker"), key: .enableColorPickerFeature)
                    .settingsHighlight(id: highlightID("Enable Color Picker"))
            } header: {
                Text("Color Picker")
            } footer: {
                Text("Enable screen color picking functionality. Use Cmd+Shift+P to quickly access the color picker.")
            }
            
            if enableColorPickerFeature {
                Section {
                    Defaults.Toggle(String(localized: "Show Color Picker Icon"), key: .showColorPickerIcon)
                        .settingsHighlight(id: highlightID("Show Color Picker Icon"))
                    
                    HStack {
                        Text("Display Mode")
                        Spacer()
                        Picker("Display Mode", selection: $colorPickerDisplayMode) {
                            ForEach(ColorPickerDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    .settingsHighlight(id: highlightID("Display Mode"))
                    
                    HStack {
                        Text("History Size")
                        Spacer()
                        Picker("History Size", selection: $colorHistorySize) {
                            Text("5 colors").tag(5)
                            Text("10 colors").tag(10)
                            Text("15 colors").tag(15)
                            Text("20 colors").tag(20)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    .settingsHighlight(id: highlightID("History Size"))
                    
                    Defaults.Toggle(String(localized: "Show All Color Formats"), key: .showColorFormats)
                        .settingsHighlight(id: highlightID("Show All Color Formats"))
                    
                } header: {
                    Text("Settings")
                } footer: {
                    switch colorPickerDisplayMode {
                    case .popover:
                        Text("Popover mode shows color picker as a dropdown attached to the color picker button. Panel mode shows color picker in a floating window.")
                    case .panel:
                        Text("Panel mode shows color picker in a floating window. Popover mode shows color picker as a dropdown attached to the color picker button.")
                    }
                }
                
                Section {
                    HStack {
                        Text("Color History")
                        Spacer()
                        Text("\(colorPickerManager.colorHistory.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Picking Status")
                        Spacer()
                        Text(colorPickerManager.isPickingColor ? "Active" : "Ready")
                            .foregroundColor(colorPickerManager.isPickingColor ? .green : .secondary)
                    }
                    
                    Button("Show Color Picker Panel") {
                        ColorPickerPanelManager.shared.showColorPickerPanel()
                    }
                    .disabled(!enableColorPickerFeature)
                    
                } header: {
                    Text("Status & Actions")
                }
                
                Section {
                    Button("Clear Color History") {
                        colorPickerManager.clearHistory()
                    }
                    .foregroundColor(.red)
                    .disabled(colorPickerManager.colorHistory.isEmpty)
                    
                    Button("Start Color Picking") {
                        colorPickerManager.startColorPicking()
                    }
                    .disabled(!enableColorPickerFeature || colorPickerManager.isPickingColor)
                    
                } header: {
                    Text("Quick Actions")
                } footer: {
                    Text("Clear color history removes all picked colors. Start color picking begins screen color capture mode.")
                }
            }
        }
        .navigationTitle("Color Picker")
    }
}

struct CustomOSDSettings: View {
    @Default(.enableCustomOSD) var enableCustomOSD
    @Default(.hasSeenOSDAlphaWarning) var hasSeenOSDAlphaWarning
    @Default(.enableOSDVolume) var enableOSDVolume
    @Default(.enableOSDBrightness) var enableOSDBrightness
    @Default(.enableOSDKeyboardBacklight) var enableOSDKeyboardBacklight
    @Default(.osdMaterial) var osdMaterial
    @Default(.osdIconColorStyle) var osdIconColorStyle
    @Default(.enableSystemHUD) var enableSystemHUD
    @ObservedObject private var accessibilityPermission = AccessibilityPermissionStore.shared
    
    @State private var showAlphaWarning = false
    @State private var previewValue: CGFloat = 0.65
    @State private var previewType: SneakContentType = .volume
    
    private func highlightID(_ title: String) -> String {
        SettingsTab.hudAndOSD.highlightID(for: title)
    }

    private var hasAccessibilityPermission: Bool {
        accessibilityPermission.isAuthorized
    }
    
    var body: some View {
        Form {
            if !hasAccessibilityPermission {
                Section {
                    SettingsPermissionCallout(
                        message: "Accessibility permission is needed to intercept system controls for the Custom OSD.",
                        requestAction: { accessibilityPermission.requestAuthorizationPrompt() },
                        openSettingsAction: { accessibilityPermission.openSystemSettings() }
                    )
                } header: {
                    Text("Accessibility")
                }
            }

            if hasAccessibilityPermission {
                Section {
                    Toggle("Volume OSD", isOn: $enableOSDVolume)
                        .settingsHighlight(id: highlightID("Volume OSD"))
                    Toggle("Brightness OSD", isOn: $enableOSDBrightness)
                        .settingsHighlight(id: highlightID("Brightness OSD"))
                    Toggle("Keyboard Backlight OSD", isOn: $enableOSDKeyboardBacklight)
                        .settingsHighlight(id: highlightID("Keyboard Backlight OSD"))
                } header: {
                    Text("Controls")
                } footer: {
                    Text("Choose which system controls should display custom OSD windows.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                Section {
                    Picker("Material", selection: $osdMaterial) {
                        ForEach(OSDMaterial.allCases, id: \.self) { material in
                            Text(material.rawValue).tag(material)
                        }
                    }
                    .settingsHighlight(id: highlightID("Material"))
                    .onChange(of: osdMaterial) { _, _ in
                        previewValue = previewValue == 0.65 ? 0.651 : 0.65
                    }
                    
                    Picker("Icon & Progress Color", selection: $osdIconColorStyle) {
                        ForEach(OSDIconColorStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .settingsHighlight(id: highlightID("Icon & Progress Color"))
                    .onChange(of: osdIconColorStyle) { _, _ in
                        previewValue = previewValue == 0.65 ? 0.651 : 0.65
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Material Options:")
                        Text("• Frosted Glass: Translucent blur effect")
                        Text("• Liquid Glass: Modern glass effect (macOS 26+)")
                        Text("• Solid Dark/Light/Auto: Opaque backgrounds")
                        Text("")
                        Text("Color options control the icon and progress bar appearance. Auto adapts to system theme.")
                    }
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Text("Live Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            CustomOSDView(
                                type: .constant(previewType),
                                value: .constant(previewValue),
                                icon: .constant("")
                            )
                            .frame(width: 200, height: 200)
                            
                            HStack(spacing: 8) {
                                Button("Volume") {
                                    previewType = .volume
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Brightness") {
                                    previewType = .brightness
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Backlight") {
                                    previewType = .backlight
                                }
                                .buttonStyle(.bordered)
                            }
                            .controlSize(.small)
                            
                            Slider(value: $previewValue, in: 0...1)
                                .frame(width: 160)
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                } header: {
                    Text("Preview")
                } footer: {
                    Text("Adjust settings above to see changes in real-time. The actual OSD appears at the bottom center of your screen.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Custom OSD")
        .onAppear {
            accessibilityPermission.refreshStatus()
        }
        .onChange(of: accessibilityPermission.isAuthorized) { _, granted in
            if !granted {
                enableCustomOSD = false
            }
        }
    }
}

struct SettingsPermissionCallout: View {
    let title: String
    let message: String
    let icon: String
    let iconColor: Color
    let requestButtonTitle: String
    let openSettingsButtonTitle: String
    let requestAction: () -> Void
    let openSettingsAction: () -> Void

    init(
        title: String = String(localized: "Accessibility permission required"),
        message: String,
        icon: String = "exclamationmark.triangle.fill",
        iconColor: Color = .orange,
        requestButtonTitle: String = String(localized: "Request Access"),
        openSettingsButtonTitle: String = String(localized: "Open Settings"),
        requestAction: @escaping () -> Void,
        openSettingsAction: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.iconColor = iconColor
        self.requestButtonTitle = requestButtonTitle
        self.openSettingsButtonTitle = openSettingsButtonTitle
        self.requestAction = requestAction
        self.openSettingsAction = openSettingsAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconColor)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button(requestButtonTitle) {
                    requestAction()
                }
                .buttonStyle(.borderedProminent)

                Button(openSettingsButtonTitle) {
                    openSettingsAction()
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    HUD()
}

struct NotesSettingsView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared

    private func highlightID(_ title: String) -> String {
        SettingsTab.notes.highlightID(for: title)
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(String(localized: "Enable Notes"), key: .enableNotes)
                if Defaults[.enableNotes] {
                    Defaults.Toggle(String(localized: "Enable Note Pinning"), key: .enableNotePinning)
                    Defaults.Toggle(String(localized: "Enable Note Search"), key: .enableNoteSearch)
                    Defaults.Toggle(String(localized: "Enable Color Filtering"), key: .enableNoteColorFiltering)
                    Defaults.Toggle(String(localized: "Enable Create from Clipboard"), key: .enableCreateFromClipboard)
                    Defaults.Toggle(String(localized: "Show Character Count"), key: .enableNoteCharCount)
                }
            } header: {
                Text("General")
            } footer: {
                Text("Customize how you organize and create notes. Enabling color filtering and search helps manage large lists.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notes")
    }
}
