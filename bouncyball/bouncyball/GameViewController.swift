//
//  GameViewController.swift
//  bouncyball
//
//  Created by Kraig Wastlund on 12/6/18.
//  Copyright © 2018 Kraig Wastlund. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let skView = SKView(frame: view.bounds)
        view.addSubview(skView)
        
        let scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }
}
