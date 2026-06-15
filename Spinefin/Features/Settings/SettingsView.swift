import SwiftUI

struct SettingsView: View {
    @Environment(\.palette) private var p
    @Environment(AuthStore.self) private var auth
    @Environment(DownloadManager.self) private var downloads
    @Environment(SettingsStore.self) private var settings

    @State private var showAddServer = false
    @State private var confirmClearDownloads = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ZStack {
                SpineBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(p.text)
                            .padding(.top, 8).padding(.bottom, 18)

                        accountCard.padding(.bottom, 26)

                        // Servers
                        group("Servers") {
                            ForEach(auth.servers) { server in
                                button(label: server.serverName, detail: server.username,
                                       icon: "globe",
                                       trailing: server.id == auth.activeServerID ? "checkmark" : nil) {
                                    auth.setActive(server)
                                }
                                divider
                            }
                            button(label: "Add a server", icon: "plus", last: true) {
                                showAddServer = true
                            }
                        }

                        // Playback
                        group("Playback") {
                            speedMenu(settings: $settings)
                            divider
                            skipMenu(title: "Skip back", selection: $settings.skipBackSeconds)
                            divider
                            skipMenu(title: "Skip forward", selection: $settings.skipForwardSeconds, last: true)
                        }

                        // Storage
                        group("Storage") {
                            info(label: "Downloads",
                                 detail: ByteCountFormatter.string(fromByteCount: downloads.totalBytes, countStyle: .file),
                                 icon: "arrow.down")
                            divider
                            Button(role: .destructive) { confirmClearDownloads = true } label: {
                                rowContent(label: "Clear all downloads", detail: nil, icon: nil,
                                           labelColor: downloads.records.isEmpty ? p.text3 : .red, showChevron: false)
                            }
                            .buttonStyle(.plain)
                            .disabled(downloads.records.isEmpty)
                        }

                        // About
                        group("About") {
                            info(label: "Version", detail: appVersion)
                        }

                        Button(role: .destructive) { auth.signOutActive() } label: {
                            Text("Sign Out")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(p.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddServer) { AddServerSheet() }
            .confirmationDialog("Delete all downloaded books?", isPresented: $confirmClearDownloads, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) { downloads.deleteAll() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Pieces

    private var accountCard: some View {
        HStack(spacing: 14) {
            Text(initial)
                .font(.system(size: 21, weight: .bold)).foregroundStyle(p.onAccent)
                .frame(width: 52, height: 52)
                .background(Circle().fill(LinearGradient(
                    colors: [p.accent, Color(hslHue: 18, saturation: 0.62, lightness: 0.40)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 2) {
                Text(auth.activeServer?.username ?? "Account")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(p.text)
                Text(displayHost).font(.system(size: 13.5)).foregroundStyle(p.text2)
            }
            Spacer()
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18).fill(p.listBg)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(p.glassBorder, lineWidth: 0.5))
        }
    }

    private func group(_ header: String, @ViewBuilder _ rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header.uppercased())
                .font(.system(size: 12.5, weight: .semibold)).tracking(0.4)
                .foregroundStyle(p.text3)
                .padding(.leading, 4).padding(.bottom, 9)
            VStack(spacing: 0) { rows() }
                .background {
                    RoundedRectangle(cornerRadius: 18).fill(p.listBg)
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(p.glassBorder, lineWidth: 0.5))
                }
        }
        .padding(.bottom, 26)
    }

    private func rowContent(label: String, detail: String?, icon: String?,
                            labelColor: Color? = nil, trailingSymbol: String? = nil,
                            showChevron: Bool) -> some View {
        HStack(spacing: 13) {
            if let icon {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(p.accent)
                    .frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 8).fill(p.accentSoft))
            }
            Text(label).font(.system(size: 16)).foregroundStyle(labelColor ?? p.text)
            Spacer()
            if let detail { Text(detail).font(.system(size: 15)).foregroundStyle(p.text2) }
            if let trailingSymbol { Image(systemName: trailingSymbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.accent) }
            if showChevron { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(p.text3) }
        }
        .padding(.horizontal, 16).frame(minHeight: 50)
    }

    private func info(label: String, detail: String? = nil, icon: String? = nil) -> some View {
        rowContent(label: label, detail: detail, icon: icon, showChevron: false)
    }

    private func button(label: String, detail: String? = nil, icon: String? = nil,
                        trailing: String? = nil, last: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowContent(label: label, detail: detail, icon: icon, trailingSymbol: trailing, showChevron: false)
        }
        .buttonStyle(.plain)
    }

    private func speedMenu(settings: Bindable<SettingsStore>) -> some View {
        Menu {
            Picker("Default speed", selection: settings.defaultSpeed) {
                ForEach(SettingsStore.speedOptions, id: \.self) { Text(self.settings.speedLabel($0)).tag($0) }
            }
        } label: {
            rowContent(label: "Default speed", detail: self.settings.speedLabel(self.settings.defaultSpeed), icon: nil, showChevron: true)
        }
    }

    private func skipMenu(title: String, selection: Binding<Int>, last: Bool = false) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(SettingsStore.skipOptions, id: \.self) { Text("\($0)s").tag($0) }
            }
        } label: {
            rowContent(label: title, detail: "\(selection.wrappedValue)s", icon: nil, showChevron: true)
        }
    }

    private var divider: some View { Divider().overlay(p.sep).padding(.leading, 16) }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private var initial: String {
        let name = auth.activeServer?.username ?? "Me"
        return String(name.prefix(1)).uppercased()
    }

    private var displayHost: String {
        guard let s = auth.activeServer, let host = URL(string: s.baseURLString)?.host else {
            return auth.activeServer?.serverName ?? "Not signed in"
        }
        return host
    }
}

/// Add-another-server flow presented as a sheet; dismisses once a server is added.
private struct AddServerSheet: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var startCount: Int?

    var body: some View {
        OnboardingView()
            .onAppear { if startCount == nil { startCount = auth.servers.count } }
            .onChange(of: auth.servers.count) { _, new in
                if let start = startCount, new > start { dismiss() }
            }
            .overlay(alignment: .topTrailing) {
                Button("Cancel") { dismiss() }
                    .padding()
            }
    }
}
