//
//  WaypointMissionOperator.swift
//  MDGA
//
//  Created by LuoHuanyu on 2022/3/16.
//  Copyright © 2022 LuoHuanyu. All rights reserved.
//

import DJISDK

public protocol WaypointMissionOperator: AnyObject {
    
    
    /**
     *  Gets the currently loaded mission of the operator. There are two ways to load a
     *  mission. 1. A mission can be loaded by user through `loadMission`. 2. If the
     *  aircraft is already executing a waypoint mission when SDK is re-connected, the
     *  operator will download part of the mission's information from the aircraft and
     *  load it automatically. In that case, the loaded mission will only contain the
     *  summary of the executing mission but information for each waypoint is absent.
     *  User can call `downloadMissionWithCompletion` to get all the information for the
     *  loaded mission. The `loadedMission` will be reset to `nil` when the execution of
     *  the loadedMission is stopped, finished or interrupted.
     */
    var loadedMission: DJIWaypointMission? { get }
    
    
    /**
     *  Loads a waypoint mission into the operator. A mission can be loaded only when
     *  the `DJIWaypointMissionState` is one of the following:
     *   - `DJIWaypointMissionStateReadyToUpload`
     *   - `DJIWaypointMissionStateReadyToExecute`
     *   Calling `loadMission` when the current state is
     *  `DJIWaypointMissionStateReadyToExecute` will change the state to
     *  `DJIWaypointMissionStateReadyToUpload`. After calling `loadMission`,
     *  `latestExecutionProgress` will be reset to `nil`.
     *
     *  @param mission Waypoint mission to load.
     *
     *  @return Returns an error when mission data is invalid or the mission cannot be loaded in the current state.
     */
    func load(_ mission: DJIWaypointMission) -> Error?
    
    
    /**
     *  The current state of the operator.
     */
    var currentState: DJIWaypointMissionState { get }
    
    
    /**
     *  The latest execution progress cached by the operator. It will be reset to `nil`
     *  after `loadMission` is called.
     */
    var latestExecutionProgress: DJIWaypointExecutionProgress? { get }
    /**
     *  Starts to upload the `loadedMission` to the aircraft. It can only be called when
     *  the `loadedMission` is complete and the `currentState` is
     *  `DJIWaypointMissionStateReadyToUpload`. If a timeout error occurs during the
     *  previous upload, the upload operation will resume from the previous break-point.
     *  After a mission is uploaded successfully, the `DJIWaypointMissionState` will
     *  become `DJIWaypointMissionStateReadyToExecute`.
     *
     *  @param completion Completion block that will be called when the upload operation succeeds or fails to start. If it is started successfully, use `addListenerToUploadEvent:withQueue:andBlock` to receive the detailed progress.
     */
    func uploadMission(completion: DJICompletionBlock?)
    
    /**
     *  Starts the execution of the uploaded mission. It can only be called when the
     *  `currentState` is `DJIWaypointMissionStateReadyToExecute`. After a mission is
     *  started successfully, the `currentState` will become
     *  `DJIWaypointMissionStateExecuting`.
     *
     *  @param completion Completion block that will be called when the operator succeeds or fails to start the execution. If it fails, an error will be returned.
     */
    func startMission(completion: DJICompletionBlock?)
    
    
    
    /**
     *  Pauses the executing mission. It can only be called when the
     *  `DJIWaypointMissionState` is `DJIWaypointMissionStateExecuting`. After a mission
     *  is paused successfully, the `currentState` will become
     *  `DJIWaypointMissionStateExecutionPaused`.
     *
     *  @param completion Completion block that will be called when the operator succeeds or fails to pause the mission. If it fails, an error will be returned.
     */
    func pauseMission(completion: DJICompletionBlock?)
    
    
    
    /**
     *  Resumes the paused mission. It can only be called when the `currentState` is
     *  `DJIWaypointMissionStateExecutionPaused`. After a mission is resumed
     *  successfully, the `currentState` will become `DJIWaypointMissionStateExecuting`.
     *
     *  @param completion Completion block that will be called when the operator succeeds or fails to resume the mission. If it fails, an error will be returned.
     */
    func resumeMission(completion: DJICompletionBlock?)
    
    
    
    /**
     *  Stops the executing or paused mission. It can only be called when the
     *  `currentState` is one of the following: - `DJIWaypointMissionStateExecuting` -
     *  `DJIWaypointMissionStateExecutionPaused` After a mission is stopped
     *  successfully, `currentState` will become `DJIWaypointMissionStateReadyToUpload`.
     *
     *  @param completion Completion block that will be called when the operator succeeds or fails to stop the mission. If it fails, an error will be returned.
     */
    func stopMission(completion: DJICompletionBlock?)
    
}

extension DJIWaypointMissionOperator: WaypointMissionOperator { }
