import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationView {
            Text("La tua libreria musicale")
                .navigationTitle("Libreria")
        }
    }
}

struct SearchView: View {
    @State private var query = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Cerca brani, artisti o playlist", text: $query)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Riproduci Bohemian Rhapsody (Test)") {
                    AudioEngine.shared.play(videoId: "fJ9rUzIMcZQ", title: "Bohemian Rhapsody", artist: "Queen")
                }
                .padding()
                
                Button("Riproduci Capo Plaza (Test)") {
                    AudioEngine.shared.play(videoId: "hLlJfj_3ufM", title: "Capo Plaza", artist: "Art Track")
                }
                
                Spacer()
            }
            .navigationTitle("Cerca")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Text("Impostazioni (Copieremo quelle di Demus)")
                .navigationTitle("Impostazioni")
        }
    }
}

struct MiniPlayerView: View {
    @StateObject private var engine = AudioEngine.shared
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                // Cover Placeholder
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 44, height: 44)
                    .cornerRadius(4)
                
                VStack(alignment: .leading) {
                    Text(engine.currentTitle)
                        .font(.subheadline)
                        .bold()
                        .lineLimit(1)
                    Text(engine.currentArtist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: {
                    if engine.isPlaying {
                        engine.pause()
                    } else {
                        engine.resume()
                    }
                }) {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground).opacity(0.95))
            .onTapGesture {
                // Espandi a Full Player in futuro
            }
        }
    }
}
