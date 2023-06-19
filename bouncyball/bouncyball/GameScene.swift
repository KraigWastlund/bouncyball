import SpriteKit
import GameplayKit
import AudioToolbox

enum GameState {
    case waitingForUser
    case userIsPullingBackWithValidAngle
    case userIsPullingBackWithInvalidAngle
    case ballsAreFlying
    case needsRoundReset
    case needsRestart
}

struct CategoryBitMask {
    static let ballCategory: UInt32 = 0x1 << 0
    static let brickCategory: UInt32 = 0x1 << 1
    static let topAndSidesEdgeCategory: UInt32 = 0x1 << 2
    static let bottomEdgeCategory: UInt32 = 0x1 << 3
    static let aimBallCategory: UInt32 = 0x1 << 4
    static let ballCollisionCategory: UInt32 = 0x1 << 5
}

class GameScene: SKScene {
    var state: GameState = .needsRestart
    
    // Declare your properties
    var ball: BouncyBall!
    var aimBalls: [SKShapeNode] = []
    var initialPosition: CGPoint = .zero
    
    var highScoreLabel: SKLabelNode!
    var currentLevelLabel: SKLabelNode!
    var currentHitsLabel: SKLabelNode!
    var maxRoundHitsLabel: SKLabelNode!
    var roundRatioLabel: SKLabelNode!
    var bestRatioLabel: SKLabelNode!
    
    var warningView: SKSpriteNode!
    
    let numColumns = 7
    var numRows = 1
    
    var round = 1
    var currentHits = 0
    var maxHits = 0
    var highestLevel = 1
    
    var numOfTrailingBalls = 0
    
    let ballDimension: CGFloat = 7
    let minYValueForBall: CGFloat = 50
    
    let brickSpacing: CGFloat = 4
    var brickDimension: CGFloat!
    
    var warningThreshold1: CGFloat!
    var warningThreshold2: CGFloat!
    var warningThreshold3: CGFloat!
    
    var ballYPosition: CGFloat!
    var gameOverYPosition: CGFloat!
    var playAreaHeight: CGFloat!
    let scoreBoardHeight: CGFloat = 80
    
    var brickHaptic: UIImpactFeedbackGenerator!
    
    var bestRatio: Float = 0
    var roundRatio: Float = 0
        
    deinit {
        brickHaptic = nil
    }
    
    // MARK: - VIEW DID LOAD

    override func didMove(to view: SKView) {
        grabUserDefaults()
        setupHaptic()
        setBrickDimension()
        setupLabels()
        setupBoundaries()
        (playAreaHeight, gameOverYPosition) = playAreaHeightAndGameOverYValue()
        ballYPosition = calculateBallYPosition()
        setupWarningView()
        gamePlayBackground()

        // Set up physics bodies and collision handling
        physicsWorld.contactDelegate = self

        updateLabels()
    }
    
    private func grabUserDefaults() {
        let br = AppSettings.bestRatio
        let mh = AppSettings.maxHits
        let hl = AppSettings.highestLevel
        
        if br > bestRatio {
            bestRatio = br
        }
        
        if mh > maxHits {
            maxHits = mh
        }
        if hl > highestLevel {
            highestLevel = hl
        }
    }
    
    private func setupHaptic() {
        brickHaptic = UIImpactFeedbackGenerator(style: .light)
        brickHaptic.prepare()
    }
    
    private func setBrickDimension() {
        brickDimension = (frame.width - CGFloat(numColumns - 1) * brickSpacing) / CGFloat(numColumns)
    }
    
