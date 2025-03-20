//
//  QRControlControl.swift
//  QRControl
//
//  Created by Vaibhav Satishkumar on 3/19/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct QRControlControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.click.QRShare.QRControl"
        ) {
            ControlWidgetButton(action: ScanQRCodeIntent()) {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }
        }
        .displayName("Scan QR Code")
        .description("Quickly open the QR Share Pro QR code scanner.")
    }
}

struct ScanQRCodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan QR Code"
    
    func perform() async throws -> some IntentResult {
        // When this intent is performed, it will launch your app
        // The app can then detect that it was launched from this intent
        // and navigate to the QR scanner
        return .result()
    }
}
