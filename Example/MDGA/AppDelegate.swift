//
//  AppDelegate.swift
//  MDGA
//
//  Created by Huanyu Luo on 04/27/2023.
//  Copyright (c) 2023 Huanyu Luo. All rights reserved.
//

import UIKit
import DJISDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        DJISDKManager.registerApp(with: self)
        DJISDKManager.closeConnection(whenEnteringBackground: false)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}


extension AppDelegate: DJISDKManagerDelegate {
    
    func appRegisteredWithError(_ error: Error?) {
        if let error = error {
            print("DJISDK register failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                errorAlert(error.localizedDescription)
            }
        } else {
            print("DJISDK register success")
            DJISDKManager.startConnectionToProduct()
        }
    }
    
    func didUpdateDatabaseDownloadProgress(_ progress: Progress) {
        print("DJISDK sync db progress: \(Int(progress.fractionCompleted * 100))%")
    }
    
    func productConnected(_ product: DJIBaseProduct?) {
        if let product = product as? DJIAircraft {
            DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
                MissionControl.shared.autopilot.setup()
            }
        }
    }
    
    func productChanged(_ product: DJIBaseProduct?) {
        if let product = product as? DJIAircraft {
            DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
                MissionControl.shared.autopilot.setup()
            }
        }
    }
    
    func productDisconnected() {
        
    }
}
