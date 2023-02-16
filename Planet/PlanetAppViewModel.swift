//
//  PlanetAppViewModel.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import Foundation
import SwiftUI


class PlanetAppViewModel: ObservableObject {
    static let shared = PlanetAppViewModel()
    
    @Published var selectedTab: PlanetAppTab = PlanetAppTab(rawValue: UserDefaults.standard.integer(forKey: .settingsSelectedTabKey)) ?? .latest {
        didSet {
            UserDefaults.standard.set(selectedTab.rawValue, forKey: .settingsSelectedTabKey)
        }
    }
}
