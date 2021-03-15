# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'

def sileo_pods
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!

  # ignore all warnings from all pods
  inhibit_all_warnings!

  # Pods for Sileo
	pod 'SDWebImage', '~> 5.0', :modular_headers => true
	pod 'Alamofire', '~> 5.0'
	pod 'Cosmos', '~> 19.0'
	pod 'LNZTreeView'
	pod 'XLForm', '~> 4.0', :modular_headers => true
	pod 'KeychainAccess'
	pod 'SwiftSoup'
	pod 'Google-Mobile-Ads-SDK', '~> 7.41.0'
	pod 'SWCompression', '~> 4.5'
	pod 'Flurry-iOS-SDK/FlurrySDK', :git => 'https://github.com/flurry/flurry-ios-sdk.git', :tag => '11.2.0.rc1'
	pod 'Down'
	pod 'AUPickerCell'
	pod 'Alderis', :git => 'https://github.com/hbang/Alderis.git'
	pod 'SwiftTryCatch', :modular_headers => true
	pod 'SQLite.swift', '~> 0.12.0'
end

target 'Sileo' do
  sileo_pods

  post_install do |pi|
    pi.pods_project.targets.each do |t|
	t.build_configurations.each do |config|
	    config.build_settings['ARCHS'] = '$(ARCHS_STANDARD)'
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
        end
    end
  end
end

target 'Sileo Demo' do
  sileo_pods
end

target 'SileoTests' do
  inherit! :search_paths
  # Pods for testing
end

target 'SileoUITests' do
  inherit! :search_paths
  # Pods for testing
end
