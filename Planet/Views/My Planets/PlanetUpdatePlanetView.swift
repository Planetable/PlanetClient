//
//  PlanetUpdatePlanetView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI


struct PlanetUpdatePlanetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var isCreating: Bool = false
    var planet: Planet?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack {
                    Text("Hi")
                    Spacer()
                }
            }
            .navigationTitle(isCreating ? "Create Planet" : "Edit Planet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Save")
                    }
                }
            }
        }
    }
}

struct PlanetUpdatePlanetView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetUpdatePlanetView()
    }
}
