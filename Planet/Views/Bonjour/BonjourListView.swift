//
//  BonjourListView.swift
//  Planet
//
//  Created by Xin Liu on 10/28/23.
//

import SwiftUI
import Foundation

struct BonjourListView: View {
    @ObservedObject var viewModel = BonjourViewModel()

    var body: some View {
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
}

class BonjourViewModel: NSObject, ObservableObject {
    var browser: NetServiceBrowser?
    @Published var services: [NetService] = []

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
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        DispatchQueue.main.async {
            self.services.append(service)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
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
            let sockaddrPointer = data.withUnsafeBytes { $0.bindMemory(to: sockaddr.self).baseAddress! }
            getnameinfo(sockaddrPointer, socklen_t(data.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: hostname, encoding: .utf8)
            return ip != "127.0.0.1"
        }

        // Use usable IPv4 if found, otherwise use the first address
        let preferredAddress = usableIPv4 ?? addressData.first

        guard let address = preferredAddress else { return }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let sockaddrPointer = address.withUnsafeBytes { $0.bindMemory(to: sockaddr.self).baseAddress! }
        
        if getnameinfo(sockaddrPointer, socklen_t(address.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
            if let ip = String(cString: hostname, encoding: .utf8) {
                print("Service IP: \(ip), Port: \(sender.port)")

                // Set this IP and port to settings view
                let serverURL: String
                if ip.contains(":") {
                    serverURL = "http://[\(ip)]:\(sender.port)"
                } else {
                    serverURL = "http://\(ip):\(sender.port)"
                }
                PlanetSettingsViewModel.shared.serverURL = serverURL
                PlanetAppViewModel.shared.showBonjourList = false
            }
        }
    }
}

struct BonjourListView_Previews: PreviewProvider {
    static var previews: some View {
        BonjourListView()
    }
}

#Preview {
    BonjourListView()
}