    private func setupLabels() {
        let lowerLabelY = frame.maxY - 76
        let upperLabelY = lowerLabelY + 16
        
        currentLevelLabel = SKLabelNode(fontNamed: "Helvetica")
        currentLevelLabel.fontSize = 16
        currentLevelLabel.fontColor = .green
        currentLevelLabel.horizontalAlignmentMode = .center
        currentLevelLabel.position = CGPoint(x: frame.midX, y: lowerLabelY)
        addChild(currentLevelLabel)
        
        highScoreLabel = SKLabelNode(fontNamed: "Helvetica")
        highScoreLabel.fontSize = 9
        highScoreLabel.fontColor = .green
        highScoreLabel.horizontalAlignmentMode = .center
        highScoreLabel.position = CGPoint(x: frame.midX, y: upperLabelY)
        addChild(highScoreLabel)
        
        maxRoundHitsLabel = SKLabelNode(fontNamed: "Helvetica")
        maxRoundHitsLabel.fontSize = 14
        maxRoundHitsLabel.fontColor = .green
        maxRoundHitsLabel.horizontalAlignmentMode = .center
        maxRoundHitsLabel.position = CGPoint(x: frame.midX + 130, y: lowerLabelY)
        addChild(maxRoundHitsLabel)
        
        currentHitsLabel = SKLabelNode(fontNamed: "Helvetica")
        currentHitsLabel.fontSize = 14
        currentHitsLabel.fontColor = .green
        currentHitsLabel.horizontalAlignmentMode = .center
        currentHitsLabel.position = CGPoint(x: frame.midX - 130, y: lowerLabelY)
        addChild(currentHitsLabel)
        
        roundRatioLabel = SKLabelNode(fontNamed: "Helvetica")
        roundRatioLabel.fontSize = 14
        roundRatioLabel.fontColor = .green
        roundRatioLabel.horizontalAlignmentMode = .center
        roundRatioLabel.position = CGPoint(x: frame.midX - 130, y: upperLabelY)
        addChild(roundRatioLabel)
        
        bestRatioLabel = SKLabelNode(fontNamed: "Helvetica")
        bestRatioLabel.fontSize = 14
        bestRatioLabel.fontColor = .green
        bestRatioLabel.horizontalAlignmentMode = .center
        bestRatioLabel.position = CGPoint(x: frame.midX + 130, y: upperLabelY)
        addChild(bestRatioLabel)
    }
    
    private func setupBoundaries() {
        let topEdge = SKPhysicsBody(edgeFrom: CGPoint(x: frame.minX, y: frame.maxY - scoreBoardHeight), to: CGPoint(x: frame.maxX, y: frame.maxY - scoreBoardHeight))
        topEdge.categoryBitMask = CategoryBitMask.topAndSidesEdgeCategory
        topEdge.collisionBitMask = CategoryBitMask.ballCollisionCategory
        topEdge.contactTestBitMask = CategoryBitMask.ballCategory
        physicsBody = topEdge

        let leftEdgeNode = SKNode()
        let leftEdge = SKPhysicsBody(edgeFrom: CGPoint(x: frame.minX, y: frame.minY),
                                     to: CGPoint(x: frame.minX, y: frame.maxY))
        leftEdge.categoryBitMask = CategoryBitMask.topAndSidesEdgeCategory
        leftEdge.collisionBitMask = CategoryBitMask.ballCollisionCategory
        leftEdge.contactTestBitMask = CategoryBitMask.ballCategory
        leftEdgeNode.physicsBody = leftEdge
        addChild(leftEdgeNode)

        let rightEdgeNode = SKNode()
        let rightEdge = SKPhysicsBody(edgeFrom: CGPoint(x: frame.maxX, y: frame.minY),
                                      to: CGPoint(x: frame.maxX, y: frame.maxY))
        rightEdge.categoryBitMask = CategoryBitMask.topAndSidesEdgeCategory
        rightEdge.collisionBitMask = CategoryBitMask.ballCollisionCategory
        rightEdge.contactTestBitMask = CategoryBitMask.ballCategory
        rightEdgeNode.physicsBody = rightEdge
        addChild(rightEdgeNode)
    }
    
