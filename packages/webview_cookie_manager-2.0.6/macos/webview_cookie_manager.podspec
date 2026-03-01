Pod::Spec.new do |s|
  s.name             = 'webview_cookie_manager'
  s.version          = '0.0.1'
  s.summary          = 'Cookie manager plugin for Flutter WebView.'
  s.description      = <<-DESC
Manages web cookies for Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/fryette/webview_cookie_manager'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'webview_cookie_manager' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency       'FlutterMacOS'
  s.platform         = :osx, '10.13'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end