

import SwiftUI
import Combine

// MARK: - Data Models
struct Position: Equatable, Hashable {
    var x: Int
    var y: Int
}

enum Direction {
    case up, down, left, right
}

enum GameState {
    case splash, menu, playing, paused, levelComplete, gameOver, achievements, customization, gameComplete
}

struct Level {
    let number: Int
    let name: String
    let eggsCount: Int
    let chickenSpeed: Double
    let timeLimit: Int
    let gridSize: Int
    let backgroundImage: String
}

// MARK: - New Models for Features
struct Achievement: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let target: Int
    var progress: Int
    var isUnlocked: Bool
    let reward: Int
}

struct SnakeSkin: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let unlockScore: Int
    var isUnlocked: Bool
    var isSelected: Bool
}

struct DailyChallenge {
    let id = UUID()
    let name: String
    let description: String
    let target: Int
    let reward: Int
    var progress: Int
    let duration: Int // in hours
    let startDate: Date
    var isCompleted: Bool
}

// MARK: - Game Manager
class GameManager: ObservableObject {
    @Published var gameState: GameState = .splash
    @Published var currentLevel = 1
    @Published var score = 0
    @Published var timeLeft = 60
    @Published var snakeLives = 3
    
    // Game progress tracking
    @Published var totalEggsCollected = 0
    @Published var totalGoldenEggsCollected = 0
    @Published var levelsCompletedWithoutHit = 0
    @Published var levelsCompletedUnderTime = 0
    
    // Current level tracking
    @Published var eggsCollectedThisLevel = 0
    @Published var eggsRemainingThisLevel = 0
    
    // Snake properties
    @Published var snakePosition = Position(x: 2, y: 2)
    @Published var snakeDirection: Direction = .right
    @Published var hasEgg = false
    @Published var isPoweredUp = false
    @Published var powerUpTime = 0
    @Published var isSnakeHit = false
    @Published var currentSnakeSkin: String = "snake_normal"
    
    // Chicken properties
    @Published var chickenPosition = Position(x: 8, y: 8)
    @Published var chickenDirection: Direction = .left
    @Published var isChickenAttacking = false
    @Published var chickenAnimation = false
    
    // Game objects
    @Published var eggs: [Position] = []
    @Published var collectedEggs: [Position] = []
    @Published var goldenEgg: Position?
    
    // New Features
    @Published var achievements: [Achievement] = []
    @Published var snakeSkins: [SnakeSkin] = []
    @Published var dailyChallenges: [DailyChallenge] = []
    @Published var leaderboard: [String: Int] = [:]
    
    // Level data
    private var timer: AnyCancellable?
    private var chickenTimer: AnyCancellable?
    private var snakeMoveTimer: AnyCancellable?
    private var animationTimer: AnyCancellable?
    
    public let levels: [Level] = [
        Level(number: 1, name: "Peaceful Pastures", eggsCount: 3, chickenSpeed: 2.0, timeLimit: 60, gridSize: 10, backgroundImage: "level1_bg"),
        Level(number: 2, name: "Wild Woods", eggsCount: 6, chickenSpeed: 1.5, timeLimit: 75, gridSize: 10, backgroundImage: "level2_bg"),
        Level(number: 3, name: "Mountain Challenge", eggsCount: 9, chickenSpeed: 1.0, timeLimit: 90, gridSize: 10, backgroundImage: "level3_bg"),
        Level(number: 4, name: "Final Showdown", eggsCount: 12, chickenSpeed: 0.8, timeLimit: 120, gridSize: 10, backgroundImage: "level4_bg")
    ]
    
    var currentLevelData: Level {
        return levels[currentLevel - 1]
    }
    
    init() {
        setupAchievements()
        setupSnakeSkins()
        setupDailyChallenges()
        checkSnakeSkinUnlocks() // Check unlocks on startup
    }
    
    // MARK: - New Feature Setups
    private func setupAchievements() {
        achievements = [
            Achievement(name: "Egg Collector", description: "Collect 50 eggs", icon: "egg.fill", target: 50, progress: 0, isUnlocked: false, reward: 100),
            Achievement(name: "Speed Runner", description: "Complete 3 levels under time limit", icon: "clock.fill", target: 3, progress: 0, isUnlocked: false, reward: 150),
            Achievement(name: "Untouchable", description: "Complete 2 levels without getting hit", icon: "shield.fill", target: 2, progress: 0, isUnlocked: false, reward: 200),
            Achievement(name: "Golden Hunter", description: "Collect 5 golden eggs", icon: "star.fill", target: 5, progress: 0, isUnlocked: false, reward: 250)
        ]
    }
    
