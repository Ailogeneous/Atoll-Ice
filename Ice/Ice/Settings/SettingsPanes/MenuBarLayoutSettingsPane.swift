//
//  MenuBarLayoutSettingsPane.swift
//  Ice
//

import SwiftUI

struct MenuBarLayoutSettingsPane: View {
    private let visibleSectionWidthLimit: CGFloat = 660

    @EnvironmentObject var appState: AppState
    @State private var visibleSectionWidth: CGFloat?

    var body: some View {
        if !ScreenCapture.cachedCheckPermissions() {
            missingScreenRecordingPermission
        } else if appState.menuBarManager.isMenuBarHiddenBySystemUserDefaults {
            cannotArrange
        } else {
            IceForm(alignment: .leading, spacing: 20) {
                header
                layoutBars
            }
            .onAppear {
                Task {
                    await updateVisibleSectionWidth(refreshCache: true)
                }
            }
            .onReceive(appState.itemManager.$itemCache) { _ in
                Task {
                    await updateVisibleSectionWidth(refreshCache: false)
                }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        Text("Drag to arrange your menu bar items")
            .font(.title2)

        IceGroupBox {
            AnnotationView(
                alignment: .center,
                font: .callout.bold()
            ) {
                Label {
                    Text("Tip: you can also arrange menu bar items by Command + dragging them in the menu bar")
                } icon: {
                    Image(systemName: "lightbulb")
                }
            }
        }
    }

    @ViewBuilder
    private var layoutBars: some View {
        VStack(spacing: 25) {
            ForEach(MenuBarSection.Name.allCases, id: \.self) { section in
                layoutBar(for: section)
            }
        }
    }

    @ViewBuilder
    private var cannotArrange: some View {
        Text("Ice cannot arrange menu bar items in automatically hidden menu bars")
            .font(.title3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var missingScreenRecordingPermission: some View {
        VStack {
            Text("Menu bar layout requires screen recording permissions")
                .font(.title2)

            Button {
                appState.navigationState.settingsNavigationIdentifier = .advanced
            } label: {
                Text("Go to Advanced Settings")
            }
            .buttonStyle(.link)
        }
    }

    @ViewBuilder
    private func layoutBar(for section: MenuBarSection.Name) -> some View {
        if
            let section = appState.menuBarManager.section(withName: section),
            section.isEnabled
        {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(section.name.displayString) Section")
                    .font(.system(size: 14))
                    .padding(.leading, 2)

                LayoutBar(section: section)
                    .environmentObject(appState.imageCache)

                if section.name == .visible, let visibleSectionWidth {
                    let isOverLimit = visibleSectionWidth > visibleSectionWidthLimit

                    Text("Current Width: \(visibleSectionWidth, specifier: "%.1f") pt / \(visibleSectionWidthLimit, specifier: "%.0f") pt")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isOverLimit ? .red : .secondary)
                        .padding(.leading, 2)

                    if isOverLimit {
                        Text("Visible section exceeds the 660 pt limit. New drag placements into Visible are blocked until width is reduced.")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .padding(.leading, 2)
                    }
                }
            }
        }
    }

    private func updateVisibleSectionWidth(refreshCache: Bool) async {
        if refreshCache {
            await appState.itemManager.cacheItemsIfNeeded()
        }
        let width = appState.itemManager.itemCache
            .managedItems(for: .visible)
            .reduce(0) { $0 + $1.frame.width }
        await MainActor.run {
            visibleSectionWidth = width
        }
    }
}
