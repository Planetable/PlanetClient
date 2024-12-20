//
//  PlanetArticleTaskStatusView.swift
//  Planet
//

import Foundation
import SwiftUI


struct PlanetArticleTaskStatusView: View {
    @EnvironmentObject private var taskStatusViewModel: PlanetArticleTaskStatusViewModel
    
    @Binding var isShowingTaskStatus: Bool
    
    @State private var isVisible: Bool = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if isVisible {
                    HStack {
                        VStack {
                            Spacer()
                            if taskStatusViewModel.uploadTaskStatus != "" {
                                HStack {
                                    Text(taskStatusViewModel.uploadTaskStatus)
                                    Spacer()
                                }
                            }
                            if taskStatusViewModel.downloadTaskStatus != "" {
                                if taskStatusViewModel.uploadTaskStatus != "" {
                                    Divider()
                                }
                                HStack {
                                    Text(taskStatusViewModel.downloadTaskStatus)
                                    Spacer()
                                }
                            }
                            if taskStatusViewModel.uploadTaskStatus == "" && taskStatusViewModel.downloadTaskStatus == "" {
                                HStack {
                                    Text("No tasks running.")
                                    Spacer()
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                        Spacer()
                        Button {
                            withAnimation(.spring) {
                                isVisible = false
                                isShowingTaskStatus = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .padding(.trailing, 8)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring) {
                            isVisible = false
                            isShowingTaskStatus = false
                        }
                    }
                    .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .onChange(of: isShowingTaskStatus) { newValue in
            if isShowingTaskStatus && isVisible == false {
                withAnimation(.spring) {
                    isVisible = true
                }
            } else if isShowingTaskStatus == false && isVisible {
                withAnimation(.spring) {
                    isVisible = false
                }
            }
        }
        .task {
            guard isShowingTaskStatus, isVisible == false else { return }
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
