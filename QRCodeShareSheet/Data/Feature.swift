//
//  Feature.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 4/3/24.
//

import Foundation

struct Feature: Decodable, Identifiable {
    var id = UUID()
    let title: String
    let description: String
    let image: String
}
