# FirstAIGame 專案開發紀錄與原始碼彙整

本文件紀錄了 **FirstAIGame** (1A2B Code Breaker) 專案的開發歷程、實作步驟以及最終的原始碼。

## 1. 開發歷程與實作步驟

### 第一階段：專案建立與基礎結構
- **專案初始化**：建立了名為 `FirstAIGame` 的 SwiftUI 專案，設定了標準的 iOS 專案目錄結構。
- **基礎 UI 實作**：建立初步的 `ContentView.swift`，使用 `VStack` 與 `HStack` 建立基本的計數器原型。
- **配置清理**：清理了從 Demo 專案複製過來的舊路徑參考，確保 `FirstAIGame` 擁有獨立的開發環境。

### 第二階段：核心遊戲邏輯 (1A2B)
- **隨機數生成**：實作了不重複隨機 4 位數生成算法。
- **A/B 判斷邏輯**：撰寫了精確的 `A`（位置與數字皆對）與 `B`（數字對但位置錯）計算機制。
- **黑客解碼主題 UI**：
    - 採用深色霓虹主題 (`#0D0D1A`)。
    - 實作自定義數位鍵盤，具備「已輸入數字禁用」功能防止重複輸入。
    - 建立 4 個發光的數位輸入框。

### 第三階段：動態效果與使用者體驗優化
- **時鐘 App 風格紀錄列表**：
    - 利用 iOS 17 的 `.scrollTransition` 實作「中心放大、滑開縮小」的動態焦點效果。
    - 加入 `.scrollTargetBehavior(.viewAligned)`，實現滑動自動對齊中心的「段落感」。
- **自動捲動**：確保每次輸入新紀錄後，清單會自動平滑捲動到底部。
- **計次器功能**：記錄玩家每場遊戲嘗試的次數。

### 第四階段：生涯紀錄與多模式擴展
- **最佳紀錄儲存 (Best Score)**：使用 `@AppStorage` 實作本地持久化儲存，紀錄 BASIC 模式的最少嘗試次數。
- **多模式選擇介面**：
    - **BASIC**：經典 4 位數解碼。
    - **HARD**：極限 5 位數解碼。
    - **TIME ATTACK**：限時 120 秒挑戰，每過一關獎勵時間（隨關卡數遞減）。
- **緊急倒數警告**：當 TIME ATTACK 倒數至最後 10 秒時，觸發全螢幕紅色呼吸燈與計時器抖動特效。
- **過關動畫**：實作「ACCESS GRANTED」全螢幕成功特效，增強解碼成功的快感。
- **退出功能**：在所有模式中加入「返回主選單」按鍵，並確保計時器能正確停止。

---

## 2. 原始碼檔案彙整

### FirstAIGameApp.swift
```swift
//
//  FirstAIGameApp.swift
//  FirstAIGame
//
//  Created by Kimi on 2026/03/03.
//

import SwiftUI

@main
struct FirstAIGameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### ContentView.swift
```swift
//
//  ContentView.swift
//  FirstAIGame
//
//  Created by Kimi on 2026/03/03.
//

import SwiftUI
import Combine

// MARK: - Models
enum GameMode: String, CaseIterable {
    case basic = "BASIC"
    case hard = "HARD"
    case timeAttack = "TIME ATTACK"
    
    var digitCount: Int {
        self == .hard ? 5 : 4
    }
}

enum GameState {
    case menu
    case playing
    case gameOver
}

struct GameRecord: Identifiable {
    let id = UUID()
    let guess: String
    let aCount: Int
    let bCount: Int
    let tryIndex: Int
}

// MARK: - Main View
struct ContentView: View {
    // 遊戲狀態控制
    @State private var gameState: GameState = .menu
    @State private var gameMode: GameMode = .basic
    
    // 遊戲數據
    @State private var targetNumber: [Int] = []
    @State private var currentGuess: [Int] = []
    @State private var history: [GameRecord] = []
    @State private var tryCount = 0
    @State private var levelScore = 0
    
    // 動畫狀態
    @State private var showWinEffect = false
    @State private var winEffectScale: CGFloat = 0.5
    @State private var winEffectOpacity: Double = 0
    @State private var warningFlash = false
    
    // 計時器邏輯
    @State private var timeRemaining = 120
    @State private var currentRewardTime = 45 // 初始獎勵時間
    @State private var timer: AnyCancellable?
    
