//
//  AppIcons.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/7/24.
//

import SwiftUI

struct AppIcon: Identifiable {
    var id = UUID()
    var iconURL: String
    var iconName: String
    var proRequired: Bool = true
}

struct AppIcons: View {
    private var allIcons: [AppIcon] = [AppIcon(iconURL: "AppIcon", iconName: "Default", proRequired: false), AppIcon(iconURL: "AppIcon2", iconName: "Hacker", proRequired: false), AppIcon(iconURL: "AppIcon3", iconName: "Rainbow", proRequired: false)]
    
    @State private var currentlySelected = "AppIcon"
    
    private func changeAppIcon(to iconURL: String) {
        UIApplication.shared.setAlternateIconName(iconURL) { error in
            if let error = error {
                print(error.localizedDescription)
//                fatalError(error.localizedDescription)
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(allIcons) { i in
                Button {
                    changeAppIcon(to: i.iconURL)
                    currentlySelected = i.iconURL
                } label: {
                    HStack {
                        Image(systemName: i.iconURL == currentlySelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                        
                        Image(uiImage: #imageLiteral(resourceName: i.iconURL))
                            .resizable()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 50)
                        
                        Text(i.iconName)
                    }
                }
            }
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AppIcons()
}