    private func gamePlayBackground() {
        let backgroundHeight = playAreaHeight!
        let backgroundSize = CGSize(width: frame.width, height: backgroundHeight)
        let background = SKSpriteNode(color: .black, size: backgroundSize)
        
        background.position = CGPoint(x: frame.midX, y: frame.midY)
        background.zPosition = -1
        
        // Adjust the position of the background to match the collision points
        background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        background.position.y = (gameOverYPosition - brickDimension - brickSpacing) + backgroundHeight / 2
        
        addChild(background)
    }
    
    private func setupWarningView() {
        warningThreshold1 = gameOverYPosition + (brickDimension + brickSpacing) * 3
        warningThreshold2 = warningThreshold1 - (brickDimension + brickSpacing)
        warningThreshold3 = warningThreshold2 - (brickDimension + brickSpacing)
        
        warningView = SKSpriteNode(color: .red.withAlphaComponent(0.5), size: CGSize(width: frame.width, height: 2))
        warningView.position = CGPoint(x: frame.midX, y: gameOverYPosition - 2)
        addChild(warningView)
        warningView.alpha = 0.0
    }
    
    private func playAreaHeightAndGameOverYValue() -> (CGFloat, CGFloat) {
        
        // calculate play height by starting at the bottom of the
        // scoreboard and moving down until i'm close the bottom
        
        let yThreshold = minYValueForBall
        
        let bottomOfScoreBoard = frame.maxY - scoreBoardHeight
        var yValue = bottomOfScoreBoard
        
        // first remove one brick height:
        yValue -= brickDimension
        
        // now loop until threshold is reached
        while yValue > yThreshold {
            yValue -= (brickDimension + brickSpacing)
        }
         
        // back it off a level
        yValue += (brickDimension + brickSpacing)
        
        return (frame.maxY - (yValue + scoreBoardHeight), yValue + (brickDimension + brickSpacing))
    }
    
    private func calculateBallYPosition() -> CGFloat {
        return gameOverYPosition - brickDimension + ballDimension
    }

    // MARK: - Gets called 30 times a second
    override func update(_ currentTime: TimeInterval) {
        switch state {
        case .waitingForUser, .userIsPullingBackWithValidAngle, .userIsPullingBackWithInvalidAngle:
            flashWarningIfNeeded()
            if bricksHaveReachedBottom() {
                state = .needsRestart
            }
            return
        case .ballsAreFlying:
            updateFlying(currentTime)
        case .needsRoundReset:

            resetScores()
            updateLabels()

            shiftBricksAndCreateNewRow()
            state = .waitingForUser
            saveValuesToUserDefaults()
        case .needsRestart:
            restartGame()
            state = .waitingForUser
            saveValuesToUserDefaults()
        }
    }
    
    private func saveValuesToUserDefaults() {
        AppSettings.bestRatio = bestRatio
        AppSettings.highestLevel = highestLevel
        AppSettings.maxHits = maxHits
    }
    
    private func noBallsFlying() -> Bool {
        guard let ball else { return true }
        
        if ball.physicsBody?.velocity == .zero {
            if !trailingBallsExist() {
                return true
            }
        }
        
        return false
    }
    
    private func updateFlying(_ currentTime: TimeInterval) {
        guard !noBallsFlying() else { state = .needsRoundReset; return }
        
        flashWarningIfNeeded()
        
        removeTrailingBalls()
        
        if ball.position.y < ballYPosition || nodeIsOffScreen(node: ball) {
            updateMainBall(previousX: ball.position.x)
        }
        
        if !trailingBallsExist() && ball.physicsBody?.velocity == .zero {
            state = .needsRoundReset
        } else {
            addGravityToBallsIfNeeded(for: currentTime)
            removeAnyBallsInsideABrick()
        }
        
        if bricksHaveReachedBottom() {
            state = .needsRestart
        }
        
        updateLabels()
    }
    
