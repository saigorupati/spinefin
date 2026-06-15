import SwiftUI

/// Step 2 of onboarding: sign in with username/password, or use Quick Connect.
struct LoginView: View {
    let server: DiscoveredServer

    @Environment(\.palette) private var p
    @Environment(AuthStore.self) private var auth

    @State private var username = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var showQuickConnect = false

    private var api: JellyfinAPI {
        JellyfinAPI(baseURL: URL(string: server.baseURLString)!)
    }

    var body: some View {
        ZStack {
            SpineBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text(server.serverName)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(p.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(p.accentSoft))
                    .padding(.bottom, 18)

                    Text("Sign in")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(p.text)
                    Text("Use your Jellyfin account.")
                        .font(.system(size: 16))
                        .foregroundStyle(p.text2)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        GlassField(systemImage: "person") {
                            TextField("Username", text: $username)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(p.text)
                        }
                        GlassField(systemImage: "lock") {
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .submitLabel(.go)
                                .onSubmit(signIn)
                                .foregroundStyle(p.text)
                        }
                    }
                    .padding(.top, 26)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(p.accent)
                            .padding(.top, 14)
                    }

                    PillButton(title: isSigningIn ? "Signing in…" : "Sign In", filled: true) {
                        signIn()
                    }
                    .padding(.top, 18)
                    .disabled(username.isEmpty || isSigningIn)
                    .overlay { if isSigningIn { ProgressView().tint(p.onAccent).padding(.top, 18) } }

                    OrDivider(label: "or quick connect")

                    Button { showQuickConnect = true } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "qrcode")
                            Text("Use Quick Connect")
                        }
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
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showQuickConnect) {
            QuickConnectView(server: server)
        }
    }

    private func signIn() {
        errorMessage = nil
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                let result = try await api.authenticate(username: username, password: password)
                auth.add(ServerConnection(
                    serverName: server.serverName,
                    baseURLString: server.baseURLString,
                    userId: result.user.id,
                    username: result.user.name,
                    accessToken: result.accessToken,
                    serverId: result.serverId
                ))
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Sign in failed."
            }
        }
    }
}
