//
//  AppDelegate.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 13/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import UIKit
import CoreData
import FPSCounter

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Display Frames/Second
        FPSCounter.showInStatusBar(application)

        return true
    }
}

