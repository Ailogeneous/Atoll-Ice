//
//  AnimationEditorView.swift
//  DynamicIsland
//
//  Created by AI Assistant on 11/10/2025.
//  Editor for resizing, repositioning, and cropping Lottie animations
//

import SwiftUI
import LottieUI
import Defaults

struct AnimationEditorView: View {
    @Environment(\.dismiss) var dismiss
    
    let sourceURL: URL
    let isRemoteURL: Bool
    @Binding var animation: CustomIdleAnimation?
    let existingAnimation: CustomIdleAnimation?
    
    @State private var name: String
    @State private var speed: CGFloat = 1.0
    @State private var scale: CGFloat = 1.0
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @State private var cropWidth: CGFloat = 30
    @State private var cropHeight: CGFloat = 20
    @State private var rotation: CGFloat = 0
    @State private var opacity: CGFloat = 1.0
    @State private var paddingBottom: CGFloat = 0
    @State private var expandWithAnimation: Bool = false
    @State private var loopMode: AnimationLoopMode = .loop
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isImporting = false
    
    // Preview state
    @State private var previewScale: CGFloat = 1.0
    
    init(sourceURL: URL, isRemoteURL: Bool, animation: Binding<CustomIdleAnimation?>, existingAnimation: CustomIdleAnimation? = nil) {
        self.sourceURL = sourceURL
        self.isRemoteURL = isRemoteURL
        self._animation = animation
        self.existingAnimation = existingAnimation
        
        // Initialize from existing animation if editing, otherwise from URL
        if let existing = existingAnimation {
            _name = State(initialValue: existing.name)
            _speed = State(initialValue: existing.speed)
            
            // Load from overrides if they exist
            let config = Defaults[.animationTransformOverrides][existing.id.uuidString] ?? .default
            _scale = State(initialValue: config.scale)
            _offsetX = State(initialValue: config.offsetX)
            _offsetY = State(initialValue: config.offsetY)
            _cropWidth = State(initialValue: config.cropWidth)
            _cropHeight = State(initialValue: config.cropHeight)
            _rotation = State(initialValue: config.rotation)
            _opacity = State(initialValue: config.opacity)
            _paddingBottom = State(initialValue: config.paddingBottom)
            _expandWithAnimation = State(initialValue: config.expandWithAnimation)
            _loopMode = State(initialValue: config.loopMode)
        } else {
            let fileName = sourceURL.deletingPathExtension().lastPathComponent
            _name = State(initialValue: fileName)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingAnimation != nil ? "Edit Animation" : "Customize Animation")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            
            Divider()
            
            HSplitView {
                // Preview Panel
                VStack {
                    Text("Preview")
                        .font(.headline)
                        .padding(.top)
                    
                    ZStack {
                        // Background to show bounds
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        // Target size indicator (30x20 - actual size in notch)
                        Rectangle()
                            .strokeBorder(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .frame(width: 30 * previewScale, height: 20 * previewScale)
                        
                        // Animation preview with transformations
                        if let existing = existingAnimation, case .builtInFace = existing.source {
                            // Show built-in face
                            MinimalFaceFeatures(height: 20, width: 30)
                                .scaleEffect(previewScale)
                                .frame(width: cropWidth * scale * previewScale, height: cropHeight * scale * previewScale)
                                .offset(x: offsetX * previewScale, y: offsetY * previewScale)
                                .rotationEffect(.degrees(rotation))
                                .opacity(opacity)
                                .padding(.bottom, paddingBottom * previewScale)
                                .clipped()
                        } else {
                            // Show Lottie animation
                            LottieView(state: LUStateData(
                                type: .loadedFrom(sourceURL),
                                speed: speed,
                                loopMode: loopMode.lottieLoopMode
                            ))
                            .frame(width: cropWidth * scale * previewScale, height: cropHeight * scale * previewScale)
                            .offset(x: offsetX * previewScale, y: offsetY * previewScale)
                            .rotationEffect(.degrees(rotation))
                            .opacity(opacity)
                            .padding(.bottom, paddingBottom * previewScale)
                            .clipped()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    
                    // Preview Scale Control
                    HStack {
                        Text("Preview Zoom:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $previewScale, in: 1...10)
                            .frame(width: 150)
                        Text("\(Int(previewScale))x")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .frame(minWidth: 300)
                
                Divider()
                
                // Controls Panel
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Animation Name")
                                .font(.headline)
                            TextField("Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Divider()
                        
                        // Size Controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Size & Scale")
                                .font(.headline)
                            
                            // Scale
                            HStack {
                                Text("Scale:")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $scale, in: 0.1...5.0)
                                Text(String(format: "%.2f", scale))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Button("Reset") {
                                    withAnimation { scale = 1.0 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            // Crop Width
                            HStack {
                                Text("Width:")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $cropWidth, in: 5...100)
                                Text(String(format: "%.0f", cropWidth))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Button("30") {
                                    withAnimation { cropWidth = 30 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            // Crop Height
                            HStack {
                                Text("Height:")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $cropHeight, in: 5...100)
                                Text(String(format: "%.0f", cropHeight))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Button("20") {
                                    withAnimation { cropHeight = 20 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        Divider()
                        
                        // Position Controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Position")
                                .font(.headline)
                            
                            // Offset X
                            HStack {
                                Text("Horizontal:")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $offsetX, in: -50...50)
                                Text(String(format: "%.1f", offsetX))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Button("Center") {
                                    withAnimation { offsetX = 0 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            // Offset Y
                            HStack {
                                Text("Vertical:")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $offsetY, in: -50...50)
                                Text(String(format: "%.1f", offsetY))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Button("Center") {
                                    withAnimation { offsetY = 0 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            // Padding Bottom
                            HStack {
                                Text("Bottom Pad:")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $paddingBottom, in: -20...20)
                                Text(String(format: "%.1f", paddingBottom))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Button("Reset") {
                                    withAnimation { paddingBottom = 0 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        Divider()
                        
                        // Rotation & Opacity
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transform")
                                .font(.headline)
                            
                            // Rotation
                            HStack {
                                Text("Rotation:")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $rotation, in: -180...180)
                                Text(String(format: "%.0f°", rotation))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Button("Reset") {
                                    withAnimation { rotation = 0 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            // Opacity
                            HStack {
                                Text("Opacity:")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $opacity, in: 0...1)
                                Text(String(format: "%.0f%%", opacity * 100))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Button("100%") {
                                    withAnimation { opacity = 1.0 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        Divider()
                        
                        // Animation Speed
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Animation")
                                .font(.headline)
                            
                            HStack {
                                Text("Speed:")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $speed, in: 0.1...3.0)
                                Text(String(format: "%.2fx", speed))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Button("1x") {
                                    withAnimation { speed = 1.0 }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            // Loop Mode
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Loop Mode:")
                                    .font(.subheadline)
                                Picker("Loop Mode", selection: $loopMode) {
                                    ForEach(AnimationLoopMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        Divider()
                        
                        // Display Options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Display Options")
                                .font(.headline)
                            
                            Toggle(isOn: $expandWithAnimation) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Expand Notch with Animation")
                                        .font(.body)
                                    Text("When enabled, the Atoll will expand horizontally to match the animation size")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Presets
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Presets")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                Button("Fit to Notch") {
                                    withAnimation {
                                        scale = 1.0
                                        cropWidth = 30
                                        cropHeight = 20
                                        offsetX = 0
                                        offsetY = 0
                                        rotation = 0
                                        paddingBottom = 0
                                        expandWithAnimation = false
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Fill Notch") {
                                    withAnimation {
                                        scale = 1.5
                                        cropWidth = 30
                                        cropHeight = 20
                                        offsetX = 0
                                        offsetY = 0
                                        paddingBottom = 0
                                        expandWithAnimation = false
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Scale Up 2x") {
                                    withAnimation {
                                        scale = 2.0
                                        expandWithAnimation = true
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Scale Down") {
                                    withAnimation {
                                        scale = 0.75
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Reset All") {
                                    withAnimation {
                                        scale = 1.0
                                        cropWidth = 30
                                        cropHeight = 20
                                        offsetX = 0
                                        offsetY = 0
                                        rotation = 0
                                        opacity = 1.0
                                        speed = 1.0
                                        paddingBottom = 0
                                        expandWithAnimation = false
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                    }
                    .padding()
                }
                .frame(minWidth: 350, maxWidth: 450)
            }
            
            Divider()
            
            // Footer with actions
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Blue dashed box shows actual size in Atoll")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(existingAnimation != nil ? "Save Changes" : "Import") {
                    importAnimation()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || isImporting)
            }
            .padding()
        }
        .frame(idealWidth: 900, idealHeight: 650)
        .frame(minWidth: 800, minHeight: 600)
        .fixedSize()
        .alert("Import Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Import Logic
    
    private func importAnimation() {
        guard !name.isEmpty else { return }
        
        isImporting = true
        
        // Create animation config with transform settings
        let config = AnimationTransformConfig(
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY,
            cropWidth: cropWidth,
            cropHeight: cropHeight,
            rotation: rotation,
            opacity: opacity,
            paddingBottom: paddingBottom,
            expandWithAnimation: expandWithAnimation,
            loopMode: loopMode
        )
        
        // If editing existing animation, save transform config to overrides
        if let existing = existingAnimation {
            // Store only the transform config override
            var overrides = Defaults[.animationTransformOverrides]
            overrides[existing.id.uuidString] = config
            Defaults[.animationTransformOverrides] = overrides
            
            print("✅ [AnimationEditor] Saved transform override for: \(existing.name)")
            print("✅ [AnimationEditor] Override: \(config)")
            
            // Force view refresh by updating selectedIdleAnimation if this is the selected one
            if Defaults[.selectedIdleAnimation]?.id == existing.id {
                // Trigger refresh by re-setting the same animation
                let current = Defaults[.selectedIdleAnimation]
                Defaults[.selectedIdleAnimation] = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    Defaults[.selectedIdleAnimation] = current
                }
            }
            
            dismiss()
            return
        }
        
        // Import with config (new animation)
        let result = IdleAnimationManager.shared.importLottieFile(
            from: sourceURL,
            name: name,
            speed: speed
        )
        
        switch result {
        case .success(let importedAnimation):
            animation = importedAnimation
            dismiss()
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
            isImporting = false
        }
    }
}

// MARK: - Preview
#Preview {
    AnimationEditorView(
        sourceURL: URL(string: "https://assets9.lottiefiles.com/packages/lf20_mniampqn.json")!,
        isRemoteURL: true,
        animation: .constant(nil)
    )
}
