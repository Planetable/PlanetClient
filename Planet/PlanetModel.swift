//
//  PlanetModel.swift
//  Planet
//
//  Created by Kai on 2/16/23.
//

import Foundation
import SwiftUI


enum PlanetAppTab: Int, Hashable {
    case latest
    case myPlanets
    case settings
    
    func name() -> String {
        switch self {
            case .latest:
                return "Latest"
            case .myPlanets:
                return "My Planets"
            case .settings:
                return "Settings"
        }
    }
}
