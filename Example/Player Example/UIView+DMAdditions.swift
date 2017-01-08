//
//  Copyright © 2017 Dailymotion. All rights reserved.
//

import UIKit

extension UIView {

  func usesAutolayout(_ usesAutolayout: Bool) {
    translatesAutoresizingMaskIntoConstraints = !usesAutolayout
  }
  
}
