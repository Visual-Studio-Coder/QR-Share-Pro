//
//  View+splashView.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 4/3/24.
//

import SwiftUI

extension View {
    func splashView<SplashContent: View>(@ViewBuilder splashContent: @escaping () -> SplashContent) -> some View {
        self.modifier(SplashView(splashContent: splashContent))
    }
}