    private func setupSnakeSkins() {
        snakeSkins = [
            SnakeSkin(name: "Green Snake", imageName: "snake_normal", unlockScore: 0, isUnlocked: true, isSelected: true),
            SnakeSkin(name: "Blue Viper", imageName: "snake_blue", unlockScore: 500, isUnlocked: false, isSelected: false),
            SnakeSkin(name: "Golden Python", imageName: "snake_gold", unlockScore: 1000, isUnlocked: false, isSelected: false),
            SnakeSkin(name: "Fire Serpent", imageName: "snake_fire", unlockScore: 2000, isUnlocked: false, isSelected: false)
        ]
    }
    
    private func setupDailyChallenges() {
        let today = Date()
        dailyChallenges = [
            DailyChallenge(name: "Quick Collector", description: "Collect 10 eggs in one level", target: 10, reward: 100, progress: 0, duration: 24, startDate: today, isCompleted: false),
            DailyChallenge(name: "Perfect Run", description: "Complete a level without getting hit", target: 1, reward: 150, progress: 0, duration: 24, startDate: today, isCompleted: false),
            DailyChallenge(name: "Speed Demon", description: "Complete a level with 30+ seconds left", target: 1, reward: 120, progress: 0, duration: 24, startDate: today, isCompleted: false)
        ]
    }
    
    // MARK: - UPDATED: Game Setup with Unlock Checking
    func startGame() {
        setupLevel()
        gameState = .playing
        startTimers()
        checkSnakeSkinUnlocks() // Check on game start
    }
    
    func setupLevel() {
        let level = currentLevelData
        snakePosition = Position(x: 2, y: 2)
        chickenPosition = Position(x: level.gridSize - 3, y: level.gridSize - 3)
        snakeDirection = .right
        hasEgg = false
        isPoweredUp = false
        isSnakeHit = false
        timeLeft = level.timeLimit
        snakeLives = 3
        
        // Reset level tracking
        eggsCollectedThisLevel = 0
        eggsRemainingThisLevel = level.eggsCount
        
        // Generate eggs at random positions
        eggs = []
        for _ in 0..<level.eggsCount {
            let randomPos = Position(
                x: Int.random(in: 1...(level.gridSize - 2)),
                y: Int.random(in: 1...(level.gridSize - 2))
            )
            if randomPos != snakePosition && randomPos != chickenPosition {
                eggs.append(randomPos)
            }
        }
        
        // Generate golden egg (30% chance)
        if Int.random(in: 1...100) <= 30 {
            goldenEgg = Position(
                x: Int.random(in: 1...(level.gridSize - 2)),
                y: Int.random(in: 1...(level.gridSize - 2))
            )
        } else {
            goldenEgg = nil
        }
        
        collectedEggs = []
    }
    
    // MARK: - Timers
    private func startTimers() {
        stopTimers()
        
        // Main game timer
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateGameTime()
            }
        
        // Chicken AI timer
        chickenTimer = Timer.publish(every: currentLevelData.chickenSpeed, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.moveChicken()
            }
        
        // Auto-move snake timer
        snakeMoveTimer = Timer.publish(every: 0.3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                if self?.gameState == .playing {
                    self?.moveSnake()
                }
            }
        
