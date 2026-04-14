#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint twentyface_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'twentyface_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for 20face SDK face verification.'
  s.description      = <<-DESC
Flutter plugin for 20face SDK face verification. Enables comparison of live
camera images against passport photos (DG2) with liveness detection.
                       DESC
  s.homepage         = 'https://github.com/privacybydesign/vcmrtd'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Privacy by Design Foundation' => 'info@privacybydesign.foundation' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Vendor the 20face SDK framework
  s.vendored_frameworks = 'Frameworks/twentyface_objcxx_wrapper.xcframework'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
