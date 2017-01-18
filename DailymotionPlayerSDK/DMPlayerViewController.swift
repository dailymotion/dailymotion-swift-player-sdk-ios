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
  fileprivate static let pathPrefix = "/embed/video/"
  private static let messageHandlerEvent = "triggerEvent"
  
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
  
  private var webView: WKWebView!

  override open var shouldAutorotate: Bool {
    return true
  }
  
  deinit {
    pause()
    webView?.stopLoading()
    webView?.configuration.userContentController
      .removeScriptMessageHandler(forName: DMPlayerViewController.messageHandlerEvent)
    webView = nil
  }

  /// Load a video with ID and optional OAuth token
  ///
  /// - Parameter videoId:        The video's XID
  /// - Parameter accessToken:    An optional oauth token. If provided it will be passed as Bearer token to the player.
  /// - Parameter withParameters: The dictionary of configuration parameters that are passed to the player.
  public func load(videoId: String, accessToken: String? = nil, withParameters parameters: [String: Any]) {
    assert(baseUrl != nil)

    webView = newWebView(frame: .zero)
    view = webView

    let request = newRequest(forVideoId: videoId, accessToken: accessToken, parameters: parameters)
    webView.load(request)
  }
  
  private func newRequest(forVideoId videoId: String, accessToken: String?, parameters: [String: Any]) -> URLRequest {
    var request = URLRequest(url: url(forVideoId: videoId, parameters: parameters))
    if let accessToken = accessToken {
      request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    return request
  }
  
  private func newWebView(frame: CGRect) -> WKWebView {
    let webView = WKWebView(frame: frame, configuration: newConfiguration())
    webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webView.backgroundColor = .clear
    webView.isOpaque = false
    webView.scrollView.isScrollEnabled = false
    return webView
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
  
  private func url(forVideoId videoId: String, parameters: [String: Any]) -> URL {
    guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { fatalError() }
    components.path = DMPlayerViewController.pathPrefix + videoId
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
  
  final func notifyPlayerApi(method: String, argument: String? = nil) {
    let playerArgument = argument != nil ? argument! : "null"
    webView?.evaluateJavaScript("player.api('\(method)', \(playerArgument))", completionHandler: nil)
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