        // Animation timer
        animationTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.chickenAnimation.toggle()
            }
    }
    
    private func stopTimers() {
        timer?.cancel()
        chickenTimer?.cancel()
        snakeMoveTimer?.cancel()
        animationTimer?.cancel()
        timer = nil
        chickenTimer = nil
        snakeMoveTimer = nil
        animationTimer = nil
    }
    
    private func updateGameTime() {
        if gameState == .playing {
            timeLeft -= 1
            if isPoweredUp {
                powerUpTime -= 1
                if powerUpTime <= 0 {
                    isPoweredUp = false
                }
            }
            
            if timeLeft <= 0 {
                endGame()
            }
        }
    }
    
    // MARK: - Snake Movement
    func moveSnake() {
        guard gameState == .playing else { return }
        
        var newPosition = snakePosition
        
        switch snakeDirection {
        case .up: newPosition.y -= 1
        case .down: newPosition.y += 1
        case .left: newPosition.x -= 1
        case .right: newPosition.x += 1
        }
        
        // Check boundaries
        let gridSize = currentLevelData.gridSize
        if newPosition.x < 0 || newPosition.x >= gridSize ||
           newPosition.y < 0 || newPosition.y >= gridSize {
            return
        }
        
        snakePosition = newPosition
        checkCollisions()
    }
    
    func changeSnakeDirection(_ direction: Direction) {
        // Prevent 180-degree turns
        switch (snakeDirection, direction) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left):
            return
        default:
            snakeDirection = direction
        }
    }
    
    // MARK: - Chicken AI
    private func moveChicken() {
        guard gameState == .playing else { return }
        
        // If snake is close, attack
        let distance = abs(snakePosition.x - chickenPosition.x) + abs(snakePosition.y - chickenPosition.y)
        
        if distance <= 3 {
            isChickenAttacking = true
            moveTowardsSnake()
        } else {
            isChickenAttacking = false
            moveRandomly()
        }
        
        checkChickenAttack()
    }
    
    private func moveTowardsSnake() {
        var newPosition = chickenPosition
        
        if abs(snakePosition.x - chickenPosition.x) > abs(snakePosition.y - chickenPosition.y) {
            // Move horizontally
            newPosition.x += snakePosition.x > chickenPosition.x ? 1 : -1
        } else {
            // Move vertically
            newPosition.y += snakePosition.y > chickenPosition.y ? 1 : -1
        }
        
        // Check boundaries
        let gridSize = currentLevelData.gridSize
        if newPosition.x >= 0 && newPosition.x < gridSize &&
           newPosition.y >= 0 && newPosition.y < gridSize {
            chickenPosition = newPosition
        }
    }
    
    private func moveRandomly() {
        let directions: [Direction] = [.up, .down, .left, .right]
        guard let randomDirection = directions.randomElement() else { return }
        
        var newPosition = chickenPosition
        
        switch randomDirection {
        case .up: newPosition.y -= 1
        case .down: newPosition.y += 1
        case .left: newPosition.x -= 1
        case .right: newPosition.x += 1
        }
        
        // Check boundaries
        let gridSize = currentLevelData.gridSize
        if newPosition.x >= 0 && newPosition.x < gridSize &&
           newPosition.y >= 0 && newPosition.y < gridSize {
            chickenPosition = newPosition
        }
    }
    
    // MARK: - Collision Detection
    private func checkCollisions() {
        checkEggCollection()
        checkGoldenEggCollection()
        checkEscapeZone()
    }
    
    // MARK: - UPDATED: Score Methods with Unlock Checking
    private func updateScoreAndCheckUnlocks() {
        checkSnakeSkinUnlocks()
        updateLeaderboard()
    }
    
    private func checkEggCollection() {
        if let eggIndex = eggs.firstIndex(of: snakePosition) {
            if !hasEgg {
                eggs.remove(at: eggIndex)
                hasEgg = true
                score += 10
                eggsCollectedThisLevel += 1
                eggsRemainingThisLevel -= 1
                totalEggsCollected += 1
                
                // Update achievements
                updateAchievementProgress(name: "Egg Collector", progress: totalEggsCollected)
                
                // Update daily challenges
                updateDailyChallengeProgress(name: "Quick Collector", progress: eggsCollectedThisLevel)
                
                // Check for skin unlocks
                updateScoreAndCheckUnlocks()
            }
        }
    }
    
    private func checkGoldenEggCollection() {
        if let goldenEgg = goldenEgg, snakePosition == goldenEgg {
            self.goldenEgg = nil
            activatePowerUp()
            score += 50
            totalGoldenEggsCollected += 1
            
            // Update achievements
            updateAchievementProgress(name: "Golden Hunter", progress: totalGoldenEggsCollected)
            
            // Check for skin unlocks
            updateScoreAndCheckUnlocks()
        }
    }
    
    private func checkEscapeZone() {
        if hasEgg && (snakePosition.x == 0 || snakePosition.y == 0) {
            hasEgg = false
            collectedEggs.append(snakePosition)
            score += 20
            
            // Check for skin unlocks
            updateScoreAndCheckUnlocks()
            
            if eggs.isEmpty && goldenEgg == nil {
                completeLevel()
            }
        }
    }
    
    private func checkChickenAttack() {
        if snakePosition == chickenPosition {
            handleSnakeHit()
        }
    }
    
    private func handleSnakeHit() {
        isSnakeHit = true
        snakeLives -= 1
        
        if hasEgg {
            hasEgg = false
            let gridSize = currentLevelData.gridSize
            let newEggPos = Position(
                x: Int.random(in: 1...(gridSize - 2)),
                y: Int.random(in: 1...(gridSize - 2))
            )
            eggs.append(newEggPos)
            eggsRemainingThisLevel += 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSnakeHit = false
        }
        
        if snakeLives <= 0 {
            endGame()
        }
    }
    
    // MARK: - Power-ups
    private func activatePowerUp() {
        isPoweredUp = true
        powerUpTime = 10 // 10 seconds
    }
    
    // MARK: - UPDATED: New Feature Methods
    private func updateAchievementProgress(name: String, progress: Int) {
        if let index = achievements.firstIndex(where: { $0.name == name }) {
            achievements[index].progress = progress
            if progress >= achievements[index].target && !achievements[index].isUnlocked {
                achievements[index].isUnlocked = true
                score += achievements[index].reward
                
                // Check for skin unlocks after achievement reward
                updateScoreAndCheckUnlocks()
            }
        }
    }
    
    private func updateDailyChallengeProgress(name: String, progress: Int) {
        if let index = dailyChallenges.firstIndex(where: { $0.name == name }) {
            dailyChallenges[index].progress = progress
            if progress >= dailyChallenges[index].target && !dailyChallenges[index].isCompleted {
                dailyChallenges[index].isCompleted = true
                score += dailyChallenges[index].reward
                
                // Check for skin unlocks after challenge reward
                updateScoreAndCheckUnlocks()
            }
        }
    }
    
    // UPDATED: Improved unlock checking method
    private func checkSnakeSkinUnlocks() {
        var unlockedAny = false
        
        for index in snakeSkins.indices {
            let skin = snakeSkins[index]
            let shouldBeUnlocked = score >= skin.unlockScore
            
            if shouldBeUnlocked && !skin.isUnlocked {
                snakeSkins[index].isUnlocked = true
                unlockedAny = true
                print("🎉 Unlocked: \(skin.name) at score \(score)")
            }
        }
        
        // Force UI update
        objectWillChange.send()
    }
    
    private func updateLeaderboard() {
        leaderboard["You"] = score
    }
    
    func selectSnakeSkin(_ skinName: String) {
        for index in snakeSkins.indices {
            snakeSkins[index].isSelected = snakeSkins[index].imageName == skinName
            if snakeSkins[index].isSelected {
                currentSnakeSkin = skinName
            }
        }
    }
    
    // MARK: - Game State Management
    private func completeLevel() {
        stopTimers()
        score += timeLeft * 2
        
        // Check for skin unlocks after level completion bonus
        updateScoreAndCheckUnlocks()
        
        // Check for speed runner achievement
        if timeLeft >= 10 {
            levelsCompletedUnderTime += 1
            updateAchievementProgress(name: "Speed Runner", progress: levelsCompletedUnderTime)
            updateDailyChallengeProgress(name: "Speed Demon", progress: 1)
        }
        
        // Check for untouchable achievement
        if !isSnakeHit {
            levelsCompletedWithoutHit += 1
            updateAchievementProgress(name: "Untouchable", progress: levelsCompletedWithoutHit)
            updateDailyChallengeProgress(name: "Perfect Run", progress: 1)
        }
        
        // Check if all levels are completed
        if currentLevel >= levels.count {
            gameState = .gameComplete
        } else {
            gameState = .levelComplete
        }
    }
    
    func nextLevel() {
        currentLevel += 1
        if currentLevel > levels.count {
            gameState = .gameComplete
        } else {
            startGame()
        }
    }
    
    private func endGame() {
        stopTimers()
        gameState = .gameOver
    }
    
    func restartGame() {
        currentLevel = 1
        score = 0
        totalEggsCollected = 0
        totalGoldenEggsCollected = 0
        levelsCompletedWithoutHit = 0
        levelsCompletedUnderTime = 0
        updateScoreAndCheckUnlocks() // Reset unlocks check
        startGame()
    }
    
    // NEW: Reset everything for new game
    func resetGame() {
        currentLevel = 1
        score = 0
        totalEggsCollected = 0
        totalGoldenEggsCollected = 0
        levelsCompletedWithoutHit = 0
        levelsCompletedUnderTime = 0
        
        // Reset achievements progress
        for index in achievements.indices {
            achievements[index].progress = 0
            achievements[index].isUnlocked = false
        }
        
        // Reset daily challenges
        let today = Date()
        dailyChallenges = [
            DailyChallenge(name: "Quick Collector", description: "Collect 10 eggs in one level", target: 10, reward: 100, progress: 0, duration: 24, startDate: today, isCompleted: false),
            DailyChallenge(name: "Perfect Run", description: "Complete a level without getting hit", target: 1, reward: 150, progress: 0, duration: 24, startDate: today, isCompleted: false),
            DailyChallenge(name: "Speed Demon", description: "Complete a level with 30+ seconds left", target: 1, reward: 120, progress: 0, duration: 24, startDate: today, isCompleted: false)
        ]
        
        // Reset snake skins (keep only default unlocked)
        for index in snakeSkins.indices {
            if snakeSkins[index].unlockScore > 0 {
                snakeSkins[index].isUnlocked = false
                snakeSkins[index].isSelected = false
            } else {
                snakeSkins[index].isSelected = true
                currentSnakeSkin = snakeSkins[index].imageName
            }
        }
        
        updateScoreAndCheckUnlocks()
        gameState = .menu
    }
    
    func pauseGame() {
        if gameState == .playing {
            gameState = .paused
            stopTimers()
        } else if gameState == .paused {
            gameState = .playing
            startTimers()
        }
    }
    
    func goToMainMenu() {
        stopTimers()
        gameState = .menu
    }
    
    func showAchievements() {
        gameState = .achievements
    }
    
    func showCustomization() {
        gameState = .customization
    }
    
    func showMainMenu() {
        gameState = .menu
    }
    
    // ADDED: Method to refresh unlocks when customization view appears
    func refreshUnlocks() {
        checkSnakeSkinUnlocks()
    }
}

