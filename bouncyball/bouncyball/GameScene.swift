import SpriteKit
import GameplayKit
import AudioToolbox

enum GameState {
    case waitingForUser
    case userIsPullingBack
    case ballsAreFlying
    case needsRoundReset
    case needsRestart
}

class GameScene: SKScene {
    var state: GameState = .needsRestart
    
    let ballCategory: UInt32 = 0x1 << 0
    let brickCategory: UInt32 = 0x1 << 1
    let topAndSidesEdgeCategory: UInt32 = 0x1 << 2
    let bottomEdgeCategory: UInt32 = 0x1 << 3
    let aimBallCategory: UInt32 = 0x1 << 4
    let ballCollisionCategory: UInt32 = 0x1 << 5

    // Declare your properties
    var ball: SKShapeNode!
    var aimBalls: [SKShapeNode] = []
    var initialPosition: CGPoint = .zero
    
    var highScoreLabel: SKLabelNode!
    var currentHitsLabel: SKLabelNode!
    var maxRoundHitsLabel: SKLabelNode!
    var roundRatioLabel: SKLabelNode!
    var bestRatioLabel: SKLabelNode!
    
    var flashingRedArea: SKSpriteNode!
    
    let numColumns = 7
    var numRows = 1
    
    var round = 1
    var currentHits = 0
    var maxRoundHits = 0
    var maxRounds = 1
    
    var numOfTrailingBalls = 0
    
    let ballDimension: CGFloat = 7
    
    let brickSpacing: CGFloat = 4
    var brickDimension: CGFloat!
    
    var warningThreshold1: CGFloat!
    var warningThreshold2: CGFloat!
    var warningThreshold3: CGFloat!
    
    let ballYPosition: CGFloat = 60
    var gameOverYPosition: CGFloat!
    
    let initialRowDelta: CGFloat = 80
    
    var brickHaptic: UIImpactFeedbackGenerator!
    
    var bestRatio: Double = 0
    var roundRatio: Double = 0
        
    deinit {
        brickHaptic = nil
    }
    
    private func calculatedGameOverYPosition() -> CGFloat {
        //let startPosition = frame.maxY - brickDimension / 2 - brickSpacing - initialRowDelta
        var position: CGFloat = frame.maxY - brickDimension / 2 - brickSpacing - initialRowDelta
        let brickDelta = brickSpacing + brickDimension
        
        while position - brickDelta > ballYPosition + ballDimension {
            position -= brickDelta
        }
        
        return position - (brickDimension / 2)
    }

    override func didMove(to view: SKView) {
        // Set up the game scene
        brickDimension = (frame.width - CGFloat(numColumns - 1) * brickSpacing) / CGFloat(numColumns)
        gameOverYPosition = calculatedGameOverYPosition()
        brickHaptic = UIImpactFeedbackGenerator(style: .light)
        brickHaptic.prepare()
        
        warningThreshold1 = gameOverYPosition + (brickDimension + brickSpacing) * 2.5
        warningThreshold2 = warningThreshold1 - (brickDimension + brickSpacing)
        warningThreshold3 = warningThreshold2 - (brickDimension + brickSpacing)
        
        // Create the high score label
        highScoreLabel = SKLabelNode(fontNamed: "Helvetica")
        highScoreLabel.fontSize = 16
        highScoreLabel.fontColor = .green
        highScoreLabel.horizontalAlignmentMode = .center
        highScoreLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 72)
        addChild(highScoreLabel)
        
        maxRoundHitsLabel = SKLabelNode(fontNamed: "Helvetica")
        maxRoundHitsLabel.fontSize = 14
        maxRoundHitsLabel.fontColor = .green
        maxRoundHitsLabel.horizontalAlignmentMode = .center
        maxRoundHitsLabel.position = CGPoint(x: frame.midX + 130, y: frame.maxY - 72)
        addChild(maxRoundHitsLabel)
        
        currentHitsLabel = SKLabelNode(fontNamed: "Helvetica")
        currentHitsLabel.fontSize = 14
        currentHitsLabel.fontColor = .green
        currentHitsLabel.horizontalAlignmentMode = .center
        currentHitsLabel.position = CGPoint(x: frame.midX - 130, y: frame.maxY - 72)
        addChild(currentHitsLabel)
        
        roundRatioLabel = SKLabelNode(fontNamed: "Helvetica")
        roundRatioLabel.fontSize = 14
        roundRatioLabel.fontColor = .green
        roundRatioLabel.horizontalAlignmentMode = .center
        roundRatioLabel.position = CGPoint(x: frame.midX - 130, y: frame.maxY - 54)
        addChild(roundRatioLabel)
        