    private func removeAnyBallsInsideABrick() {
        let balls = children.compactMap { $0 as? BouncyBall }
        let bricks = children.filter { $0.name == "brick" }
        
        for ball in balls {
            for brick in bricks {
                if let ballPhysicsBody = ball.physicsBody, let brickPhysicsBody = brick.physicsBody {
                    if ballPhysicsBody.allContactedBodies().contains(brickPhysicsBody) {
                        if ball.name == "mainball" {
                            // reset ball
                            ball.position.y = ballYPosition - 1000
                        } else {
                            ball.removeFromParent()
                        }
                    }
                }
            }
        }
    }

    
    private func addGravityToBallsIfNeeded(for currentTime: TimeInterval) {
        if let balls = children.filter({ $0.name == "mainball" || $0.name == "trailingball" }) as? [BouncyBall] {
            if balls.isNotEmpty {
                for ball in balls {
                    if Int(currentTime - ball.releasedAt!) > BouncyBall.ttl { // I'm over my ttl
                        if ball.physicsBody!.velocity.dy >= 0 { // I'm not moving down
                            ball.physicsBody?.velocity.dy = -50
                        } else if ball.physicsBody!.velocity.dy > -50 { // My downward velocity is too slow
                            ball.physicsBody?.velocity.dy = -50
                        }
                    }
                }
            }
        }
    }
    
    private func checkForBallsOffScreen() -> Bool {
        let balls = children.filter { $0.name == "mainball" || $0.name == "trailingball" }
        for ball in balls {
            if nodeIsOffScreen(node: ball) {
                return true
            }
        }
        
        return false
    }
    
    private func nodeIsOffScreen(node: SKNode) -> Bool {
        let sceneFrame = self.frame
        let nodeFrame = node.calculateAccumulatedFrame()
        if nodeFrame.maxY < sceneFrame.minY || nodeFrame.minY > sceneFrame.maxY ||
            nodeFrame.maxX < sceneFrame.minX || nodeFrame.minX > sceneFrame.maxX {
            return true
        }
        return false
    }
    
    private func removeTrailingBalls() {
        let trailingBalls = children.filter { $0.name == "trailingball" }
        for ball in trailingBalls {
            if nodeIsOffScreen(node: ball) {
                ball.removeFromParent()
            }
            if ball.position.y < ballYPosition {
                ball.removeFromParent()
            }
        }
    }
    
    private func trailingBallsExist() -> Bool {
        return !children.filter { $0.name == "trailingball" }.isEmpty
    }
    
    private func flashWarningIfNeeded() {
        // Check if the bricks have reached the flashing Y value
        let lowestBrickYValue = lowestYBrickValue()
        if lowestBrickYValue < warningThreshold1 {
            startFlashingWarningView(brickY: lowestBrickYValue)
        } else {
            stopFlashingWarningView()
        }
    }
    
    private func updateMainBall(previousX: CGFloat) {
        var newX = previousX
        if newX < frame.minX + ballDimension {
            newX = frame.minX + ballDimension
        }
        if newX > frame.maxX - ballDimension {
            newX = frame.maxX - ballDimension
        }
        ball.position = CGPoint(x: newX, y: frame.minY + ballYPosition)
        ball.physicsBody?.velocity = .zero
    }
    
    private func resetScores() {
        if currentHits > maxHits {
            maxHits = currentHits
        }
        round += 1
        numOfTrailingBalls = round - 1
        
        if round > highestLevel {
            highestLevel = round
        }
    }
    
    func startFlashingWarningView(brickY: CGFloat) {
        guard !warningView.hasActions() || warningView.color != color(for: brickY) else { return }
        let flashDuration = duration(for: brickY)

        // Create the actions for the flashing effect
        let fadeInAction = SKAction.fadeIn(withDuration: flashDuration)
        let fadeOutAction = SKAction.fadeOut(withDuration: flashDuration)
        let flashSequence = SKAction.sequence([fadeOutAction, fadeInAction])
        let repeatAction = SKAction.repeatForever(flashSequence)
        
        let color = color(for: brickY)
        warningView.removeAction(forKey: "flashAction")
        warningView.run(repeatAction, withKey: "flashAction")
        warningView.color = color
        
    }
    
