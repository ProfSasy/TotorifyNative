import Foundation

struct SpotifyTrack: Identifiable {
    let trackId: String
    let title: String
    let artist: String
    let album: String?
    let durationMs: Int
    let coverUrl: String?
    
    var id: String { trackId }
}

struct SpotifyPlaylistData: Identifiable {
    let id: String
    let title: String
    let description: String?
    let coverUrl: String?
    let tracks: [SpotifyTrack]
}

class SpotifyService {
    static let shared = SpotifyService()
    
    private let maxCacheSize = 300
    private var coverCache = [String: String]()
    
    private init() {}
    
    private func cacheCover(trackId: String, url: String) {
        if coverCache.count >= maxCacheSize {
            if let firstKey = coverCache.keys.first {
                coverCache.removeValue(forKey: firstKey)
            }
        }
        coverCache[trackId] = url
    }
    
    /// Recupera la copertina originale in HD (640x640) per un singolo trackId Spotify tramite oembed.
    func fetchTrackCoverHD(trackId: String) async -> String? {
        if let cached = coverCache[trackId] {
            return cached
        }
        do {
            let oembedUrl = "https://open.spotify.com/oembed?url=https://open.spotify.com/track/\(trackId)"
            guard let url = URL(string: oembedUrl) else { return nil }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let thumb = json["thumbnail_url"] as? String, !thumb.isEmpty {
                    let hd = thumb.replacingOccurrences(of: "00001e02", with: "0000b273")
                    cacheCover(trackId: trackId, url: hd)
                    return hd
                }
            }
        } catch {
            print("SpotifyService.fetchTrackCoverHD error for \(trackId): \(error)")
        }
        return nil
    }
    
    func extractPlaylistId(urlOrUri: String) -> String? {
        let clean = urlOrUri.trimmingCharacters(in: .whitespacesAndNewlines)
        let regExp = try? NSRegularExpression(pattern: "playlist[:/]([a-zA-Z0-9]+)")
        if let match = regExp?.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)),
           let range = Range(match.range(at: 1), in: clean) {
            return String(clean[range])
        }
        if clean.count == 22 && clean.range(of: "^[a-zA-Z0-9]{22}$", options: .regularExpression) != nil {
            return clean
        }
        return nil
    }
    
    func fetchPlaylist(urlOrId: String) async -> SpotifyPlaylistData? {
        guard let playlistId = extractPlaylistId(urlOrUri: urlOrId) else { return nil }
        
        do {
            let embedUrl = "https://open.spotify.com/embed/playlist/\(playlistId)"
            guard let url = URL(string: embedUrl) else { return nil }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            request.setValue("it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")
            request.timeoutInterval = 10
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                print("SpotifyService: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1) on embed")
                return nil
            }
            
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            let regex = try NSRegularExpression(pattern: "<script id=\"__NEXT_DATA__\" type=\"application/json\">(.*?)</script>", options: .dotMatchesLineSeparators)
            guard let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let range = Range(match.range(at: 1), in: html) else {
                print("SpotifyService: __NEXT_DATA__ non trovato nell'embed")
                return nil
            }
            
            let jsonRaw = String(html[range])
            if jsonRaw.isEmpty { return nil }
            
            guard let jsonData = jsonRaw.data(using: .utf8),
                  let decoded = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("SpotifyService: json.decode error")
                return nil
            }
            
            guard let props = decoded["props"] as? [String: Any],
                  let pageProps = props["pageProps"] as? [String: Any],
                  let state = pageProps["state"] as? [String: Any],
                  let dataDict = state["data"] as? [String: Any],
                  let entity = dataDict["entity"] as? [String: Any] else {
                return nil
            }
            
            let title = entity["title"] as? String ?? "Playlist Spotify"
            let description = entity["subtitle"] as? String ?? "Importata da Spotify"
            
            var playlistCover: String?
            if let coverArt = entity["coverArt"] as? [String: Any], let sources = coverArt["sources"] as? [[String: Any]], let firstUrl = sources.first?["url"] as? String {
                playlistCover = firstUrl
            } else if let visualIdentity = entity["visualIdentity"] as? [String: Any], let images = visualIdentity["image"] as? [[String: Any]], let lastUrl = images.last?["url"] as? String {
                playlistCover = lastUrl
            }
            
            let rawTracks = entity["trackList"] as? [[String: Any]] ?? []
            var tracks = [SpotifyTrack]()
            
            for raw in rawTracks {
                let trackTitle = raw["title"] as? String ?? ""
                let artist = raw["subtitle"] as? String ?? ""
                let durationMs = raw["duration"] as? Int ?? 0
                let uri = raw["uri"] as? String ?? ""
                
                if trackTitle.isEmpty { continue }
                
                var trackId = uri.contains(":") ? String(uri.split(separator: ":").last ?? "") : uri
                if trackId.isEmpty {
                    trackId = "sp_\(trackTitle.hashValue)_\(artist.hashValue)"
                }
                
                tracks.append(SpotifyTrack(trackId: trackId, title: trackTitle, artist: artist, album: nil, durationMs: durationMs, coverUrl: playlistCover))
            }
            
            return SpotifyPlaylistData(id: playlistId, title: title, description: description, coverUrl: playlistCover, tracks: tracks)
        } catch {
            print("SpotifyService.fetchPlaylist error: \(error)")
            return nil
        }
    }
    
    func getCachedCover(trackId: String) -> String? {
        return coverCache[trackId]
    }
    
    func fetchTrackCoversBatch(trackIds: [String], concurrency: Int = 6) async -> [String: String] {
        var results = [String: String]()
        var toFetch = [String]()
        
        for id in trackIds {
            if let cached = coverCache[id] {
                results[id] = cached
            } else {
                toFetch.append(id)
            }
        }
        
        if toFetch.isEmpty { return results }
        
        await withTaskGroup(of: (String, String?).self) { group in
            for id in toFetch {
                group.addTask {
                    let url = await self.fetchTrackCoverHD(trackId: id)
                    return (id, url)
                }
            }
            for await (id, url) in group {
                if let u = url {
                    results[id] = u
                }
            }
        }
        return results
    }
    
    func searchTracks(query: String) async -> [SpotifyTrack] {
        guard let token = await SpotifyInternalAuthService.shared.getInternalAccessToken() else {
            return []
        }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=track&limit=15") else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tracksObj = json["tracks"] as? [String: Any],
                   let items = tracksObj["items"] as? [[String: Any]] {
                    
                    var result = [SpotifyTrack]()
                    for t in items {
                        guard let id = t["id"] as? String,
                              let title = t["name"] as? String,
                              let artistsArray = t["artists"] as? [[String: Any]],
                              let albumObj = t["album"] as? [String: Any],
                              let albumName = albumObj["name"] as? String,
                              let durationMs = t["duration_ms"] as? Int else { continue }
                        
                        let artists = artistsArray.compactMap { $0["name"] as? String }.joined(separator: ", ")
                        
                        var coverUrl: String?
                        if let images = albumObj["images"] as? [[String: Any]], let firstImage = images.first {
                            coverUrl = firstImage["url"] as? String
                        }
                        
                        result.append(SpotifyTrack(
                            id: "spotify_\(id)",
                            title: title,
                            artist: artists,
                            album: albumName,
                            duration: Double(durationMs) / 1000.0,
                            thumbnailUrl: coverUrl ?? "",
                            spotifyTrackId: id,
                            /* no yt id */
                        ))
                    }
                    return result
                }
            } else {
                print("Spotify search failed: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            print("SpotifyService.searchTracks error: \(error)")
        }
        return []
    }
}
