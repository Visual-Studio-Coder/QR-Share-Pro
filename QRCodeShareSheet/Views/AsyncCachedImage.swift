//
//  AsyncCachedImage.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 4/3/24.
//

import SwiftUI

@MainActor
struct AsyncCachedImage<ImageView: View, PlaceholderView: View>: View {
    var url: URL?
    @ViewBuilder var content: (Image) -> ImageView
    @ViewBuilder var placeholder: () -> PlaceholderView
    
    @State var image: UIImage? = nil
    @State private var offline = false
    
    private let monitor = NetworkMonitor()
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> ImageView, @ViewBuilder placeholder: @escaping () -> PlaceholderView) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        VStack {
            if let uiImage = image {
                content(Image(uiImage: uiImage))
            } else {
                if offline {
                    Image(systemName: "network")
                        .foregroundStyle(.white)
                        .font(.largeTitle)
                        .padding()
                        .background(Color.accentColor)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    placeholder()
                }
            }
        }
        .onAppear {
            Task {
                image = await downloadPhoto()
            }
        }
    }
    
    private func downloadPhoto() async -> UIImage? {
        do {
            guard let url else { return nil }
            
            if let cachedResponse = URLCache.shared.cachedResponse(for: .init(url: url)) {
                return UIImage(data: cachedResponse.data)
            } else {
                if monitor.isActive {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    
                    URLCache.shared.storeCachedResponse(.init(response: response, data: data), for: .init(url: url))
                    
                    guard let image = UIImage(data: data) else {
                        return nil
                    }
                    
                    return image
                }
                
                offline = true
                return nil
            }
        } catch {
            print("Error downloading: \(error)")
            return nil
        }
    }
}
