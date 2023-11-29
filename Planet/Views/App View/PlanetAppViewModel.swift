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

    @Published var path: NavigationPath = NavigationPath()
    @Published var selectedTab: PlanetAppTab = PlanetAppTab(rawValue: UserDefaults.standard.integer(forKey: .settingsSelectedTabKey)) ?? .latest {
        didSet {
            UserDefaults.standard.set(selectedTab.rawValue, forKey: .settingsSelectedTabKey)
        }
    }
    @Published var currentNodeID: String? = UserDefaults.standard.string(forKey: .settingsNodeIDKey) {
        didSet {
            guard let currentNodeID else { return }
            UserDefaults.standard.setValue(currentNodeID, forKey: .settingsNodeIDKey)
        }
    }
    @Published var showBonjourList = false
    @Published var showSettings = false
    @Published var newArticle = false
    @Published var newPlanet = false

    // MARK: -
    @Published private(set) var myPlanets: [Planet] = []
    @Published private(set) var myArticles: [PlanetArticle] = []

    @MainActor
    func updateMyPlanets(_ planets: [Planet]) {
        debugPrint("updated my planets: \(planets.count)")
        myPlanets = planets.sorted(by: { a, b in
            return a.created > b.created
        })
        Task(priority: .background) {
            for planet in planets {
                planet.reloadTemplate()
            }
        }
    }

    @MainActor
    func updateMyArticles(_ articles: [PlanetArticle]) {
        debugPrint("updated my articles: \(articles.count)")
        myArticles = articles.sorted(by: { a, b in
            return a.created > b.created
        })
        Task(priority: .background) {
            var planets: [Planet] = []
            for article in articles {
                guard let planetID = article.planetID, let planet = Planet.getPlanet(forID: planetID.uuidString) else { continue }
                if planets.contains(planet) { continue }
                planets.append(planet)
            }
            for planet in planets {
                planet.reloadTemplate()
            }
        }
    }
}
