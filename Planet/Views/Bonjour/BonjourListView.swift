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
        guard let addressData = sender.addresses?.first else { return }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let sockaddrPointer = addressData.withUnsafeBytes { $0.bindMemory(to: sockaddr.self).baseAddress! }
        
        if getnameinfo(sockaddrPointer, socklen_t(addressData.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
            if let ip = String(cString: hostname, encoding: .utf8) {
                print("Service IP: \(ip), Port: \(sender.port)")
                // Set this IP and port to settings view
                PlanetSettingsViewModel.shared.serverURL = "http://\(ip):\(sender.port)"
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
