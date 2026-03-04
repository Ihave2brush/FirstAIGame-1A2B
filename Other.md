# FirstAIGame 開發紀錄 - 2026/03/04

## 1. 今日優化重點回顧

### 音樂與音效系統 (AudioManager)
- **多曲目管理**：區分了 `Background music` (選單)、`Normal` (一般模式) 與 `Time Attack music` (競技模式)。
- **儀式感換軌邏輯**：
    - **同曲重播 (Menu ➔ Menu)**：1s 淡出 ➔ **2s 完全靜默** ➔ 2s 淡入，強化進入感。
    - **異曲切換 (模式轉換)**：0.5s 淡出 ➔ **0.5s 極短靜默** ➔ 0.5s 淡入，保持遊戲節奏。
- **穩定性優化**：引入 `currentlyTargetingURL` 與 `DispatchWorkItem` 機制，徹底解決快速點擊按鈕時導致的音樂重疊與延遲播放 Bug。

### 視覺與 UX 優化
- **霓虹流動背景**：在底層加入深藍與紫色的模糊圓形，透過持續位移營造深邃科技感。
- **粒子噴發特效**：在成功過關時，利用 `TimelineView` 與 `Canvas` 實作綠色數位方塊噴發動畫。
- **三段式觸覺回饋**：
    - **輕震 (.light)**：每次數位輸入。
    - **中震 (.medium)**：猜錯時的提示。
    - **成功震 (.success)**：解碼成功的連續通知震動。
- **背景圖層加強**：針對 Time Attack 模式加入專屬科技感底圖，並使用 `GeometryReader` 與 `clipped()` 修復溢出問題。

---

## 2. 核心程式碼備份

### AudioManager.swift
```swift
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var bgmPlayer: AVAudioPlayer?
    private var sfxPlayer: AVAudioPlayer?
    
    private var currentlyTargetingURL: URL?
    private var pendingBGMItem: DispatchWorkItem?
    
    func playBGM(named name: String, loop: Bool = true, volume: Float = 0.5) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        if currentlyTargetingURL == url && bgmPlayer?.isPlaying == true { return }
        
        currentlyTargetingURL = url
        pendingBGMItem?.cancel()
        
        let isSameTrack = bgmPlayer?.url == url
        
        if let current = bgmPlayer, current.isPlaying {
            current.setVolume(0, fadeDuration: 0.1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.currentlyTargetingURL != current.url { current.stop() }
            }
        }
        
        let silenceDuration: TimeInterval = isSameTrack ? 2.0 : 0.5
        let fadeInDuration: TimeInterval = isSameTrack ? 2.0 : 0.5
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.currentlyTargetingURL == url else { return }
            self.startNewBGM(url: url, loop: loop, volume: volume, fadeIn: fadeInDuration)
        }
        pendingBGMItem = workItem
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
        } catch { print("BGM Error: \(error)") }
    }
    
    func stopBGM(fadeDuration: TimeInterval = 0.5) {
        currentlyTargetingURL = nil
        pendingBGMItem?.cancel()
        bgmPlayer?.setVolume(0, fadeDuration: fadeDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) { self.bgmPlayer?.stop() }
    }
    
    func playSFX(named name: String, type: String = "wav", volume: Float = 1.0) {
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else { return }
        do {
            sfxPlayer = try AVAudioPlayer(contentsOf: url)
            sfxPlayer?.volume = volume
            sfxPlayer?.play()
        } catch { print("SFX Error: \(error)") }
    }
}
```

### ContentView.swift (關鍵異動部分)
```swift
// 音樂管理透過 onChange 統一驅動
.onAppear {
    handleMusicChange(state: gameState, mode: gameMode)
}
.onChange(of: gameState) { _, newValue in
    handleMusicChange(state: newValue, mode: gameMode)
}
.onChange(of: gameMode) { _, newValue in
    handleMusicChange(state: gameState, mode: newValue)
}

private func handleMusicChange(state: GameState, mode: GameMode) {
    switch state {
    case .menu:
        AudioManager.shared.playBGM(named: "Background music", volume: 0.3)
    case .playing:
        if mode == .timeAttack {
            AudioManager.shared.playBGM(named: "Time Attack music", volume: 0.4)
        } else {
            AudioManager.shared.playBGM(named: "Normal", volume: 0.3)
        }
    case .gameOver:
        AudioManager.shared.stopBGM(fadeDuration: 1.0)
    }
}
```

## 3. 命名建議
- **介面名稱**：可於 `mainMenuView` 中修改 `Text("FIRST AI GAME")` 與 `Text("CODE BREAKER")`。
- **App 顯示名稱**：需在 Xcode 的 Target -> Info -> `Bundle display name` 進行設定。
