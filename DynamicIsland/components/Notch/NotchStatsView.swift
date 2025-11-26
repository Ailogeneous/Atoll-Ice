//
//  NotchStatsView.swift
//  DynamicIsland
//
//  Adapted from boring.notch StatsView 
//  Stats tab view for system performance monitoring with clickable process popovers

import SwiftUI
import Defaults

// Graph data protocol for unified interface
protocol GraphData {
    var title: String { get }
    var color: Color { get }
    var icon: String { get }
    var type: GraphType { get }
}

enum GraphType {
    case single
    case dual
}

// Single value graph data
struct SingleGraphData: GraphData {
    let title: String
    let value: String
    let data: [Double]
    let color: Color
    let icon: String
    let type: GraphType = .single
}

// Dual value graph data (for network/disk)
struct DualGraphData: GraphData {
    let title: String
    let positiveValue: String
    let negativeValue: String
    let positiveData: [Double]
    let negativeData: [Double]
    let positiveColor: Color
    let negativeColor: Color
    let color: Color // Primary color for the component
    let icon: String
    let type: GraphType = .dual
}

struct NotchStatsView: View {
    @ObservedObject var statsManager = StatsManager.shared
    @Default(.enableStatsFeature) var enableStatsFeature
    @Default(.showCpuGraph) var showCpuGraph
    @Default(.showMemoryGraph) var showMemoryGraph
    @Default(.showGpuGraph) var showGpuGraph
    @Default(.showNetworkGraph) var showNetworkGraph
    @Default(.showDiskGraph) var showDiskGraph
    @State private var showingCPUPopover = false
    @State private var showingMemoryPopover = false
    @State private var showingGPUPopover = false
    @State private var showingNetworkPopover = false
    @State private var showingDiskPopover = false
    @State private var isHoveringCPUPopover = false
    @State private var isHoveringMemoryPopover = false
    @State private var isHoveringGPUPopover = false
    @State private var isHoveringNetworkPopover = false
    @State private var isHoveringDiskPopover = false
    @State private var isResizingForStats = false
    @State private var statsHoverGraceActive = false
    @State private var statsHoverGraceWorkItem: DispatchWorkItem?
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared

    var availableGraphs: [GraphData] {
        var graphs: [GraphData] = []

        if showCpuGraph {
            graphs.append(SingleGraphData(
                title: "CPU",
                value: statsManager.cpuUsageString,
                data: statsManager.cpuHistory,
                color: .blue,
                icon: "cpu"
            ))
        }

        if showMemoryGraph {
            graphs.append(SingleGraphData(
                title: "Memory",
                value: statsManager.memoryUsageString,
                data: statsManager.memoryHistory,
                color: .green,
                icon: "memorychip"
            ))
        }

        if showGpuGraph {
            graphs.append(SingleGraphData(
                title: "GPU",
                value: statsManager.gpuUsageString,
                data: statsManager.gpuHistory,
                color: .purple,
                icon: "display"
            ))
        }

        if showNetworkGraph {
            graphs.append(DualGraphData(
                title: "Network",
                positiveValue: "↓" + statsManager.networkDownloadString,
                negativeValue: "↑" + statsManager.networkUploadString,
                positiveData: statsManager.networkDownloadHistory,
                negativeData: statsManager.networkUploadHistory,
                positiveColor: .orange,
                negativeColor: .red,
                color: .orange,
                icon: "network"
            ))
        }

        if showDiskGraph {
            graphs.append(DualGraphData(
                title: "Disk",
                positiveValue: "R " + statsManager.diskReadString,
                negativeValue: "W " + statsManager.diskWriteString,
                positiveData: statsManager.diskReadHistory,
                negativeData: statsManager.diskWriteHistory,
                positiveColor: .cyan,
                negativeColor: .yellow,
                color: .cyan,
                icon: "internaldrive"
            ))
        }

        return graphs
    }

