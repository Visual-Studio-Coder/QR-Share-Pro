//
//  VisualEffectView.swift
//  QRSharePro
//
//  Created by Aaron Ma on 4/3/24.
//

import SwiftUI

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        return UIVisualEffectView(effect: effect)
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}