//
//  PlanetLatestViewModel.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import Foundation
import SwiftUI


class PlanetLatestViewModel: ObservableObject {
    static let shared = PlanetLatestViewModel()
    
    @Published private(set) var myArticles: [PlanetArticle] = []
    
    @MainActor
    func updateMyArticles(_ articles: [PlanetArticle]) {
        myArticles = articles.sorted(by: { a, b in
            return a.created > b.created
        })
    }
}