    // Smart grid layout system for different graph counts
    @ViewBuilder
    var statsGridLayout: some View {
        let graphCount = availableGraphs.count

        if graphCount <= 3 {
            // 1-3 graphs: Single row with equal spacing
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: graphCount),
                spacing: 12
            ) {
                ForEach(0..<graphCount, id: \.self) { index in
                    graphViewForIndex(index)
                }
            }
        } else if graphCount == 4 {
            // 4 graphs: second row scales from zero height on tab open
            VStack(spacing: 0) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                    spacing: 12
                ) {
                    ForEach(0..<2, id: \.self) { index in
                        graphViewForIndex(index)
                    }
                }

                StatsCollapsibleRow(
                    expansion: coordinator.statsSecondRowExpansion,
                    height: statsSecondRowContentHeight + statsGridSpacingHeight
                ) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 12
                    ) {
                        ForEach(2..<graphCount, id: \.self) { index in
                            graphViewForIndex(index)
                        }
                    }
                    .padding(.top, statsGridSpacingHeight)
                }
            }
        } else {
            // 5 graphs: First row 3 graphs, second row 2 graphs (half-width each)
            VStack(spacing: 0) {
                // First row: 3 graphs
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(0..<3, id: \.self) { index in
                        graphViewForIndex(index)
                    }
                }
                // Second row: 2 graphs (half-width each)
                StatsCollapsibleRow(
                    expansion: coordinator.statsSecondRowExpansion,
                    height: statsSecondRowContentHeight + statsGridSpacingHeight
                ) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        ForEach(3..<graphCount, id: \.self) { index in
                            graphViewForIndex(index)
                        }
                    }
                    .padding(.top, statsGridSpacingHeight)
                }
            }
        }
    }

    @ViewBuilder
    private func graphViewForIndex(_ index: Int) -> some View {
        let graphData = availableGraphs[index]

        if let rankingType = rankingTypeForGraph(graphData) {
            Button(action: {
                handleGraphClick(for: graphData)
            }) {
                UnifiedStatsCard(graphData: graphData)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: bindingForGraph(graphData)) {
                RankedProcessPopover(
                    rankingType: rankingType,
                    onHoverChange: { hovering in
                        switch graphData.title {
                        case "CPU":
                            isHoveringCPUPopover = hovering
                        case "Memory":
                            isHoveringMemoryPopover = hovering
                        case "GPU":
                            isHoveringGPUPopover = hovering
                        case "Network":
                            isHoveringNetworkPopover = hovering
                        case "Disk":
                            isHoveringDiskPopover = hovering
                        default:
                            break
                        }
                    }
                )
                .onDisappear {
                    switch graphData.title {
                    case "CPU":
                        isHoveringCPUPopover = false
                    case "Memory":
                        isHoveringMemoryPopover = false
                    case "GPU":
                        isHoveringGPUPopover = false
                    case "Network":
                        isHoveringNetworkPopover = false
                    case "Disk":
                        isHoveringDiskPopover = false
                    default:
                        break
                    }
                    DispatchQueue.main.async {
                        updateStatsPopoverState()
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4)),
                removal: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4))
            ))
        } else {
            UnifiedStatsCard(graphData: graphData)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4)),
                    removal: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4))
                ))
        }
    }

    private func handleGraphClick(for graphData: GraphData) {
        switch graphData.title {
        case "CPU":
            showingCPUPopover = true
        case "Memory":
            showingMemoryPopover = true
        case "GPU":
            showingGPUPopover = true
        case "Network":
            showingNetworkPopover = true
        case "Disk":
            showingDiskPopover = true
        default:
            break
        }
    }

    private func bindingForGraph(_ graphData: GraphData) -> Binding<Bool> {
        switch graphData.title {
        case "CPU":
            return $showingCPUPopover
        case "Memory":
            return $showingMemoryPopover
        case "GPU":
            return $showingGPUPopover
        case "Network":
            return $showingNetworkPopover
        case "Disk":
            return $showingDiskPopover
        default:
            return .constant(false)
        }
    }

    private func rankingTypeForGraph(_ graphData: GraphData) -> ProcessRankingType? {
        switch graphData.title {
        case "CPU":
            return .cpu
        case "Memory":
            return .memory
        case "GPU":
            return .gpu
        case "Network":
            return .network
        case "Disk":
            return .disk
        default:
            return nil
        }
    }
    
    // Helper function to create graph views using unified component
    @ViewBuilder
    func graphView(for graphData: GraphData) -> some View {
        UnifiedStatsCard(graphData: graphData)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !enableStatsFeature {
                // Disabled state
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("Stats Disabled")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Enable stats monitoring in Settings to view system performance data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if availableGraphs.isEmpty {
                // No graphs enabled state
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No Graphs Enabled")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Enable graph visibility in Settings → Stats to view performance data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                VStack(spacing: 8) {
                    statsGridLayout
                }
                .padding(12)
                .animation(.easeInOut(duration: 0.4), value: availableGraphs.count)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4)),
                    removal: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4))
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Note: Smart monitoring will handle starting/stopping based on notch state and current view
            // Protect against hover interference during view transition
            isResizingForStats = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isResizingForStats = false
            }
        }
        .onDisappear {
            statsHoverGraceWorkItem?.cancel()
            statsHoverGraceWorkItem = nil
            if statsHoverGraceActive {
                statsHoverGraceActive = false
            }
            // Keep monitoring running when tab is not visible
            updateStatsPopoverState()
        }
        .animation(.easeInOut(duration: 0.4), value: enableStatsFeature)
        .animation(.easeInOut(duration: 0.4), value: availableGraphs.count)
        .onChange(of: availableGraphs.count) { _, _ in
            // Protect against hover interference during dynamic sizing
            isResizingForStats = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isResizingForStats = false
            }
        }
        .onChange(of: showingCPUPopover) { _, newValue in
            if newValue {
                activateStatsHoverGrace()
            } else {
                deactivateStatsHoverGrace()
            }
            updateStatsPopoverState()
        }
        .onChange(of: showingMemoryPopover) { _, newValue in
            if newValue {
                activateStatsHoverGrace()
            } else {
                deactivateStatsHoverGrace()
            }
            updateStatsPopoverState()
        }
        .onChange(of: showingGPUPopover) { _, newValue in
            if newValue {
                activateStatsHoverGrace()
            } else {
                deactivateStatsHoverGrace()
            }
            updateStatsPopoverState()
        }
        .onChange(of: showingNetworkPopover) { _, newValue in
            if newValue {
                activateStatsHoverGrace()
            } else {
                deactivateStatsHoverGrace()
            }
            updateStatsPopoverState()
        }
        .onChange(of: showingDiskPopover) { _, newValue in
            if newValue {
                activateStatsHoverGrace()
            } else {
                deactivateStatsHoverGrace()
            }
            updateStatsPopoverState()
        }
        .onChange(of: isHoveringCPUPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: isHoveringMemoryPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: isHoveringGPUPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: isHoveringNetworkPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: isHoveringDiskPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: coordinator.statsSecondRowExpansion) { _, newValue in
            let shouldHold = availableGraphs.count >= 4 && newValue < 0.999
            if shouldHold {
                isResizingForStats = true
            } else {
                DispatchQueue.main.async {
                    isResizingForStats = false
                }
            }
        }
    }


