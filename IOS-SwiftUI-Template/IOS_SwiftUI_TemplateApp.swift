import SwiftUI
import SwiftData

@main
struct TotorifyNativeApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [TotorSong.self, TotorPlaylist.self])
    }
}
