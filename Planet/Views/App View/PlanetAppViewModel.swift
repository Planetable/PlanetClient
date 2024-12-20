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
    @Published var currentNodeID: String? = PlanetManager.shared.userDefaults.string(forKey: .settingsNodeIDKey) {
        willSet {
            if newValue != currentNodeID {
                debugPrint("👌 New Node ID is: \(String(describing: newValue))")
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
                                self.resetAndChooseServer()
                            }
                        }
                    } catch {
                        debugPrint("failed to load planets from disk: \(error)")
                    }
                }
            }
        }
    }
    @Published var currentServerName: String = PlanetManager.shared.userDefaults.string(forKey: .settingsServerNameKey) ?? ""
    @Published var currentServerURLString: String = PlanetManager.shared.userDefaults.string(forKey: .settingsServerURLKey) ?? "" {
        willSet {
            if newValue != currentServerURLString {
                debugPrint("👌 Current Server URL is: \(newValue)")
            }
        }
    }
    @Published var searchText: String = ""
    @Published var showBonjourList = false
    @Published var showSettings = false
    @Published var chooseServer = false
    @Published var newArticle = false
    @Published var newArticleDraft = false
    @Published var newPlanet = false
    @Published var resumeNewArticle = false
    @Published var resumedArticleDraft: PlanetArticle?
    @Published var failedToReload = false
    @Published var failedToCreateArticle = false
    @Published var failedMessage = ""

    // MARK: -
    @Published private(set) var myPlanets: [Planet] = []
    @Published private(set) var myArticles: [PlanetArticle] = []
    @Published private(set) var drafts: [PlanetArticle] = []

    init() {
        guard let currentNodeID else {
            debugPrint("No active node id found, notify users for connecting to a server.")
            Task { @MainActor in
                self.resetAndChooseServer()
            }
            return
        }
        debugPrint("Try to load from last active node id: \(currentNodeID)")
        Task.detached(priority: .background) {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                let (planets, articles) = try PlanetManager.shared.loadPlanetsAndArticlesFromNode(byID: currentNodeID)
                Task { @MainActor in
                    self.updateMyPlanets(planets)
                    self.updateMyArticles(articles)
                }
            } catch {
                debugPrint("failed to load planets from disk with last active node id: \(currentNodeID), error: \(error)")
                Task { @MainActor in
                    self.resetAndChooseServer()
                }
                return
            }
            do {
                let drafts = try PlanetManager.shared.loadArticleDrafts()
                Task { @MainActor in
                    self.updateDrafts(drafts)
                }
            } catch {
                debugPrint("failed to load drafts: \(error)")
            }
            Task { @MainActor in
                do {
                    try await PlanetAppViewModel.shared.reloadPlanetsAndArticles()
                } catch {
                    debugPrint("failed to reload planets and articles.")
                }
            }
        }
    }

    var filteredResults: [PlanetArticle] {
        if searchText.isEmpty {
            if selectedTab == .drafts {
                return drafts
            }
            return myArticles
        }

        let searchTerms = searchText.split(separator: " ")
        let sources: [PlanetArticle] = selectedTab == .drafts ? drafts : myArticles

        return sources.filter { article in
            for term in searchTerms {
                let termString = String(term)
                // Only match whole words or file extensions
                let wholeWordMatches = { (text: String) -> Bool in
                    text.range(of: "\\b\(termString)\\b",
                               options: [.regularExpression, .caseInsensitive]) != nil
                }

                if let title = article.title, wholeWordMatches(title) {
                    return true
                }
                if let summary = article.summary, wholeWordMatches(summary) {
                    return true
                }
                if let content = article.content, wholeWordMatches(content) {
                    return true
                }
                if let attachments = article.attachments,
                   attachments.contains(where: { $0.localizedCaseInsensitiveContains(termString) }) {
                    return true
                }
            }
            return false
        }
    }

    @MainActor
    func resetAndChooseServer() {
        self.chooseServer = true
        self.updateMyPlanets([])
        self.updateMyArticles([])
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
        debugPrint("updating my planets: \(planets.count)")
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
        debugPrint("updating my articles: \(articles.count)")
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

    @MainActor
    func updateDrafts(_ articles: [PlanetArticle]) {
        debugPrint("updating drafts: \(articles.count)")
        withAnimation {
            drafts = articles.sorted(by: { a, b in
                return a.created > b.created
            })
        }
    }

    @MainActor
    func removeDraft(_ draft: PlanetArticle) {
        withAnimation {
            drafts = drafts.filter({ a in
                return a.id != draft.id
            })
        }
        Task(priority: .userInitiated) {
            PlanetManager.shared.removeArticleDraft(draft)
        }
    }
}
