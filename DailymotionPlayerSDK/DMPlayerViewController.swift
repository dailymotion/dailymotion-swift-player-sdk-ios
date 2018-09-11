//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import UIKit
import WebKit
import AdSupport

public protocol DMPlayerViewControllerDelegate: class {
  
  func player(_ player: DMPlayerViewController, didReceiveEvent event: PlayerEvent)
  func player(_ player: DMPlayerViewController, openUrl url: URL)
  func playerDidInitialize(_ player: DMPlayerViewController)
  func player(_ player: DMPlayerViewController, didFailToInitializeWithError error: Error)
  
}

public enum PlayerEvent {
  
  case timeEvent(name: String, time: Double)
  case namedEvent(name : String, data: [String: String]?)
  
}

open class DMPlayerViewController: UIViewController {
  
  private static let defaultUrl = URL(string: "https://www.dailymotion.com")!
  fileprivate static let version = "3.7.6"
  fileprivate static let eventName = "dmevent"
  fileprivate static let pathPrefix = "/embed/"
  fileprivate static let messageHandlerEvent = "triggerEvent"
  fileprivate static let consoleHandlerEvent = "consoleEvent"
  fileprivate static let loggerParameterKey = "logger"
  
  private var webView: WKWebView!
  private var baseUrl: URL!
  private var deviceIdentifier: String?
  private var loggerEnabled: Bool = false
  fileprivate var isInitialized = false
  fileprivate var videoIdToLoad: String?
  fileprivate var paramsToLoad: String?
  
  open weak var delegate: DMPlayerViewControllerDelegate?
  
  override open var shouldAutorotate: Bool {
    return true
  }
  
  /// Initialize a new instance of the player
  /// - Parameters:
  ///   - parameters:  The dictionary of configuration parameters that are passed to the player.
  ///   - baseUrl:     An optional base URL. Defaults to dailymotion's server.
  ///   - accessToken: An optional oauth token. If provided it will be passed as Bearer token to the player.
  ///   - cookies:     An optional array of HTTPCookie values that are passed to the player.
  ///   - allowIDFA:   Allow IDFA Collection. Defaults true
  public init(parameters: [String: Any], baseUrl: URL? = nil, accessToken: String? = nil, cookies: [HTTPCookie]? = nil,
              allowIDFA: Bool = true) {
    super.init(nibName: nil, bundle: nil)
    if allowIDFA {
      deviceIdentifier = advertisingIdentifier()
    }
    if parameters.contains(where: { $0.key == DMPlayerViewController.loggerParameterKey }) {
      loggerEnabled = true
    }
    self.loadWebView(parameters: parameters, baseUrl: baseUrl, accessToken: accessToken, cookies: cookies)
  }
  
  private func newWebView(cookies: [HTTPCookie]?) -> WKWebView {
    let webView = WKWebView(frame: .zero, configuration: newConfiguration(cookies: cookies))
    webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webView.backgroundColor = .clear
    webView.isOpaque = false
    webView.scrollView.isScrollEnabled = false
    webView.uiDelegate = self
    return webView
  }
  
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  open func loadWebView(parameters: [String: Any], baseUrl: URL? = nil, accessToken: String? = nil, cookies: [HTTPCookie]? = nil) {
    self.baseUrl = baseUrl ?? DMPlayerViewController.defaultUrl
    webView = newWebView(cookies: cookies)
    view = webView
    let request = newRequest(parameters: parameters, accessToken: accessToken, cookies: cookies)
    webView.load(request)
    webView.navigationDelegate = self
  }
  
  deinit {
    pause()
    webView.stopLoading()
    webView.configuration.userContentController.removeScriptMessageHandler(forName: DMPlayerViewController.messageHandlerEvent)
    if loggerEnabled {
      webView.configuration.userContentController.removeScriptMessageHandler(forName: DMPlayerViewController.consoleHandlerEvent)
    }
  }
  
  /// Load a video with ID optional Player parameters
  ///
  /// - Parameter videoId: The video's XID
  /// - Parameter payload: An optional payload to pass to the load
  @available(*, deprecated)
  open func load(videoId: String, payload: [String: Any]?, completion: (() -> ())? = nil) {
    var params: String? = nil
    if let payload = payload {
      params = convertDictionaryToString(payload: payload)
    }
    load(videoId: videoId, params: params, completion: completion)
  }
  
