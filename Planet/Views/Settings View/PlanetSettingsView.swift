//
//  PlanetSettingsView.swift
//  Planet
//
//  Created by Kai on 2/18/23.
//

import SwiftUI


struct PlanetSettingsView: View {
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    @EnvironmentObject private var settingsViewModel: PlanetSettingsViewModel
    
    @State private var serverOnlineStatus: Bool = false
    
    var body: some View {
        NavigationStack(path: $appViewModel.settingsTabPath) {
            ScrollView {
                serverInfoSection()
                    .padding(.horizontal, 12)
                Spacer(minLength: 48)
                serverStatusSection()
                    .padding(.horizontal, 12)
            }
            .navigationTitle(PlanetAppTab.settings.name())
            .frame(maxHeight: .infinity)
            .onReceive(settingsViewModel.timer) { t in
                Task(priority: .background) {
                    let status = await self.settingsViewModel.serverIsOnline()
                    await MainActor.run {
                        self.serverOnlineStatus = status
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func serverInfoSection() -> some View {
        Section {
            TextField(text: $settingsViewModel.serverURL) {
                Text("Server URL")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textFieldStyle(.roundedBorder)
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            
            Toggle("Server Authentication", isOn: $settingsViewModel.serverAuthenticationEnabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField(text: $settingsViewModel.serverUsername) {
                Text("Server Username")
            }
            .disabled(!settingsViewModel.serverAuthenticationEnabled)
            .textFieldStyle(.roundedBorder)
            
            TextField(text: $settingsViewModel.serverPassword) {
                Text("Server Password")
            }
            .disabled(!settingsViewModel.serverAuthenticationEnabled)
            .textFieldStyle(.roundedBorder)
        } header: {
            Text("Planet Server Info")
                .frame(maxWidth: .infinity, alignment: .leading)
        } footer: {
            Text("Example: http://127.0.0.1:9191")
                .disabled(true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(.footnote, design: .monospaced, weight: .light))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func serverStatusSection() -> some View {
        Section {
            HStack {
                Image(systemName: serverOnlineStatus ? "poweron" : "poweroff")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(serverOnlineStatus ? .green : .gray)
                    .cornerRadius(7)
                if serverOnlineStatus {
                    Text("Server is running.")
                } else {
                    Text("Server is inactive.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PlanetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsView()
    }
}
