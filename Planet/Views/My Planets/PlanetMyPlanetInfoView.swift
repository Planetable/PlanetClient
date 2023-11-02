//
//  PlanetMyPlanetInfoView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI


struct PlanetMyPlanetInfoView: View {
    var planet: Planet
    
    @State private var isEdit: Bool = false
    
    var body: some View {
        List {
            Section {
                PlanetAvatarView(planet: planet, size: CGSize(width: 96, height: 96))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Text(planet.name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(planet.about == "" ? "No description" : planet.about)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(planet.about == "" ? .secondary : .primary)
        }
        .toolbar {
            // MARK: TODO: Edit planet info.
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isEdit {
                    Button {
                        withAnimation {
                            isEdit = false
                        }
                    } label: {
                        Text("Cancel")
                    }
                }
                Button {
                    withAnimation {
                        isEdit.toggle()
                    }
                } label: {
                    Text(isEdit ? "Save" : "Edit")
                }
            }
        }
    }
}


struct PlanetMyPlanetInfoView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetInfoView(planet: .empty())
    }
}
