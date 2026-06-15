import SwiftUI

/// A server the user has reached but not yet authenticated against.
struct DiscoveredServer: Hashable, Identifiable {
    let baseURLString: String
    let serverName: String
    var id: String { baseURLString }
}

struct OnboardingView: View {
    var body: some View {
        NavigationStack {
            AddServerView()
        }
    }
}