    // 生涯最佳
    @AppStorage("bestTryCount") private var bestTryCount = 0
    @AppStorage("bestTimeAttackScore") private var bestTimeAttackScore = 0
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            // 緊急倒數紅色閃爍層
            if gameMode == .timeAttack && timeRemaining <= 10 && gameState == .playing {
                Color.red.opacity(warningFlash ? 0.2 : 0.05)
                    .ignoresSafeArea()
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                            warningFlash = true
                        }
                    }
                    .onDisappear { warningFlash = false }
            }
            
            switch gameState {
            case .menu:
                mainMenuView
            case .playing:
                gamePlayView
            case .gameOver:
                gameOverView
            }
            
            if showWinEffect { successOverlay }
        }
    }
    
    // MARK: - Subviews: Menu
    
    private var mainMenuView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Text("FIRST AI GAME").font(.system(size: 14, weight: .black)).tracking(8).foregroundColor(.blue.opacity(0.7))
                Text("CODE BREAKER").font(.system(size: 44, weight: .bold, design: .monospaced)).foregroundColor(.white).shadow(color: .blue, radius: 15)
            }
            .padding(.top, 100)
            
            Spacer()
            
            VStack(spacing: 20) {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    Button(action: { withAnimation(.spring()) { startNewGame(mode: mode) } }) {
                        VStack(spacing: 4) {
                            Text(mode.rawValue).font(.title3).fontWeight(.bold)
                            Text(modeDescription(mode)).font(.caption2).opacity(0.7)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(modeColor(mode).opacity(0.12))
                        .foregroundColor(modeColor(mode))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(modeColor(mode), lineWidth: 2))
                        .cornerRadius(15)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            hallOfFameView
        }
    }
    
    private var hallOfFameView: some View {
        Group {
            if bestTimeAttackScore > 0 || bestTryCount > 0 {
                VStack(spacing: 8) {
                    Text("--- HALL OF FAME ---").font(.system(size: 10, weight: .bold)).foregroundColor(.gray.opacity(0.5))
                    HStack(spacing: 25) {
                        VStack { Text("BASIC BEST").font(.system(size: 9)); Text("\(bestTryCount)").font(.system(size: 16, weight: .bold)) }.foregroundColor(.blue)
                        VStack { Text("TIME ATTACK").font(.system(size: 9)); Text("\(bestTimeAttackScore)").font(.system(size: 16, weight: .bold)) }.foregroundColor(.orange)
                    }.monospaced()
                }.padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Subviews: Game Play
    
    private var gamePlayView: some View {
        VStack(spacing: 15) {
            HStack(alignment: .center) {
                Button(action: { quitGame() }) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundColor(.gray).padding(10).background(Circle().fill(Color.white.opacity(0.1)))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(gameMode.rawValue).font(.system(size: 10, weight: .black)).foregroundColor(modeColor(gameMode))
                    Text(gameMode == .timeAttack ? "LEVEL \(levelScore + 1)" : "DECODING...").font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(.white)
                }
                Spacer()
                statusDisplay
            }
            .padding(.top, 40)
            
            guessInputView
            historyListView
            
            if gameMode == .timeAttack && !showWinEffect {
                Text("NEXT REWARD: +\(currentRewardTime)s")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.7))
                    .padding(.vertical, 5)
            }
            
            Spacer()
            numberPadView
        }
        .padding(.horizontal)
    }
    
    private var statusDisplay: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if gameMode == .timeAttack {
                Text("TIME LEFT").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                Text("\(timeRemaining)s")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(timeRemaining <= 10 ? .red : .orange)
                    .scaleEffect(timeRemaining <= 10 && warningFlash ? 1.1 : 1.0)
            } else {
                Text("ATTEMPTS").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                Text("\(tryCount)").font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.orange)
            }
        }
    }
    
    private var successOverlay: some View {
        ZStack {
            Color.green.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 80)).foregroundColor(.green).shadow(color: .green, radius: 20)
                Text("ACCESS GRANTED").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundColor(.white).shadow(color: .green, radius: 10)
                if gameMode == .timeAttack { Text("REWARD: +\(currentRewardTime)s").font(.title2).bold().foregroundColor(.green) }
                Text("ENCRYPTION BROKEN").font(.caption).tracking(4).foregroundColor(.green.opacity(0.8))
            }
            .scaleEffect(winEffectScale).opacity(winEffectOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { winEffectScale = 1.0; winEffectOpacity = 1.0 }
        }
    }
    
    // MARK: - Components
    
    private var guessInputView: some View {
        HStack(spacing: 8) {
            ForEach(0..<gameMode.digitCount, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 10).stroke(currentGuess.indices.contains(index) ? modeColor(gameMode) : Color.gray.opacity(0.2), lineWidth: 2).frame(width: gameMode == .hard ? 50 : 60, height: 75).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    if currentGuess.indices.contains(index) { Text("\(currentGuess[index])").font(.system(size: 32, weight: .bold, design: .monospaced)).foregroundColor(.white) }
                }
            }
        }
    }
    
    private var historyListView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    Color.clear.frame(height: 40)
                    ForEach(history) { record in
                        HStack {
                            Text("#\(record.tryIndex)").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray).frame(width: 25)
                            Text(record.guess).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.white)
                            Spacer()
                            HStack(spacing: 8) { resultBadge(count: record.aCount, label: "A", color: .green); resultBadge(count: record.bCount, label: "B", color: .orange) }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.08)))
                        .scrollTransition(.animated) { content, phase in content.opacity(phase.isIdentity ? 1.0 : 0.3).scaleEffect(phase.isIdentity ? 1.0 : 0.8) }
                        .id(record.id)
                    }
                    Color.clear.frame(height: 40)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned).frame(height: 180)
            .onChange(of: history.count) { _, _ in withAnimation { proxy.scrollTo(history.last?.id, anchor: .center) } }
        }
    }
    
    private func resultBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 2) { Text("\(count)").fontWeight(.bold); Text(label).font(.caption2) }.foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(color.opacity(0.8)))
    }
    
    private var numberPadView: some View {
        VStack(spacing: 10) {
            let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [-1, 0, -2]]
            ForEach(0..<4, id: \.self) { rowIndex in
                HStack(spacing: 12) {
                    ForEach(rows[rowIndex], id: \.self) { num in
                        if num >= 0 {
                            Button(action: { addDigit(num) }) {
                                Text("\(num)").font(.title3).fontWeight(.bold).frame(width: 80, height: 50).background(currentGuess.contains(num) ? Color.gray.opacity(0.1) : Color.white.opacity(0.1)).foregroundColor(currentGuess.contains(num) ? .gray : .white).cornerRadius(15)
                            }.disabled(currentGuess.contains(num))
                        } else { actionButton(type: num) }
                    }
                }
            }
        }.padding(.bottom, 20)
    }
    
    private func actionButton(type: Int) -> some View {
        Button(action: { if type == -1 { currentGuess.removeAll() } else if !currentGuess.isEmpty { currentGuess.removeLast() } }) {
            Image(systemName: type == -1 ? "trash" : "delete.left").font(.title3).frame(width: 80, height: 50).background(type == -1 ? Color.red.opacity(0.2) : Color.blue.opacity(0.2)).foregroundColor(type == -1 ? .red : .blue).cornerRadius(15)
        }
    }
    
    private var gameOverView: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 60)).foregroundColor(.red)
            Text("SYSTEM TERMINATED").font(.system(size: 32, weight: .bold, design: .monospaced)).foregroundColor(.white)
            VStack(spacing: 10) {
                Text("MODE: \(gameMode.rawValue)")
                if gameMode == .timeAttack { Text("LEVELS CLEARED: \(levelScore)").font(.title2).bold().foregroundColor(.orange) }
                else { Text("TOTAL ATTEMPTS: \(tryCount)") }
            }.foregroundColor(.gray)
            Button(action: { gameState = .menu }) { Text("RETURN TO MAIN MENU").fontWeight(.bold).padding().frame(maxWidth: .infinity).background(Color.blue).foregroundColor(.white).cornerRadius(15) }.padding(.horizontal, 40)
        }
    }
    
    // MARK: - Game Logic
    
    private func modeColor(_ mode: GameMode) -> Color {
        switch mode { case .basic: return .blue; case .hard: return .purple; case .timeAttack: return .orange }
    }
    
    private func modeDescription(_ mode: GameMode) -> String {
        switch mode { case .basic: return "4 DIGITS - NO LIMIT"; case .hard: return "5 DIGITS - EXTREME"; case .timeAttack: return "120S + DECREASING REWARD" }
    }
    
    private func quitGame() { timer?.cancel(); withAnimation { gameState = .menu } }
    
    private func startNewGame(mode: GameMode) {
        gameMode = mode; gameState = .playing; levelScore = 0; resetLevel()
        if mode == .timeAttack { timeRemaining = 120; currentRewardTime = 45; startTimer() }
    }
    
    private func resetLevel() {
        var numbers = Array(0...9); numbers.shuffle()
        targetNumber = Array(numbers.prefix(gameMode.digitCount))
        currentGuess = []; history = []; tryCount = 0
    }
    
    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { _ in
            if timeRemaining > 0 { timeRemaining -= 1 }
            else { endGame() }
        }
    }
    
    private func addDigit(_ num: Int) {
        guard currentGuess.count < gameMode.digitCount else { return }
        withAnimation(.spring()) { currentGuess.append(num) }
        if currentGuess.count == gameMode.digitCount { checkGuess() }
    }
    
    private func checkGuess() {
        tryCount += 1; var a = 0; var b = 0
        for i in 0..<gameMode.digitCount { if currentGuess[i] == targetNumber[i] { a += 1 } else if targetNumber.contains(currentGuess[i]) { b += 1 } }
        history.append(GameRecord(guess: currentGuess.map { "\($0)" }.joined(), aCount: a, bCount: b, tryIndex: tryCount))
        currentGuess = []
        if a == gameMode.digitCount { handleWin() }
    }
    
    private func handleWin() {
        withAnimation { showWinEffect = true }
        let rewarded = currentRewardTime
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showWinEffect = false; winEffectScale = 0.5; winEffectOpacity = 0
                if gameMode == .timeAttack {
                    levelScore += 1; timeRemaining += rewarded
                    currentRewardTime = max(5, currentRewardTime - 5); resetLevel()
                } else {
                    if gameMode == .basic && (bestTryCount == 0 || tryCount < bestTryCount) { bestTryCount = tryCount }
                    gameState = .menu
                }
            }
        }
    }
    
    private func endGame() { timer?.cancel(); if gameMode == .timeAttack && levelScore > bestTimeAttackScore { bestTimeAttackScore = levelScore }; gameState = .gameOver }
}

#Preview { ContentView() }
```
