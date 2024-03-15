//
//  Haptics.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/7/24.
//

import Foundation
import UIKit

class Haptics {
    static let shared = Haptics()
    
    private init() { }
    
    func play(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }
    
    func notify(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
    }
}
