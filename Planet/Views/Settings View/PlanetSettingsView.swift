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
                LazyVStack {
                    serverInfoSection()
                    Spacer(minLength: 48)
                    serverStatusSection()

                    Button {
                        appViewModel.showBonjourList = true
                    } label: {
                        Text("Discover Nearby Servers")
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 10)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.automatic)
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
            .onAppear {
                Task(priority: .background) {
                    self.settingsViewModel.resetPreviousServerInfo()
                    let status = await self.settingsViewModel.serverIsOnline()
                    await MainActor.run {
                        self.serverOnlineStatus = status
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        dismissKeyboard()
                    } label: {
                        Text("Dismiss")
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
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textFieldStyle(.roundedBorder)

            SecureField(text: $settingsViewModel.serverPassword) {
                Text("Server Password")
            }
            .disabled(!settingsViewModel.serverAuthenticationEnabled)
            .textFieldStyle(.roundedBorder)
        } header: {
            Text("Planet Server Info")
                .frame(maxWidth: .infinity, alignment: .leading)
        } footer: {
            Text("Example: http://127.0.0.1:4321")
                .disabled(true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(.footnote, design: .monospaced, weight: .light))
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
    }

    @ViewBuilder
    private func serverStatusSection() -> some View {
        Section {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .frame(width: 14, height: 14)
                        .foregroundColor(serverOnlineStatus ? .green : .gray)
                    if serverOnlineStatus {
                        Text("Server is connected.")
                    }
                    else {
                        Text("Server is not connected.")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let nodeID = appViewModel.currentNodeID {
                    HStack(spacing: 10) {
                        Circle()
                            .frame(width: 14, height: 14)
                            .foregroundColor(.clear)
                        Text("\(nodeID)")
                            .font(.system(.footnote, design: .monospaced, weight: .light))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.move(edge: .top))
                }
            }

        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

struct PlanetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsView()
    }
}
