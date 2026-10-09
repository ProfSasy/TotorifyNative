import Foundation
import WebKit
import AVFoundation

class AudioEngine: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = AudioEngine()
    
    private var webView: WKWebView!
    @Published var isPlaying = false
    @Published var currentPosition: Double = 0
    @Published var duration: Double = 0
    
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
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15" // AGGIRA I BLOCCHI MOBILE
    }
    
    func play(videoId: String) {
        // Carica la pagina embed ufficiale, forzando l'autoplay tramite parametri URL
        let urlString = "https://www.youtube.com/embed/\(videoId)?autoplay=1&playsinline=1&enablejsapi=1"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer") // BYPASS BLOCCO EMBED
        
        webView.load(request)
        isPlaying = true
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
