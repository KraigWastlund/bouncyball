import SpriteKit
import GameplayKit

class GameScene: SKScene {
    let ballCategory: UInt32 = 0x1 << 0
    let brickCategory: UInt32 = 0x1 << 1
    let topAndSidesEdgeCategory: UInt32 = 0x1 << 2
    let bottomEdgeCategory: UInt32 = 0x1 << 3
    let trailBallCategory: UInt32 = 0x1 << 4

    // Declare your properties
    var ball: SKShapeNode!
    var trailBalls: [SKShapeNode] = []
    var isPullingBack = false
    var initialPosition: CGPoint = .zero
    
    let numColumns = 7
    var numRows = 1
    
    var round = 1
    
    let ballDimension: CGFloat = 10
    
    let brickSpacing: CGFloat = 4
    var brickDimension: CGFloat!
    
    let ballYPosition: CGFloat = 40
    var gameOverYPosition: CGFloat!
    
    let initialRowDelta: CGFloat = 80

    override func didMove(to view: SKView) {
        // Set up the game scene
        brickDimension = (frame.width - CGFloat(numColumns - 1) * brickSpacing) / CGFloat(numColumns)
        gameOverYPosition = ballYPosition + brickDimension

        // Create the ball
        ball = createMainBall()
        addChild(ball)
        
        // Create the bricks
        let bricks = createTopBricks()
        addChild(bricks)

        // Create physics bodies for screen edges
        let topEdge = SKPhysicsBody(edgeFrom: CGPoint(x: frame.minX, y: frame.maxY),
                                    to: CGPoint(x: frame.maxX, y: frame.maxY))
        topEdge.categoryBitMask = topAndSidesEdgeCategory
        topEdge.collisionBitMask = ballCategory
        topEdge.contactTestBitMask = ballCategory
        physicsBody = topEdge

        let leftEdgeNode = SKNode()
        let leftEdge = SKPhysicsBody(edgeFrom: CGPoint(x: frame.minX, y: frame.minY),
                                     to: CGPoint(x: frame.minX, y: frame.maxY))
        leftEdge.categoryBitMask = topAndSidesEdgeCategory
        leftEdge.collisionBitMask = ballCategory
        leftEdge.contactTestBitMask = ballCategory
        leftEdgeNode.physicsBody = leftEdge
        addChild(leftEdgeNode)

        let rightEdgeNode = SKNode()
        let rightEdge = SKPhysicsBody(edgeFrom: CGPoint(x: frame.maxX, y: frame.minY),
                                      to: CGPoint(x: frame.maxX, y: frame.maxY))
        rightEdge.categoryBitMask = topAndSidesEdgeCategory
        rightEdge.collisionBitMask = ballCategory
        rightEdge.contactTestBitMask = ballCategory
        rightEdgeNode.physicsBody = rightEdge
        addChild(rightEdgeNode)

        // Set up physics bodies and collision handling
        physicsWorld.contactDelegate = self
        ball.physicsBody?.categoryBitMask = ballCategory
        ball.physicsBody?.contactTestBitMask = brickCategory
        bricks.enumerateChildNodes(withName: "brick") { [weak self] node, _ in
            guard let self else { return }
            node.physicsBody?.categoryBitMask = brickCategory
            node.physicsBody?.contactTestBitMask = ballCategory
        }
    }

    override func update(_ currentTime: TimeInterval) {
        // Check if the ball is out of bounds and resurrect it
        if ball.position.y < ballYPosition {
            let previousX = ball.position.x
            
            ball.position = CGPoint(x: previousX, y: frame.minY + ballYPosition)
            ball.physicsBody?.velocity = .zero

            shiftBricksAndCreateNewRow()
            
            if bricksHaveReachedBottom() {
                restartGame()
            }
        }
    }
    
    // Restart the game
        func restartGame() {
            round = 1
            // Remove all existing bricks and balls
            for child in children {
                if ["bricks", "mainball", "trailball"].contains(child.name) {
                    child.removeFromParent()
                }
            }
            
            // Reset necessary properties and variables
            numRows = 1
            trailBalls.removeAll()
            
            // Create the initial ball and bricks
            ball = createMainBall()
            addChild(ball)
            
            let bricks = createTopBricks()
            addChild(bricks)
            
            // Set up physics bodies and collision handling
            physicsWorld.contactDelegate = self
            ball.physicsBody?.categoryBitMask = ballCategory
            ball.physicsBody?.contactTestBitMask = brickCategory
            bricks.enumerateChildNodes(withName: "brick") { [weak self] node, _ in
                guard let self else { return }
                node.physicsBody?.categoryBitMask = brickCategory
                node.physicsBody?.contactTestBitMask = ballCategory
            }
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
        ball.fillColor = .red
        ball.strokeColor = .clear
        ball.physicsBody = SKPhysicsBody(circleOfRadius: ballDimension)
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.restitution = 1.0
        ball.physicsBody?.friction = 0.0
        ball.physicsBody?.linearDamping = 0.0
        ball.physicsBody?.angularDamping = 0.0
        ball.physicsBody?.affectedByGravity = false
        ball.name = "mainball"
        return ball
    }

