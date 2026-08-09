Pod::Spec.new do |s|
  s.name             = 'haptic_engine'
  s.version          = '0.1.0'
  s.summary          = 'Semantic haptics for iOS (Taptic Engine).'
  s.description      = 'Maps semantic haptic events to UIImpact/UINotification/UISelection feedback.'
  s.homepage         = 'https://example.invalid/haptic_engine'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Relay' => 'dev@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
