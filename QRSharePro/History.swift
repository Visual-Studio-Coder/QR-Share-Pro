//
//  History.swift
//  QRSharePro
//
//  Created by Aaron Ma on 3/25/24.
//

import SwiftUI

func showShareSheet(url: URL) {
    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    UIApplication.shared.currentUIWindow()?.rootViewController?.present(activityVC, animated: true, completion: nil)
}

struct History: View {
    @EnvironmentObject var qrCodeStore: QRCodeStore

    @State private var editMode = false

    @State private var searchText = ""
    @State private var searchTag = "All"
    @State private var showingEditButtonDeleteConfirmation = false
    @State private var showingAllPins = true
    @State private var showingDeleteConfirmation = false
    @State private var currentQRCode = QRCode(text: "")

    @State private var showOfflineText = true

    @State private var showingClearFaviconsConfirmation = false
    @State private var showingClearAllPinsConfirmation = false
    @State private var showingClearHistoryConfirmation = false

    private let monitor = NetworkMonitor()

    private var allSearchTags = ["All", "URL", "Text"]

    func save() async throws {
        qrCodeStore.save(history: qrCodeStore.history)
    }

    var searchResults: [QRCode] {
        guard !searchText.isEmpty else { return qrCodeStore.history }

        return qrCodeStore.history.filter { $0.text.lowercased().contains(searchText.lowercased()) }
    }

    private func getTypeOf(type: String) -> String {
        return type.isValidURL() ? "URL" : "Text"
    }

