//
//  PlanetMyPlanetInfoView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI


struct PlanetMyPlanetInfoView: View {
    var planet: Planet
    
    var body: some View {
        Text(planet.name)
    }
}


struct PlanetMyPlanetInfoView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetInfoView(planet: .empty())
    }
}