    func stopFlashingWarningView() {
        guard warningView.hasActions() else { return }
        warningView.removeAction(forKey: "flashAction")
        warningView.alpha = 0.0
    }
    
    func color(for brickY: CGFloat) -> UIColor {
        if brickY < warningThreshold3 {
            return .red
        }
        if brickY < warningThreshold2 {
            return .orange
        }
        return .yellow
    }
    
    func duration(for brickY: CGFloat) -> CGFloat {
        if brickY < warningThreshold3 {
            return 0.25
        }
        if brickY < warningThreshold2 {
            return 0.5
        }
        return 0.75
    }

    func lowestYBrickValue() -> CGFloat {
        var lowest = CGFloat.greatestFiniteMagnitude
        for child in children {
            if child.name == "bricks" {
                for brick in child.children {
                    if brick.position.y < lowest {
                        lowest = brick.position.y
                    }
                }
            }
        }
        return lowest
    }

    
    private func updateLabels() {
        roundRatio = max(roundRatio, (Float(currentHits) / Float(numOfTrailingBalls + 1)))
        bestRatio = max(bestRatio, roundRatio)
        currentLevelLabel.text = "Level: \(round)"
        highScoreLabel.text = "Highest Level: \(highestLevel)"
        maxRoundHitsLabel.text = "Max Hits: \(maxHits)"
        currentHitsLabel.text = "Hits: \(currentHits)"
        roundRatioLabel.text = "Ratio: \(String(format: "%.2f", roundRatio))"
        bestRatioLabel.text = "Best Ratio: \(String(format: "%.2f", bestRatio))"
    }
    
    // Restart the game
        func restartGame() {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            
            currentHits = 0
            round = 1
            
            // Remove all existing bricks and balls
            for child in children {
                if ["bricks", "mainball", "aimball"].contains(child.name) {
                    child.removeFromParent()
                }
            }
            
            // Reset necessary properties and variables
            numRows = 1
            aimBalls.removeAll()
            
            // Create the initial ball and bricks
            ball = createMainBall()
            ball.name = "mainball"
            addChild(ball)
            
            let bricks = createTopBricks()
            addChild(bricks)
            
            // Set up physics bodies and collision handling
            physicsWorld.contactDelegate = self
            ball.physicsBody?.categoryBitMask = CategoryBitMask.ballCategory
            ball.physicsBody?.contactTestBitMask = CategoryBitMask.brickCategory
            
            updateLabels()
        }
    
    // Check if any bricks have reached the bottom gutter
        func bricksHaveReachedBottom() -> Bool {
            for child in children {
                if child.name == "bricks" {
                    for brick in child.children {
                        if brick.position.y <= gameOverYPosition {
                            return true
                        }
                    }
                }
            }
            return false
        }

    // Create the ball node
    func createMainBall() -> BouncyBall {
        let ball = BouncyBall(radius: ballDimension)
        ball.position = CGPoint(x: frame.midX, y: frame.minY + ballYPosition)
        ball.fillColor = .green
        ball.strokeColor = .clear
        ball.physicsBody = SKPhysicsBody(circleOfRadius: ballDimension)
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.restitution = 1.0
        ball.physicsBody?.friction = 0.0
        ball.physicsBody?.linearDamping = 0.0
        ball.physicsBody?.angularDamping = 0.0
        ball.physicsBody?.affectedByGravity = false
        ball.physicsBody?.categoryBitMask = CategoryBitMask.ballCategory
        ball.physicsBody?.contactTestBitMask = CategoryBitMask.brickCategory | CategoryBitMask.topAndSidesEdgeCategory
        ball.physicsBody?.collisionBitMask = CategoryBitMask.ballCollisionCategory | CategoryBitMask.topAndSidesEdgeCategory
        
        ball.name = "mainball"
        ball.releasedAt = CACurrentMediaTime()
        return ball
    }

