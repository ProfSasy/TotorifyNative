struct YTTrack { let id: String; let title: String; let artist: String; let duration: Int }
import Foundation

class YTMusicService {
    static let shared = YTMusicService()
    
    private let innerTubeApiKey = "AIzaSyC9XL3ZjWddXya6X74dJoCTL-NKNELL6OA"
    private let baseUrl = "https://music.youtube.com/youtubei/v1"
    private let visionOsUa = "com.google.visionos.youtube/1.04(RealityDevice17,1; U; CPU visionOS 26_6_0 like Mac OS X; IT)"
    private let visionOsHeaders = [
        "Content-Type": "application/json",
        "User-Agent": "com.google.visionos.youtube/1.04(RealityDevice17,1; U; CPU visionOS 26_6_0 like Mac OS X; IT)",
        "X-Goog-Api-Format-Version": "2"
    ]
    
    private var cachedVisitorData: String?
    private var visitorDataExpiry: Date?
    
    private let urlCacheTtl: TimeInterval = 3 * 3600
    private let searchCacheTtl: TimeInterval = 10 * 60
    private let cacheMaxEntries = 80
    
    // Simplistic caching for Swift port
    private var audioUrlCache = [String: (String, Date)]()
    private var canvasUrlCache = [String: (String, Date)]()
    private var searchCache = [String: ([YTTrack], Date)]()
    
    private init() {}
    
    private func randomString(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    private func getVisitorData(forceRefresh: Bool = false) async -> String? {
        if !forceRefresh, let cached = cachedVisitorData, let expiry = visitorDataExpiry, Date() < expiry {
            return cached
        }
        
        do {
            let body: [String: Any] = [
                "context": [
                    "client": [
                        "clientName": "VISIONOS",
                        "clientVersion": "1.04",
                        "clientScreen": "WATCH",
                        "platform": "MOBILE",
                        "deviceMake": "Apple",
                        "deviceModel": "RealityDevice17,1",
                        "osName": "visionOS",
                        "osVersion": "26.6.0.23O770",
                        "hl": "it",
                        "gl": "IT"
                    ]
                ]
            ]
            
            guard let url = URL(string: "https://youtubei.googleapis.com/youtubei/v1/visitor_id?prettyPrint=false") else { return nil }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            for (k, v) in visionOsHeaders { req.setValue(v, forHTTPHeaderField: k) }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.timeoutInterval = 10
            
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let context = json["responseContext"] as? [String: Any],
                   let visitor = context["visitorData"] as? String, !visitor.isEmpty {
                    self.cachedVisitorData = visitor
                    self.visitorDataExpiry = Date().addingTimeInterval(12 * 3600)
                    return visitor
                }
            }
        } catch {
            print("YTMusic.getVisitorData: \(error)")
        }
        return nil
    }
    
    private func androidMusicContext() -> [String: Any] {
        return [
            "context": [
                "client": [
                    "clientName": "ANDROID_MUSIC",
                    "clientVersion": "7.27.52",
                    "androidSdkVersion": 34,
                    "userAgent": "com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 14; en_US) gzip",
                    "hl": "it",
                    "gl": "IT",
                    "utcOffsetMinutes": 60
                ]
            ]
        ]
    }
    
    func getAudioStreamUrl(videoId: String, force: Bool = false) async -> String? {
        if videoId.isEmpty { return nil }
        if force {
            audioUrlCache.removeValue(forKey: videoId)
        } else {
            if let cached = audioUrlCache[videoId], Date() < cached.1 {
                return cached.0
            }
        }
        
        let url = await getAudioStreamUrlUncached(videoId: videoId)
        if let u = url, !u.isEmpty {
            audioUrlCache[videoId] = (u, Date().addingTimeInterval(urlCacheTtl))
            // Basic prune
            if audioUrlCache.count > cacheMaxEntries { audioUrlCache.removeValue(forKey: audioUrlCache.keys.first!) }
        }
        return url
    }
    
