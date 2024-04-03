//
//  SplashView.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 4/3/24.
//

import SwiftUI

struct SplashView<SplashContent: View>: ViewModifier {
    private let splashContent: () -> SplashContent
    
    @State private var isActive = true
    
    init(@ViewBuilder splashContent: @escaping () -> SplashContent) {
        self.splashContent = splashContent
    }
    
    func body(content: Content) -> some View {
        if isActive {
            splashContent()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation {
                            self.isActive = false
                        }
                    }
                }
        } else {
            content
        }
    }
}
