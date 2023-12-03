//
//  PlanetSettingsView.swift
//  Planet
//
//  Created by Kai on 2/18/23.
//

import SwiftUI

struct PlanetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    @EnvironmentObject private var settingsViewModel: PlanetSettingsViewModel

    @State var serverOnlineStatus: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Server Info")
                ) {
                    Picker("Protocol", selection: $settingsViewModel.serverProtocol) {
                        Text("http").tag("http")
                        Text("https").tag("https")
                    }.pickerStyle(.navigationLink)

                    LabeledContent {
                        TextField(
                            "Host",
                            text: $settingsViewModel.serverHost,
                            prompt: Text("Host name or IP address")
                        )
                        .multilineTextAlignment(.trailing)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)

                    } label: {
                        Text("Host")
                    }

                    LabeledContent {
                        TextField(
                            "Port",
                            text: $settingsViewModel.serverPort,
                            prompt: Text("Port")
                        )
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                    } label: {
                        Text("Port")
                    }

                    Toggle("Authentication", isOn: $settingsViewModel.serverAuthenticationEnabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledContent {
                        TextField(
                            "Username",
                            text: $settingsViewModel.serverUsername,
                            prompt: Text("Username")
                        )
                        .multilineTextAlignment(.trailing)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                    } label: {
                        Text("Username")
                    }
                    .disabled(!settingsViewModel.serverAuthenticationEnabled)

                    LabeledContent {
                        SecureField(
                            "Password",
                            text: $settingsViewModel.serverPassword,
                            prompt: Text("Password")
                        )
                        .multilineTextAlignment(.trailing)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                    } label: {
                        Text("Password")
                    }
                    .disabled(!settingsViewModel.serverAuthenticationEnabled)

                    if settingsViewModel.isConnecting {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Connecting...")
                                .foregroundColor(.secondary)
                        }
                    }
                    else {
                        Button {
                            Task(priority: .userInitiated) {
                                await settingsViewModel.saveAndConnect()
                            }
                        } label: {
                            Text("Save and Connect")
                        }
                    }
                }
                .alert(isPresented: $settingsViewModel.showServerUnreachableAlert) {
                    Alert(
                        title: Text("Server Unreachable"),
                        message: Text("Please check the info you entered and try again."),
                        dismissButton: .cancel(Text("OK")))
                }

                Section(header: Text("Bonjour")) {
                    Button {
                        appViewModel.showBonjourList = true
                    } label: {
                        Text("Discover Nearby Servers")
                    }
                }

                Section(header: Text("Current Saved Server")) {
                    HStack {
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
                    }
                    if let nodeID = appViewModel.currentNodeID {
                        HStack(spacing: 10) {
                            Circle()
                                .frame(width: 14, height: 14)
                                .foregroundColor(.clear)
                            Text("\(nodeID)")
                                .font(.system(.callout, design: .monospaced))
                                .onTapGesture {
                                    UIPasteboard.general.string = nodeID
                                }
                        }
                    }
                }
            }
            .navigationTitle(PlanetAppTab.settings.name())
            .onReceive(settingsViewModel.timer) { t in
                Task { @MainActor in
                    let status = await PlanetStatus.shared.serverIsOnline()
                    self.serverOnlineStatus = status
                }
            }
            .onAppear {
                Task(priority: .userInitiated) {
                    let status = await PlanetStatus.shared.serverIsOnline()
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .sheet(isPresented: $appViewModel.showBonjourList) {
            BonjourListView()
        }
    }

    @ViewBuilder
    private func serverInfoSection() -> some View {
        Section {
            TextField(text: $settingsViewModel.serverURLString) {
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
