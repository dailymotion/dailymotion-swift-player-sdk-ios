//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import AdSupport
import AppTrackingTransparency
import OMSDK_Dailymotion
import UIKit
import WebKit
import AVKit

public protocol DMPlayerViewControllerDelegate: AnyObject {
  
  func player(_ player: DMPlayerViewController, didReceiveEvent event: PlayerEvent)
  func player(_ player: DMPlayerViewController, openUrl url: URL)
  func playerDidInitialize(_ player: DMPlayerViewController)
  func player(_ player: DMPlayerViewController, didFailToInitializeWithError error: Error)
  
}

private struct EmbedderProperties: Codable {
  let version: String
  let capabilities: Capabilities
}

private struct Capabilities: Codable {
  let omsdk: String
  let ompartner: String
  let omversion: String
  let tracking: Tracking
}

private struct Tracking: Codable {
  let atts: UInt?
  let deviceID: String?
  let trackingAllowed: Bool?
  let limitAdTracking: Bool?
}

private enum OMSDKError: Error {
  case error
}

private enum Quartile {
  case Init
  case start
  case firstQuartile
  case midpoint
  case thirdQuartile
  case complete
}

final class DailymotionSDK {
  static let resourceBundle: Bundle? = {
#if SWIFT_PACKAGE
    return Bundle.module
#else
    let myBundle = Bundle(for: DailymotionSDK.self)
    
    guard let resourceBundleURL = myBundle.url(forResource: "DailymotionPlayerSDK", withExtension: "bundle") else {
      assertionFailure("DailymotionPlayerSDK.bundle required for OM SDK not found")
      return nil
    }
    
    guard let resourceBundle = Bundle(url: resourceBundleURL) else {
      assertionFailure("Cannot access DailymotionPlayerSDK.bundle required for OM SDK")
      return nil
    }
    
    return resourceBundle
#endif
  }()
}

open class DMPlayerViewController: UIViewController {
  
  private static let defaultUrl = URL(string: "https://www.dailymotion.com")!
  private static let version = "4.0.1"
  private static let eventName = "dmevent"
  private static let pathPrefix = "/embed/"
  private static let messageHandlerEvent = "triggerEvent"
  private static let consoleHandlerEvent = "consoleEvent"
  fileprivate static let loggerParameterKey = "logger"
  private static let tcStringKey = "IABTCF_TCString"
  private static let tcStringCookieName = "dm-euconsent-v2"
  
  private var webView: WKWebView!
  private var baseUrl: URL!
  private var loggerEnabled: Bool = false
  fileprivate var isInitialized = false
  fileprivate var videoIdToLoad: String?
  fileprivate var paramsToLoad: String?
  
  open weak var delegate: DMPlayerViewControllerDelegate?

  /// OM SDK
  private static let omidPartnerName = "Dailymotion"
  private static let omidPartnerVersion = "6.7.5"
  private static var omidScriptUrl: URL? = DailymotionSDK.resourceBundle?.url(forResource: "omsdk-v1", withExtension: "js")

  private var allowOMSDK = false
  private var allowAudioSessionActive = false
  private var omidAdEvents: OMIDDailymotionAdEvents?
  private var omidMediaEvents: OMIDDailymotionMediaEvents?
  private var currentQuartile: Quartile = .Init
  private var adPosition: TimeInterval = 0.0
  private var adDuration: TimeInterval = 0.0
  private var omidSession: OMIDDailymotionAdSession?
  private var isAdPaused = false
  private var allowIDFA = true

  override open var shouldAutorotate: Bool {
    return true
  }

  public var playerState: OMIDPlayerState? {
    didSet {
      guard allowOMSDK, let playerState = playerState else { return }

      if oldValue != playerState {
        omidMediaEvents?.playerStateChange(to: playerState)
      }
    }
  }

