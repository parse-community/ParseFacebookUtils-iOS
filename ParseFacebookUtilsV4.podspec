Pod::Spec.new do |s|
  s.name             = 'ParseFacebookUtilsV4'
  s.version          = '1.11.1'
  s.license          =  { :type => 'Commercial', :text => "See https://www.parse.com/about/terms" }
  s.homepage         = 'https://www.parse.com/'
  s.summary          = 'Parse is a complete technology stack to power your app\'s backend.'
  s.authors          = 'Parse'

  s.source           = { :git => "https://github.com/ParsePlatform/ParseFacebookUtils-iOS.git", :tag => "v4-#{s.version.to_s}" }

  s.platform = :ios, :tvos
  s.ios.deployment_target = '7.0'
  s.tvos.deployment_target = '9.0'
  s.requires_arc = true

  s.public_header_files = 'ParseFacebookUtils/*.h'
  s.source_files = 'ParseFacebookUtils/**/*.{h,m}'

  s.ios.exclude_files = 'ParseFacebookUtils/Internal/AuthenticationProvider/tvOS/**/*.{h,m}'
  s.tvos.exclude_files = 'ParseFacebookUtils/Internal/AuthenticationProvider/iOS/**/*.{h,m}'

  s.frameworks        = 'AudioToolbox',
                        'CFNetwork',
                        'CoreGraphics',
                        'CoreLocation',
                        'QuartzCore',
                        'Security',
                        'SystemConfiguration'
  s.ios.weak_frameworks = 'Accounts',
                          'Social'
  s.libraries        = 'z', 'sqlite3'

  s.dependency 'Bolts/Tasks', '>= 1.6'
  s.dependency 'Parse', '~> 1.12'
  s.dependency 'FBSDKCoreKit', '~> 4.10'

  s.ios.dependency 'FBSDKLoginKit', '~> 4.10'
  s.tvos.dependency 'FBSDKTVOSKit', '~> 4.10'
end