  /// Load a video with ID and optional Player parameters
  ///
  /// - Parameter videoId: video's XID
  /// - Parameter params: (Optional) String encoded Player parameters
  open func load(videoId: String, params: String? = nil, completion: (() -> ())? = nil) {
    guard isInitialized else {
      self.videoIdToLoad = videoId
      self.paramsToLoad = params
      return
    }
    
    let js = buildLoadString(videoId: videoId, params: params)
    
    webView.evaluateJavaScript(js) { _,_ in
      completion?()
    }
  }
  
  private func convertDictionaryToString(payload: [String: Any]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
      let string = String(data: data, encoding: .utf8) else { return nil }
    return string
  }
  
  /// Set a player property
  ///
  /// - Parameter prop: The property name
  /// - Parameter data: The data value to set
  @available(*, deprecated)
  open func setProp(_ prop: String, data: [String: Any], completion: (() -> ())? = nil) {
    let value = convertDictionaryToString(payload: data)
    setProp(prop, value: value)
  }
  
  /// Set a player property
  ///
  /// - Parameter prop: property name
  /// - Parameter value: property value
  @nonobjc
  open func setProp(_ prop: String, value: String?, completion: (() -> ())? = nil) {
    guard isInitialized, let value = value else { return }
    
    let js = "player.setProp('\(prop)', \(value))"
    webView.evaluateJavaScript(js) { _,_ in
      completion?()
    }
  }
  
  /// Build the player load JS string
  ///
  /// - Parameter videoId: Video's XID
  /// - Parameter params: (Optional) params to pass during the load
  /// - Returns: A JS string command
  private func buildLoadString(videoId: String, params: String?) -> String {
    var builder: [String] = []
    builder.append("player.load('\(videoId)'")
    if let params = params {
      builder.append(", \(params)")
    }
    builder.append(")")
    return builder.joined()
  }
  
