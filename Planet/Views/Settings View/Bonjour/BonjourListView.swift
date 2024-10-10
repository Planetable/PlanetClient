//
//  BonjourListView.swift
//  Planet
//
//  Created by Xin Liu on 10/28/23.
//

import Foundation
import SwiftUI

struct BonjourListView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel = BonjourViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Scanning nearby Planet servers")
                    Spacer()
                    ProgressView()
                }
                .padding()
                List(viewModel.services, id: \.name) { service in
                    Button(action: {
                        viewModel.resolveService(service: service)
                    }) {
                        Text(service.name)
                    }
                }
                .onAppear {
                    viewModel.startScanning()
                }
                .onDisappear {
                    viewModel.stopScanning()
                }
            }
            .navigationTitle("Discover Nearby Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert("Authtication", isPresented: $viewModel.isShowingAuth, actions: {
                TextField("Username", text: $viewModel.username)
                SecureField("Password", text: $viewModel.password)
                Button {
                    Task {
                        await MainActor.run {
                            PlanetAppViewModel.shared.showBonjourList = false
                            PlanetSettingsViewModel.shared.serverAuthenticationEnabled = true
                            PlanetSettingsViewModel.shared.serverUsername = self.viewModel.username
                            PlanetSettingsViewModel.shared.serverPassword = self.viewModel.password
                        }
                        try? await Task.sleep(for: .seconds(1))
                        await PlanetSettingsViewModel.shared.saveAndConnect()
                    }
                } label: {
                    Text("Login")
                }
                Button {
                    Task { @MainActor in
                        PlanetAppViewModel.shared.showBonjourList = false
                        self.viewModel.username = ""
                        self.viewModel.password = ""
                    }
                } label: {
                    Text("Cancel")
                }
            }, message: {
                Text("Please enter username and password for the server.")
            })
        }
    }
}

class BonjourViewModel: NSObject, ObservableObject {
    var browser: NetServiceBrowser?
    @Published var services: [NetService] = []

    @Published var isShowingAuth: Bool = false
    @Published var username: String = ""
    @Published var password: String = ""

    func startScanning() {
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: "_planet._tcp.", inDomain: "local.")
    }

    func stopScanning() {
        browser?.stop()
        browser = nil
    }

    func resolveService(service: NetService) {
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }
}

extension BonjourViewModel: NetServiceBrowserDelegate {
    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        DispatchQueue.main.async {
            debugPrint("Bonjour: found new service: \(service)")
            self.services.append(service)
        }
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        DispatchQueue.main.async {
            self.services.removeAll(where: { $0 == service })
        }
    }
}

extension BonjourViewModel: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addressData = sender.addresses else { return }

        // Filter IPv4 addresses and exclude 127.0.0.1
        let filteredIPv4Addresses = addressData.filter { data in
            let pointer = data.withUnsafeBytes { $0.bindMemory(to: sockaddr.self).baseAddress! }
            return pointer.pointee.sa_family == AF_INET
        }

        let usableIPv4 = filteredIPv4Addresses.first { data in
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let sockaddrPointer = data.withUnsafeBytes {
                $0.bindMemory(to: sockaddr.self).baseAddress!
            }
            getnameinfo(
                sockaddrPointer,
                socklen_t(data.count),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            let ip = String(cString: hostname, encoding: .utf8)
            return ip != "127.0.0.1"
        }

        // Use usable IPv4 if found, otherwise use the first address
        let preferredAddress = usableIPv4 ?? addressData.first

        guard let address = preferredAddress else { return }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let sockaddrPointer = address.withUnsafeBytes {
            $0.bindMemory(to: sockaddr.self).baseAddress!
        }

        if getnameinfo(
            sockaddrPointer,
            socklen_t(address.count),
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0 {
            if let ip = String(cString: hostname, encoding: .utf8) {
                // Set this IP and port to settings view
                let serverURL: String
                if ip.contains(":") {
                    serverURL = "http://[\(ip)]:\(sender.port)"
                } else {
                    serverURL = "http://\(ip):\(sender.port)"
                }
                let serverPort = sender.port
                debugPrint("Service IP: \(ip), Port: \(serverPort), URL: \(serverURL)")
                Task(priority: .userInitiated) {
                    await MainActor.run {
                        PlanetSettingsViewModel.shared.serverProtocol = "http"
                        PlanetSettingsViewModel.shared.serverHost = ip
                        PlanetSettingsViewModel.shared.serverPort = "\(serverPort)"
                    }
                    var request = URLRequest(url: URL(string: serverURL)!.appendingPathComponent("/v0/ping"))
                    request.httpMethod = "GET"
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                        await MainActor.run {
                            self.isShowingAuth = true
                        }
                        return
                    }
                    await MainActor.run {
                        PlanetAppViewModel.shared.showBonjourList = false
                    }
                    try? await Task.sleep(for: .seconds(1))
                    await PlanetSettingsViewModel.shared.saveAndConnect()
                }
            }
        }
    }
}

struct BonjourListView_Previews: PreviewProvider {
    static var previews: some View {
        BonjourListView()
    }
}
