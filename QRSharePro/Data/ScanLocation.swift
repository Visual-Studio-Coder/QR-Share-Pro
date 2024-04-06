//
//  ScanLocation.swift
//  QRSharePro
//
//  Created by Aaron Ma on 4/3/24.
//

import Foundation
import CoreLocation

struct ScanLocation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}
