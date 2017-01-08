//
//  Copyright © 2017 Dailymotion. All rights reserved.
//

import UIKit

final class ShareActivityItemProvider: UIActivityItemProvider {
  
  let title: String
  let url: URL
  
  init(title: String, url: URL) {
    self.title = title
    self.url = url
    super.init(placeholderItem: url)
  }
  
  override var item: Any {
    return url
  }
  
  override func activityViewController(_ activityViewController: UIActivityViewController,
                                       subjectForActivityType activityType: UIActivityType?) -> String {
    return title
  }
  
}
