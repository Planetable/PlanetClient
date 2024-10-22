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

    @State private var serverURLString: String = ""
    @State private var serverProtocol: String = ""
    @State private var serverHost: String = ""
    @State private var serverPort: String = ""
    @State private var serverAuthenticationEnabled: Bool = false
    @State private var serverUsername: String = ""
    @State private var serverPassword: String = ""

    @State private var serverOnlineStatus: Bool = false
    @State private var isShowingConfirmResetLocalCache: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Server Info")
                ) {
                    Picker("Protocol", selection: $serverProtocol) {
                        Text("http").tag("http")
                        Text("https").tag("https")
                    }.pickerStyle(.navigationLink)

                    LabeledContent {
                        TextField(
                            "Host",
                            text: $serverHost,
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
                            text: $serverPort,
                            prompt: Text("Port")
                        )
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                    } label: {
                        Text("Port")
                    }

                    Toggle("Authentication", isOn: $serverAuthenticationEnabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledContent {
                        TextField(
                            "Username",
                            text: $serverUsername,
                            prompt: Text("Username")
                        )
                        .multilineTextAlignment(.trailing)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                    } label: {
                        Text("Username")
                    }
                    .disabled(!serverAuthenticationEnabled)

                    LabeledContent {
                        SecureField(
                            "Password",
                            text: $serverPassword,
                            prompt: Text("Password")
                        )
                        .multilineTextAlignment(.trailing)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                    } label: {
                        Text("Password")
                    }
                    .disabled(!serverAuthenticationEnabled)

                    if settingsViewModel.isConnecting {
                        connectingView()
                    } else {
                        Button {
                            Task(priority: .userInitiated) {
                                do {
                                    try await applyServerInformation()
                                    await settingsViewModel.saveAndConnect()
                                } catch {
                                    debugPrint("failed to save and connect to server: \(error)")
                                    Task { @MainActor in
                                        self.settingsViewModel.showServerUnreachableAlert = true
                                    }
                                }
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
                        dismissButton: .cancel(Text("OK"))
                    )
                }

                Section(header: Text("Bonjour")) {
                    Button {
                        appViewModel.showBonjourList = true
                    } label: {
                        Text("Discover Nearby Servers")
                    }
                }

                currentSavedServerSection()

                Section {
                    Button {
                        isShowingConfirmResetLocalCache = true
                    } label: {
                        Text("Reset Local Cache")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                Task(priority: .userInitiated) {
                    let status = await PlanetStatus.shared.serverIsOnline()
                    await MainActor.run {
                        self.serverOnlineStatus = status
                    }
                    guard status else { return }
                    guard
                        self.serverProtocol == "",
                        self.serverHost == "",
                        self.serverPort == "",
                        self.serverUsername == "",
                        self.serverPassword == ""
                    else { return }
                    Task { @MainActor in
                        await self.syncServerInformation()
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
        .confirmationDialog(String("Are you sure you want to remove all local cache?"), isPresented: $isShowingConfirmResetLocalCache, titleVisibility: .visible) {
            Button(role: .cancel) {
                isShowingConfirmResetLocalCache = false
            } label: {
                Text("Cancel")
            }
            Button(role: .destructive) {
                Task(priority: .userInitiated) {
                    await settingsViewModel.resetLocalCache()
                }
            } label: {
                Text("Reset")
            }
        } message: {
            Text("This will remove all local cache, including all attachments and drafts.")
        }
    }

    @MainActor
    private func syncServerInformation() async {
        self.serverURLString = self.settingsViewModel.serverURLString
        self.serverProtocol = self.settingsViewModel.serverProtocol
        self.serverHost = self.settingsViewModel.serverHost
        self.serverPort = self.settingsViewModel.serverPort
        self.serverAuthenticationEnabled = self.settingsViewModel.serverAuthenticationEnabled
        if self.serverAuthenticationEnabled && self.settingsViewModel.serverUsername != "" {
            self.serverUsername = self.settingsViewModel.serverUsername
            self.serverPassword = self.settingsViewModel.serverPassword
        } else {
            self.serverUsername = ""
            self.serverPassword = ""
        }
    }

    @MainActor
    private func applyServerInformation() async throws {
        guard !self.serverProtocol.isEmpty, !self.serverHost.isEmpty, !self.serverPort.isEmpty else {
            throw PlanetError.APIServerError
        }
        self.settingsViewModel.serverURLString = self.serverURLString
        self.settingsViewModel.serverProtocol = self.serverProtocol
        self.settingsViewModel.serverHost = self.serverHost
        self.settingsViewModel.serverPort = self.serverPort
        self.settingsViewModel.serverAuthenticationEnabled = self.serverAuthenticationEnabled
        self.settingsViewModel.serverUsername = self.serverUsername
        self.settingsViewModel.serverPassword = self.serverPassword
    }

    @ViewBuilder
    private func connectingView() -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .frame(width: 14, height: 14)
            Text("Connecting...")
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func currentSavedServerSection() -> some View {
        let serverName = appViewModel.currentServerName.count > 0 ? appViewModel.currentServerName : ""
        let serverURL = appViewModel.currentServerURLString
        Section(header: Text("Current Saved Server")) {
            HStack(spacing: 10) {
                Circle()
                    .frame(width: 14, height: 14)
                    .foregroundColor(serverOnlineStatus ? .green : .gray)
                if serverOnlineStatus {
                    Text("Server is connected.")
                } else {
                    Text("Server is not connected.")
                }
            }
            if serverName != "" {
                HStack(spacing: 10) {
                    Circle()
                        .frame(width: 14, height: 14)
                        .foregroundColor(.clear)
                    Text("\(serverName)")
                        .font(.system(.callout, design: .monospaced))
                }
            }
            if serverURL != "" {
                HStack(spacing: 10) {
                    Circle()
                        .frame(width: 14, height: 14)
                        .foregroundColor(.clear)
                    Text("\(serverURL)")
                        .font(.system(.callout, design: .monospaced))
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
            if serverName != "" {
                HStack {
                    if settingsViewModel.isConnecting {
                        connectingView()
                    } else {
                        Button {
                            Task { @MainActor in
                                if self.serverOnlineStatus {
                                    PlanetAppViewModel.shared.currentServerURLString = ""
                                    self.serverOnlineStatus = false
                                } else {
                                    await settingsViewModel.saveAndConnect()
                                }
                            }
                        } label: {
                            if serverOnlineStatus {
                                Text("Disconnect from \(serverName)")
                            } else {
                                Text("Reconnect to \(serverName)")
                            }
                        }
                    }
                    Spacer(minLength: 1)
                }
            }
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
