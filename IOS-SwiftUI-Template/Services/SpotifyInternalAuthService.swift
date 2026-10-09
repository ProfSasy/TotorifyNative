import Foundation
import CryptoKit

class SpotifyInternalAuthService {
    static let shared = SpotifyInternalAuthService()
    
    private let serverTimeUrl = "https://open.spotify.com/api/server-time"
    private let nuanceUrl = "https://gist.githubusercontent.com/sonic-liberation/22ed9c6ba463899e933427f7de1f0eef/raw/nuances.json"
    private let tokenUrl = "https://open.spotify.com/api/token"
    
    private var accessToken: String?
    private var tokenExpirationTime: Int64 = 0
    
    private init() {}
    
    func saveSpDcCookie(_ spDc: String) async {
        await StorageService.shared.setSpDcCookie(spDc)
        accessToken = nil // Invalidate current token
    }
    
    func getSpDcCookie() -> String? {
        return StorageService.shared.spDcCookie
    }
    
    var hasSpDcCookie: Bool {
        let cookie = getSpDcCookie()
        return cookie != nil && !(cookie!.isEmpty)
    }
    
    /// Restituisce l'access token interno, rigenerandolo tramite TOTP se scaduto.
    func getInternalAccessToken() async -> String? {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if let token = accessToken, now < tokenExpirationTime {
            return token
        }
        
        guard let spDc = getSpDcCookie(), !spDc.isEmpty else {
            print("SpotifyInternalAuth: Nessun cookie sp_dc trovato.")
            return nil
        }
        
        do {
            let totpData = try await generateTotp()
            guard let code = totpData["code"] as? String,
                  let version = totpData["version"] as? Int else {
                return nil
            }
            
            guard var urlComponents = URLComponents(string: tokenUrl) else { return nil }
            urlComponents.queryItems = [
                URLQueryItem(name: "reason", value: "transport"),
                URLQueryItem(name: "productType", value: "web-player"),
                URLQueryItem(name: "totp", value: code),
                URLQueryItem(name: "totpServer", value: code),
                URLQueryItem(name: "totpVer", value: String(version))
            ]
            
            guard let url = urlComponents.url else { return nil }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64)", forHTTPHeaderField: "User-Agent")
            request.setValue("sp_dc=\(spDc)", forHTTPHeaderField: "Cookie")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let token = json["accessToken"] as? String
                    let isAnonymous = json["isAnonymous"] as? Bool ?? true
                    
                    if isAnonymous || token == nil || token!.isEmpty {
                        print("SpotifyInternalAuth: Il cookie sp_dc fornito è invalido o scaduto.")
                        return nil
                    }
                    
                    self.accessToken = token
                    self.tokenExpirationTime = now + 3500000 // Valido per ~1 ora
                    return self.accessToken
                }
            } else {
                let bodyString = String(data: data, encoding: .utf8) ?? ""
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("SpotifyInternalAuth: HTTP \(statusCode) - \(bodyString)")
            }
        } catch {
            print("SpotifyInternalAuth: Errore durante il recupero del token: \(error)")
        }
        return nil
    }
    
    private func generateTotp() async throws -> [String: Any] {
        guard let nUrl = URL(string: nuanceUrl), let tUrl = URL(string: serverTimeUrl) else {
            throw URLError(.badURL)
        }
        
        let (nData, _) = try await URLSession.shared.data(from: nUrl)
        guard let nuances = try JSONSerialization.jsonObject(with: nData) as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }
        
        var secret = ""
        var version = 0
        for n in nuances {
            if let v = n["v"] as? Int, let s = n["s"] as? String {
                if v > version && isValidBase32(s) {
                    version = v
                    secret = s
                }
            }
        }
        
        let (tData, _) = try await URLSession.shared.data(from: tUrl)
        guard let timeJson = try JSONSerialization.jsonObject(with: tData) as? [String: Any],
              let serverTimeSec = timeJson["serverTime"] as? Int else {
            throw URLError(.cannotParseResponse)
        }
        
        let code = generateTotpFromSecret(secret: secret, serverTimeSec: serverTimeSec)
        return ["code": code, "version": version]
    }
    
    private func isValidBase32(_ secret: String) -> Bool {
        let regex = "^[A-Z2-7]+=*$"
        return secret.range(of: regex, options: .regularExpression) != nil
    }
    
    private func generateTotpFromSecret(secret: String, serverTimeSec: Int) -> String {
        let timeStep = Int(floor(Double(serverTimeSec) / 30.0))
        let key = base32Decode(secret)
        
        var timeBytes = [UInt8](repeating: 0, count: 8)
        var value = timeStep
        for i in (0...7).reversed() {
            timeBytes[i] = UInt8(value & 0xFF)
            value = value >> 8
        }
        
        let symmetricKey = SymmetricKey(data: key)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: timeBytes, using: symmetricKey)
        let digest = Array(hmac)
        
        let offset = Int(digest[digest.count - 1] & 0x0F)
        let binary = ((Int(digest[offset] & 0x7F) << 24) |
                      (Int(digest[offset + 1] & 0xFF) << 16) |
                      (Int(digest[offset + 2] & 0xFF) << 8) |
                      Int(digest[offset + 3] & 0xFF))
        
        let otp = binary % 1_000_000
        return String(format: "%06d", otp)
    }
    
    private func base32Decode(_ input: String) -> [UInt8] {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let cleaned = input.uppercased().replacingOccurrences(of: "=", with: "")
        var output = [UInt8]()
        var buffer: Int = 0
        var bitsLeft: Int = 0
        
        for char in cleaned {
            guard let val = alphabet.firstIndex(of: char)?.utf16Offset(in: alphabet) else { continue }
            buffer = (buffer << 5) | val
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                output.append(UInt8((buffer >> bitsLeft) & 0xFF))
            }
        }
        return output
    }
}
