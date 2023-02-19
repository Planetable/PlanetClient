//
//  PlanetMyPlanetsItemView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI
import CachedAsyncImage


struct PlanetMyPlanetsItemView: View {
    var planet: Planet
    
    var body: some View {
        HStack(spacing: 12) {
            PlanetAvatarView(planet: planet)
            VStack {
                Text(planet.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(planet.about == "" ? "No description" : planet.about)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(planet.about == "" ? .secondary.opacity(0.5) : .secondary)
            }
            .multilineTextAlignment(.leading)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, minHeight: 48, idealHeight: 48, maxHeight: 96, alignment: .leading)
    }
    
}

struct PlanetMyPlanetsItemView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetsItemView(planet: .empty())
    }
}
