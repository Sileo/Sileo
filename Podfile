# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

def sileo_pods
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!

  # ignore all warnings from all pods
  inhibit_all_warnings!

  # Pods for Sileo
	pod 'SDWebImage', '~> 4.0', :modular_headers => true
	pod 'SDWebImage/GIF'
	pod 'Alamofire', '~> 5.0'
	pod 'Cosmos', '~> 19.0'
	pod 'LNZTreeView'
  	pod 'SwiftSoup'
	pod 'Google-Mobile-Ads-SDK', '~> 7.41.0'
	pod 'FLAnimatedImage', '~> 1.0', :modular_headers => true
	pod 'SWCompression', '~> 4.5'
	pod 'Flurry-iOS-SDK/FlurrySDK'
	pod 'Down'
end

target 'Sileo' do
  sileo_pods

  post_install do |pi|
    pi.pods_project.targets.each do |t|
	t.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
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
