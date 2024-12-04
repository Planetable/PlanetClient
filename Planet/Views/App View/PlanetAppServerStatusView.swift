//
//  PlanetAppServerStatusView.swift
//  Planet
//

import SwiftUI


struct PlanetAppServerStatusView: View {
    @Binding var isShowingServerStatus: Bool
    @Binding var serverStatus: Bool

    var body: some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: serverStatus ? "bolt.fill" : "bolt.slash.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 16)
                Group {
                    if serverStatus {
                        Text("Server Connected")
                    } else {
                        Text("Server Disconnected")
                    }
                }
                .font(.footnote)
            }
            .foregroundStyle(serverStatus ? .green : .gray)
            .frame(height: 24)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring) {
                    isShowingServerStatus = false
                }
            }
            Spacer()
        }
        .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
    }
}