  private func newRequest(parameters: [String: Any], accessToken: String?, cookies: [HTTPCookie]?) -> URLRequest {
    var request = URLRequest(url: url(parameters: parameters))
    if let accessToken = accessToken {
      request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    if let cookies = cookies {
      let cookieHeader = cookies.flatMap({ "\($0.name)=\($0.value)" }).joined(separator: ";")
      request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
    }
    return request
  }
  
  private func newConfiguration(cookies: [HTTPCookie]?) -> WKWebViewConfiguration {
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
    configuration.userContentController = newContentController(cookies: cookies)
    return configuration
  }
  
  private func newPreferences() -> WKPreferences {
    let preferences = WKPreferences()
    preferences.javaScriptCanOpenWindowsAutomatically = true
    return preferences
  }
  
  private func newContentController(cookies: [HTTPCookie]?) -> WKUserContentController {
    let controller = WKUserContentController()
    var source = eventHandler()
    if let cookies = cookies {
      let cookieSource = cookies.map({ "document.cookie='\(jsCookie(from: $0))'" }).joined(separator: "; ")
      source += cookieSource
    }
    controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    controller.add(Trampoline(delegate: self), name: DMPlayerViewController.messageHandlerEvent)
    if loggerEnabled {
      controller.addUserScript(WKUserScript(source: consoleHandler(), injectionTime: .atDocumentStart, forMainFrameOnly: false))
      controller.add(Trampoline(delegate: self), name: DMPlayerViewController.consoleHandlerEvent)
    }
    return controller
  }
  
  private func consoleHandler() -> String {
    var source = "window.console.log = function(...args) {"
    source += "window.webkit.messageHandlers.\(DMPlayerViewController.consoleHandlerEvent).postMessage(args);"
    source += "};"
    return source
  }
  
  private func eventHandler() -> String {
    var source = "window.dmpNativeBridge = {"
    source += "triggerEvent: function(data) {"
    source += "window.webkit.messageHandlers.\(DMPlayerViewController.messageHandlerEvent).postMessage(decodeURIComponent(data));"
    source += "}};"
    return source
  }
  
  private func jsCookie(from cookie: HTTPCookie) -> String {
    var value = "\(cookie.name)=\(cookie.value);domain=\(cookie.domain);path=\(cookie.path)"
    if cookie.isSecure {
      value += ";secure=true"
    }
    return value
  }
  
  private func url(parameters: [String: Any]) -> URL {
    guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { fatalError() }
    components.path = DMPlayerViewController.pathPrefix
    var items = [
      URLQueryItem(name: "api", value: "nativeBridge"),
      URLQueryItem(name: "objc_sdk_version", value: DMPlayerViewController.version),
      URLQueryItem(name: "app", value: Bundle.main.bundleIdentifier),
      URLQueryItem(name: "client_type", value: "iosapp"),
      URLQueryItem(name: "webkit-playsinline", value: "1"),
      URLQueryItem(name: "queue-enable", value: "0")
      
    ]
    
    let parameterItems = parameters.map { return URLQueryItem(name: $0, value: String(describing: $1)) }
    items.append(contentsOf: parameterItems)
    
    if let deviceIdentifier = deviceIdentifier {
      items.append(URLQueryItem(name: "ads_device_id", value: deviceIdentifier))
      items.append(URLQueryItem(name: "ads_device_tracking", value: true.description))
    }
    
    components.queryItems = items
    let url = components.url!
    return url
  }
  
  open func toggleControls(show: Bool) {
    let hasControls = show ? "1" : "0"
    notifyPlayerApi(method: "controls", argument: hasControls)
  }
  
  final public func notifyPlayerApi(method: String, argument: String? = nil, completion: (() -> ())? = nil) {
    let playerArgument = argument != nil ? argument! : "null"
    
    webView.evaluateJavaScript("player.api('\(method)', \(playerArgument))") { _,_ in
      completion?()
    }
  }
  
  open func toggleFullscreen() {
    notifyPlayerApi(method: "notifyFullscreenChanged")
  }
  
  open func play() {
    notifyPlayerApi(method: "play")
  }
  
  open func pause() {
    notifyPlayerApi(method: "pause")
  }
  
  open func seek(to: TimeInterval) {
    notifyPlayerApi(method: "seek", argument: "\(to)")
  }
  
  open func mute(completion: (() -> ())? = nil) {
    webView.evaluateJavaScript("player.mute()") { _,_ in
      completion?()
    }
  }
  
  open func unmute(completion: (() -> ())? = nil) {
    webView.evaluateJavaScript("player.unmute()") { _,_ in
      completion?()
    }
  }
  
}

extension DMPlayerViewController: WKScriptMessageHandler {
  
  open func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if message.name == DMPlayerViewController.consoleHandlerEvent {
      print(message.body)
    } else {
      guard let event = EventParser.parseEvent(from: message.body) else { return }
      switch event {
      case .namedEvent(let name, _) where name == "apiready":
        isInitialized = true
        
        if let videoIdToLoad = videoIdToLoad {
          load(videoId: videoIdToLoad, params: paramsToLoad)
          self.videoIdToLoad = nil
          self.paramsToLoad = nil
        }
        delegate?.playerDidInitialize(self)
      default:
        break
      }
      delegate?.player(self, didReceiveEvent: event)
    }
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
  
  open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard let url = navigationAction.request.url , navigationAction.navigationType == .linkActivated else {
      decisionHandler(.allow)
      return
    }
    if !url.absoluteString.contains(DMPlayerViewController.pathPrefix) {
      if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let scheme = components.scheme, scheme == "http" || scheme == "https" {
        delegate?.player(self, openUrl: url)
        decisionHandler(.cancel)
        return
      }
    }
    decisionHandler(.allow)
  }
  
  open func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    delegate?.player(self, didFailToInitializeWithError: error)
  }
  
  open func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    delegate?.player(self, didFailToInitializeWithError: error)
  }
  
}

extension DMPlayerViewController: WKUIDelegate {
  
  public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                      for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if let url = navigationAction.request.url {
      delegate?.player(self, openUrl: url)
    }
    return nil
  }
  
}

extension DMPlayerViewController {
  
  fileprivate func advertisingIdentifier() -> String? {
    let canTrack = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
    let advertisingIdentifier = ASIdentifierManager.shared().advertisingIdentifier
    if canTrack {
      #if swift(>=4.0)
      return advertisingIdentifier.uuidString
      #else
      return advertisingIdentifier?.uuidString
      #endif
    } else {
      return nil
    }
  }
  
}

