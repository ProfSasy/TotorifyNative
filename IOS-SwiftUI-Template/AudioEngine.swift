import Foundation
import WebKit
import AVFoundation

class AudioEngine: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = AudioEngine()
    
    private var webView: WKWebView!
    @Published var isPlaying = false
    @Published var currentPosition: Double = 0
    @Published var duration: Double = 0
    @Published var currentVideoId: String? = nil
    @Published var currentTitle: String = "Senza Titolo"
    @Published var currentArtist: String = "Sconosciuto"
    
    override init() {
        super.init()
        setupAudioSession()
        setupWebView()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("Failed to set audio session category.")
        }
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [] // FORZA L'AUTOPLAY (IL SEGRETO DI DEMUS)
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
    }
    
    func play(videoId: String, title: String = "Senza Titolo", artist: String = "Sconosciuto") {
        self.currentVideoId = videoId
        self.currentTitle = title
        self.currentArtist = artist
        
        // Carichiamo la VERA pagina di YouTube, NON l'embed. 
        // Questo distrugge completamente qualsiasi blocco "notEmbeddable" perché per i server di YouTube stiamo semplicemente visitando il sito!
        let urlString = "https://m.youtube.com/watch?v=\(videoId)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        webView.load(request)
        isPlaying = true
        startPolling()
    }
    
    // Implementiamo il delegate per forzare il play quando la pagina ha finito di caricare
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Appena la pagina carica, cerchiamo il tag <video> e forziamo la riproduzione ignorando il tap
        let js = """
        setTimeout(function() {
            var v = document.querySelector('video');
            if(v) { 
                v.play(); 
            } else {
                // Su alcune interfacce mobile di youtube serve un click sul bottone play
                var btn = document.querySelector('.ytp-large-play-button');
                if(btn) btn.click();
            }
        }, 1000);
        """
        webView.evaluateJavaScript(js)
    }
    
    func pause() {
        webView.evaluateJavaScript("document.querySelector('video').pause();")
        isPlaying = false
    }
    
    func resume() {
        webView.evaluateJavaScript("document.querySelector('video').play();")
        isPlaying = true
    }
    
    // Polling per aggiornare la UI
    func startPolling() {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.webView.evaluateJavaScript("document.querySelector('video').currentTime;") { result, error in
                if let time = result as? Double {
                    self?.currentPosition = time
                }
            }
        }
    }
}