// MARK: - Splash Screen View
struct SplashView: View {
    @ObservedObject var gameManager: GameManager
    @State private var isAnimating = false
    @State private var scaleEffect = 0.5
    
    var body: some View {
        ZStack {
            // Animated Background
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.purple, Color.orange]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(
                Image("splash_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.4)
                    .ignoresSafeArea()
            )
            
            // Animated Background Elements
            VStack {
                HStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .offset(x: isAnimating ? -UIScreen.main.bounds.width : 0, y: 0)
                    Spacer()
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .offset(x: isAnimating ? UIScreen.main.bounds.width : 0, y: 0)
                }
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .offset(x: isAnimating ? -UIScreen.main.bounds.width : 0, y: 0)
                    Spacer()
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .offset(x: isAnimating ? UIScreen.main.bounds.width : 0, y: 0)
                }
            }
            .padding()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animated Logo and Title
                VStack(spacing: 25) {
                    ZStack {
                        Image("chicken_angry")
                            .resizable()
                            .frame(width: 140, height: 140)
                            .scaleEffect(scaleEffect)
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                    
                    VStack(spacing: 10) {
                        Text("ChickenShowdown")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                            .scaleEffect(isAnimating ? 1.05 : 0.95)
                        
                        Text("Epic Egg Hunt Adventure")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                }
                
                Spacer()
                
                // Loading Section
                VStack(spacing: 20) {
                    Text("Loading Game...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .opacity(isAnimating ? 1 : 0.5)
                    
                    // Custom Progress Bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 200, height: 8)
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.yellow)
                            .frame(width: isAnimating ? 200 : 0, height: 8)
                            .animation(.easeInOut(duration: 2.5), value: isAnimating)
                    }
                    
                    HStack(spacing: 15) {
                        Image("egg_golden")
                            .resizable()
                            .frame(width: 22,height: 22)
                            .scaleEffect(isAnimating ? 1.2 : 0.8)
                        
                        Image("snake_gold")
                            .resizable()
                            .frame(width: 22,height: 22)
                            .scaleEffect(isAnimating ? 1.2 : 0.8)
                       
                    }
                   
                }
                .padding(.bottom, 60)
            }
            .padding()
        }
        .onAppear {
            // Start animations
            withAnimation(.easeInOut(duration: 1.0)) {
                scaleEffect = 1.0
            }
            
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            
            // Navigate to menu after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                gameManager.gameState = .menu
            }
        }
    }
}

