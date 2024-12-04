//
//  PlanetAppServerStatusView.swift
//  Planet
//

import SwiftUI


struct PlanetAppServerStatusView: View {
    @Binding var isShowingServerStatus: Bool
    @Binding var serverStatus: Bool

    @State private var isVisible: Bool = false

    var body: some View {
        VStack {
            if isVisible {
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
                        isVisible = false
                        isShowingServerStatus = false
                    }
                }
                .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .onChange(of: serverStatus) { _ in
            guard isShowingServerStatus, isVisible == false else { return }
            withAnimation(.spring) {
                isVisible = true
            }
        }
        .onChange(of: isShowingServerStatus) { newValue in
            if isShowingServerStatus && isVisible == false {
                withAnimation(.spring) {
                    isVisible = true
                }
            } else if isShowingServerStatus == false && isVisible {
                withAnimation(.spring) {
                    isVisible = false
                }
            }
        }
        .task {
            guard isShowingServerStatus, isVisible == false else { return }
            Task.detached(priority: .background) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let _ = await MainActor.run {
                    withAnimation(.spring) {
                        self.isVisible = true
                    }
                }
            }
        }
    }
}
