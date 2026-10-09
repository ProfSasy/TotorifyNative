import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var filterIndex = 0
    let filters = ["Popolari", "Classifiche"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Cerca su Spotify, YouTube, Wikipedia...", text: $viewModel.query)
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    if !viewModel.searchResults.isEmpty {
                        ForEach(viewModel.searchResults) { track in
                            HStack {
                                AsyncImage(url: URL(string: track.coverUrl ?? "")) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 50, height: 50)
                                .cornerRadius(5)
                                
                                VStack(alignment: .leading) {
                                    Text(track.title)
                                        .font(.headline)
                                    Text(track.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button(action: {
                                    // MATCH and PLAY
                                    playTrack(track: track)
                                }) {
                                    Image(systemName: "play.circle")
                                        .font(.title)
                                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Picker "Popolari" / "Classifiche"
                        Picker("Filtro", selection: $filterIndex) {
                            ForEach(0..<filters.count, id: \\.self) { index in
                                Text(filters[index]).tag(index)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // Carousel 1
                        Text("The sound of autumn")
                            .font(.title2).bold()
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(0..<5) { _ in
                                    VStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 150, height: 150)
                                            .cornerRadius(10)
                                        Text("Morning Drive")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Taylor Swift")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Scelte Rapide
                        Text("Scelte rapide >")
                            .font(.title2).bold()
                            .padding(.horizontal)
                        
                        VStack(spacing: 10) {
                            ForEach(0..<3) { _ in
                                HStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(5)
                                    
                                    VStack(alignment: .leading) {
                                        Text("PER NOI (feat. Achille Lauro)")
                                            .font(.headline)
                                        Text("Geolier")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .font(.title2)
                                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer(minLength: 100) // Spazio per il MiniPlayer
                }
            }
            .navigationTitle("Aggiungi")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "gearshape")
                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "crown")
                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Accedi") {}
                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                }
            }
        }
    }
    
    private func playTrack(track: SpotifyTrack) {
        Task {
            let id = await TrackMatcherService.shared.resolveAndCacheStreamId(for: track)
            if let ytId = id {
                DispatchQueue.main.async {
                    AudioEngine.shared.play(videoId: ytId, title: track.title, artist: track.artist)
                }
            }
        }
    }
}
