//
//  MissionControlView.swift
//  MDGA_Example
//
//  Created by LuoHuanyu on 2023/5/19.
//  Copyright (c) 2023 Huanyu Luo. All rights reserved.
//

import UIKit
import SnapKit
import DJISDK
import Combine

class MissionControlView: UIView {
    
    lazy var addWaypointButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .white
        button.setImage(.init(systemName: "pencil"), for: .normal)
        button.setTitle("Add Waypoint", for: .normal)
        button.setTitle("Done", for: .selected)
        button.addTarget(self, action: #selector(enableWaypointEditing(_:)), for: .touchUpInside)
        return button
    }()
    
    @objc
    func enableWaypointEditing(_ sender: UIButton) {
        sender.isSelected.toggle()
    }
    
    lazy var resetButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .white
        button.setImage(.init(systemName: "trash"), for: .normal)
        button.setTitle("Clear Mission", for: .normal)
        return button
    }()
    
    lazy var simulationButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .white
        button.setImage(.init(systemName: "cube"), for: .normal)
        button.setTitle("Simulator Off", for: .normal)
        button.setTitle("Simulator On", for: .selected)
        button.addTarget(self, action: #selector(toggleSimulationMode(_:)), for: .touchUpInside)
        return button
    }()
    
    var simulationCoordinate: CLLocationCoordinate2D?
    
    @objc
    func toggleSimulationMode(_ sender: UIButton) {
        guard let aircraft = DJISDKManager.product() as? DJIAircraft,
              let simulator = aircraft.flightController?.simulator else {
            return
        }
        guard let simulationCoordinate = simulationCoordinate else {
            return
        }
        if simulator.isSimulatorActive {
            simulator.stop() {
                error in
                if let _ = error {
                } else {
                    sender.isSelected = false
                }
            }
        } else {
            simulator.start(withLocation: simulationCoordinate, updateFrequency: 10, gpsSatellitesNumber: 12) { error in
                if let _ = error {
                } else {
                    sender.isSelected = true
                }
            }
        }
    }
    
    lazy var startButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .white
        button.setImage(.init(systemName: "paperplane"), for: .normal)
        button.setTitle("Disconnected", for: .normal)
        button.addTarget(self, action: #selector(startButtonOnClick(_:)), for: .touchUpInside)
        return button
    }()
    
    @objc
    func startButtonOnClick(_ sender: UIButton) {
        guard let waypointMissionOperator = MissionControl.shared.waypointMissionOperator else {
            return
        }
        switch waypointMissionOperator.currentState {
        case .unknown:
            break
        case .disconnected:
            break
        case .recovering:
            break
        case .notSupported:
            break
        case .readyToUpload:
            MissionControl.shared.loadMission()
        case .uploading:
            break
        case .readyToExecute:
            MissionControl.shared.startMission()
        case .executing:
            MissionControl.shared.stopMission()
        case .executionPaused:
            MissionControl.shared.stopMission()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        let stackView = UIStackView(arrangedSubviews: [
            addWaypointButton,
            resetButton,
            simulationButton,
            startButton
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.bottom.top.equalToSuperview()
        }
        
        stateSub = MissionControl.shared.autopilot.$currentState.sink(receiveValue: { [unowned self] state in
            updateState(state)
        })
    }
    
    private func updateState(_ state: DJIWaypointMissionState) {
        switch state {
        case .unknown:
            break
        case .disconnected:
            startButton.setTitle("Disconnected", for: .normal)
        case .recovering:
            break
        case .notSupported:
            break
        case .readyToUpload:
            startButton.setTitle("Upload Mission", for: .normal)
        case .uploading:
            startButton.setTitle("Uploading", for: .normal)
        case .readyToExecute:
            startButton.setTitle("Start Mission", for: .normal)
        case .executing:
            startButton.setTitle("Stop Mission", for: .normal)
        case .executionPaused:
            startButton.setTitle("Stop Mission", for: .normal)
        }
    }
    
    var stateSub: Cancellable?
    
}
