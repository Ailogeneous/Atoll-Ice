//
//  TabSelectionView.swift
//  DynamicIsland
//
//  Created by Hugo Persson on 2024-08-25.
//  Modified by Hariharan Mudaliar
import AtollExtensionKit
import SwiftUI
import Defaults

struct TabModel: Identifiable {
    let id: String
    let label: String
    let icon: String
    let view: NotchViews
    let experienceID: String?
    let accentColor: Color?

    init(label: String, icon: String, view: NotchViews, experienceID: String? = nil, accentColor: Color? = nil) {
        self.id = experienceID.map { "extension-\($0)" } ?? "system-\(view)-\(label)"
        self.label = label
        self.icon = icon
        self.view = view
        self.experienceID = experienceID
        self.accentColor = accentColor
    }
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @ObservedObject private var extensionNotchExperienceManager = ExtensionNotchExperienceManager.shared
    @Default(.enableTimerFeature) var enableTimerFeature
    @Default(.enableStatsFeature) var enableStatsFeature
    @Default(.enableColorPickerFeature) var enableColorPickerFeature
    @Default(.timerDisplayMode) var timerDisplayMode
    @Default(.enableThirdPartyExtensions) private var enableThirdPartyExtensions
    @Default(.enableExtensionNotchExperiences) private var enableExtensionNotchExperiences
    @Default(.enableExtensionNotchTabs) private var enableExtensionNotchTabs
    @Namespace var animation
    
    private var tabs: [TabModel] {
        var tabsArray: [TabModel] = []
        
        tabsArray.append(TabModel(label: "Home", icon: "house.fill", view: .home))

        if Defaults[.dynamicShelf] {
            tabsArray.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
        }
        
        if enableTimerFeature && timerDisplayMode == .tab {
            tabsArray.append(TabModel(label: "Timer", icon: "timer", view: .timer))
        }

        // Stats tab only shown when stats feature is enabled
        if Defaults[.enableStatsFeature] {
            tabsArray.append(TabModel(label: "Stats", icon: "chart.xyaxis.line", view: .stats))
        }

        if Defaults[.enableNotes] || (Defaults[.enableClipboardManager] && Defaults[.clipboardDisplayMode] == .separateTab) {
            let label = Defaults[.enableNotes] ? "Notes" : "Clipboard"
            let icon = Defaults[.enableNotes] ? "note.text" : "doc.on.clipboard"
            tabsArray.append(TabModel(label: label, icon: icon, view: .notes))
        }
        if extensionTabsEnabled {
            for payload in extensionTabPayloads {
                guard let tab = payload.descriptor.tab else { continue }
                let accent = payload.descriptor.accentColor.swiftUIColor
                let iconName = tab.iconSymbolName ?? "puzzlepiece.extension"
                tabsArray.append(
                    TabModel(
                        label: tab.title,
                        icon: iconName,
                        view: .extensionExperience,
                        experienceID: payload.descriptor.id,
                        accentColor: accent
                    )
                )
            }
        }
        
        return tabsArray
    }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                let isSelected = isSelected(tab)
                let activeAccent = tab.accentColor ?? .white
                TabButton(label: tab.label, icon: tab.icon, selected: isSelected) {
                    withAnimation(.smooth) {
                        if tab.view == .extensionExperience {
                            coordinator.selectedExtensionExperienceID = tab.experienceID
                        }
                        coordinator.currentView = tab.view
                    }
                }
                .frame(height: 26)
                .foregroundStyle(isSelected ? activeAccent : .gray)
                .background {
                    if isSelected {
                        Capsule()
                            .fill((tab.accentColor ?? Color(nsColor: .secondarySystemFill)).opacity(0.25))
                            .shadow(color: (tab.accentColor ?? .clear).opacity(0.4), radius: 8)
                            .matchedGeometryEffect(id: "capsule", in: animation)
                    } else {
                        Capsule()
                            .fill(Color.clear)
                            .matchedGeometryEffect(id: "capsule", in: animation)
                            .hidden()
                    }
                }
            }
        }
        .clipShape(Capsule())
    }

    private var extensionTabsEnabled: Bool {
        enableThirdPartyExtensions && enableExtensionNotchExperiences && enableExtensionNotchTabs
    }

    private var extensionTabPayloads: [ExtensionNotchExperiencePayload] {
        extensionNotchExperienceManager.activeExperiences.filter { $0.descriptor.tab != nil }
    }

    private func isSelected(_ tab: TabModel) -> Bool {
        if tab.view == .extensionExperience {
            return coordinator.currentView == .extensionExperience
                && coordinator.selectedExtensionExperienceID == tab.experienceID
        }
        return coordinator.currentView == tab.view
    }
}

#Preview {
    DynamicIslandHeader().environmentObject(DynamicIslandViewModel())
}
