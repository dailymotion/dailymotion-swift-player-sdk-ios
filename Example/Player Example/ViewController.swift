//
//  Copyright © 2017 Dailymotion. All rights reserved.
//

import UIKit
import DailymotionPlayerSDK

class ViewController: UIViewController {

  @IBOutlet private var containerView: UIView!
  @IBOutlet fileprivate var playerHeightConstraint: NSLayoutConstraint! {
    didSet {
      initialPlayerHeight = playerHeightConstraint.constant
    }
  }
  fileprivate var initialPlayerHeight: CGFloat!
  fileprivate var isPlayerFullscreen = false
  
  fileprivate lazy var playerViewController: DMPlayerViewController = {
    let parameters: [String: Any] = [
      "fullscreen-action": "trigger_event",
      "sharing-action": "trigger_event"
    ]
    
    let controller = DMPlayerViewController(parameters: parameters, cookies: cookies)
    controller.delegate = self
    return controller
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupPlayerViewController()
  }
  
  private func setupPlayerViewController() {
    addChildViewController(playerViewController)
    
    let view = playerViewController.view!
    containerView.addSubview(view)
    view.usesAutolayout(true)
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      view.topAnchor.constraint(equalTo: containerView.topAnchor),
      view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ])
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    
    isPlayerFullscreen = size.width > size.height
    playerViewController.toggleFullscreen()
    updatePlayerSize()
  }
  
  @IBAction private func play(_ sender: Any) {
    playerViewController.load(videoId: "x4r5udv")
  }

  @IBAction func umute(_ sender: Any) {
    playerViewController.unmute()
  }
  @IBAction func mute(_ sender: Any) {
    playerViewController.mute()
  }
}

extension ViewController: DMPlayerViewControllerDelegate {
  
  func player(_ player: DMPlayerViewController, didReceiveEvent event: PlayerEvent) {
    switch event {
    case .namedEvent(let name, _) where name == "fullscreen_toggle_requested":
      toggleFullScreen()
    case .namedEvent(let name, .some(let data)) where name == "share_requested":
      guard let raw = data["shortUrl"] ?? data["url"], let url = URL(string: raw) else { return }
      share(url: url)
    default:
      break
    }
  }
  
  fileprivate func toggleFullScreen() {
    isPlayerFullscreen = !isPlayerFullscreen
    updateDeviceOrientation()
    updatePlayerSize()
  }
  
  private func updateDeviceOrientation() {
    let orientation: UIDeviceOrientation = isPlayerFullscreen ? .landscapeLeft : .portrait
    UIDevice.current.setValue(orientation.rawValue, forKey: #keyPath(UIDevice.orientation))
  }
  
  fileprivate func updatePlayerSize() {
    if isPlayerFullscreen {
      playerHeightConstraint.constant = view.frame.size.height
    } else {
      playerHeightConstraint.constant = initialPlayerHeight
    }
  }
  
  private func share(url: URL) {
    playerViewController.pause()
    let item = ShareActivityItemProvider(title: "Dailymotion", url: url)
    let shareViewController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
    shareViewController.excludedActivityTypes = [.assignToContact, .print]
    present(shareViewController, animated: true, completion: nil)
  }
  
  func player(_ player: DMPlayerViewController, openUrl url: URL) {
  }
  
}
