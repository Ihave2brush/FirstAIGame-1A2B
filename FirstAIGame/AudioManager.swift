//
//  AudioManager.swift
//  FirstAIGame
//

import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var bgmPlayer: AVAudioPlayer?
    private var sfxPlayer: AVAudioPlayer?
    
    // 追蹤目前「打算」播放的 URL，用於過濾過時的異步任務
    private var currentlyTargetingURL: URL?
    private var pendingBGMItem: DispatchWorkItem?
    
    func playBGM(named name: String, loop: Bool = true, volume: Float = 0.5) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        
        // 1. 如果目標已經是這首歌且正在播，則不重複動作
        if currentlyTargetingURL == url && bgmPlayer?.isPlaying == true {
            return
        }
        
        // 2. 標記目前最新的目標，並取消之前的排隊任務
        currentlyTargetingURL = url
        pendingBGMItem?.cancel()
        
        let isSameTrack = bgmPlayer?.url == url
        
        // 3. 立即停止當前音樂 (不管之前的淡出)
        if let current = bgmPlayer, current.isPlaying {
            current.setVolume(0, fadeDuration: 0.1)
            // 延遲一點點停止以防爆音
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.currentlyTargetingURL != current.url { // 只有當目標確實改變時才停止
                    current.stop()
                }
            }
        }
        
        // 4. 計算靜默與淡入時間
        let silenceDuration: TimeInterval = isSameTrack ? 2.0 : 0.5
        let fadeInDuration: TimeInterval = isSameTrack ? 2.0 : 0.5
        
        // 5. 建立排隊任務
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.currentlyTargetingURL == url else { return }
            self.startNewBGM(url: url, loop: loop, volume: volume, fadeIn: fadeInDuration)
        }
        pendingBGMItem = workItem
        
        // 6. 執行靜默後啟動
        DispatchQueue.main.asyncAfter(deadline: .now() + silenceDuration, execute: workItem)
    }
    
    private func startNewBGM(url: URL, loop: Bool, volume: Float, fadeIn: TimeInterval) {
        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = loop ? -1 : 0
            bgmPlayer?.volume = 0
            bgmPlayer?.prepareToPlay()
            bgmPlayer?.play()
            bgmPlayer?.setVolume(volume, fadeDuration: fadeIn)
        } catch {
            print("無法播放背景音樂: \(error.localizedDescription)")
        }
    }
    
    func stopBGM(fadeDuration: TimeInterval = 0.5) {
        currentlyTargetingURL = nil
        pendingBGMItem?.cancel()
        bgmPlayer?.setVolume(0, fadeDuration: fadeDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) {
            self.bgmPlayer?.stop()
        }
    }
    
    func playSFX(named name: String, type: String = "wav", volume: Float = 1.0) {
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else { return }
        do {
            sfxPlayer = try AVAudioPlayer(contentsOf: url)
            sfxPlayer?.volume = volume
            sfxPlayer?.prepareToPlay()
            sfxPlayer?.play()
        } catch {
            print("無法播放音效: \(error.localizedDescription)")
        }
    }
}
