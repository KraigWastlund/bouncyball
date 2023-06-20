//
//  AppSettings.swift
//  bouncyball
//
//  Created by Kraig Wastlund on 6/19/23.
//  Copyright © 2023 Kraig Wastlund. All rights reserved.
//

import Foundation

enum AppSettings {
        
    private static let userDefaults = UserDefaults(suiteName: "group.com.ktw.bouncy")!
    
    private static let _userDefaultsKeyBestRatio  = "ktw.bouncy.bestRatio"
    private static let _userDefaultsKeyMaxHits  = "ktw.bouncy.maxHits"
    private static let _userDefaultsKeyHighestLevel  = "ktw.bouncy.highestLevel"
    
        
    static var bestRatio: Float {
        get {
            AppSettings.userDefaults.float(forKey: _userDefaultsKeyBestRatio)
        }
        set(newValue) {
            AppSettings.userDefaults.set(newValue, forKey: _userDefaultsKeyBestRatio)
        }
    }
    static var maxHits: Int {
        get {
            AppSettings.userDefaults.integer(forKey: _userDefaultsKeyMaxHits)
        }
        set(newValue) {
            AppSettings.userDefaults.set(newValue, forKey: _userDefaultsKeyMaxHits)
        }
    }
    static var highestLevel: Int {
        get {
            AppSettings.userDefaults.integer(forKey: _userDefaultsKeyHighestLevel)
        }
        set(newValue) {
            AppSettings.userDefaults.set(newValue, forKey: _userDefaultsKeyHighestLevel)
        }
    }
}