// MARK: - Instruction Row View
struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

// MARK: - Level Card View
struct LevelCardView: View {
    let level: Level
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        Button(action: {
            gameManager.currentLevel = level.number
            gameManager.startGame()
        }) {
            VStack(spacing: 10) {
                Image(level.backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 80)
                    .clipped()
                    .cornerRadius(12)
                
                Text(level.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(level.eggsCount) Eggs")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("\(level.timeLimit)s")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
            )
        }
    }
}

// MARK: - Daily Challenge Row View
struct DailyChallengeRow: View {
    let challenge: DailyChallenge
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.name)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .bold()
                
                Text(challenge.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                ProgressView(value: Double(challenge.progress), total: Double(challenge.target))
                    .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("+\(challenge.reward)")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .bold()
                
                if challenge.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Text("\(challenge.progress)/\(challenge.target)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Main Menu View
struct MainMenuView: View {
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        ZStack {
            Image("menu_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .ignoresSafeArea()
                .overlay(
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                )
            
            ScrollView {
                VStack(spacing: 8) {
                    // Header
                    VStack(spacing: 15) {
                        Image("app_logo")
                            .resizable()
                            .frame(width: 80, height: 80)
                        
                        Text("ChickenShowdown")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Adventure")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    
                    // Play Button
                    Button(action: {
                        gameManager.startGame()
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                            Text("Continue Game")
                                .font(.title2.bold())
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(radius: 10)
                    }
                    .padding(.horizontal, 40)

                    // New Feature Buttons - Circular Design
                    HStack(spacing: 30) {
                        Button(action: {
                            gameManager.showAchievements()
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.orange.opacity(0.8))
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image(systemName: "trophy.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    )
                                
                                Text("Trophy Case")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: {
                            gameManager.showCustomization()
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.purple.opacity(0.8))
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image(systemName: "paintbrush.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    )
                                
                                Text("Snake Styles")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                
                    
                    
                    // Level Selection
                    VStack(spacing: 15) {
                        Text("Choose Your Quest")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                            ForEach(gameManager.levels, id: \.number) { level in
                                LevelCardView(level: level, gameManager: gameManager)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Daily Challenges Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today's Target")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(gameManager.dailyChallenges.prefix(2), id: \.id) { challenge in
                            DailyChallengeRow(challenge: challenge)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Game Guide:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        InstructionRow(icon: "arrow.up.arrow.down", text: "Use arrows to move snake")
                        InstructionRow(icon: "egg.fill", text: "Collect eggs and reach border")
                        InstructionRow(icon: "bird.fill", text: "Avoid the angry chicken")
                        InstructionRow(icon: "bolt.fill", text: "Golden eggs give power-ups")
                        InstructionRow(icon: "heart.fill", text: "You have 3 lives - avoid chicken attacks!")
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .padding(.bottom,35)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Game View
struct GameView: View {
    @ObservedObject var gameManager: GameManager
    let gridSize: Int = 10
    let cellSize: CGFloat = 35
    
    var body: some View {
        ZStack {
            Image(gameManager.currentLevelData.backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .ignoresSafeArea()
                .overlay(
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                )
            
            ScrollView {
                VStack(spacing: 15) {
                    // Updated Header with Egg Count
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(gameManager.currentLevelData.name)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                            
                            // Score Board
                            HStack(spacing: 20) {
                                // Score
                                HStack(spacing: 8) {
                                    Image(systemName: "star.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.yellow)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SCORE")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                        Text("\(gameManager.score)")
                                            .font(.title3.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                // Eggs Collected
                                HStack(spacing: 8) {
                                    Image(systemName: "egg.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("EGGS")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                        Text("\(gameManager.eggsCollectedThisLevel)/\(gameManager.currentLevelData.eggsCount)")
                                            .font(.title3.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                // Golden Eggs
                                HStack(spacing: 8) {
                                    Image(systemName: "crown.fill")
                                        .font(.title3)
                                        .foregroundColor(.yellow)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("GOLDEN")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                        Text("\(gameManager.totalGoldenEggsCollected)")
                                            .font(.title3.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("\(gameManager.timeLeft)s")
                                .font(.title2.bold())
                                .foregroundColor(gameManager.timeLeft < 10 ? .red : .white)
                                .shadow(radius: 2)
                            
                            HStack {
                                ForEach(0..<gameManager.snakeLives, id: \.self) { _ in
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Game grid with grassy background
                    ZStack {
                        Image("grass_background")
                            .resizable()
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green, lineWidth: 3)
                            )
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSize)), count: gridSize), spacing: 0) {
                            ForEach(0..<(gridSize * gridSize), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                        
                        // Eggs
                        ForEach(gameManager.eggs, id: \.self) { eggPosition in
                            Image("egg_normal")
                                .resizable()
                                .frame(width: cellSize - 8, height: cellSize - 8)
                                .position(
                                    x: CGFloat(eggPosition.x) * cellSize + cellSize / 2,
                                    y: CGFloat(eggPosition.y) * cellSize + cellSize / 2
                                )
                        }
                        
                        // Golden egg
                        if let goldenEgg = gameManager.goldenEgg {
                            Image("egg_golden")
                                .resizable()
                                .frame(width: cellSize - 6, height: cellSize - 6)
                                .position(
                                    x: CGFloat(goldenEgg.x) * cellSize + cellSize / 2,
                                    y: CGFloat(goldenEgg.y) * cellSize + cellSize / 2
                                )
                        }
                        
                        // Snake with hit effect - UPDATED to use current skin
                        ZStack {
                            Image(gameManager.currentSnakeSkin)
                                .resizable()
                                .frame(width: cellSize, height: cellSize)
                                .overlay(
                                    Group {
                                        if gameManager.hasEgg {
                                            Image("egg_carried")
                                                .resizable()
                                                .frame(width: cellSize - 15, height: cellSize - 15)
                                        }
                                    }
                                )
                            
                            if gameManager.isSnakeHit {
                                Circle()
                                    .fill(Color.red.opacity(0.7))
                                    .frame(width: cellSize + 10, height: cellSize + 10)
                                    .blur(radius: 2)
                            }
                        }
                        .position(
                            x: CGFloat(gameManager.snakePosition.x) * cellSize + cellSize / 2,
                            y: CGFloat(gameManager.snakePosition.y) * cellSize + cellSize / 2
                        )
                        
                        // Chicken with animation
                        Image(gameManager.isChickenAttacking ? "chicken_angry" : "chicken_normal")
                            .resizable()
                            .frame(width: cellSize + 20, height: cellSize + 20)
                            .scaleEffect(gameManager.chickenAnimation ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: gameManager.chickenAnimation)
                            .position(
                                x: CGFloat(gameManager.chickenPosition.x) * cellSize + cellSize / 2,
                                y: CGFloat(gameManager.chickenPosition.y) * cellSize + cellSize / 2
                            )
                        
                        // Escape zones (borders)
                        Rectangle()
                            .fill(Color.blue.opacity(0.4))
                            .frame(width: CGFloat(gridSize) * cellSize, height: cellSize)
                            .position(x: CGFloat(gridSize) * cellSize / 2, y: cellSize / 2)
                        
                        Rectangle()
                            .fill(Color.blue.opacity(0.4))
                            .frame(width: cellSize, height: CGFloat(gridSize) * cellSize)
                            .position(x: cellSize / 2, y: CGFloat(gridSize) * cellSize / 2)
                    }
                    .frame(width: CGFloat(gridSize) * cellSize, height: CGFloat(gridSize) * cellSize)
                    .shadow(radius: 5)
                    
                    // Controls Section
                    VStack(spacing: 15) {
                        if gameManager.isPoweredUp {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                Text("POWER UP ACTIVE! \(gameManager.powerUpTime)s")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(Color.purple.opacity(0.7))
                            .cornerRadius(10)
                        }
                        
                        HStack(spacing: 20) {
                            // Direction controls
                            VStack {
                                Button(action: { gameManager.changeSnakeDirection(.up) }) {
                                    Image(systemName: "arrow.up")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 50)
                                        .background(Color.blue.opacity(0.8))
                                        .cornerRadius(12)
                                }
                                
                                HStack {
                                    Button(action: { gameManager.changeSnakeDirection(.left) }) {
                                        Image(systemName: "arrow.left")
                                            .font(.title2.bold())
                                            .foregroundColor(.white)
                                            .frame(width: 60, height: 50)
                                            .background(Color.blue.opacity(0.8))
                                            .cornerRadius(12)
                                    }
                                    
                                    Spacer().frame(width: 60)
                                    
                                    Button(action: { gameManager.changeSnakeDirection(.right) }) {
                                        Image(systemName: "arrow.right")
                                            .font(.title2.bold())
                                            .foregroundColor(.white)
                                            .frame(width: 60, height: 50)
                                            .background(Color.blue.opacity(0.8))
                                            .cornerRadius(12)
                                    }
                                }
                                
                                Button(action: { gameManager.changeSnakeDirection(.down) }) {
                                    Image(systemName: "arrow.down")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 50)
                                        .background(Color.blue.opacity(0.8))
                                        .cornerRadius(12)
                                }
                            }
                            
                            Spacer()
                            
                            // Action buttons
                            VStack(spacing: 12) {
                                Button(action: {
                                    gameManager.pauseGame()
                                }) {
                                    VStack {
                                        Image(systemName: gameManager.gameState == .paused ? "play.circle.fill" : "pause.circle.fill")
                                            .font(.title2)
                                        Text(gameManager.gameState == .paused ? "Resume" : "Pause")
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 90, height: 65)
                                    .background(Color.orange.opacity(0.8))
                                    .cornerRadius(15)
                                }
                                
                                Button(action: {
                                    gameManager.goToMainMenu()
                                }) {
                                    VStack {
                                        Image(systemName: "house.fill")
                                            .font(.title2)
                                        Text("Menu")
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 90, height: 65)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(15)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.top,50)
            }
        }
    }
}

// MARK: - Level Complete View
struct LevelCompleteView: View {
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        ScrollView {
            ZStack {
                Image("menu_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: UIScreen.main.bounds.width,
                        height: UIScreen.main.bounds.height
                    )
                    .ignoresSafeArea()
                    .overlay(
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                    )
                
                VStack(spacing: 25) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Level Complete!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(gameManager.currentLevelData.name)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                    
                    VStack(spacing: 10) {
                        Text("Score: \(gameManager.score)")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Time Bonus: +\(gameManager.timeLeft * 2)")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(15)
                    
                    HStack(spacing: 20) {
                        if gameManager.currentLevel < 4 {
                            Button("Next Level") {
                                gameManager.nextLevel()
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 140)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        
                        Button("Main Menu") {
                            gameManager.gameState = .menu
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 140)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(30)
                .background(Color.black.opacity(0.5))
                .cornerRadius(25)
                .padding(40)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - NEW: Game Complete View
struct GameCompleteView: View {
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        ScrollView {
            ZStack {
                Image("menu_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: UIScreen.main.bounds.width,
                        height: UIScreen.main.bounds.height
                    )
                    .ignoresSafeArea()
                    .overlay(
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                    )
                
                VStack(spacing: 25) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow)
                    
                    Text("Victory!")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("You've Completed All Levels!")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                    
                    VStack(spacing: 15) {
                        Text("Final Score: \(gameManager.score)")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .bold()
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Total Eggs Collected:")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(gameManager.totalEggsCollected)")
                                    .foregroundColor(.yellow)
                                    .bold()
                            }
                            
                            HStack {
                                Text("Golden Eggs Found:")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(gameManager.totalGoldenEggsCollected)")
                                    .foregroundColor(.yellow)
                                    .bold()
                            }
                            
                            HStack {
                                Text("Perfect Levels:")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(gameManager.levelsCompletedWithoutHit)")
                                    .foregroundColor(.yellow)
                                    .bold()
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(15)
                    }
                    
                    VStack(spacing: 15) {
                        Button("New Adventure") {
                            gameManager.resetGame()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(Color.green)
                        .cornerRadius(12)
                        
                        Button("Main Menu") {
                            gameManager.gameState = .menu
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(30)
                .background(Color.black.opacity(0.5))
                .cornerRadius(25)
                .padding(40)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Game Over View
struct GameOverView: View {
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        ScrollView {
            ZStack {
                Image("menu_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: UIScreen.main.bounds.width,
                        height: UIScreen.main.bounds.height
                    )
                    .ignoresSafeArea()
                    .overlay(
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                    )
                
                VStack(spacing: 25) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Game Over")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Final Score: \(gameManager.score)")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 15) {
                        Button("Play Again") {
                            gameManager.restartGame()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(Color.green)
                        .cornerRadius(12)
                        
                        Button("Main Menu") {
                            gameManager.gameState = .menu
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(30)
                .background(Color.black.opacity(0.5))
                .cornerRadius(25)
                .padding(40)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Achievements View
struct AchievementsView: View {
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        ZStack {
            Image("menu_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .ignoresSafeArea()
                .overlay(
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 20) {
                Text("Trophy Case")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 50)
                
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(gameManager.achievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                    .padding(.horizontal)
                }
                                
                Spacer()
                
                Button("Back to Menu") {
                    gameManager.showMainMenu()
                }
                .foregroundColor(.white)
                .padding()
                .frame(width: 200)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.bottom, 100)
            }
        }
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(achievement.isUnlocked ? .yellow : .gray)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                ProgressView(value: Double(achievement.progress), total: Double(achievement.target))
                    .progressViewStyle(LinearProgressViewStyle(tint: achievement.isUnlocked ? .green : .blue))
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                if achievement.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Text("+\(achievement.reward)")
                        .font(.caption)
                        .foregroundColor(.yellow)
                } else {
                    Text("\(achievement.progress)/\(achievement.target)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - UPDATED: Snake Customization View
struct CustomizationView: View {
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        ZStack {
            Image("menu_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .ignoresSafeArea()
                .overlay(
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 20) {
                Text("Snake Styles")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 50)
                
                Text("Current Score: \(gameManager.score)")
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding(.bottom, 10)
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(gameManager.snakeSkins) { skin in
                            SnakeSkinCard(skin: skin, gameManager: gameManager)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Button("Back to Menu") {
                    gameManager.showMainMenu()
                }
                .foregroundColor(.white)
                .padding()
                .frame(width: 200)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            // Refresh unlocks when customization view appears
            gameManager.refreshUnlocks()
        }
    }
}

struct SnakeSkinCard: View {
    let skin: SnakeSkin
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Image(skin.imageName)
                    .resizable()
                    .frame(width: 60, height: 60)
                
                if skin.isSelected {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 3)
                        .frame(width: 70, height: 70)
                }
            }

            Text(skin.name)
                .font(.headline)
                .foregroundColor(.white)
            
            if skin.isUnlocked {
                if skin.isSelected {
                    Text("SELECTED")
                        .font(.caption)
                        .foregroundColor(.green)
                        .bold()
                } else {
                    Button("Select") {
                        gameManager.selectSnakeSkin(skin.imageName)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            } else {
                Text("Unlocks at \(skin.unlockScore) points")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(height: 190)
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(skin.isSelected ? Color.yellow : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    
    var body: some View {
        ZStack {
            switch gameManager.gameState {
            case .splash:
                SplashView(gameManager: gameManager)
            case .menu:
                MainMenuView(gameManager: gameManager)
            case .playing, .paused:
                GameView(gameManager: gameManager)
            case .levelComplete:
                LevelCompleteView(gameManager: gameManager)
            case .gameOver:
                GameOverView(gameManager: gameManager)
            case .achievements:
                AchievementsView(gameManager: gameManager)
            case .customization:
                CustomizationView(gameManager: gameManager)
            case .gameComplete:
                GameCompleteView(gameManager: gameManager)
            }
        }
    }
}

