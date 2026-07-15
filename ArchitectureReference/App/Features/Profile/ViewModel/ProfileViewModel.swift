//
//  ProfileViewModel.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    
    // MARK: - Published States
    
    @Published private(set) var state: ViewState<ProfileEntity> = .idle
    
    // MARK: - Dependencies
    
    private let getProfileUseCase: GetProfileUseCase
    private weak var navigator: ProfileNavigator?
    
    // MARK: - Initializer
    
    init(
        getProfileUseCase: GetProfileUseCase,
        navigator: ProfileNavigator
    ) {
        self.getProfileUseCase = getProfileUseCase
        self.navigator = navigator
    }
    
    // MARK: - User Intents
    
    /// Triggers profile retrieval from use cases.
    func loadProfile(forceRefresh: Bool = false) async {
        let previousData = state.data
        state = .loading(previousData: previousData)
        
        do {
            let profile = try await getProfileUseCase.execute(forceRefresh: forceRefresh)
            state = .success(profile)
        } catch {
            state = .failure(error, previousData: previousData)
        }
    }
    
    /// Safely clears/dismisses the error state, reverting to success if previous data is available.
    func dismissError() {
        if case .failure(_, let previousData) = state {
            if let data = previousData {
                state = .success(data)
            } else {
                state = .idle
            }
        }
    }
    
    /// Directs coordinator to navigate to the settings screen.
    func openSettings() {
        navigator?.navigateToSettings()
    }
}
