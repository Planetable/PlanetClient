//
//  PlanetMyPlanetsViewModel.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI


class PlanetMyPlanetsViewModel: ObservableObject {
    static let shared = PlanetMyPlanetsViewModel()
    
    @Published private(set) var myPlanets: [Planet] = []
    
    @MainActor
    func updateMyPlanets(_ planets: [Planet]) {
        myPlanets = planets.sorted(by: { a, b in
            return a.created > b.created
        })
    }
}
