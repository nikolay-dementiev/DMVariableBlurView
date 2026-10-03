
Pod::Spec.new do |s|
  s.name             = 'DMVariableBlurView'
  s.version          = '1.1.0'
  s.summary          = 'A blur whose radius changes from row to row, for SwiftUI and UIKit.'
  s.description      = <<-DESC
    DMVariableBlurView blurs what lies behind it. The blur is strongest where you ask for it
    and fades linearly to clear: from the top, from the bottom, from a band across the middle,
    or not at all. It uses a private filter of the system: read the README before you ship it.
                       DESC

  s.homepage         = 'https://github.com/nikolay-dementiev/DMVariableBlurView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Mykola Dementiev' => 'nikolas.dementiev@gmail.com' }
  s.ios.deployment_target = "17.0"
  #s.watchos.deployment_target = "7.0"
  
  s.source           = { :git => 'https://github.com/nikolay-dementiev/DMVariableBlurView.git', :tag => s.version.to_s }
  s.source_files = 'Sources/DMVariableBlurView/**/*.swift'
  s.requires_arc = true
  s.frameworks = 'Foundation'
  # The sources use the package access level, which needs the name of the package.
  s.pod_target_xcconfig = { 'OTHER_SWIFT_FLAGS' => '-package-name DMVariableBlurView' }
  
  s.cocoapods_version = '>= 1.4.0'
  if s.respond_to?(:swift_versions) then
    s.swift_versions = ['5.0', '6.0']
  else
    s.swift_version = '5.0'
  end
end
