#
# Be sure to run `pod lib lint DBModel.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "DBModel"
  s.version          = "0.1.0"
  s.summary          = "This is a combination of json parsing and database."

  s.homepage         = "https://github.com/Musjoy/DBModel"
  s.license          = 'MIT'
  s.author           = { "Raymond" => "Ray.musjoy@gmail.com" }
  s.source           = { :git => "https://github.com/Musjoy/DBModel.git", :tag => "v-#{s.version}", :submodules => true }

  s.ios.deployment_target = '7.0'

  s.default_subspec = 'DBModel'

  s.user_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => 'MODULE_DB_MODEL'
  }

  s.subspec 'DBModel' do |ss|
    ss.source_files = 'DBModel/DBMode*.{h,m}'
  end

  s.subspec 'DBManager' do |ss|
    ss.source_files = 'DBModel/DBManager.{h,m}', 'DBModel/DBTableInfo.{h,m}'
    ss.dependency 'DBModel/DBModel'
    ss.dependency 'FMDB'
    ss.user_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'MODULE_DB_MANAGER'
    }
    ss.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'MODULE_DB_MANAGER'
    }
  end

  s.dependency 'ModuleCapability', '~> 0.1.1'
  s.prefix_header_contents = '#import "ModuleCapability.h"'

end
