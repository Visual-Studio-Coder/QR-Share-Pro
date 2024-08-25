//
//  String.swift
//  QRSharePro
//
//  Created by Aaron Ma on 5/22/24.
//

import Foundation

extension String {
    func isValidURL() -> Bool {
        guard self.count >= 10 else { return false } // http://a.a
        
        if let url = URLComponents(string: self) {
            if url.scheme != nil && !url.scheme!.isEmpty {
                let scheme = (url.scheme ?? "fail")
                return scheme == "http" || scheme == "https"
            }
        }
        
        return false
    }
    
    func extractFirstURL() -> String {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: self, options: [], range: NSMakeRange(0, self.utf16.count))
        let urls = matches?.compactMap { Range($0.range, in: self) }.map { String(self[($0)]) }
        return urls?.first ?? self
    }
    
    func removeTrackers() -> String {
        var components = URLComponents(url: URL(string: self)!, resolvingAgainstBaseURL: true)!
        
        // Remove trackers
		let trackers = ["utm_ref", "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "fbclid", "gclid", "dclid", "twclkd", "msclkid", "mc_eid", "igshid", "epik", "ef_id", "s_kwicid", "dm_i", "_branch_match_id", "mkevt", "campid", "si", "_bta_tid", "_bta_c", "_kx", "tt", "ref", "ir", "cx", "cof", "pt", "mt", "ct", "click_id", "campaign_id", "sourceid", "aqs", "client", "source", "ust", "usg", "ga_source", "ga_medium", "ga_term", "ga_content", "ga_campaign", "ga_place", "yclid", "_openstat", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref", "action_object_map", "action_type_map", "action_ref_map", "gs_l", "mkt_tok", "hmb_campaign", "hmb_medium", "hmb_source", "click", "_k", "ref_", "_encoding", "af_qr", "__hsfp", "__hssc", "__hstc", "__s", "_hsenc", "_openstat", "hsCtaTracking", "ml_subscriber", "ml_subscriber_hash", "oly_anon_id", "oly_enc_id", "rb_clickid", "s_cid", "vero_conv", "vero_id", "wickedid", "p", "v", "recommended_by", "source_impression_id", "previous_page_section_name", "federated_search_id", "affiliate_id", "aid", "affiliate_token", "tid", "sid", "pid", "cid", "wpid"]
        // https://lunio.ai/blog/strategy/ios-17-link-tracking/
        // https://github.com/origamiman72/uni/blob/main/Shared/URLShortener.swift
        // https://privacytests.org/
        
        for parameter in components.queryItems ?? [] {
            if trackers.contains(parameter.name) {
                components.queryItems?.removeAll { $0.name == parameter.name }
            }
        }
        
        // Reconstruct the URL without trackers
        return components.url!.absoluteString
    }
    
    var asciiDecoded: String {
        let withRegularSpaces = self.replacingOccurrences(of: "\u{00A0}", with: " ")
        return withRegularSpaces.unicodeScalars.filter { $0.isASCII }.map { String($0) }.joined()
    }
}

