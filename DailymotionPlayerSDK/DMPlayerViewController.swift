//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import UIKit
import WebKit

public protocol DMPlayerViewControllerDelegate: class {
  
  func player(_ player: DMPlayerViewController, didReceiveEvent event: PlayerEvent)
  func player(_ player: DMPlayerViewController, openUrl url: URL)
  
}

public enum PlayerEvent {
  
  case timeEvent(name: String, time: Double)
  case namedEvent(name : String, data: [String: String]?)
  
}

open class DMPlayerViewController: UIViewController {
  
  private static let defaultUrl = URL(string: "https://www.dailymotion.com")!
  fileprivate static let version = "2.9.3"
  fileprivate static let eventName = "dmevent"
  fileprivate static let pathPrefix = "/embed/"
  private static let messageHandlerEvent = "triggerEvent"
  
  fileprivate var loaded: Bool = false
  fileprivate var loadVideoId: String?
  
  public weak var delegate: DMPlayerViewControllerDelegate?
  
  var _baseUrl: URL!
  public var baseUrl: URL! {
    get {
      return _baseUrl ?? DMPlayerViewController.defaultUrl
    }
    set {
      _baseUrl = newValue
    }
  }
  
  private lazy var webView: WKWebView = {
    let webView = WKWebView(frame: .zero, configuration: self.newConfiguration())
    webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webView.backgroundColor = .clear
    webView.isOpaque = false
    webView.scrollView.isScrollEnabled = false
    return webView
  }()

  override open var shouldAutorotate: Bool {
    return true
  }
  
  /// Initialize a new instance of the player
  /// - Parameter parameters:   The dictionary of configuration parameters that are passed to the player.
  /// - Parameter accessToken:  An optional oauth token. If provided it will be passed as Bearer token to the player.
  public init(parameters: [String: Any], accessToken: String? = nil) {
    super.init(nibName: nil, bundle: nil)
    view = webView
    let request = newRequest(accessToken: accessToken, parameters: parameters)
    webView.load(request)
    webView.navigationDelegate = self
  }
  
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  deinit {
    pause()
    webView.stopLoading()
    webView.configuration.userContentController.removeScriptMessageHandler(forName: DMPlayerViewController.messageHandlerEvent)
  }
  
  /// Load a video with ID and optional OAuth token
  ///
  /// - Parameter videoId: The video's XID
  public func load(videoId: String) {
    assert(baseUrl != nil)
    if self.loaded {
      webView.evaluateJavaScript("player.load('\(videoId)')", completionHandler: nil)
    }
    else {
      self.loadVideoId = videoId
    }
  }
  
  private func newRequest(accessToken: String?, parameters: [String: Any]) -> URLRequest {
    var request = URLRequest(url: url(parameters: parameters))
    if let accessToken = accessToken {
      request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    return request
  }
  
  private func newConfiguration() -> WKWebViewConfiguration {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    if #available(iOS 9.0, *) {
      configuration.requiresUserActionForMediaPlayback = false
      configuration.allowsAirPlayForMediaPlayback = true
    } else {
      configuration.mediaPlaybackRequiresUserAction = false
      configuration.mediaPlaybackAllowsAirPlay = true
    }
    configuration.preferences = newPreferences()
    configuration.userContentController = newContentController()
    return configuration
  }
  
  private func newPreferences() -> WKPreferences {
    let preferences = WKPreferences()
    preferences.javaScriptCanOpenWindowsAutomatically = true
    return preferences
  }
  
  private func newContentController() -> WKUserContentController {
    let controller = WKUserContentController()
    var source = "window.dmpNativeBridge = {"
    source += "triggerEvent: function(data) {"
    source += "window.webkit.messageHandlers.\(DMPlayerViewController.messageHandlerEvent).postMessage(data);"
    source += "}}"
    controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    controller.add(Trampoline(delegate: self), name: DMPlayerViewController.messageHandlerEvent)
    return controller
  }
  
  private func url(parameters: [String: Any]) -> URL {
    guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { fatalError() }
    components.path = DMPlayerViewController.pathPrefix
    var items = [
      URLQueryItem(name: "api", value: "nativeBridge"),
      URLQueryItem(name: "objc_sdk_version", value: DMPlayerViewController.version),
      URLQueryItem(name: "app", value: Bundle.main.bundleIdentifier),
      URLQueryItem(name: "GK_PV5_ANTI_ADBLOCK", value: "0"),
      URLQueryItem(name: "webkit-playsinline", value: "1")
    ]
    let parameterItems = parameters.map { return URLQueryItem(name: $0, value: String(describing: $1)) }
    items.append(contentsOf: parameterItems)
    components.queryItems = items
    let url = components.url!
    return url
  }

  public func toggleControls(show: Bool) {
    let hasControls = show ? "1" : "0"
    notifyPlayerApi(method: "controls", argument: hasControls)
  }
  
  final public func notifyPlayerApi(method: String, argument: String? = nil) {
    let playerArgument = argument != nil ? argument! : "null"
    webView.evaluateJavaScript("player.api('\(method)', \(playerArgument))", completionHandler: nil)
  }
  
  public func toggleFullscreen() {
    notifyPlayerApi(method: "notifyFullscreenChanged")
  }

  public func play() {
    notifyPlayerApi(method: "play")
  }
  
  public func pause() {
    notifyPlayerApi(method: "pause")
  }
  
  public func seek(to: TimeInterval) {
    notifyPlayerApi(method: "seek", argument: "\(to)")
  }

}

extension DMPlayerViewController: WKScriptMessageHandler {
 
  public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let event = EventParser.parseEvent(from: message.body) else { return }
    delegate?.player(self, didReceiveEvent: event)
  }
}

/// A weak delegate bridge. WKScriptMessageHandler retains it's delegate and causes a memory leak.
final class Trampoline: NSObject, WKScriptMessageHandler {
  
  private weak var delegate: WKScriptMessageHandler?
  
  init(delegate: WKScriptMessageHandler) {
    self.delegate = delegate
    super.init()
  }
  
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    delegate?.userContentController(userContentController, didReceive: message)
  }
  
}


extension DMPlayerViewController: WKNavigationDelegate {
  
  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    self.loaded = true
    
    if let loadVideoId = self.loadVideoId {
      self.load(videoId: loadVideoId)
      self.loadVideoId = nil
    }
  }
  
}
