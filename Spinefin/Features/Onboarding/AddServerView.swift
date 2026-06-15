import SwiftUI

/// Step 1 of onboarding: enter a Jellyfin server address and validate it.
struct AddServerView: View {
    @Environment(\.palette) private var p

    @State private var urlText = ""
    @State private var isChecking = false
    @State private var errorMessage: String?
    @State private var discovered: DiscoveredServer?

    var body: some View {
        ZStack {
            SpineBackground()
            RadialGradient(
                colors: [p.accentSoft, .clear],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                SpineMark()

                Text("Connect your server")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(p.text)
                    .padding(.top, 26)

                Text("Point Spinefin at your Jellyfin server to start listening to your library.")
                    .font(.system(size: 16))
                    .foregroundStyle(p.text2)
                    .lineSpacing(3)
                    .frame(maxWidth: 300, alignment: .leading)
                    .padding(.top, 10)

                Text("SERVER URL")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(p.text2)
                    .padding(.leading, 4)
                    .padding(.top, 30)
                    .padding(.bottom, 8)

                GlassField(systemImage: "globe") {
                    TextField("https://jellyfin.home.local", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .onSubmit(connect)
                        .foregroundStyle(p.text)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(p.accent)
                        .padding(.top, 12)
                }

                PillButton(title: isChecking ? "Connecting…" : "Continue", filled: true) {
                    connect()
                }
                .padding(.top, 20)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
                .overlay {
                    if isChecking {
                        ProgressView().tint(p.onAccent)
                    }
                }

                OrDivider()

                NavigationLink(value: QuickConnectStart(urlText: urlText)) {
                    Text("Use Quick Connect")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(p.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(p.glassFill)
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(p.glassBorder, lineWidth: 0.5))
                        }
                }
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)

                Text("Self-hosted & private. Your library never\nleaves your server.")
                    .font(.system(size: 13))
                    .foregroundStyle(p.text3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .navigationDestination(item: $discovered) { server in
            LoginView(server: server)
        }
        .navigationDestination(for: QuickConnectStart.self) { start in
            if let url = AddServerView.normalizedURL(from: start.urlText) {
                QuickConnectView(server: DiscoveredServer(baseURLString: url.absoluteString, serverName: "Jellyfin"))
            }
        }
    }

    private func connect() {
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard let baseURL = Self.normalizedURL(from: trimmed) else {
            errorMessage = "That doesn't look like a valid address."
            return
        }
        errorMessage = nil
        isChecking = true

        Task {
            defer { isChecking = false }
            do {
                let api = JellyfinAPI(baseURL: baseURL)
                let info = try await api.publicSystemInfo()
                discovered = DiscoveredServer(
                    baseURLString: baseURL.absoluteString,
                    serverName: info.serverName ?? "Jellyfin"
                )
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Couldn't reach a Jellyfin server at that address."
            }
        }
    }

    /// Accepts bare hosts and adds a scheme; defaults to http for LAN-style addresses.
    static func normalizedURL(from input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        guard let url = URL(string: text), url.host != nil else { return nil }
        return url
    }
}

/// Routing value so "Use Quick Connect" can go straight from the server screen.
struct QuickConnectStart: Hashable {
    let urlText: String
}

/// The amber app mark — a rounded tile with two "spine" bars.
struct SpineMark: View {
    @Environment(\.palette) private var p
    var size: CGFloat = 64

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3)
            .fill(LinearGradient(
                colors: [p.accent, Color(hslHue: 18, saturation: 0.62, lightness: 0.40)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
            .overlay {
                HStack(spacing: 5) {
                    Capsule().fill(p.onAccent).opacity(0.92).frame(width: 7, height: size * 0.47)
                    Capsule().fill(p.onAccent).opacity(0.55).frame(width: 4, height: size * 0.31)
                }
            }
            .shadow(color: p.shadow, radius: 18, y: 12)
    }
}

struct GlassField<Content: View>: View {
    @Environment(\.palette) private var p
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(p.text3)
            content
                .font(.system(size: 16))
        }
        .padding(.horizontal, 15)
        .frame(height: 52)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(p.glassFill)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(p.glassBorder, lineWidth: 0.5))
        }
    }
}

struct OrDivider: View {
    @Environment(\.palette) private var p
    var label: String = "or"
    var body: some View {
        HStack(spacing: 14) {
            Rectangle().fill(p.sep).frame(height: 1)
            Text(label).font(.system(size: 13)).foregroundStyle(p.text3).fixedSize()
            Rectangle().fill(p.sep).frame(height: 1)
        }
        .padding(.vertical, 24)
    }
}
