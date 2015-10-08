Pod::Spec.new do |s|
  s.name             = 'ParseFacebookUtils'
  s.version          = '1.9.0'
  s.license          =  { :type => 'Commercial', :text => "See https://www.parse.com/about/terms" }
  s.homepage         = 'https://www.parse.com/'
  s.summary          = 'Parse is a complete technology stack to power your app\'s backend.'
  s.authors          = 'Parse'

  s.source           = { :git => "https://github.com/ParsePlatform/ParseFacebookUtils-iOS.git", :tag => "v3-#{s.version.to_s}" }

  s.platform = :ios
  s.ios.deployment_target = '7.0'
  s.requires_arc = true

  s.public_header_files = 'ParseFacebookUtils/*.h'
  s.source_files = 'ParseFacebookUtils/**/*.{h,m}'

  s.frameworks        = 'AudioToolbox',
                        'CFNetwork',
                        'CoreGraphics',
                        'CoreLocation',
                        'QuartzCore',
                        'Security',
                        'StoreKit',
                        'SystemConfiguration'
  s.weak_frameworks = 'Accounts',
                      'Social'
  s.libraries        = 'z', 'sqlite3'

  s.dependency 'Bolts/Tasks', '>= 1.3.0'
  s.dependency 'Parse', '~> 1.9'
  s.dependency 'Facebook-iOS-SDK', '~> 3.24'
end
