import SwiftUI

/// Switches between onboarding and the main app based on auth state.
struct RootView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        if auth.isAuthenticated {
            MainTabView()
                .transition(.opacity)
        } else {
            OnboardingView()
                .transition(.opacity)
        }
    }
}