  /// Initialize a new instance of the player
  /// - Parameters:
  ///   - parameters:  The dictionary of configuration parameters that are passed to the player.
  ///   - baseUrl:     An optional base URL. Defaults to dailymotion's server.
  ///   - accessToken: An optional oauth token. If provided it will be passed as Bearer token to the player.
  ///   - cookies:     An optional array of HTTPCookie values that are passed to the player.
  ///   - allowIDFA:   Allow IDFA Collection. Defaults true
  ///   - allowPiP:    Allow Picture in Picture on iPad. Defaults true
  ///   - allowAudioSessionActive: In order to control the view-ability of the Ads, OMID SDK needs AVAudioSession sharedInstance of app to be set to .mixWithOthers options and Active. Disabling this will affect Ads monetisation of your app.
  public init(parameters: [String: Any], baseUrl: URL? = nil, accessToken: String? = nil,
              cookies: [HTTPCookie]? = nil, allowIDFA: Bool = true, allowPiP: Bool = true, allowAudioSessionActive: Bool = true) {
    super.init(nibName: nil, bundle: nil)
    
    self.allowAudioSessionActive = allowAudioSessionActive
    
    if OMIDDailymotionSDK.shared.isActive {
      allowOMSDK = true
    } else {
      if
        let _ = DMPlayerViewController.omidScriptUrl,
        OMIDDailymotionSDK.shared.activate()
      {
        allowOMSDK = true
      } else {
        allowOMSDK = false
      }
    }
    
    self.allowIDFA = allowIDFA
    
    NotificationCenter.default.addObserver(self, selector: #selector(self.willEnterInForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    setAudioSession()
    
    if parameters.contains(where: { $0.key == DMPlayerViewController.loggerParameterKey }) {
      loggerEnabled = true
    }

    var cookiesToLoad: [HTTPCookie] = []
    cookiesToLoad.append(contentsOf: cookies ?? [])
    if let consentCookie = buildConsentCookie() {
      cookiesToLoad.append(consentCookie)
    }

    self.loadWebView(parameters: parameters, baseUrl: baseUrl, accessToken: accessToken, cookies: cookiesToLoad, allowPiP: allowPiP)
  }

  @objc private func willEnterInForeground(notification: NSNotification) {
    setAudioSession()
  }
  
  private func newWebView(cookies: [HTTPCookie]?, allowPiP: Bool = true) -> WKWebView {
    let webView = WKWebView(frame: .zero, configuration: newConfiguration(cookies: cookies, allowPiP: allowPiP))
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
  
  open func loadWebView(parameters: [String: Any], baseUrl: URL? = nil, accessToken: String? = nil, cookies: [HTTPCookie]? = nil, allowPiP: Bool = true) {
    self.baseUrl = baseUrl ?? DMPlayerViewController.defaultUrl
    webView = newWebView(cookies: cookies, allowPiP: allowPiP)
    view = webView
    let request = newRequest(parameters: parameters, accessToken: accessToken, cookies: cookies)
    webView.load(request)
    webView.navigationDelegate = self
  }
  
  //We need this since sometimes the system sets the AVAudioSession to inactive when the app enter in background.
  private func setAudioSession() {
    if (allowAudioSessionActive && allowOMSDK) {
      if #available(iOS 10.0, *) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
      }
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
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
      completion?()
      return
    }

    
    // x5xvext
    // x80wxwd
    let js = self.buildLoadString(videoId: videoId, params: params)
//    let js = self.buildLoadString(videoId: "x5xvext", params: params)

    if let consentCookie = buildConsentCookie() {
      setCookie(consentCookie) {
        self.webView.evaluateJavaScript(js) { _, _ in
          completion?()
        }
      }
    } else {
      self.webView.evaluateJavaScript(js) { _, _ in
        completion?()
      }
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
      let cookieHeader = cookies.compactMap({ "\($0.name)=\($0.value)" }).joined(separator: ";")
      request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
    }
    return request
  }
  
  private func newConfiguration(cookies: [HTTPCookie]?, allowPiP: Bool = true) -> WKWebViewConfiguration {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    if #available(iOS 9.0, *) {
      configuration.requiresUserActionForMediaPlayback = false
      configuration.allowsAirPlayForMediaPlayback = true
      configuration.allowsPictureInPictureMediaPlayback = allowPiP
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
    if let embedderProperties = getEmbedderProperties() {
      source += "getEmbedderProperties: function() {"
      source += "return '\(embedderProperties)';"
      source += "},"
    }
    source += "triggerEvent: function(data) {"
    source += "window.webkit.messageHandlers.\(DMPlayerViewController.messageHandlerEvent).postMessage(decodeURIComponent(data));"
    source += "}};"
    return source
  }

  private func getEmbedderProperties() -> String? {
    let capabilities = Capabilities(omsdk: OMIDDailymotionSDK.versionString(), ompartner: DMPlayerViewController.omidPartnerName, omversion: DMPlayerViewController.omidPartnerVersion, tracking: constructTracking())
    let embedderProperties = EmbedderProperties(version: DMPlayerViewController.version, capabilities: capabilities)
    guard let encodedData = try? JSONEncoder().encode(embedderProperties) else { return nil }
    return String(data: encodedData, encoding: .utf8)
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
      URLQueryItem(name: "client_type", value: UIDevice.current.userInterfaceIdiom == .pad ? "ipadosapp" : "iosapp"),
      URLQueryItem(name: "webkit-playsinline", value: "1"),
      URLQueryItem(name: "queue-enable", value: "0")
      
    ]
    
    let parameterItems = parameters.map { return URLQueryItem(name: $0, value: String(describing: $1)) }
    items.append(contentsOf: parameterItems)
    
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

      if allowOMSDK {
        handleOmsdkSignals(event)
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
  
  fileprivate func constructTracking() -> Tracking {
    if allowIDFA {
      let advertisingIdentifier = ASIdentifierManager.shared().advertisingIdentifier
      if #available(iOS 14, *) {
        let tracking = Tracking(atts: ATTrackingManager.trackingAuthorizationStatus.rawValue, deviceID: advertisingIdentifier.uuidString, trackingAllowed: true, limitAdTracking: nil)
        return tracking
      } else {
        let tracking = Tracking(atts: nil, deviceID: advertisingIdentifier.uuidString, trackingAllowed: true, limitAdTracking: ASIdentifierManager.shared().isAdvertisingTrackingEnabled)
        return tracking
      }
    } else {
      let tracking = Tracking(atts: nil, deviceID: "", trackingAllowed: false, limitAdTracking: nil)
      return tracking
    }
  }

  private func buildConsentCookie() -> HTTPCookie? {
    if let tcString = UserDefaults.standard.string(forKey: DMPlayerViewController.tcStringKey) {
      var cookieProperties: [HTTPCookiePropertyKey: Any] = [
        .name: DMPlayerViewController.tcStringCookieName,
        .value: tcString,
        .domain: ".dailymotion.com",
        .path: "/",
        .secure: true
      ]
      if let expiresDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) {
        cookieProperties[.expires] = expiresDate
      }

      return HTTPCookie(properties: cookieProperties)
    }

    return nil
  }

