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
        willSet {
            if newValue != currentNodeID {
                debugPrint("👌 Current Node ID is: \(newValue)")
                Task(priority: .userInitiated) {
                    do {
                        if let newNodeID = newValue {
                            let (planets, articles) = try PlanetManager.shared.loadPlanetsAndArticlesFromNode(byID: newNodeID)
                            Task { @MainActor in
                                self.updateMyPlanets(planets)
                                self.updateMyArticles(articles)
                            }
                        } else {
                            Task { @MainActor in
                                self.updateMyPlanets([])
                                self.updateMyArticles([])
                            }
                        }
                    } catch {
                        debugPrint("failed to load planets from disk: \(error)")
                    }
                }
            }
        }
    }
    @Published var currentServerURLString: String = UserDefaults.standard.string(forKey: .settingsServerURLKey) ?? "" {
        willSet {
            if newValue != currentServerURLString {
                debugPrint("👌 Current Server URL is: \(newValue)")
            }
        }
    }
    @Published var showBonjourList = false
    @Published var showSettings = false
    @Published var newArticle = false
    @Published var newPlanet = false

    // MARK: -
    @Published private(set) var myPlanets: [Planet] = []
    @Published private(set) var myArticles: [PlanetArticle] = []
    
    init() {
        debugPrint("Planet App View Model Init.")
        guard let currentNodeID else {
            debugPrint("No active node id found, notify users for connecting to a server.")
            Task { @MainActor in
                self.showSettings = true
            }
            return
        }
        debugPrint("Last active node id: \(currentNodeID)")
        do {
            let (planets, articles) = try PlanetManager.shared.loadPlanetsAndArticlesFromNode(byID: currentNodeID)
            Task { @MainActor in
                self.updateMyPlanets(planets)
                self.updateMyArticles(articles)
            }
        } catch {
            debugPrint("failed to load planets from disk: \(error)")
        }
    }
    
    func reloadPlanets() async throws {
        let planets = try await PlanetManager.shared.getMyPlanets()
        Task { @MainActor in
            self.updateMyPlanets(planets)
        }
    }

    func reloadArticles() async throws {
        if myPlanets.count == 0 {
            let planets = try await PlanetManager.shared.getMyPlanets()
            Task { @MainActor in
                self.updateMyPlanets(planets)
                Task(priority: .utility) {
                    let articles = try await PlanetManager.shared.getMyArticles()
                    Task { @MainActor in
                        self.updateMyArticles(articles)
                    }
                }
            }
        } else {
            let articles = try await PlanetManager.shared.getMyArticles()
            Task { @MainActor in
                self.updateMyArticles(articles)
            }
        }
    }
    
    func reloadPlanetsAndArticles() async throws {
        let planets = try await PlanetManager.shared.getMyPlanets()
        Task { @MainActor in
            self.updateMyPlanets(planets)
            Task(priority: .userInitiated) {
                let articles = try await PlanetManager.shared.getMyArticles()
                Task { @MainActor in
                    self.updateMyArticles(articles)
                }
            }
        }
    }

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
