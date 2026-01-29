/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import SwiftUI
import UniformTypeIdentifiers

struct AirDropView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    
    @State var trigger: UUID = .init()
    @State var targeting = false
    
    var body: some View {
        dropArea
            .onDrop(of: [.data], isTargeted: $vm.dropZoneTargeting) { providers in
                trigger = .init()
                vm.dropEvent = true
                DispatchQueue.global().async { beginDrop(providers) }
                return true
            }
    }
    
    var dropArea: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .opacity(0.5)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay { dropLabel }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
    }
    
    var dropLabel: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplayaudio")
            Text("AirDrop")
        }
        .foregroundStyle(.gray)
        .font(.system(.headline, design: .rounded))
        .contentShape(Rectangle())
        .onTapGesture {
            trigger = .init()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let picker = NSOpenPanel()
                picker.allowsMultipleSelection = true
                picker.canChooseDirectories = true
                picker.canChooseFiles = true
                picker.begin { response in
                    if response == .OK {
                        let drop = AirDrop(files: picker.urls)
                        drop.begin()
                    }
                }
            }
        }
    }
    
    func beginDrop(_ providers: [NSItemProvider]) {
        assert(!Thread.isMainThread)
        guard let urls = providers.interfaceConvert() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let drop = AirDrop(files: urls)
            drop.begin()
        }
    }
}
