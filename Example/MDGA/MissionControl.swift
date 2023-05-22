//
//  MissionControl.swift
//  MDGA
//
//  Created by LuoHuanyu on 2023/5/19.
//  Copyright (c) 2023 Huanyu Luo. All rights reserved.
//

import DJISDK
import MDGA

class MissionControl {
    
    static let shared = MissionControl()
    
    lazy var autopilot = AutoPilot()
    
    var waypointMissionOperator: WaypointMissionOperator? {
        if autopilot.isSupported {
            return autopilot
        }
        return DJISDKManager.missionControl()?.waypointMissionOperator()
    }
    
    var mission: DJIMutableWaypointMission?
    
    var pointOfInterest: CLLocationCoordinate2D?
        
    func addWaypoint(at coordinate: CLLocationCoordinate2D, altitude: Float) {
        if mission == nil {
            mission = DJIMutableWaypointMission()
            mission?.maxFlightSpeed = 15
            mission?.autoFlightSpeed = 10
            if let pointOfInterest = pointOfInterest {
                mission?.pointOfInterest = pointOfInterest
            }
//            mission?.flightPathMode = .curved
            mission?.repeatTimes = 10
        }
        let waypoint = DJIWaypoint(coordinate: coordinate)
        waypoint.altitude = altitude
//        waypoint.cornerRadiusInMeters = 10
        waypoint.add(.init(actionType: .stay, param: 3000))
        waypoint.add(.init(actionType: .rotateGimbalPitch, param: [-20, -40, -60, -80].randomElement()!))
        waypoint.add(.init(actionType: .stay, param: 1000))
        waypoint.add(.init(actionType: .shootPhoto, param: 0))
        waypoint.add(.init(actionType: .stay, param: 1000))
        mission?.add(waypoint)
    }
    
    func loadMission() {
        guard let mission = mission else {
            errorAlert("Please Add waypoints to create a mission.")
            return
        }
        if let error = waypointMissionOperator?.load(mission) {
            print(error)
            errorAlert(error.localizedDescription)
            return
        }
        waypointMissionOperator?.uploadMission(completion: { error in
            if let error = error {
                print(error)
                errorAlert(error.localizedDescription)
            }
        })
    }
    
    func startMission() {
        waypointMissionOperator?.startMission(completion: { error in
            if let error = error {
                print(error)
                errorAlert(error.localizedDescription)
            }
        })
    }
    
    func stopMission() {
        waypointMissionOperator?.stopMission(completion: { error in
            if let error = error {
                print(error)
                errorAlert(error.localizedDescription)
            }
        })
    }
    
    func reset() {
        mission = nil
        waypointMissionOperator?.stopMission(completion: nil)
    }
    
}
