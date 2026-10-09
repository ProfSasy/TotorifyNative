import SwiftUI
import AVKit

struct CanvasView: View {
    let videoUrlString: String
    @State private var player: AVPlayer?
    
    var body: some View {
        GeometryReader { geometry in
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .disabled(true) // Nascondi controlli default
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Color.black.opacity(0.8) // Caricamento
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        guard let url = URL(string: videoUrlString) else { return }
        let p = AVPlayer(url: url)
        p.actionAtItemEnd = .none
        p.isMuted = true
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { _ in
            p.seek(to: .zero)
            p.play()
        }
        self.player = p
    }
}
