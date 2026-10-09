import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showFullPlayer = false
    @ObservedObject var audioEngine = AudioEngine.shared
    
    // Un colore giallo simile a Demus
    let accentColor = Color(red: 1.0, green: 0.7, blue: 0.0)
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Aggiungi")
                    }
                    .tag(0)
                
                Text("Brani")
                    .tabItem {
                        Image(systemName: "music.note")
                        Text("Brani")
                    }
                    .tag(1)
                
                Text("Album")
                    .tabItem {
                        Image(systemName: "square.stack")
                        Text("Album")
                    }
                    .tag(2)
                
                Text("Artisti")
                    .tabItem {
                        Image(systemName: "mic")
                        Text("Artisti")
                    }
                    .tag(3)
                
                Text("Playlist")
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("Playlist")
                    }
                    .tag(4)
            }
            .accentColor(accentColor)
            
            // Mini Player Floating
            if audioEngine.currentVideoId != nil {
                MiniPlayerView(showFullPlayer: $showFullPlayer)
                    .padding(.bottom, 50) // Sopra la tab bar
                    .padding(.horizontal, 10)
            }
        }
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView(showFullPlayer: $showFullPlayer)
        }
        .preferredColorScheme(.dark)
    }
}