private struct StatsCollapsibleRow<Content: View>: View {
    let expansion: CGFloat
    let height: CGFloat
    let content: () -> Content
    private let minVisibleHeight: CGFloat = 0.5

    init(expansion: CGFloat, height: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.expansion = expansion
        self.height = height
        self.content = content
    }

    var body: some View {
        let clamped = max(0, min(expansion, 1))
        let targetHeight = clamped == 0 ? 0 : max(height * clamped, minVisibleHeight)

        return Group {
            if targetHeight == 0 {
                Color.clear.frame(height: 0)
            } else {
                content()
                    .frame(height: height, alignment: .top)
                    .clipped()
                    .mask(
                        Rectangle()
                            .frame(height: targetHeight)
                            .frame(maxWidth: .infinity, alignment: .top)
                    )
                    .frame(height: targetHeight, alignment: .top)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: clamped)
    }
}
    private func activateStatsHoverGrace(duration: TimeInterval = 0.45) {
        statsHoverGraceWorkItem?.cancel()
        statsHoverGraceActive = true
        let workItem = DispatchWorkItem {
            statsHoverGraceActive = false
            statsHoverGraceWorkItem = nil
            updateStatsPopoverState()
        }
        statsHoverGraceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func deactivateStatsHoverGrace() {
        statsHoverGraceWorkItem?.cancel()
        statsHoverGraceWorkItem = nil
        if statsHoverGraceActive {
            statsHoverGraceActive = false
        }
    }
    
    private func updateStatsPopoverState() {
        let anyPopoverOpen = showingCPUPopover || showingMemoryPopover || showingGPUPopover || showingNetworkPopover || showingDiskPopover
        let newState = anyPopoverOpen || isResizingForStats || statsHoverGraceActive
        if vm.isStatsPopoverActive != newState {
            vm.isStatsPopoverActive = newState
            #if DEBUG
            print("📊 Stats popover state updated: \(newState)")
            print("   CPU open=\(showingCPUPopover)")
            print("   Memory open=\(showingMemoryPopover)")
            print("   GPU open=\(showingGPUPopover)")
            print("   Network open=\(showingNetworkPopover)")
            print("   Disk open=\(showingDiskPopover)")
            print("   Resizing: \(isResizingForStats)")
            print("   Hover grace: \(statsHoverGraceActive)")
            #endif
        }
    }
}

// Unified Stats Card Component - handles both single and dual data types, matches boring.notch sizing
struct UnifiedStatsCard: View {
    let graphData: GraphData
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 3) { // Match boring.notch spacing
            // Header - consistent across all card types
            HStack(spacing: 4) {
                Image(systemName: graphData.icon)
                    .foregroundColor(graphData.color)
                    .font(.caption) // Match boring.notch font size
                
                Text(graphData.title)
                    .font(.caption) // Match boring.notch font size
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Show value on right for single graphs like boring.notch
                if let singleData = graphData as? SingleGraphData {
                    Text(singleData.value)
                        .font(.caption) // Match boring.notch font size
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            
            // Values section for dual graphs only
            if let dualData = graphData as? DualGraphData {
                HStack(spacing: 6) {
                    Text(dualData.positiveValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(dualData.positiveColor)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(dualData.negativeValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(dualData.negativeColor)
                }
                .frame(height: 18) // Smaller for dual graphs
            }
            
            // Graph section - adapts based on graph type
            Group {
                if let singleData = graphData as? SingleGraphData {
                    MiniGraph(data: singleData.data, color: singleData.color)
                } else if let dualData = graphData as? DualGraphData {
                    DualQuadrantGraph(
                        positiveData: dualData.positiveData,
                        negativeData: dualData.negativeData,
                        positiveColor: dualData.positiveColor,
                        negativeColor: dualData.negativeColor
                    )
                }
            }
            .frame(height: 36) // Match boring.notch exactly - reduced from 50
            
            // Click hint - shown for graphs that open popovers
            if ["CPU", "Memory", "GPU", "Network", "Disk"].contains(graphData.title) {
                Text("Click for details")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
        }
        .padding(8) // Match boring.notch padding - reduced from 10
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.7)) // Match boring.notch opacity
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(graphData.color.opacity(isHovered ? 0.5 : 0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct MiniGraph: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.max() ?? 1.0
            let normalizedData = maxValue > 0 ? data.map { $0 / maxValue } : data
            
            Path { path in
                guard !normalizedData.isEmpty else { return }
                
                let stepX = geometry.size.width / CGFloat(normalizedData.count - 1)
                
                for (index, value) in normalizedData.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height * (1 - CGFloat(value))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 2)
            
            // Gradient fill
            Path { path in
                guard !normalizedData.isEmpty else { return }
                
                let stepX = geometry.size.width / CGFloat(normalizedData.count - 1)
                
                path.move(to: CGPoint(x: 0, y: geometry.size.height))
                
                for (index, value) in normalizedData.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height * (1 - CGFloat(value))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}



struct DualQuadrantGraph: View {
    let positiveData: [Double]
    let negativeData: [Double]
    let positiveColor: Color
    let negativeColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            let maxPositive = positiveData.max() ?? 1.0
            let maxNegative = negativeData.max() ?? 1.0
            let maxValue = max(maxPositive, maxNegative)
            
            let normalizedPositive = maxValue > 0 ? positiveData.map { $0 / maxValue } : positiveData
            let normalizedNegative = maxValue > 0 ? negativeData.map { $0 / maxValue } : negativeData
            
            let centerY = geometry.size.height / 2
            
            ZStack {
                // Center dividing line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: centerY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                
                // Positive quadrant (upper half)
                Path { path in
                    guard !normalizedPositive.isEmpty else { return }
                    
                    let stepX = geometry.size.width / CGFloat(normalizedPositive.count - 1)
                    
                    for (index, value) in normalizedPositive.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = centerY - (centerY * CGFloat(value)) // Above center
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(positiveColor, lineWidth: 2)
                
                // Positive fill
                Path { path in
                    guard !normalizedPositive.isEmpty else { return }
                    
                    let stepX = geometry.size.width / CGFloat(normalizedPositive.count - 1)
                    
                    path.move(to: CGPoint(x: 0, y: centerY))
                    
                    for (index, value) in normalizedPositive.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = centerY - (centerY * CGFloat(value))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [positiveColor.opacity(0.3), positiveColor.opacity(0.1)]),
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                
                // Negative quadrant (lower half)
                Path { path in
                    guard !normalizedNegative.isEmpty else { return }
                    
                    let stepX = geometry.size.width / CGFloat(normalizedNegative.count - 1)
                    
                    for (index, value) in normalizedNegative.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = centerY + (centerY * CGFloat(value)) // Below center
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(negativeColor, lineWidth: 2)
                
                // Negative fill
                Path { path in
                    guard !normalizedNegative.isEmpty else { return }
                    
                    let stepX = geometry.size.width / CGFloat(normalizedNegative.count - 1)
                    
                    path.move(to: CGPoint(x: 0, y: centerY))
                    
                    for (index, value) in normalizedNegative.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = centerY + (centerY * CGFloat(value))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [negativeColor.opacity(0.3), negativeColor.opacity(0.1)]),
                        startPoint: .bottom,
                        endPoint: .center
                    )
                )
            }
        }
    }
}

#Preview {
    NotchStatsView()
        .frame(width: 400, height: 300)
        .background(Color.black)
}