    // Create the ball node
    func createAimBalls() -> [SKShapeNode] {
        var balls = [SKShapeNode]()

        for _ in 0..<16 {
            let ball = SKShapeNode(circleOfRadius: ballDimension)
            ball.position = CGPoint(x: frame.minX, y: frame.minY - 100)  // first draw them off screen
            ball.fillColor = .white.withAlphaComponent(0.25)
            ball.strokeColor = .clear
            
            ball.physicsBody = SKPhysicsBody(circleOfRadius: ballDimension)

            ball.physicsBody?.isDynamic = true
            ball.physicsBody?.restitution = 1.0
            ball.physicsBody?.friction = 0.0
            ball.physicsBody?.linearDamping = 0.0
            ball.physicsBody?.angularDamping = 0.0
            ball.physicsBody?.affectedByGravity = false

            ball.physicsBody!.categoryBitMask = CategoryBitMask.aimBallCategory
            ball.physicsBody!.collisionBitMask = 0
            ball.physicsBody!.contactTestBitMask = 0
            
            ball.name = "aimball"

            balls.append(ball)
        }

        return balls
    }

    // Create the bricks node
    func createTopBricks() -> SKNode {
        let bricks = SKNode()

        let startX = frame.minX + brickDimension / 2
        let startY = frame.maxY - (scoreBoardHeight + brickDimension + brickSpacing) - (brickDimension / 2)

        var topRow = [SKSpriteNode]()
        for col in 0..<numColumns {
            let brick = SKSpriteNode(color: .blue, size: CGSize(width: brickDimension, height: brickDimension))
            brick.position = CGPoint(x: startX + CGFloat(col) * (brickDimension + brickSpacing), y: startY)
            brick.name = "brick"
            brick.physicsBody = SKPhysicsBody(rectangleOf: brick.size)
            brick.physicsBody?.isDynamic = false
            
            // Add a hit count property to the brick
            brick.hitCount = Int.random(in: 0..<10) > 5 ? round : round * 2
            
            // Add hit count label
            let hitCountLabel = SKLabelNode(text: "\(brick.hitCount)")
            hitCountLabel.name = "hitCountLabel"
            hitCountLabel.fontColor = .white
            hitCountLabel.fontName = "Helvetica-Bold"
            hitCountLabel.fontSize = 20
            hitCountLabel.verticalAlignmentMode = .center
            brick.addChild(hitCountLabel)
            
            topRow.append(brick)
        }
        bricks.name = "bricks"
        
        var random = selectRandomItems(topRow, percentage: 0.45)
        while random.isEmpty {
            random = selectRandomItems(topRow, percentage: 0.45)
        }
        random.forEach { bricks.addChild($0) }

        return bricks
    }
    
    func selectRandomItems<T>(_ items: [T], percentage: Double) -> [T] {
        let numberOfItemsToSelect = Int(Double(items.count) * percentage)
        var randomlySelectedItems: [T] = []
        
        let shuffledItems = items.shuffled()
        for index in 0..<numberOfItemsToSelect {
            randomlySelectedItems.append(shuffledItems[index])
        }
        
        return randomlySelectedItems
    }
    
    // Shift the existing bricks down and create a new row above them
    func shiftBricksAndCreateNewRow() {
        let shiftAmount = brickDimension + brickSpacing // Adjust the shift amount as desired
        
        for child in children {
            if child.name == "bricks" {
                child.children.forEach { $0.position.y -= shiftAmount }
            }
        }

        // Create a new row of bricks above the existing bricks
        let newBricks = createTopBricks()
        addChild(newBricks)
        numRows += 1
        
        let bricks = children.filter { $0.name == "brick" }
        bricks.forEach { [weak self] node in
            guard let self else { return }
            node.physicsBody?.categoryBitMask = CategoryBitMask.brickCategory
            node.physicsBody?.contactTestBitMask = CategoryBitMask.ballCategory
            node.physicsBody?.collisionBitMask = CategoryBitMask.ballCollisionCategory
        }
    }
}

