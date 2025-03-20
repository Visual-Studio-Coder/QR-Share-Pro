//
//  QRControlBundle.swift
//  QRControl
//
//  Created by Vaibhav Satishkumar on 3/19/25.
//

import WidgetKit
import SwiftUI

@main
struct QRControlBundle: WidgetBundle {
    var body: some Widget {
        QRControl()
        QRControlControl()
    }
}
