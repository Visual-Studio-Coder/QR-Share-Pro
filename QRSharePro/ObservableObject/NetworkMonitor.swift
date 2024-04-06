//
//  NetworkMonitor.swift
//  QRSharePro
//
//  Created by Aaron Ma on 4/3/24.
//

import SwiftUI
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "QR Share Pro - Network Monitor")

    var isActive = false

    init() {
        monitor.pathUpdateHandler = { path in
            self.isActive = path.status == .satisfied

            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }

        monitor.start(queue: queue)
    }
}