// Implement physics contact handling
extension GameScene: SKPhysicsContactDelegate {
    
    func didBegin(_ contact: SKPhysicsContact) {
        if let brickNode = contact.bodyA.node as? SKSpriteNode, brickNode.name == "brick" {
            brickNode.hitCount -= 1
            currentHits += 1
            brickHaptic.impactOccurred()
            updateHitCountLabel(for: brickNode)
            if brickNode.hitCount <= 0 {
                brickNode.removeFromParent()
                createExplosion(at: brickNode.position)
            }
        } else if let brickNode = contact.bodyB.node as? SKSpriteNode, brickNode.name == "brick" {
            brickNode.hitCount -= 1
            currentHits += 1
            brickHaptic.impactOccurred()
            updateHitCountLabel(for: brickNode)
            if brickNode.hitCount <= 0 {
                brickNode.removeFromParent()
                createExplosion(at: brickNode.position)
            }
        }
    }
    
    // Decrease the hit count of the brick
    func decreaseHitCount(for brick: SKSpriteNode) {
        if let hitCount = brick.userData?.value(forKey: "hitCount") as? Int {
            brick.userData?.setValue(hitCount - 1, forKey: "hitCount")
        }
    }
    
    func updateHitCountLabel(for brick: SKSpriteNode) {
        if let hitCountLabel = brick.childNode(withName: "hitCountLabel") as? SKLabelNode {
            hitCountLabel.text = "\(brick.hitCount)"
        }
    }
    
    func createExplosion(at position: CGPoint) {
        let explosion = SKEmitterNode(fileNamed: "Explosion.sks")
        explosion?.position = position
        explosion?.particleScale = 0.1
        explosion?.particleTexture?.filteringMode = .nearest
        addChild(explosion!)

        // Remove the explosion node after a short delay
        let removeAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.15),
            SKAction.removeFromParent()
        ])
        explosion?.run(removeAction)
    }

}

extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state != .ballsAreFlying else { return } // disregard user input while balls are flying
        guard state == .waitingForUser else { state = .waitingForUser; return }
        guard ball.physicsBody?.velocity == .zero else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        state = .userIsPullingBackWithValidAngle
        initialPosition = location
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .userIsPullingBackWithValidAngle || state == .userIsPullingBackWithInvalidAngle else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Calculate the distance and direction of the pull
        let vector = CGVector(dx: initialPosition.x - location.x, dy: initialPosition.y - location.y)
        let magnitude = hypot(vector.dx, vector.dy)
        let normalizedVector = CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)

        // Calculate the angle between the current position and previous position of the ball
        let angle = atan2(normalizedVector.dy, normalizedVector.dx)
        
        // Add trail balls
        if aimBalls.isEmpty {
            aimBalls = createAimBalls()
            aimBalls.forEach { addChild($0) }
        }
        
        state = pullBackState(angle: angle)
        if state == .userIsPullingBackWithInvalidAngle {
            hideAimBalls()
            return
        }
        
        // Update the orientation of the trail balls
        adjustAimBallsOrientation(angle: angle, magnitude: magnitude)
    }
    
    private func pullBackState(angle: CGFloat) -> GameState {
        let minAngleDelta = 0.025
        if angle < 0.0 {
            return .userIsPullingBackWithInvalidAngle
        }
        if abs(CGFloat.pi - angle) < minAngleDelta {
            return .userIsPullingBackWithInvalidAngle
        }
        if angle < minAngleDelta {
            return .userIsPullingBackWithInvalidAngle
        }
        
        return .userIsPullingBackWithValidAngle
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Release the ball and apply a force or impulse
        guard state == .userIsPullingBackWithValidAngle || state == .userIsPullingBackWithInvalidAngle else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if state == .userIsPullingBackWithInvalidAngle {
            state = .waitingForUser
            return
        }
        
        currentHits = 0
        roundRatio = 0.0

        // Calculate the force or impulse based on the pull distance and direction
        let vector = CGVector(dx: initialPosition.x - location.x, dy: initialPosition.y - location.y)
        let magnitude = hypot(vector.dx, vector.dy)
        let normalizedVector = CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)

        let forceMultiplier: CGFloat = 15.0
        let slowest: CGFloat = 500
        let fastest: CGFloat = 1000
        let magnification = max(slowest, min(magnitude * forceMultiplier, fastest))
        let force = CGVector(dx: normalizedVector.dx * magnification,
                             dy: normalizedVector.dy * magnification)

        // Apply the force or impulse to the ball's physics body
        ball.physicsBody?.applyForce(force)
        ball.releasedAt = CACurrentMediaTime()
        let position = ball.position
        
        for i in 0..<numOfTrailingBalls {
            let trailingBall = createMainBall()
            trailingBall.name = "trailingball"
            trailingBall.position = position
            addChild(trailingBall)
            
            let delay = TimeInterval(i) * 0.1
            let waitAction = SKAction.wait(forDuration: delay)
            let applyForceAction = SKAction.run {
                trailingBall.physicsBody?.applyForce(force)
            }
            let sequenceAction = SKAction.sequence([waitAction, applyForceAction])
            self.run(sequenceAction)
        }
        
        aimBalls.forEach { $0.removeFromParent() }
        aimBalls.removeAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            state = .ballsAreFlying
        }
    }
    
    func hideAimBalls() {
        for aimBall in aimBalls {
            aimBall.alpha = 0.0
        }
    }
    
    func adjustAimBallsOrientation(angle: CGFloat, magnitude: CGFloat) {
        let originalMin = 10.0
        let originalMax = 300.0
        let newMin = 12.0
        let newMax = 60.0

        let interpolationFactor = (magnitude - originalMin) / (originalMax - originalMin)
        let mappedValue = CGFloat(newMin + (newMax - newMin) * interpolationFactor)

        for (index, aimBall) in aimBalls.enumerated() {
            aimBall.alpha = 1.0
            let offset = CGFloat(index + 1) * mappedValue
            let aimPosition = CGPoint(x: ball.position.x + cos(angle) * offset, y: ball.position.y + sin(angle) * offset)
            aimBall.position = aimPosition
            aimBall.fillColor = .white.withAlphaComponent(opacity(for: mappedValue))
        }
    }
    
    func opacity(for magnitude: CGFloat) -> CGFloat {
        let minValue: CGFloat = 16
        let maxValue: CGFloat = 70
        let minOpacity: CGFloat = 0.25
        let maxOpacity: CGFloat = 1.0

        let normalizedValue = (magnitude - minValue) / (maxValue - minValue)
        let mappedOpacity = minOpacity + normalizedValue * (maxOpacity - minOpacity)
        
        return mappedOpacity
    }

}

extension SKSpriteNode {
    private struct AssociatedKeys {
        static var hitCountKey = "hitCountKey"
    }
    
    var hitCount: Int {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.hitCountKey) as? Int ?? 0
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.hitCountKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

class BouncyBall: SKShapeNode {
    var releasedAt: TimeInterval?
    static let ttl: Int = 30 // time to live: 30 seconds
    
    init(radius: CGFloat) {
        super.init()
        
        let path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        self.path = path
        self.fillColor = .red
        
        self.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        self.physicsBody?.restitution = 0.8
        self.physicsBody?.friction = 0.2
        self.physicsBody?.categoryBitMask = CategoryBitMask.ballCategory
        self.physicsBody?.contactTestBitMask = CategoryBitMask.brickCategory
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension Collection {
    var isNotEmpty: Bool {
        return !isEmpty
    }
}
