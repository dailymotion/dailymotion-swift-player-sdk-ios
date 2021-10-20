Pod::Spec.new do |s|
  s.name             = 'DailymotionPlayerSDK'
  s.version          = '4.0.0'
  s.summary          = 'Dailymotion iOS player (Swift)'
  s.homepage         = 'https://github.com/dailymotion/dailymotion-swift-player-sdk-ios'
  s.author           = 'Dailymotion'
  s.license          = 'MIT'
  s.source           = { :git => 'https://github.com/dailymotion/dailymotion-swift-player-sdk-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.source_files = 'DailymotionPlayerSDK/*.swift'
  s.swift_version = '5.0'
  s.frameworks = 'UIKit', 'WebKit', 'AdSupport', 'OMSDK_Dailymotion'
  s.vendored_frameworks = 'OMSDK_Dailymotion.xcframework'
  s.resource_bundles = { 'DailymotionPlayerSDK' => ['DailymotionPlayerSDK/*.js'] }
end
