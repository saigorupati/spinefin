import SwiftUI

struct LibraryView: View {
    @Environment(\.palette) private var p
    @Environment(AuthStore.self) private var auth
    @Environment(LibraryStore.self) private var library

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    @State private var searchText = ""
    @State private var sort: SortOption = .recent

    enum SortOption: String, CaseIterable, Identifiable {
        case recent = "Recent", title = "Title", author = "Author"
        var id: String { rawValue }
    }

    private var searchActive: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var displayedBooks: [Book] {
        var books = library.books
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            books = books.filter { $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q) }
        }
        switch sort {
        case .recent: break
        case .title: books.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author: books.sort { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
        }
        return books
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpineBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        searchBar.padding(.top, 16)

                        if library.isLoading && library.books.isEmpty {
                            loading
                        } else if let error = library.errorMessage, library.books.isEmpty {
                            errorState(error)
                        } else if library.books.isEmpty {
                            emptyState
                        } else {
                            content
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationDestination(for: Book.self) { BookDetailView(book: $0) }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await library.load() }
            .task { await library.loadIfNeeded() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !searchActive && !library.continueListening.isEmpty {
            Text("Continue Listening")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(p.text)
                .padding(.top, 22).padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(library.continueListening) { book in
                        NavigationLink(value: book) { ContinueCard(book: book) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }

        HStack {
            Text(searchActive ? "Results" : "All Books")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(p.text)
            Spacer()
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(SortOption.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(sort.rawValue).font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(p.text2)
                .padding(.horizontal, 11).frame(height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 9).fill(p.glassFill)
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(p.glassBorder, lineWidth: 0.5))
                }
            }
        }
        .padding(.top, 22).padding(.bottom, 12)

        if displayedBooks.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(displayedBooks) { book in
                    NavigationLink(value: book) { GridCard(book: book) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var loading: some View {
        ProgressView().tint(p.accent)
            .frame(maxWidth: .infinity).padding(.top, 120)
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load library", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") { Task { await library.load() } }.tint(p.accent)
        }
        .padding(.top, 80)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No audiobooks", systemImage: "books.vertical")
        } description: {
            Text("No books found in a Music-type library on \(auth.activeServer?.serverName ?? "your server").")
        }
        .padding(.top, 80)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SPINEFIN")
                    .font(.system(size: 12.5, weight: .bold)).tracking(0.6)
                    .foregroundStyle(p.accent)
                Text("Library")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(p.text)
            }
            Spacer()
            Menu {
                if let server = auth.activeServer {
                    Section(server.serverName) {
                        Label(server.username, systemImage: "person.crop.circle")
                    }
                }
                Button(role: .destructive) { auth.signOutActive() } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Text(initial)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(p.onAccent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(LinearGradient(
                        colors: [p.accent, Color(hslHue: 18, saturation: 0.62, lightness: 0.40)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
        }
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundStyle(p.text3)
            TextField("Search your library", text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(p.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if searchActive {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundStyle(p.text3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13).frame(height: 40)
        .background {
            RoundedRectangle(cornerRadius: 13).fill(p.glassFill)
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(p.glassBorder, lineWidth: 0.5))
        }
    }

    private var initial: String {
        let name = auth.activeServer?.username ?? "Me"
        return String(name.prefix(1)).uppercased()
    }
}

private struct ContinueCard: View {
    @Environment(\.palette) private var p
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverArt(hue: book.hue, cornerRadius: 16, imageURL: book.coverURL)
                .frame(width: 150, height: 150)
                .shadow(color: p.shadow, radius: 14, y: 8)
            Text(book.title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(p.text).lineLimit(1).padding(.top, 10)
            Text(book.author)
                .font(.system(size: 12.5)).foregroundStyle(p.text2).lineLimit(1)
            ProgressBar(value: book.progress ?? 0).padding(.top, 8)
            Text(book.remaining ?? "")
                .font(.system(size: 11)).foregroundStyle(p.text3).padding(.top, 6)
        }
        .frame(width: 150)
    }
}

private struct GridCard: View {
    @Environment(\.palette) private var p
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverArt(hue: book.hue, cornerRadius: 15, imageURL: book.coverURL)
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: p.shadow, radius: 14, y: 8)
            Text(book.title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(p.text).lineLimit(1).padding(.top, 9)
            Text(book.author)
                .font(.system(size: 12.5)).foregroundStyle(p.text2).lineLimit(1)
        }
    }
}
