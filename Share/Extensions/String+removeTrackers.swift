//
//  String+removeTrackers.swift
//  Share
//
//  Created by Aaron Ma on 4/7/24.
//

import Foundation

extension String {
    func removeTrackers() -> String {
        var components = URLComponents(url: URL(string: self)!, resolvingAgainstBaseURL: true)!
        
        // Remove all trackers
        let trackers = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "fbclid", "gclid", "dclid", "twclkd", "msclkid", "mc_eid", "igshid", "epik", "ef_id", "s_kwicid", "dm_i", "_branch_match_id", "mkevt", "campid", "si", "_bta_tid", "_bta_c", "_kx", "tt", "ir", "cx", "cof", "pt", "mt", "ct"] // https://lunio.ai/blog/strategy/ios-17-link-tracking/
        
        for parameter in components.queryItems ?? [] {
            if trackers.contains(parameter.name) {
                components.queryItems?.removeAll { $0.name == parameter.name }
            }
        }
        
        // Reconstruct the URL without trackers
        return components.url!.absoluteString
    }
}