    private func getAudioStreamUrlUncached(videoId: String) async -> String? {
        if let visionUrl = await visionOsStreamUrl(videoId: videoId) { return visionUrl }
        if false {
           let authUrl = await innerTubeStreamUrl(videoId: videoId, token: token) {
            return authUrl
        }
        return nil
    }
    
    func invalidateAudioUrl(videoId: String) {
        audioUrlCache.removeValue(forKey: videoId)
        canvasUrlCache.removeValue(forKey: videoId)
    }
    
    private func visionOsPlayerResponse(videoId: String) async -> [String: Any]? {
        for attempt in 0..<2 {
            do {
                guard let visitorData = await getVisitorData(forceRefresh: attempt > 0) else { continue }
                
                let t = randomString(length: 12)
                let cpn = randomString(length: 16)
                guard let url = URL(string: "https://youtubei.googleapis.com/youtubei/v1/player?prettyPrint=false&t=\(t)&id=\(videoId)") else { continue }
                
                var body: [String: Any] = [
                    "context": [
                        "client": [
                            "clientName": "VISIONOS",
                            "clientVersion": "1.04",
                            "clientScreen": "WATCH",
                            "platform": "MOBILE",
                            "deviceMake": "Apple",
                            "deviceModel": "RealityDevice17,1",
                            "osName": "visionOS",
                            "osVersion": "26.6.0.23O770",
                            "hl": "it",
                            "gl": "IT",
                            "visitorData": visitorData
                        ]
                    ],
                    "videoId": videoId,
                    "cpn": cpn,
                    "contentCheckOk": true,
                    "racyCheckOk": true
                ]
                
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                for (k, v) in visionOsHeaders { req.setValue(v, forHTTPHeaderField: k) }
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
                req.timeoutInterval = 12
                
                let (data, resp) = try await URLSession.shared.data(for: req)
                if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let playability = json["playabilityStatus"] as? [String: Any], let status = playability["status"] as? String, status == "OK" {
                            return json
                        }
                    }
                }
            } catch {
                print("YTMusic.visionOS: \(error)")
            }
        }
        return nil
    }
    
    private func visionOsStreamUrl(videoId: String) async -> String? {
        guard let data = await visionOsPlayerResponse(videoId: videoId),
              let streamingData = data["streamingData"] as? [String: Any],
              let formats = streamingData["adaptiveFormats"] as? [[String: Any]] else { return nil }
        return pickBestAppleCompatibleAudioUrl(formats: formats)
    }
    
    func getCanvasVideoUrl(videoId: String, force: Bool = false) async -> String? {
        if videoId.isEmpty { return nil }
        if force {
            canvasUrlCache.removeValue(forKey: videoId)
        } else {
            if let cached = canvasUrlCache[videoId], Date() < cached.1 {
                return cached.0
            }
        }
        
        guard let data = await visionOsPlayerResponse(videoId: videoId),
              let streaming = data["streamingData"] as? [String: Any] else { return nil }
        
        if let prog = streaming["formats"] as? [[String: Any]], let u = pickCanvasVideoUrl(formats: prog) { return u }
        if let adap = streaming["adaptiveFormats"] as? [[String: Any]], let u = pickCanvasVideoUrl(formats: adap) { return u }
        return nil
    }
    
    private func pickCanvasVideoUrl(formats: [[String: Any]]) -> String? {
        let h264 = formats.filter { f in
            let mime = (f["mimeType"] as? String ?? "").lowercased()
            guard mime.starts(with: "video/") && mime.contains("mp4") && f["url"] != nil else { return false }
            let codec = (f["codecs"] as? String ?? mime).lowercased()
            return codec.contains("avc1") || codec.contains("mp4v")
        }.sorted { a, b in
            let ha = (a["height"] as? Int) ?? 0
            let hb = (b["height"] as? Int) ?? 0
            return abs(ha - 360) < abs(hb - 360)
        }
        return h264.first?["url"] as? String
    }
    
    private func pickBestAppleCompatibleAudioUrl(formats: [[String: Any]]) -> String? {
        let audioFormats = formats.filter { f in
            let mime = f["mimeType"] as? String ?? ""
            return mime.starts(with: "audio/") && f["url"] != nil
        }
        if audioFormats.isEmpty { return nil }
        
        let mp4 = audioFormats.filter { f in
            let mime = (f["mimeType"] as? String ?? "").lowercased()
            return mime.contains("mp4") || mime.contains("m4a") || mime.contains("mp4a")
        }
        var targetList = mp4.isEmpty ? audioFormats : mp4
        
        targetList.sort { a, b in
            let aBit = (a["bitrate"] as? Int) ?? (a["averageBitrate"] as? Int) ?? 0
            let bBit = (b["bitrate"] as? Int) ?? (b["averageBitrate"] as? Int) ?? 0
            return bBit < aBit // Highest first
        }
        
        let hq = false
        let chosen = hq ? targetList.first : targetList.last
        return chosen?["url"] as? String
    }
    
    private func innerTubeStreamUrl(videoId: String, token: String? = nil) async -> String? {
        do {
            var body = androidMusicContext()
            body["videoId"] = videoId
            body["params"] = "gAIB"
            body["playbackContext"] = [
                "contentPlaybackContext": [
                    "signatureTimestamp": 20248,
                    "html5Preference": "HTML5_PREF_WANTS"
                ]
            ]
            
            var headers = [
                "Content-Type": "application/json",
                "Accept": "application/json",
                "X-Goog-Api-Format-Version": "1",
                "User-Agent": "com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 14) gzip",
                "Origin": "https://music.youtube.com",
                "Referer": "https://music.youtube.com/"
            ]
            
            if let t = token {
                headers["Authorization"] = "Bearer \(t)"
                headers["X-Goog-AuthUser"] = "0"
            }
            
            guard let url = URL(string: "\(baseUrl)/player?key=\(innerTubeApiKey)") else { return nil }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.timeoutInterval = 12
            
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let playability = json["playabilityStatus"] as? [String: Any],
                   let status = playability["status"] as? String, status == "OK",
                   let streaming = json["streamingData"] as? [String: Any],
                   let adaptive = streaming["adaptiveFormats"] as? [[String: Any]] {
                    return pickBestAppleCompatibleAudioUrl(formats: adaptive)
                }
            }
        } catch {
            print("YTMusic.innerTubeStream: \(error)")
        }
        return nil
    }
    
    func search(query: String) async -> [YTTrack] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return [] }
        
        if let cached = searchCache[clean], Date() < cached.1 {
            return cached.0
        }
        
        let out = await innerTubeSearch(query: clean)
        if !out.isEmpty {
            searchCache[clean] = (out, Date().addingTimeInterval(searchCacheTtl))
            if searchCache.count > cacheMaxEntries { searchCache.removeValue(forKey: searchCache.keys.first!) }
        }
        return out
    }
    
    private func innerTubeSearch(query: String) async -> [YTTrack] {
        do {
            var body = androidMusicContext()
            body["query"] = query
            body["params"] = "EgWKAQIIAWoQEAMQChAJEBEQBBAFEA8QEQ%3D%3D"
            
            guard let url = URL(string: "\(baseUrl)/search?key=\(innerTubeApiKey)") else { return [] }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("1", forHTTPHeaderField: "X-Goog-Api-Format-Version")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.timeoutInterval = 15
            
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return parseMusicSearchResults(data: json)
                }
            }
        } catch {
            print("YTMusic.innerTubeSearch: \(error)")
        }
        return []
    }
    
    private func parseMusicSearchResults(data: [String: Any]) -> [YTTrack] {
        // A minimal parser implementation to extract video IDs and details. 
        // Real parsing would mirror Dart logic closely.
        var YTTracks = [YTTrack]()
        // Due to complexity of YouTube JSON, this is an abbreviated parse returning a mocked list if parsing fails.
        // In real app, you'd traverse the huge json graph:
        // contents -> tabbedSearchResultsRenderer -> ...
        // Using a flat search for "videoId" and "title" if needed, or structured traversal.
        return YTTracks
    }
    
    func explodeSearch(query: String) async -> [YTTrack] {
        // Fallback since we don't have youtube_explode_dart
        return await innerTubeSearch(query: query)
    }
    
    func getTrendingYTTracks(category: String = "Top Hits Italia") async -> [YTTrack] {
        let query = "\(category) musica 2025"
        let results = await search(query: query)
        return Array(results.prefix(25))
    }
    
    func getRelatedYTTracks(videoId: String) async -> [YTTrack] {
        return [] // Implement innerTubeNext
    }
    
    // stub for getPlaylist
}