  private func setCookie(_ cookie: HTTPCookie, completion: (() -> ())? = nil) {
    if #available(iOS 11.0, *) {
      webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
        completion?()
      }
    }
  }

}

// MARK: - OMSDK
private extension DMPlayerViewController {
  func handleOmsdkSignals(_ event: PlayerEvent) {
    switch event {
    case .namedEvent(let name, let data) where name == WebPlayerEvent.adLoaded:
      guard let verificationScripts = parseVerificationScriptsInfo(from: data) else { return }

      createOmidSession(with: verificationScripts)

      do {
        try omidAdEvents?.impressionOccurred()
      } catch let error {
        omidSession?.logError(withType: .generic, message: error.localizedDescription)
      }

      guard
        let skipOffsetString = data?["skipOffset"],
        let skipOffset = Int(skipOffsetString),
        let autoPlay = data?["autoplay"]?.boolValue,
        let position = data?["position"]
      else  { return }

      let omidPosition: OMIDPosition
      switch position {
      case "preroll":
        omidPosition = .preroll
      case "midroll":
        omidPosition = .midroll
      case "postroll":
        omidPosition = .postroll
      case "standalone":
        omidPosition = .standalone
      default:
        fatalError("Incorrect position")
      }

      let properties = OMIDDailymotionVASTProperties(skipOffset: CGFloat(skipOffset), autoPlay: autoPlay, position: omidPosition)
      do {
        try omidAdEvents?.loaded(with: properties)
      } catch let error {
        omidSession?.logError(withType: .generic, message: error.localizedDescription)
      }
    case .namedEvent(let name, let data) where name == WebPlayerEvent.adStart:
      guard let duration = data?["adData[adDuration]"], let adDuration = Double(duration) else { return }
      currentQuartile = .Init
      self.adDuration = adDuration
      adPosition = 0
      isAdPaused = false

      startOmidSession()
    case .namedEvent(let name, let data) where name == WebPlayerEvent.adEnd:
      switch data?["reason"] {
      case "AD_STOPPED":
        omidMediaEvents?.complete()
        currentQuartile = .complete
      case "AD_SKIPPED":
        omidMediaEvents?.skipped()
      case "AD_ERROR":
        omidSession?.logError(withType: .media, message: data?["error"] ?? "AD_ERROR")
      default:
        break
      }

      endOmidSession()
    case .namedEvent(let name, _) where name == WebPlayerEvent.adBufferStart:
      omidMediaEvents?.bufferStart()
    case .namedEvent(let name, _) where name == WebPlayerEvent.adBufferEnd:
      omidMediaEvents?.bufferFinish()
    case .namedEvent(let name, _) where name == WebPlayerEvent.adPause:
      omidMediaEvents?.pause()
      isAdPaused = true
    case .namedEvent(let name, _) where name == WebPlayerEvent.adPlay:
      if isAdPaused {
        omidMediaEvents?.resume()
        isAdPaused = false
      }
    case .namedEvent(let name, _) where name == WebPlayerEvent.adClick:
      omidMediaEvents?.adUserInteraction(withType: .click)
    case .namedEvent(let name, let data) where name == WebPlayerEvent.volumeChange:
      if let muted = data?[WebPlayerParam.muted], muted == true.description {
        omidMediaEvents?.volumeChange(to: 0)
      } else {
        omidMediaEvents?.volumeChange(to: 1)
      }
    case .namedEvent(let name, let data) where name == WebPlayerEvent.fullscreenChange:
      if playerState == nil {
        guard let fullscreen = (data?[WebPlayerParam.fullscreen])?.boolValue else { return }
        omidMediaEvents?.playerStateChange(to: fullscreen ? .fullscreen : .normal)
      }
    case .timeEvent(let name, let position) where name == WebPlayerEvent.adTimeUpdate:
      adPosition = position
      recordQuartileChange()
    default:
      break
    }
  }