        bestRatioLabel = SKLabelNode(fontNamed: "Helvetica")
        bestRatioLabel.fontSize = 14
        bestRatioLabel.fontColor = .green
        bestRatioLabel.horizontalAlignmentMode = .center
        bestRatioLabel.position = CGPoint(x: frame.midX + 130, y: frame.maxY - 54)
        addChild(bestRatioLabel)
        
        // Create the flashing red area
        flashingRedArea = SKSpriteNode(color: .red.withAlphaComponent(0.5), size: CGSize(width: frame.width, height: 2))
        flashingRedArea.position = CGPoint(x: frame.midX, y: gameOverYPosition - 3)
        addChild(flashingRedArea)

        // Create the ball
        ball = createMainBall()
        ball.name = "mainball"
        addChild(ball)

        // Create physics bodies for screen edges
        let topEdge = SKPhysicsBody(edgeFrom: CGPoint(x: frame.minX, y: frame.maxY),
                                    to: CGPoint(x: frame.maxX, y: frame.maxY))
        topEdge.categoryBitMask = topAndSidesEdgeCategory
        topEdge.collisionBitMask = ballCollisionCategory
        topEdge.contactTestBitMask = ballCategory
        physicsBody = topEdge

        let leftEdgeNode = SKNode()
        let leftEdge = SKPhysicsBody(edgeFrom: CGPoint(x: frame.minX, y: frame.minY),
                                     to: CGPoint(x: frame.minX, y: frame.maxY))
        leftEdge.categoryBitMask = topAndSidesEdgeCategory
        leftEdge.collisionBitMask = ballCollisionCategory
        leftEdge.contactTestBitMask = ballCategory
        leftEdgeNode.physicsBody = leftEdge
        addChild(leftEdgeNode)

        let rightEdgeNode = SKNode()
        let rightEdge = SKPhysicsBody(edgeFrom: CGPoint(x: frame.maxX, y: frame.minY),
                                      to: CGPoint(x: frame.maxX, y: frame.maxY))
        rightEdge.categoryBitMask = topAndSidesEdgeCategory
        rightEdge.collisionBitMask = ballCollisionCategory
        rightEdge.contactTestBitMask = ballCategory
        rightEdgeNode.physicsBody = rightEdge
        addChild(rightEdgeNode)

        // Set up physics bodies and collision handling
        physicsWorld.contactDelegate = self
        ball.physicsBody?.categoryBitMask = ballCategory
        ball.physicsBody?.contactTestBitMask = brickCategory