    var body: some View {
        NavigationStack {
            VStack {
                if qrCodeStore.history.isEmpty {
                    VStack {
                        Spacer()

                        Image(systemName: "clock.arrow.circlepath")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .padding(.bottom, 10)

                        Text("No History Yet")
                            .font(.title)
                            .bold()
                            .padding(.bottom, 10)

                        Text("Scan, create, or share a QR code.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 50)
                            .padding(.bottom, 30)

                        Spacer()
                    }
                } else {
                    let pinned = searchResults.sorted(by: { $0.date > $1.date }).filter({ $0.pinned }).filter({ searchTag == "All" ? (searchTag == "All" ? true : $0.pinned) : getTypeOf(type: $0.text) == searchTag })

                    let x = searchResults.sorted(by: { $0.date > $1.date }).filter({ !$0.pinned }).filter({ searchTag == "All" ? (searchTag == "All" ? true : $0.pinned) : getTypeOf(type: $0.text) == searchTag })

                    if x.isEmpty && pinned.isEmpty {
                        VStack {
                            Image(systemName: "magnifyingglass")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .padding(.bottom, 10)
                                .foregroundStyle(.secondary)

                            Text("No Results")
                                .font(.title)
                                .bold()

                            Text(searchTag != "All" ? "Check the spelling or remove the filter." : "Check the spelling or try a new search.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    }

                    List {
                        if !x.isEmpty && !monitor.isActive && showOfflineText {
                            Section("Network Unavailable") {
                                Button {
                                    withAnimation {
                                        showOfflineText = false
                                    }
                                } label: {
                                    HStack {
                                        Label("You're offline.", systemImage: "network.slash")
                                            .tint(.primary)
                                        Spacer()
                                        Image(systemName: "multiply.circle.fill")
                                            .foregroundStyle(Color.gray)
                                    }
                                }
                            }
                        }

                        if editMode {
                            Section {
                                Button {
                                    showingClearFaviconsConfirmation = true
                                } label: {
                                    Label("Clear Website Favicons Cache", systemImage: "xmark.square")
                                }
                                .confirmationDialog("Clear Website Favicons Cache?", isPresented: $showingClearFaviconsConfirmation, titleVisibility: .visible) {
                                    Button("Clear Website Favicons Cache", role: .destructive) {
                                        withAnimation {
                                            URLCache.shared.removeAllCachedResponses()

                                            showingClearFaviconsConfirmation = false
                                        }
                                    }
                                }

                                if !pinned.isEmpty {
                                    Button {
                                        showingClearAllPinsConfirmation = true
                                    } label: {
                                        Label("Clear Pins", systemImage: "pin.slash.fill")
                                    }
                                }

                                Button {
                                    showingClearHistoryConfirmation = true
                                } label: {
                                    Label("Clear History", systemImage: "trash")
                                }
                                .confirmationDialog("Clear History?", isPresented: $showingClearHistoryConfirmation, titleVisibility: .visible) {
                                    Button("Clear History", role: .destructive) {
                                        withAnimation {
                                            qrCodeStore.history = []

                                            Task {
                                                do {
                                                    try await save()
                                                } catch {
                                                    print(error.localizedDescription)
                                                }
                                            }

                                            showingClearHistoryConfirmation = false
                                        }
                                    }
                                }
                            } header: {
                                Text("Danger Zone")
                            } footer: {
                                Text("These actions are permanent and can't be undone.")
                            }
                            .confirmationDialog("Clear Pins?", isPresented: $showingClearAllPinsConfirmation, titleVisibility: .visible) {
                                Button("Clear Pins", role: .destructive) {
                                    withAnimation {
                                        for i in searchResults {
                                            if i.pinned, let idx = qrCodeStore.indexOfQRCode(withID: i.id) {
                                                qrCodeStore.history[idx].pinned.toggle()

                                                Task {
                                                    do {
                                                        try await save()
                                                    } catch {
                                                        print(error.localizedDescription)
                                                    }
                                                }
                                            }
                                        }

                                        showingClearAllPinsConfirmation = false
                                    }
                                }
                            }
                        }

                        if !pinned.isEmpty {
                            Section {
                                if showingAllPins {
                                    ForEach(pinned) { i in
                                        NavigationLink {
                                            HistoryDetailInfo(qrCode: i)
                                                .environmentObject(qrCodeStore)
                                        } label: {
                                            HStack {
                                                if i.text.isValidURL() {
                                                    AsyncCachedImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(URL(string: i.text)!.host!).ico")) { i in
                                                        i
                                                            .resizable()
                                                            .aspectRatio(1, contentMode: .fit)
                                                            .frame(width: 50, height: 50)
                                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                                    } placeholder: {
                                                        ProgressView()
                                                            .controlSize(.large)
                                                            .frame(width: 50, height: 50)
                                                    }
                                                } else {
                                                    i.qrCode?.toImage()?
                                                        .resizable()
                                                        .frame(width: 50, height: 50)
                                                }

                                                VStack(alignment: .leading) {
                                                    if i.text.isValidURL() {
                                                        let fixedURL = URL(string: i.text)!.absoluteString.replacingOccurrences(of: URL(string: i.text)!.scheme!, with: "").replacingOccurrences(of: "://", with: "").replacingOccurrences(of: ":/", with: "").replacingOccurrences(of: "www.", with: "").lowercased()

                                                        Text(fixedURL)
                                                            .bold()
                                                            .lineLimit(2)
                                                    } else {
                                                        Text(i.text)
                                                            .bold()
                                                            .lineLimit(2)
                                                    }

                                                    Text(i.date, format: .dateTime)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                        .contextMenu {
                                            if i.text.isValidURL() {
                                                Button {
                                                    if let url = URL(string: i.text) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                } label: {
                                                    Label("Open URL", systemImage: "safari")
                                                }
                                            }

                                            Button {
                                                UIPasteboard.general.string = i.text
                                            } label: {
                                                Label(i.text.isValidURL() ? "Copy URL" : "Copy", systemImage: "doc.on.doc")
                                            }

                                            Divider()

                                            Button {
                                                if let idx = qrCodeStore.indexOfQRCode(withID: i.id) {
                                                    withAnimation {
                                                        qrCodeStore.history[idx].pinned.toggle()

                                                        Task {
                                                            do {
                                                                try await save()
                                                            } catch {
                                                                print(error.localizedDescription)
                                                            }
                                                        }
                                                    }
                                                }
                                            } label: {
                                                Label("Unpin", systemImage: "pin.slash.fill")
                                            }

                                            Divider()

                                            if i.text.isValidURL() {
                                                Button {
                                                    showShareSheet(url: URL(string: i.text)!)
                                                } label: {
                                                    Label("Share URL", systemImage: "square.and.arrow.up")
                                                }
                                            }

                                            Button(role: .destructive) {
                                                currentQRCode = i
                                                showingDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                if let idx = qrCodeStore.indexOfQRCode(withID: i.id) {
                                                    withAnimation {
                                                        qrCodeStore.history[idx].pinned.toggle()

                                                        Task {
                                                            do {
                                                                try await save()
                                                            } catch {
                                                                print(error.localizedDescription)
                                                            }
                                                        }
                                                    }
                                                }
                                            } label: {
                                                Label("Unpin", systemImage: "pin.slash.fill")
                                            }
                                            .tint(Color.accentColor)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button {
                                                currentQRCode = i
                                                showingDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            .tint(.red)
                                        }
                                    }
                                    .onDelete { indexSet in
                                    }
                                }
                            } header: {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
                                        showingAllPins.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text(pinned.count == 1 ? "1 Pin" : "\(pinned.count) Pins")
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .rotationEffect(Angle(degrees: showingAllPins ? 0 : -90))
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        if !x.isEmpty {
                            Section {
                                ForEach(x) { i in
                                    NavigationLink {
                                        HistoryDetailInfo(qrCode: i)
                                            .environmentObject(qrCodeStore)
                                    } label: {
                                        HStack {
                                            if i.text.isValidURL() {
                                                AsyncCachedImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(URL(string: i.text)!.host!).ico")) { i in
                                                    i
                                                        .resizable()
                                                        .aspectRatio(1, contentMode: .fit)
                                                        .frame(width: 50, height: 50)
                                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                                } placeholder: {
                                                    ProgressView()
                                                        .controlSize(.large)
                                                        .frame(width: 50, height: 50)
                                                }
                                            } else {
                                                i.qrCode?.toImage()?
                                                    .resizable()
                                                    .frame(width: 50, height: 50)
                                            }

                                            VStack(alignment: .leading) {
                                                if i.text.isValidURL() {
                                                    let fixedURL = URL(string: i.text)!.absoluteString.replacingOccurrences(of: URL(string: i.text)!.scheme!, with: "").replacingOccurrences(of: "://", with: "").replacingOccurrences(of: ":/", with: "").replacingOccurrences(of: "www.", with: "").lowercased()

                                                    //                                                    if fixedURL.last == "/" {
                                                    //                                                        print(fixedURL)
                                                    //                                                    }

                                                    Text(fixedURL)
                                                        .bold()
                                                        .lineLimit(2)
                                                } else {
                                                    Text(i.text)
                                                        .bold()
                                                        .lineLimit(2)
                                                }

                                                Text(i.date, format: .dateTime)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .contextMenu {
                                        if i.text.isValidURL() {
                                            Button {
                                                if let url = URL(string: i.text) {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                Label("Open URL", systemImage: "safari")
                                            }
                                        }

                                        Button {
                                            UIPasteboard.general.string = i.text
                                        } label: {
                                            Label(i.text.isValidURL() ? "Copy URL" : "Copy", systemImage: "doc.on.doc")
                                        }

                                        Divider()

                                        Button {
                                            if let idx = qrCodeStore.indexOfQRCode(withID: i.id) {
                                                withAnimation {
                                                    qrCodeStore.history[idx].pinned.toggle()

                                                    Task {
                                                        do {
                                                            try await save()
                                                        } catch {
                                                            print(error.localizedDescription)
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            Label("Pin", systemImage: "pin")
                                        }

                                        Divider()

                                        if i.text.isValidURL() {
                                            Button {
                                                showShareSheet(url: URL(string: i.text)!)
                                            } label: {
                                                Label("Share URL", systemImage: "square.and.arrow.up")
                                            }
                                        }

                                        Button(role: .destructive) {
                                            currentQRCode = i
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            if let idx = qrCodeStore.indexOfQRCode(withID: i.id) {
                                                withAnimation {
                                                    qrCodeStore.history[idx].pinned.toggle()

                                                    Task {
                                                        do {
                                                            try await save()
                                                        } catch {
                                                            print(error.localizedDescription)
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            Label("Pin", systemImage: "pin")
                                        }
                                        .tint(Color.accentColor)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            currentQRCode = i
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }
                                .onDelete { indexSet in
                                }
                                .confirmationDialog("Delete QR Code?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                                    Button("Delete QR Code", role: .destructive) {
                                        if let idx = qrCodeStore.indexOfQRCode(withID: currentQRCode.id) {
                                            withAnimation {
                                                qrCodeStore.history.remove(at: idx)

                                                Task {
                                                    do {
                                                        try await save()
                                                    } catch {
                                                        print(error.localizedDescription)
                                                    }
                                                }

                                                showingDeleteConfirmation = false
                                            }
                                        }
                                    }
                                }
                            } header: {
                                if searchTag == "URL" {
                                    Text(x.count == 1 ? "1 URL" : "\(x.count) URLs")
                                } else if searchTag == "Text" {
                                    Text(x.count == 1 ? "1 QR Code Found" : "\(x.count) QR Codes Found")
                                } else {
                                    Text(x.count == 1 ? "1 QR Code" : "\(x.count) QR Codes")
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search History")
                }
            }
            .environment(\.editMode, Binding(get: { editMode ? .active : .inactive }, set: { editMode = ($0 == .active) }))
            .navigationTitle(qrCodeStore.history.isEmpty ? "" : "History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !qrCodeStore.history.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(allSearchTags, id: \.self) { i in
                                Button {
                                    searchTag = i
                                } label: {
                                    if searchTag == i {
                                        Label(i, systemImage: "checkmark")
                                    } else {
                                        Text(i)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: searchTag == "All" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        }
                    }
                }

                if !qrCodeStore.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                editMode.toggle()
                            }
                        } label: {
                            Text(editMode ? "Done" : "Edit")
                        }
                    }
                }
            }
            .onDisappear {
                editMode = false
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()

        History()
            .environmentObject(qrCodeStore)
    }
}