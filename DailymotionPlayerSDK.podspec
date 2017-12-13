Pod::Spec.new do |s|
  s.name             = 'DailymotionPlayerSDK'
  s.version          = '3.7.0'
  s.summary          = 'The Dailymotion iOS player (Swift)'
  s.homepage         = 'https://github.com/dailymotion/dailymotion-swift-player-sdk-ios'
  s.author           = 'Dailymotion'
  s.license          = 'MIT'
  s.source           = { :git => 'https://github.com/dailymotion/dailymotion-swift-player-sdk-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'DailymotionPlayerSDK/*.swift'

  s.frameworks = 'UIKit', 'WebKit'
end
