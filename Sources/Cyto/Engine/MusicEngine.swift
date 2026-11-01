import Foundation

public final class MusicEngine: @unchecked Sendable {
    public private(set) var isPlaying: Bool = false
    public private(set) var currentTrack: String?
    public private(set) var currentArtist: String?
    
    public var onPlaybackChange: ((Bool, String?) -> Void)?
    
    private var musicObserver: Any?
    private var spotifyObserver: Any?
    
    public init() {
        setupObservers()
    }
    
    private func setupObservers() {
        let center = DistributedNotificationCenter.default()
        
        // 1. Apple Music
        musicObserver = center.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleNotification(notification, isAppleMusic: true)
        }
        
        // 2. Spotify
        spotifyObserver = center.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleNotification(notification, isAppleMusic: false)
        }
    }
    
    private func handleNotification(_ notification: Notification, isAppleMusic: Bool) {
        guard let info = notification.userInfo else { return }
        
        let stateString = (info["Player State"] as? String) ?? ""
        let playing = stateString.caseInsensitiveCompare("Playing") == .orderedSame ||
                      stateString.contains("Playing")
        
        let trackName: String?
        let artistName: String?
        
        if isAppleMusic {
            trackName = info["Name"] as? String
            artistName = info["Artist"] as? String
        } else {
            trackName = (info["Track"] as? String) ?? (info["Name"] as? String)
            artistName = info["Artist"] as? String
        }
        
        self.isPlaying = playing
        self.currentTrack = playing ? trackName : nil
        self.currentArtist = playing ? artistName : nil
        
        onPlaybackChange?(playing, trackName)
    }
    
    deinit {
        let center = DistributedNotificationCenter.default()
        if let obs = musicObserver { center.removeObserver(obs) }
        if let obs = spotifyObserver { center.removeObserver(obs) }
    }
}
