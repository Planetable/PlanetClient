//
//  PlanetArticleTaskStatusView.swift
//  Planet
//

import Foundation
import SwiftUI


struct PlanetArticleTaskStatusView: View {
    @EnvironmentObject private var taskStatusViewModel: PlanetArticleTaskStatusViewModel

    @Binding var isShowingTaskStatus: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
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
                        isShowingTaskStatus = false
                    }
                }
                Spacer()
            }
        }
        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
        .padding(.horizontal, 8)
    }
}
