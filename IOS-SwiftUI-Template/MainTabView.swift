import SwiftUI

struct MainTabView: View {
    @StateObject private var audioEngine = AudioEngine.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                LibraryView()
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("La tua musica")
                    }
                
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Cerca")
                    }
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Impostazioni")
                    }
            }
            .accentColor(Color(red: 0.9, green: 0.2, blue: 0.2)) // Colore stile Demus
            
            // Mini Player Overlay (Mostrato sempre sopra le tab)
            if audioEngine.currentVideoId != nil {
                MiniPlayerView()
                    .offset(y: -49) // Offset per stare sopra la TabBar
            }
        }
    }
}