  func parseVerificationScriptsInfo(from data: [String: String]?) -> [OMIDDailymotionVerificationScriptResource]? {
    guard let data = data else { return nil }

    var scripts: [String: VerificationScriptInfo] = [:]

    data.keys.forEach { key in
      guard let groups = key.groups(for: "verificationScripts\\[(.*)]\\[(.*)]").first else { return }

      switch groups[2] {
      case "resource":
        scripts[groups[1], default: VerificationScriptInfo()].url = data[groups[0]]
      case "vendor":
        scripts[groups[1], default: VerificationScriptInfo()].vendorKey = data[groups[0]]
      case "parameters":
        scripts[groups[1], default: VerificationScriptInfo()].parameters = data[groups[0]]
      default:
        break
      }
    }

    let verificationScripts: [OMIDDailymotionVerificationScriptResource] = scripts.compactMap { script in
      guard
        let urlString = script.value.url,
        let url = URL(string: urlString),
        let vendorKey = script.value.vendorKey,
        let parameters = script.value.parameters
      else { return nil }

      return OMIDDailymotionVerificationScriptResource(url: url, vendorKey: vendorKey, parameters: parameters)
    }
    print("===== \(scripts)")
    print("===== \(verificationScripts)")
    return verificationScripts
  }

  func createOmidSession(with verificationScripts: [OMIDDailymotionVerificationScriptResource]) {
    print("===== create omid session")
    guard
      omidSession == nil,
      !verificationScripts.isEmpty,
      let partner = OMIDDailymotionPartner(name: DMPlayerViewController.omidPartnerName, versionString: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)
    else {
      return
    }

    do {
      let context = try createAdSessionContext(withPartner: partner, resources: verificationScripts, webView: webView)
      let configuration = try OMIDDailymotionAdSessionConfiguration(creativeType: .video, impressionType: .onePixel, impressionOwner: .nativeOwner, mediaEventsOwner: .nativeOwner, isolateVerificationScripts: true)
      let omidSession = try OMIDDailymotionAdSession(configuration: configuration, adSessionContext: context)
      omidSession.mainAdView = webView
      omidAdEvents = try OMIDDailymotionAdEvents(adSession: omidSession)
      omidMediaEvents = try OMIDDailymotionMediaEvents(adSession: omidSession)
      self.omidSession = omidSession
    } catch let error {
      print(error.localizedDescription)
    }
  }

  func startOmidSession() {
    omidSession?.start()
  }

  func endOmidSession() {
    omidSession?.finish()
    omidSession = nil
    omidAdEvents = nil
    omidMediaEvents = nil
  }

  func createAdSessionContext(withPartner partner: OMIDDailymotionPartner, resources: [OMIDDailymotionVerificationScriptResource], webView: WKWebView) throws -> OMIDDailymotionAdSessionContext {
    guard let url = DMPlayerViewController.omidScriptUrl else { throw OMSDKError.error }

    let omidScript = try String(contentsOf: url)
    return try OMIDDailymotionAdSessionContext(partner: partner, script: omidScript, resources: resources, contentUrl: nil, customReferenceIdentifier: nil)
  }

  func recordQuartileChange() {
    let progressPercent = adPosition / adDuration

    switch currentQuartile {
    case .Init:
      if (progressPercent > 0) {
        omidMediaEvents?.start(withDuration: CGFloat(adDuration), mediaPlayerVolume: 1)
        currentQuartile = .start
      }
    case .start:
      if (progressPercent > Double(1)/Double(4)) {
        omidMediaEvents?.firstQuartile()
        currentQuartile = .firstQuartile
      }
    case .firstQuartile:
      if (progressPercent > Double(1)/Double(2)) {
        omidMediaEvents?.midpoint()
        currentQuartile = .midpoint
      }
    case .midpoint:
      if (progressPercent > Double(3)/Double(4)) {
        omidMediaEvents?.thirdQuartile()
        currentQuartile = .thirdQuartile
      }
    case .thirdQuartile:
      if (progressPercent >= 1.0) {
      }
    default:
      break
    }
  }
}
