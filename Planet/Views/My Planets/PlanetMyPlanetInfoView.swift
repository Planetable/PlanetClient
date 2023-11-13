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
    @State private var planetName: String = ""
    @State private var planetAbout: String = ""

    var body: some View {
        List {
            Section {
                planet.avatarView(.large)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if isEdit {
                TextField("Name", text: $planetName)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("Description", text: $planetAbout)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(planet.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(planet.about == "" ? "No description" : planet.about)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(planet.about == "" ? .secondary : .primary)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isEdit {
                    Button {
                        withAnimation {
                            isEdit = false
                        }
                        planetName = planet.name
                        planetAbout = planet.about
                    } label: {
                        Text("Cancel")
                    }
                }
                Button {
                    withAnimation {
                        isEdit.toggle()
                    }
                    Task(priority: .userInitiated) {
                        do {
                            try await self.updatePlanetInfo()
                        } catch {
                            debugPrint("failed to update planet info: \(error)")
                        }
                    }
                } label: {
                    Text(isEdit ? "Save" : "Edit")
                }
            }
        }
        .task {
            planetName = planet.name
            planetAbout = planet.about
        }
    }

    private func updatePlanetInfo() async throws {
        debugPrint("updating planet info ...")
    }
}


struct PlanetMyPlanetInfoView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetMyPlanetInfoView(planet: .empty())
    }
}
