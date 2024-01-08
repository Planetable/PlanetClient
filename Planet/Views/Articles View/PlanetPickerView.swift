//
//  PlanetPickerView.swift
//  Planet
//

import SwiftUI

struct PlanetPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: PlanetAppViewModel

    @Binding var selectedPlanetIndex: Int
    @Binding var selectedPlanet: Planet?

    var body: some View {
        NavigationView {
            List {
                ForEach(appViewModel.myPlanets.indices, id: \.self) {
                    index in
                    let planet = appViewModel.myPlanets[index]
                    planet.listItemView(showCheckmark: selectedPlanetIndex == index)
                        .onTapGesture {
                            selectedPlanetIndex = index
                            selectedPlanet = planet
                            debugPrint("selected planet: \(planet)")
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                NotificationCenter.default.post(name: .reloadAvatar(byID: planet.id), object: nil)
                            }
                        }
                }
            }
            .navigationTitle("Select a Planet")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .disabled(appViewModel.myPlanets.count == 0)
        }
    }
}