    // Create the ball node
    func createTrailBalls() -> [SKShapeNode] {
        var balls = [SKShapeNode]()

        for _ in 0..<20 {
            let ball = SKShapeNode(circleOfRadius: ballDimension)
            ball.position = CGPoint(x: frame.minX, y: frame.minY - 100)  // first draw them off screen
            ball.fillColor = .white.withAlphaComponent(0.5)
            ball.strokeColor = .clear

            ball.physicsBody = SKPhysicsBody(circleOfRadius: ballDimension)

            ball.physicsBody?.isDynamic = true
            ball.physicsBody?.restitution = 1.0
            ball.physicsBody?.friction = 0.0
            ball.physicsBody?.linearDamping = 0.0
            ball.physicsBody?.angularDamping = 0.0
            ball.physicsBody?.affectedByGravity = false

            ball.physicsBody!.categoryBitMask = trailBallCategory
            ball.physicsBody!.collisionBitMask = 0
            ball.physicsBody!.contactTestBitMask = 0
            
            ball.name = "trailball"

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
        
        round += 1

        // Create a new row of bricks above the existing bricks
        let newBricks = createTopBricks()
        addChild(newBricks)
        numRows += 1
    }
}

// Implement physics contact handling
extension GameScene: SKPhysicsContactDelegate {
    
    func didBegin(_ contact: SKPhysicsContact) {
        if let brickNode = contact.bodyA.node as? SKSpriteNode, brickNode.name == "brick" {
            brickNode.hitCount -= 1
            updateHitCountLabel(for: brickNode)
            if brickNode.hitCount <= 0 {
                brickNode.removeFromParent()
                createExplosion(at: brickNode.position)
            }
        } else if let brickNode = contact.bodyB.node as? SKSpriteNode, brickNode.name == "brick" {
            brickNode.hitCount -= 1
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
        // Check if the touch is on the ball and start pulling back
        guard ball.physicsBody?.velocity == .zero else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        isPullingBack = true
        initialPosition = location
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isPullingBack else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Calculate the distance and direction of the pull
        let vector = CGVector(dx: initialPosition.x - location.x, dy: initialPosition.y - location.y)
        let magnitude = hypot(vector.dx, vector.dy)
        let normalizedVector = CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)

        // Calculate the angle between the current position and previous position of the ball
        let angle = atan2(normalizedVector.dy, normalizedVector.dx)
        // Update the orientation of the trail balls
        adjustTrailBallsOrientation(angle: angle)

        // Add trail balls
        if trailBalls.isEmpty {
            print("triail balls made")
            trailBalls = createTrailBalls()
            trailBalls.forEach { addChild($0) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Release the ball and apply a force or impulse
        guard isPullingBack else { return }

        isPullingBack = false

        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Calculate the force or impulse based on the pull distance and direction
        let vector = CGVector(dx: initialPosition.x - location.x, dy: initialPosition.y - location.y)
        let magnitude = hypot(vector.dx, vector.dy)
        let normalizedVector = CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)

        let forceMultiplier: CGFloat = 15.0
        let slowest: CGFloat = 2000
        let fastest: CGFloat = 8000
        let magnification = max(slowest, min(magnitude * forceMultiplier, fastest))
        print(magnification)
        let force = CGVector(dx: normalizedVector.dx * magnification,
                             dy: normalizedVector.dy * magnification)

        // Apply the force or impulse to the ball's physics body
        ball.physicsBody?.applyForce(force)

        trailBalls.forEach { $0.removeFromParent() }
        trailBalls.removeAll()
    }

    func adjustTrailBallsOrientation(angle: CGFloat) {
        let trailDistance: CGFloat = 40.0 // Adjust the trail distance as desired

        for (index, trailBall) in trailBalls.enumerated() {
            let offset = CGFloat(index + 1) * trailDistance
            let trailPosition = CGPoint(x: ball.position.x + cos(angle) * offset,
                                        y: ball.position.y + sin(angle) * offset)
            trailBall.position = trailPosition
        }
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
