import Foundation
import SwiftData

@Model
class TotorSong {
    @Attribute(.unique) var id: String
    var title: String
    var artist: String
    var album: String?
    var coverUrl: String?
    var duration: Double
    var ytVideoId: String?
    var isDownloaded: Bool = false
    
    init(id: String, title: String, artist: String, album: String? = nil, coverUrl: String? = nil, duration: Double = 0, ytVideoId: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.coverUrl = coverUrl
        self.duration = duration
        self.ytVideoId = ytVideoId
    }
}

@Model
class TotorPlaylist {
    @Attribute(.unique) var id: String
    var name: String
    var coverUrl: String?
    @Relationship var songs: [TotorSong] = []
    
    init(id: String = UUID().uuidString, name: String, coverUrl: String? = nil) {
        self.id = id
        self.name = name
        self.coverUrl = coverUrl
    }
}
