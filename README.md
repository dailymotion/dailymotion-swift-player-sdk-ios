# Dailymotion Swift Player SDK for iOS

[![Build Status](https://travis-ci.com/dailymotion/dailymotion-swift-player-sdk-ios.svg?token=SnmrmidBUf8ovJXSP6ht&branch=master)](https://travis-ci.com/dailymotion/dailymotion-swift-player-sdk-ios)
[![Version](https://img.shields.io/cocoapods/v/DailymotionPlayerSDK.svg?style=flat)](http://cocoapods.org/pods/DailymotionPlayerSDK)
[![License](https://img.shields.io/cocoapods/l/DailymotionPlayerSDK.svg?style=flat)](http://cocoapods.org/pods/DailymotionPlayerSDK)
[![Platform](https://img.shields.io/cocoapods/p/DailymotionPlayerSDK.svg?style=flat)](http://cocoapods.org/pods/DailymotionPlayerSDK)

## Requirements
- Xcode 8 and later
- Swift 3
- iOS 8+

Note: If you require an Objective-C version of the library or support for iOS < 8, use the [old version](https://github.com/dailymotion/dailymotion-player-sdk-ios) of the library.

## Installation

The preferred way is via [CocoaPods](http://cocoapods.org). To install, add the following to your Podfile:

```ruby
use_frameworks!

pod 'DailymotionPlayerSDK`
```

## Usage

In the view controller that is going to serve videos, keep a reference to the Dailymotion player, and set your class as `delegate`:

```swift
import UIKit
import DailymotionPlayerSDK

class VideoViewController: UIViewController {

  // The player container. See setupPlayerViewController()
  @IBOutlet private var containerView: UIView!

  private lazy var playerViewController: DMPlayerViewController = {
    // If you have an OAuth token, you can pass it to the player to hook up
    // a user's view history.
    let parameters: [String: Any] = [
      "fullscreen-action": "trigger_event", // Trigger an event when the users toggles full screen mode in the player
      "sharing-action": "trigger_event" // Trigger an event to share the video to e.g. show a UIActivityViewController
    ]
    let controller = DMPlayerViewController(parameters: parameters)
    controller.delegate = self
    return controller
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    setupPlayerViewController()
  }

  // Add the player to your view. e.g. add a container on your storyboard
  // and add the player's view as subview to that
  private func setupPlayerViewController() {
    addChildViewController(playerViewController)

    let view = playerViewController.view!
    containerView.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    // Make the player's view fit our container view
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      view.topAnchor.constraint(equalTo: containerView.topAnchor),
      view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ])
  }

}

extension VideoViewController: DMPlayerViewControllerDelegate {

  // The delegate has 4 mandatory functions

  func player(_ player: DMPlayerViewController, didReceiveEvent event: PlayerEvent) {
    // Sends player events of either .namedEvent(name: String, data: [String: String]?) or .timeEvent(name: String, time: Double)
  }

  func player(_ player: DMPlayerViewController, openUrl url: URL) {
    // Sent when a user taps on an ad that can display more information
  }

  func playerDidInitialize(_ player: DMPlayerViewController) {
    // Sent when the player has finished initializing
  }

  func player(_ player: DMPlayerViewController, didFailToInitializeWithError error: Error) {
    // Sent when the player failed to initialized
  }

}

```

For a full list of events, see the [player API events page](https://developer.dailymotion.com/player#player-api-events)

To playback a video, call the player's `load` method with the video's id:

```swift
func loadVideo(withId id: String) {
  playerViewController.load(videoId: id)
}
```

For a list of parameters, see the [player API parameters page](https://developer.dailymotion.com/player#player-parameters).

To handle events sent by the player, let's implement the event delegate method mentioned above:

```swift
func player(_ player: DMPlayerViewController, didReceiveEvent event: PlayerEvent) {
  switch event {
    case .namedEvent(let name, _) where name == "fullscreen_toggle_requested":
      toggleFullScreen()
    default:
      break
  }
}

private func toggleFullScreen() {
  // Keep track of the orientation via an isPlayerFullscreen bool
  isPlayerFullscreen = !isPlayerFullscreen
  updateDeviceOrientation()
  updatePlayerSize()
}

private func updateDeviceOrientation() {
  let orientation: UIDeviceOrientation = isPlayerFullscreen ? .landscapeLeft : .portrait
  UIDevice.current.setValue(orientation.rawValue, forKey: #keyPath(UIDevice.orientation))
}

private func updatePlayerSize() {
  if isPlayerFullscreen {
    playerHeightConstraint.constant = nextSize.height
  } else {
    // Keep track of the initial player's height, e.g. via a didSet handler in the constraint outlet
    playerHeightConstraint.constant = initialPlayerHeight
  }
}
```

See the `Example` directory for a working sample of all this in action.

## License

DailymotionPlayerSDK is available under the MIT license. See the LICENSE file for more info.