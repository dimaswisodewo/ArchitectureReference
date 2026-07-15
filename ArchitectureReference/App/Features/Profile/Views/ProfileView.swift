//
//  ProfileView.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if let profile = viewModel.state.data {
                profileContentView(profile: profile)
                    .overlay(updatingOverlay)
                    .animation(.default, value: viewModel.state.isLoading)
            } else {
                stateFallbackView
            }
        }
        .navigationTitle("Profile Info")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile()
        }
        .alert(item: errorBinding) { error in
            Alert(
                title: Text("Synchronization Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var updatingOverlay: some View {
        if viewModel.state.isLoading {
            ZStack {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Updating Profile...")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                .cornerRadius(16)
            }
            .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var stateFallbackView: some View {
        switch viewModel.state {
        case .idle:
            emptyStateView
            
        case .loading:
            // Fresh load: full screen spinner
            loadingView
            
        case .failure(let error, _):
            // Full screen error
            errorStateView(error: error)
            
        case .success:
            EmptyView()
        }
    }
    
    private var errorBinding: Binding<AlertError?> {
        Binding<AlertError?>(
            get: {
                if case .failure(let error, _) = viewModel.state {
                    return AlertError(message: error.localizedDescription)
                }
                return nil
            },
            set: { _ in
                viewModel.dismissError()
            }
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Syncing Profile...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No Profile Synchronized")
                .font(.headline)
            Button("Download Profile") {
                Task {
                    await viewModel.loadProfile()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func errorStateView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            Text("Failed to Load Profile")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                Task {
                    await viewModel.loadProfile()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func profileContentView(profile: ProfileEntity) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Profile Card
                VStack(spacing: 16) {
                    if let avatarUrl = profile.avatarUrl {
                        AsyncImage(url: avatarUrl) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 100, height: 100)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            case .failure:
                                fallbackAvatar
                            @unknown default:
                                fallbackAvatar
                            }
                        }
                    } else {
                        fallbackAvatar
                    }
                    
                    VStack(spacing: 4) {
                        Text(profile.fullName)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(profile.position)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                
                // Information Form Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("EMPLOYEE DETAILS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 0) {
                        infoRow(title: "NIK / ID", value: profile.id)
                        Divider().padding(.leading, 16)
                        infoRow(title: "Email Address", value: profile.email)
                        Divider().padding(.leading, 16)
                        infoRow(title: "Phone Number", value: profile.phoneNumber)
                        Divider().padding(.leading, 16)
                        infoRow(title: "Office Address", value: profile.address)
                        Divider().padding(.leading, 16)
                        infoRow(title: "Birth Date", value: profile.birthDate)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                
                // Action Items
                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.openSettings()
                    }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Account Settings")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.loadProfile(forceRefresh: true)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Remote Profile")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
    }
    
    private var fallbackAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .frame(width: 100, height: 100)
            .foregroundColor(.gray)
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Blur Effect Helper View
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

/// Identifiable wrapper for alerts.
struct AlertError: Identifiable {
    let id = UUID()
    let message: String
}
