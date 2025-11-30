//
//  ProfileSelectionView.swift
//  DynamicIsland
//
//  Created on 2025-10-05.
//

import SwiftUI
import Defaults

struct UserProfile: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let gradient: [Color]
}

struct ProfileSelectionView: View {
    @State private var selectedProfiles: Set<String> = []
    let onContinue: (Set<String>) -> Void
    
    let profiles: [UserProfile] = [
        UserProfile(
            id: "developer",
            name: "Developer",
            icon: "terminal.fill",
            description: "Code and debug with color picker, stats monitoring, and screen assistant.",
            gradient: [Color.blue, Color.purple]
        ),
        UserProfile(
            id: "designer",
            name: "Designer",
            icon: "paintbrush.fill",
            description: "Create and design with color picker, mirror, and visual effects.",
            gradient: [Color.pink, Color.orange]
        ),
        UserProfile(
            id: "lightuse",
            name: "Light Use",
            icon: "sparkles",
            description: "Simple and minimal interface with just the essentials for everyday tasks.",
            gradient: [Color.green, Color.mint]
        ),
        UserProfile(
            id: "student",
            name: "Student",
            icon: "book.fill",
            description: "Stay organized with calendar, timer, and battery monitoring.",
            gradient: [Color.indigo, Color.cyan]
        )
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(.bottom, 8)
                
                Text("Choose Your Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Select one or more profiles to customize your experience")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 20)
            
            // Profile Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(profiles) { profile in
                    ProfileCard(
                        profile: profile,
                        isSelected: selectedProfiles.contains(profile.id),
                        onTap: {
                            toggleProfile(profile.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                if !selectedProfiles.isEmpty {
                    onContinue(selectedProfiles)
                }
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedProfiles.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
    
    private func toggleProfile(_ profileId: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedProfiles.contains(profileId) {
                selectedProfiles.remove(profileId)
            } else {
                selectedProfiles.insert(profileId)
            }
        }
    }
}

struct ProfileCard: View {
    let profile: UserProfile
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: profile.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(.linearGradient(colors: profile.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.linearGradient(colors: profile.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Text(profile.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(profile.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? 
                          LinearGradient(colors: profile.gradient.map { $0.opacity(0.15) }, startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [Color.gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? 
                        LinearGradient(colors: profile.gradient, startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isSelected ? 2 : 0
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .shadow(color: isSelected ? profile.gradient[0].opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Profile Settings Configuration

func applyProfileSettings(_ profiles: Set<String>) {
    // Clipboard is ALWAYS enabled (per user request)
    Defaults[.enableClipboardManager] = true
    
    // Developer Profile Settings
    let isDeveloper = profiles.contains("developer")
    if isDeveloper {
        Defaults[.enableColorPickerFeature] = true
        Defaults[.enableStatsFeature] = true
        Defaults[.enableTimerFeature] = true
        Defaults[.enableScreenAssistant] = true
        Defaults[.showMirror] = false
        Defaults[.enableMinimalisticUI] = false
    }
    
    // Designer Profile Settings
    let isDesigner = profiles.contains("designer")
    if isDesigner {
        Defaults[.enableColorPickerFeature] = true
        Defaults[.showMirror] = true
        Defaults[.lightingEffect] = true
        Defaults[.inlineHUD] = true
        Defaults[.enableStatsFeature] = false
        Defaults[.enableTimerFeature] = false
        Defaults[.enableMinimalisticUI] = false
        Defaults[.enableScreenAssistant] = false
    }
    
    // Light Use Profile Settings
    let isLightUse = profiles.contains("lightuse")
    if isLightUse {
        Defaults[.enableMinimalisticUI] = true
        Defaults[.enableColorPickerFeature] = false
        Defaults[.showMirror] = false
        Defaults[.enableStatsFeature] = false
        Defaults[.enableTimerFeature] = true
        Defaults[.inlineHUD] = false
        Defaults[.enableScreenAssistant] = false
        Defaults[.enableLyrics] = false
    }
    
    // Student Profile Settings
    let isStudent = profiles.contains("student")
    if isStudent {
        Defaults[.enableTimerFeature] = true
        Defaults[.showCalendar] = true
        Defaults[.enableColorPickerFeature] = false
        Defaults[.showMirror] = false
        Defaults[.enableStatsFeature] = false
        Defaults[.enableMinimalisticUI] = false
        Defaults[.enableScreenAssistant] = false
    }
    
    // If Light Use is NOT selected but others are, ensure minimalistic is OFF
    if !isLightUse && !profiles.isEmpty {
        Defaults[.enableMinimalisticUI] = false
    }
    
    // Common settings for all profiles
    Defaults[.menubarIcon] = true
    Defaults[.enableHaptics] = true
    
    print("✅ Applied profile settings for: \(profiles.joined(separator: ", "))")
}

#Preview {
    ProfileSelectionView(onContinue: { profiles in
        print("Selected profiles: \(profiles)")
    })
}
