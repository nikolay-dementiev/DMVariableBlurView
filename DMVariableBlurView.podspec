
Pod::Spec.new do |s|
  s.name             = 'DMVariableBlurView'
  s.version          = '1.0.0'
  s.summary          = 'SwiftUI-compatible SDK for applying dynamic blur effects with customizable configurations'
  s.description      = <<-DESC
    a SwiftUI-compatible library for applying dynamic blur effects with customizable configurations. 
    Features include support for multiple blur directions (e.g., blurredTopClearBottom, blurredFully), 
    dynamic blur radius adjustments, and improved error handling.
                       DESC

  s.homepage         = 'https://github.com/nikolay-dementiev/DMVariableBlurView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Mykola Dementiev' => 'nikolas.dementiev@gmail.com' }
  s.ios.deployment_target = "17.0"
  s.watchos.deployment_target = "7.0"
  
  s.source           = { :git => 'https://github.com/nikolay-dementiev/DMVariableBlurView', :tag => s.version.to_s }
  s.source_files = 'Sources/**/*.{swift,h,m,c}'
  s.exclude_files = 'Examples/**'
  s.weak_framework = "XCTest"
  s.requires_arc = true
  s.frameworks = 'Foundation'
  
  s.cocoapods_version = '>= 1.4.0'
  if s.respond_to?(:swift_versions) then
    s.swift_versions = ['5.0']
  else
    s.swift_version = '5.0'
  end
end
