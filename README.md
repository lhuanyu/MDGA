# MDGA

DJI has suspended waypoint mission support for all camera drones since the release of the Mavic Mini. However, MDGA has developed a solution that adds mission waypoint capabilities to camera drones, with the aim of making DJI great again.

MDGA is an early version of the Autopilot from the [Good Station App](https://apps.apple.com/us/app/good-station-for-dji/id1535371709), which I developed myself. Its capabilities have been approved by thousands of users over the past two years.

Given DJI's announcement that the iOS Mobile SDK will not be updated in the foreseeable future, I have decided to make MDGA open source.

# Supported Models

- Mavic Mini
- Mavic Air 2
- DJI Mini 2
- DJI Air 2S
- DJI Mini SE

# Features

MDGA declares a protocol called `WaypointMissionOperator`, which has the same interface as `DJIWaypointMissionOperator`. The `Autopilot` class has implemented this protocol, making it easy to combine the two together.

MDGA includes almost all of the native waypoint mission features and flight behaviors, such as:

- Flight Path Modes
- Point of Interest
- Finish Action
- Repeat Times
- Waypoint Actions
- Shoot Photo Distance Interval of Waypoint

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

You will need to update the DJISDKKey in the `info.plist` and bundle identifer of the sample project.

## Requirements

- `iOS 13.0`
- `Swift 5.8`
- `DJI-SDK-iOS 4.16.2`

## Installation

MDGA is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'MDGA', '~> 1.0.0'
```

## Author

Huanyu Luo, lhuany@gmail.com

## License

MDGA is available under the MIT license. See the LICENSE file for more info.
