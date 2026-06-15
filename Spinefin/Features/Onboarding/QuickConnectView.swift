import SwiftUI

/// Quick Connect: display the server-issued code, poll until the user approves it
/// from another signed-in Jellyfin session, then finish authentication.
struct QuickConnectView: View {
    let server: DiscoveredServer

    @Environment(\.palette) private var p
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .loading
    @State private var code: String?

    private enum Phase: Equatable {
        case loading, waiting, unavailable(String)
    }

    private var api: JellyfinAPI {
        JellyfinAPI(baseURL: URL(string: server.baseURLString)!)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpineBackground()
                content.padding(.horizontal, 28)
            }
            .navigationTitle("Quick Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(p.accent)
                }
            }
        }
        .task { await start() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView().tint(p.accent)

        case .waiting:
            VStack(spacing: 0) {
                SpineMark(size: 56)
                Text("Enter this code")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(p.text)
                    .padding(.top, 22)
                Text("Open Jellyfin → Quick Connect on any signed-in device and enter the code below. This screen finishes automatically.")
                    .font(.system(size: 14))
                    .foregroundStyle(p.text2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 6)

                CodeBoxes(code: code ?? "")
                    .padding(.top, 26)

                HStack(spacing: 8) {
                    ProgressView().tint(p.accent).controlSize(.small)
                    Text("Waiting for approval…")
                        .font(.system(size: 13))
                        .foregroundStyle(p.text3)
                }
                .padding(.top, 22)
            }

        case .unavailable(let message):
            ContentUnavailableView {
                Label("Quick Connect unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        }
    }

    private func start() async {
        do {
            guard try await api.quickConnectEnabled() else {
                phase = .unavailable("This server doesn't have Quick Connect enabled.")
                return
            }
            let initiated = try await api.quickConnectInitiate()
            code = initiated.code
            phase = .waiting
            await poll(secret: initiated.secret)
        } catch {
            phase = .unavailable(
                (error as? LocalizedError)?.errorDescription ?? "Couldn't start Quick Connect."
            )
        }
    }

    private func poll(secret: String) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            do {
                let state = try await api.quickConnectState(secret: secret)
                if state.authenticated {
                    let result = try await api.authenticateWithQuickConnect(secret: secret)
                    auth.add(ServerConnection(
                        serverName: server.serverName,
                        baseURLString: server.baseURLString,
                        userId: result.user.id,
                        username: result.user.name,
                        accessToken: result.accessToken,
                        serverId: result.serverId
                    ))
                    dismiss()
                    return
                }
            } catch {
                continue
            }
        }
    }
}

/// Six monospaced boxes showing the Quick Connect code.
private struct CodeBoxes: View {
    @Environment(\.palette) private var p
    let code: String

    var body: some View {
        let chars = Array(code.padding(toLength: 6, withPad: " ", startingAt: 0))
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { i in
                let ch = chars[i] == " " ? "·" : String(chars[i])
                let filled = chars[i] != " "
                Text(ch)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(filled ? p.text : p.text3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(p.glassFill)
                            .overlay(RoundedRectangle(cornerRadius: 13)
                                .strokeBorder(filled ? p.accent : p.glassBorder, lineWidth: 0.5))
                    }
            }
        }
    }
}
