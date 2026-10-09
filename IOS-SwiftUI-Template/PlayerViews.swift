import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        return AudioEngine.shared.webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct MiniPlayerView: View {
    @Binding var showFullPlayer: Bool
    @ObservedObject var audioEngine = AudioEngine.shared
    
    var body: some View {
        HStack {
            Rectangle() // Cover placeholder
                .fill(Color.red)
                .frame(width: 40, height: 40)
                .cornerRadius(5)
            
            Text(audioEngine.currentTitle)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                if audioEngine.isPlaying {
                    audioEngine.pause()
                } else {
                    audioEngine.resume()
                }
            }) {
                Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))
            }
            .padding(.trailing, 10)
            
            Button(action: {}) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.0))
            }
        }
        .padding(10)
        .background(Color(.systemGray6).opacity(0.95))
        .cornerRadius(15)
        .onTapGesture {
            showFullPlayer = true
        }
    }
}

struct FullPlayerView: View {
    @Binding var showFullPlayer: Bool
    @ObservedObject var audioEngine = AudioEngine.shared
    @State private var viewMode = 2 // 0: YouTube, 1: Video, 2: Immagine
    
    var body: some View {
        ZStack {
            // Sfondo dinamico (rosso per Capo Plaza come nello screen)
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.4, green: 0.1, blue: 0.1), .black]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { showFullPlayer = false }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Picker("", selection: $viewMode) {
                        Text("YouTube").tag(0)
                        Text("Video").tag(1)
                        Text("Immagine").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 250)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
                
                // Artwork o Video
                if viewMode == 1 {
                    WebViewWrapper()
                        .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                } else {
                    Rectangle() // Artwork placeholder
                        .fill(Color.red)
                        .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                }
                
                Spacer()
                
                // Info Brano
                VStack(alignment: .leading) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(audioEngine.currentTitle)
                                .font(.title).bold()
                                .foregroundColor(.white)
                            Text(audioEngine.currentArtist)
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .font(.title)
                            .foregroundColor(.white)
                        Image(systemName: "ellipsis")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(.leading, 10)
                    }
                }
                .padding(.horizontal, 30)
                
                // Slider (Finto per ora)
                Slider(value: .constant(0.2))
                    .accentColor(.white)
                    .padding(.horizontal, 30)
                
                HStack {
                    Text("0:27")
                    Spacer()
                    Text("-2:52")
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 30)
                
                // Controlli Audio
                HStack(spacing: 40) {
                    Image(systemName: "shuffle")
                    Image(systemName: "backward.fill").font(.title)
                    Button(action: {
                        if audioEngine.isPlaying {
                            audioEngine.pause()
                        } else {
                            audioEngine.resume()
                        }
                    }) {
                        Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 40))
                    }
                    Image(systemName: "forward.fill").font(.title)
                    Image(systemName: "repeat")
                }
                .foregroundColor(.white)
                .padding(.bottom, 30)
                
                // Bottom actions
                HStack(spacing: 50) {
                    Image(systemName: "list.bullet")
                    Image(systemName: "wand.and.stars")
                    Image(systemName: "airplayaudio")
                    Image(systemName: "quote.bubble") // Testi
                }
                .foregroundColor(.gray)
                .padding(.bottom, 40)
            }
        }
    }
}
