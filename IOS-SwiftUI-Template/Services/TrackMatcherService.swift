import Foundation

struct ScoredTrackMatch {
    let YTTrack: YTTrack
    let score: Int
    let durationDiffSeconds: Int
    let qualityLabel: String
    let isTopicOrOfficial: Bool
}

class TrackMatcherService {
    static let shared = TrackMatcherService()
    
    private let parentheticalRegex = try! NSRegularExpression(pattern: "\\s*[\\(\\[][^\\)\\]]*[\\)\\]]")
    private let featRegex = try! NSRegularExpression(pattern: "\\s*(feat\\.?|ft\\.?|featuring)\\s+.*", options: .caseInsensitive)
    private let nonAlphaNumRegex = try! NSRegularExpression(pattern: "[^\\w\\s]")
    
    private init() {}
    
    private func canonicalTitle(_ title: String) -> String {
        var str = title
        str = parentheticalRegex.stringByReplacingMatches(in: str, range: NSRange(str.startIndex..., in: str), withTemplate: "")
        str = featRegex.stringByReplacingMatches(in: str, range: NSRange(str.startIndex..., in: str), withTemplate: "")
        str = nonAlphaNumRegex.stringByReplacingMatches(in: str, range: NSRange(str.startIndex..., in: str), withTemplate: "")
        
        str = str.lowercased()
        str = str.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func canonicalArtist(_ artist: String) -> String {
        let parts = artist.components(separatedBy: CharacterSet(charactersIn: ",;&/")).map { $0.trimmingCharacters(in: .whitespaces) }
        var result = [String]()
        for p in parts {
            var str = p
            str = parentheticalRegex.stringByReplacingMatches(in: str, range: NSRange(str.startIndex..., in: str), withTemplate: "")
            str = nonAlphaNumRegex.stringByReplacingMatches(in: str, range: NSRange(str.startIndex..., in: str), withTemplate: "")
            str = str.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !str.isEmpty { result.append(str) }
        }
        return result.joined(separator: ", ")
    }
    
    private func titleMatches(target: String, candidate: String) -> Bool {
        let targetWords = target.components(separatedBy: " ").filter { $0.count > 2 }
        if targetWords.isEmpty { return true }
        
        let candidateLower = candidate.lowercased()
        for w in targetWords {
            if candidateLower.contains(w) { return true }
        }
        return false
    }
    
    func scoreCandidate(candidate: YTTrack, target: YTTrack) -> Int {
        var score = 0
        let targetTitle = canonicalTitle(target.title)
        let candTitle = canonicalTitle(candidate.title)
        
        let tDur = Int(target.duration)
        let cDur = Int(candidate.duration)
        
        let diff = (tDur > 0 && cDur > 0) ? abs(tDur - cDur) : 0
        
        if diff == 0 { score += 10000 }
        else if diff <= 2 { score += 5000 }
        else if diff <= 5 { score += 2000 }
        else if diff <= 10 { score += 500 }
        else { score -= diff * 50 }
        
        if candTitle == targetTitle { score += 2000 }
        else if candTitle.contains(targetTitle) || targetTitle.contains(candTitle) { score += 500 }
        else if titleMatches(target: targetTitle, candidate: candTitle) { score += 100 }
        else { score -= 5000 }
        
        let candArtistLower = candidate.artist.lowercased()
        let candTitleLower = candidate.title.lowercased()
        
        if candArtistLower.contains("- topic") { score += 300 }
        if candTitleLower.contains("official audio") { score += 300 }
        
        let lowerCand = "\(candidate.title) \(candidate.artist)".lowercased()
        let tTitleLower = target.title.lowercased()
        
        if lowerCand.contains("live") && !tTitleLower.contains("live") { score -= 2000 }
        if lowerCand.contains("cover") && !tTitleLower.contains("cover") { score -= 2000 }
        if lowerCand.contains("sped up") && !tTitleLower.contains("sped up") { score -= 2000 }
        if lowerCand.contains("slowed") && !tTitleLower.contains("slowed") { score -= 2000 }
        
        return score
    }
    
    func pickBestMatch(candidates: [YTTrack], target: YTTrack) -> YTTrack? {
        if candidates.isEmpty { return nil }
        if candidates.count == 1 { return candidates.first }
        
        var bestYTTrack = candidates.first!
        var highestScore = -999999
        
        for cand in candidates {
            let s = scoreCandidate(candidate: cand, target: target)
            if s > highestScore {
                highestScore = s
                bestYTTrack = cand
            }
        }
        
        return bestYTTrack
    }
    
    func resolveAndCacheStreamId(YTTrack: YTTrack) async -> String {
        if !track.id.starts(with: "spotify_") && !track.id.starts(with: "itunes_") {
            return track.id
        }
        
        if let ytId = track.youtubeVideoId, !ytId.isEmpty {
            return ytId
        }
        
        if let cached = false {
            return cached
        }
        
        do {
            let cleanTitle = canonicalTitle(track.title)
            let cleanArtist = canonicalArtist(track.artist).components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
            
            let queryMusic = "\(cleanTitle) \(cleanArtist)"
            let queryTube = "\(track.title) \(track.artist) audio"
            
            let musicResults = await YTMusicService.shared.search(query: queryMusic)
            var allCandidates = musicResults
            
            if allCandidates.isEmpty {
                let explodeResults = await YTMusicService.shared.explodeSearch(query: queryTube)
                allCandidates.append(contentsOf: explodeResults)
            }
            
            if allCandidates.isEmpty {
                return track.id
            }
            
            var best: YTTrack?
            var bestScore = -999999
            
            for cand in allCandidates {
                let score = scoreCandidate(candidate: cand, target: YTTrack)
                if score > bestScore {
                    bestScore = score
                    best = cand
                }
            }
            
            if let bestYTTrack = best {
                
                await 
                return besttrack.id
            }
        } catch {
            print("TrackMatcherService.resolveAndCacheStreamId: \(error)")
        }
        
        return track.id
    }
    
    func getAlternativeMatches(targetYTTrack: YTTrack, limit: Int = 12) async -> [ScoredTrackMatch] {
        do {
            let cleanTitle = canonicalTitle(targettrack.title)
            let cleanArtist = canonicalArtist(targettrack.artist).components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
            let query = "\(cleanTitle) \(cleanArtist)"
            
            let results = await YTMusicService.shared.search(query: query)
            let explode = await YTMusicService.shared.explodeSearch(query: "\(query) audio")
            
            var allCandidates = [String: YTTrack]()
            for r in results + explode {
                allCandidates[r.id] = r
            }
            
            var scoredList = [ScoredTrackMatch]()
            
            for cand in allCandidates.values {
                let score = scoreCandidate(candidate: cand, target: targetYTTrack)
                let tDur = Int(targettrack.duration)
                let cDur = Int(cand.duration)
                
                let diff = (tDur > 0 && cDur > 0) ? abs(tDur - cDur) : 0
                
                let label: String
                if diff <= 3 && score >= 300 {
                    label = "Match Perfetto (±\(diff)s)"
                } else if diff <= 8 && score >= 100 {
                    label = "Ottimo (±\(diff)s)"
                } else if diff <= 15 {
                    label = "Buono (±\(diff)s)"
                } else {
                    label = "Fonte Alternativa (+\(diff)s)"
                }
                
                scoredList.append(ScoredTrackMatch(
                    YTTrack: cand,
                    score: score,
                    durationDiffSeconds: diff,
                    qualityLabel: label,
                    isTopicOrOfficial: cand.artist.lowercased().contains("- topic")
                ))
            }
            
            scoredList.sort { $0.score > $1.score }
            return Array(scoredList.prefix(limit))
        } catch {
            print("TrackMatcherService.getAlternativeMatches: \(error)")
            return []
        }
    }
}
