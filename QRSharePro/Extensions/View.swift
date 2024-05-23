//
//  View.swift
//  QRSharePro
//

//

import SwiftUI

extension View {
    func splashView<SplashContent: View>(@ViewBuilder splashContent: @escaping () -> SplashContent) -> some View {
        self.modifier(SplashView(splashContent: splashContent))
    }
    
    func navigationBackButton(color: Color, text: String) -> some View {
        modifier(NavigationBackButton(color: color, text: text))
    }
}
