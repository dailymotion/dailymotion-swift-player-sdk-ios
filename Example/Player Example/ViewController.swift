//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import UIKit
import DailymotionPlayerSDK

class ViewController: UIViewController {

  private lazy var playerViewController: DMPlayerViewController = {
    let controller = DMPlayerViewController()
    controller.delegate = self
    return controller
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }

}

extension ViewController: DMPlayerViewControllerDelegate {
  
  func player(_ player: DMPlayerViewController, didReceiveEvent event: PlayerEvent) {
    
  }
  
  func player(_ player: DMPlayerViewController, openUrl url: URL) {
    
  }
  
}
