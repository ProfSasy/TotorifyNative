import Foundation
import Combine

class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var searchResults: [SpotifyTrack] = []
    @Published var isSearching: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $query
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newQuery in
                self?.performSearch(query: newQuery)
            }
            .store(in: &cancellables)
    }
    
    func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            DispatchQueue.main.async {
                self.searchResults = []
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isSearching = true
        }
        
        Task {
            let results = await SpotifyService.shared.searchTracks(query: query); if true {
                DispatchQueue.main.async {
                    self.searchResults = results
                    self.isSearching = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isSearching = false
                }
            }
        }
    }
}