        updateLabels()
    }

    // MARK: - Gets called 30 times a second
    override func update(_ currentTime: TimeInterval) {
        guard state != .userIsPullingBack else { return }
        
        flashWarningIfNeeded()
        
        removeTrailingBalls()
        
        if ball.position.y < ballYPosition || nodeIsOffScreen(node: ball) {
            updateBall(previousX: ball.position.x)
        }
        
        if state == .needsRoundReset {
            // Bricks
            shiftBricksAndCreateNewRow()
            
            // Score
            updateScores()
            state = .waitingForUser
        }
        
        if state == .needsRestart {
            restartGame()
            state = .waitingForUser
        }
        
        if state == .ballsAreFlying {
            if !trailingBallsExist() && ball.physicsBody?.velocity == .zero {
                state = .needsRoundReset
            }
        }
        
        if bricksHaveReachedBottom() {
            state = .needsRestart
        }
        
        updateLabels()
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
        }
    }
    
    private func trailingBallsExist() -> Bool {
        return !children.filter { $0.name == "trailingball" }.isEmpty
    }
    
    private func flashWarningIfNeeded() {
        // Check if the bricks have reached the flashing Y value
        let lowestBrickYValue = lowestYBrickValue()
        if lowestBrickYValue < warningThreshold1 {
            startFlashingRedArea(brickY: lowestBrickYValue)
        } else {
            stopFlashingRedArea()
        }
    }
    
    private func updateBall(previousX: CGFloat) {
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
    
    private func updateScores() {
        if currentHits > maxRoundHits {
            maxRoundHits = currentHits
        }
        round += 1
        numOfTrailingBalls += 1
        
        if round > maxRounds {
            maxRounds = round
        }
    }
    
    func startFlashingRedArea(brickY: CGFloat) {
        let flashDuration = duration(for: brickY)

        // Create the actions for the flashing effect
        let fadeInAction = SKAction.fadeIn(withDuration: flashDuration)
        let fadeOutAction = SKAction.fadeOut(withDuration: flashDuration)
        let flashSequence = SKAction.sequence([fadeOutAction, fadeInAction])
        let repeatAction = SKAction.repeatForever(flashSequence)
        
        let color = color(for: brickY)
        if flashingRedArea.color != color {
            flashingRedArea.removeAction(forKey: "flashAction")
            flashingRedArea.run(repeatAction, withKey: "flashAction")
            flashingRedArea.color = color
        }
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
  
    func stopFlashingRedArea() {
        flashingRedArea.removeAction(forKey: "flashAction")
        flashingRedArea.alpha = 0.0
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
        roundRatio = max(roundRatio, (Double(currentHits) / Double(numOfTrailingBalls + 1)))
        bestRatio = max(bestRatio, roundRatio)
        highScoreLabel.text = "High Score: \(maxRounds)"
        maxRoundHitsLabel.text = "Max Hits: \(maxRoundHits)"
        currentHitsLabel.text = "Rnd Hits: \(currentHits)"
        roundRatioLabel.text = "Ratio: \(String(format: "%.2f", roundRatio))"
        bestRatioLabel.text = "Best Ratio: \(String(format: "%.2f", bestRatio))"
    }
    
    // Restart the game
        func restartGame() {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            
            currentHits = 0
            numOfTrailingBalls = 0
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
            ball.physicsBody?.categoryBitMask = ballCategory
            ball.physicsBody?.contactTestBitMask = brickCategory
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
    func createMainBall() -> SKShapeNode {
        let ball = SKShapeNode(circleOfRadius: ballDimension)
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
        ball.physicsBody?.categoryBitMask = ballCategory
        ball.physicsBody?.contactTestBitMask = brickCategory | topAndSidesEdgeCategory
        ball.physicsBody?.collisionBitMask = ballCollisionCategory | topAndSidesEdgeCategory
        
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

            ball.physicsBody!.categoryBitMask = aimBallCategory
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
        let startY = frame.maxY - brickDimension / 2 - brickSpacing - initialRowDelta

        var topRow = [SKSpriteNode]()
        for col in 0..<numColumns {
            let brick = SKSpriteNode(color: .blue, size: CGSize(width: brickDimension, height: brickDimension))
            brick.position = CGPoint(x: startX + CGFloat(col) * (brickDimension + brickSpacing), y: startY)
            brick.name = "brick"
            brick.physicsBody = SKPhysicsBody(rectangleOf: brick.size)
            brick.physicsBody?.isDynamic = false
            
            // Add a hit count property to the brick
            brick.hitCount = round
            
            // Add hit count label
            let hitCountLabel = SKLabelNode(text: "\(round)")
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
            node.physicsBody?.categoryBitMask = brickCategory
            node.physicsBody?.contactTestBitMask = ballCategory
            node.physicsBody?.collisionBitMask = ballCollisionCategory
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
        guard state == .waitingForUser else { return }
        guard ball.physicsBody?.velocity == .zero else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        state = .userIsPullingBack
        initialPosition = location
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .userIsPullingBack else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Calculate the distance and direction of the pull
        let vector = CGVector(dx: initialPosition.x - location.x, dy: initialPosition.y - location.y)
        let magnitude = hypot(vector.dx, vector.dy)
        let normalizedVector = CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)

        // Calculate the angle between the current position and previous position of the ball
        let angle = atan2(normalizedVector.dy, normalizedVector.dx)
        // Update the orientation of the trail balls
        adjustTrailBallsOrientation(angle: angle, magnitude: magnitude)

        // Add trail balls
        if aimBalls.isEmpty {
            aimBalls = createAimBalls()
            aimBalls.forEach { addChild($0) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Release the ball and apply a force or impulse
        guard state == .userIsPullingBack else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
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
        let position = ball.position
        for i in 0..<numOfTrailingBalls {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { [weak self] in
                guard let self else { return }
                let ball = createMainBall()
                ball.name = "trailingball"
                ball.position = position
                addChild(ball)
                ball.physicsBody?.applyForce(force)
            }
        }
        
        aimBalls.forEach { $0.removeFromParent() }
        aimBalls.removeAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            state = .ballsAreFlying
        }
    }

    func adjustTrailBallsOrientation(angle: CGFloat, magnitude: CGFloat) {
        let originalMin = 10.0
        let originalMax = 300.0
        let newMin = 16.0
        let newMax = 100.0

        let interpolationFactor = (magnitude - originalMin) / (originalMax - originalMin)
        let mappedValue = CGFloat(newMin + (newMax - newMin) * interpolationFactor)

        for (index, trailBall) in aimBalls.enumerated() {
            let offset = CGFloat(index + 1) * mappedValue
            let trailPosition = CGPoint(x: ball.position.x + cos(angle) * offset,
                                        y: ball.position.y + sin(angle) * offset)
            trailBall.position = trailPosition
            trailBall.fillColor = .white.withAlphaComponent(opacity(for: mappedValue))
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
