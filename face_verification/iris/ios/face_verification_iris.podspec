Pod::Spec.new do |s|
  s.name             = 'face_verification_iris'
  s.version          = '1.0.0'
  s.summary          = 'Face verification via the vendor Iris SDK.'
  s.description      = <<-DESC
Alternate face-verification engine alongside face_verification, backed by
the vendor Iris SDK (passportreader.app) rather than an on-device pipeline.
                       DESC
  s.homepage         = 'https://github.com/privacybydesign/vcmrtd'
  s.license          = { :type => 'GPL-3.0 (wrapper code); Iris.xcframework is a proprietary vendor binary, see android/libs/README.md' }
  s.author           = { 'Yivi' => 'support@yivi.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'

  # Vendor binary, not committed — see ../.gitignore and README.md. Place the
  # unzipped Iris.xcframework here before building for iOS.
  s.vendored_frameworks = 'Iris.xcframework'

  # Matches Iris.xcframework's own MinimumOSVersion.
  s.platform = :ios, '16.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
