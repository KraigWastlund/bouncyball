//
//  GameScene.swift
//  bouncyball
//
//  Created by Kraig Wastlund on 12/6/18.
//  Copyright © 2018 Kraig Wastlund. All rights reserved.
//

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
    
    override func didMove(to view: SKView) {
        // Set up the game scene
        
        // Create the ball
        ball = createMainBall()
        addChild(ball)
        
        // Create the bricks
        let bricks = createBricks()
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
        if ball.position.y < frame.minY {
            ball.position = CGPoint(x: frame.midX, y: frame.minY + 80)
            ball.physicsBody?.velocity = .zero
        }
        
        if let bricks = children.filter { $0.name == "bricks" }.first {
            if bricks.children.contains { $0.name == "brick" } {
                print("got at least one")
            }
        }
    }
    
    // Create the ball node
    func createMainBall() -> SKShapeNode {
        let ball = SKShapeNode(circleOfRadius: 10)
        ball.position = CGPoint(x: frame.midX, y: frame.minY + 40)
        ball.fillColor = .red
        ball.strokeColor = .clear
        ball.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.restitution = 1.0
        ball.physicsBody?.friction = 0.0
        ball.physicsBody?.linearDamping = 0.0
        ball.physicsBody?.angularDamping = 0.0
        ball.physicsBody?.affectedByGravity = false
        return ball
    }
    
    // Create the ball node
    func createTrailBalls() -> [SKShapeNode] {
        var balls = [SKShapeNode]()
        
        for i in 0..<20 {
            let ball = SKShapeNode(circleOfRadius: 6)
            ball.position = CGPoint(x: frame.midX + CGFloat(i), y: frame.midY + CGFloat(i))
            ball.fillColor = .white
            ball.strokeColor = .clear
            
            ball.physicsBody = SKPhysicsBody(circleOfRadius: 6)
            
            ball.physicsBody?.isDynamic = true
            ball.physicsBody?.restitution = 1.0
            ball.physicsBody?.friction = 0.0
            ball.physicsBody?.linearDamping = 0.0
            ball.physicsBody?.angularDamping = 0.0
            ball.physicsBody?.affectedByGravity = false
            
            ball.physicsBody!.categoryBitMask = trailBallCategory
            ball.physicsBody!.collisionBitMask = 0
            ball.physicsBody!.contactTestBitMask = 0
            
            balls.append(ball)
        }
        
        return balls
    }
    
    // Create the bricks node
    func createBricks() -> SKNode {
        let bricks = SKNode()
        let brickSpacing: CGFloat = 10
        
        let brickDimension = (frame.width - CGFloat(numColumns - 1) * brickSpacing) / CGFloat(numColumns)
        let startX = frame.minX + brickDimension / 2
        let startY = frame.maxY - brickDimension / 2 - brickSpacing
        
        for row in 0..<numRows {
            let yDelta = (brickDimension * CGFloat(row)) + (brickSpacing * CGFloat(row))
            for col in 0..<numColumns {
                let brick = SKSpriteNode(color: .blue, size: CGSize(width: brickDimension, height: brickDimension))
                brick.position = CGPoint(x: startX + CGFloat(col) * (brickDimension + brickSpacing), y: startY - yDelta)
                brick.name = "brick"
                brick.physicsBody = SKPhysicsBody(rectangleOf: brick.size)
                brick.physicsBody?.isDynamic = false
                bricks.addChild(brick)
            }
        }
        
        return bricks
    }
}

// Implement physics contact handling
extension GameScene: SKPhysicsContactDelegate {
    
    func didBegin(_ contact: SKPhysicsContact) {
        if let brickNode = contact.bodyA.node as? SKSpriteNode, brickNode.name == "brick" {
            brickNode.removeFromParent()
            createExplosion(at: brickNode.position)
        } else if let brickNode = contact.bodyB.node as? SKSpriteNode, brickNode.name == "brick" {
            brickNode.removeFromParent()
            createExplosion(at: brickNode.position)
        }
    }
    
    func createExplosion(at position: CGPoint) {
        let explosion = SKEmitterNode(fileNamed: "Explosion.sks")
        explosion?.position = position
        addChild(explosion!)
        
        // Remove the explosion node after a short delay
        let removeAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.25),
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
