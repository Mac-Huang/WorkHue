#!/usr/bin/env ruby
# Install xcodeproj with `gem install xcodeproj --user-install` before the first run.
require 'fileutils'
begin
  require 'xcodeproj'
rescue LoadError
  # The task environment stores the gem here. A normal gem installation also works.
  Gem.use_paths('/tmp/punchino-gems')
  require 'xcodeproj'
end

ROOT = File.expand_path('..', __dir__)
Dir.chdir(ROOT)
project_path = File.join(ROOT, 'Punchino.xcodeproj')
FileUtils.rm_rf(project_path) if File.exist?(project_path)
project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastUpgradeCheck'] = '2700'
project.root_object.attributes['LastSwiftUpdateCheck'] = '2700'
project.root_object.compatibility_version = 'Xcode 14.0'
project.main_group.indent_width = '4'
project.main_group.tab_width = '4'

base_config = project.main_group.new_group('Config', 'Config')
base_ref = base_config.new_file('Base.xcconfig')
Dir.glob('Config/*').sort.each do |path|
  next if File.basename(path) == 'Base.xcconfig'
  base_config.new_file(File.basename(path))
end
project.build_configurations.each do |config|
  config.base_configuration_reference = base_ref
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
end

source_refs = {}
%w[Phone Shared Watch Widgets Tests/UITests Tests/WatchUITests].each do |directory|
  group = project.main_group.new_group(directory, directory)
  source_refs[directory] = []
  Dir.glob("#{directory}/**/*").sort.each do |path|
    next if File.directory?(path)
    next if path.split('/').any? { |part| part.end_with?('.xcassets') }
    next unless ['.swift', '.xcprivacy', '.strings', '.stringsdict'].include?(File.extname(path))
    relative = path.sub(/^#{Regexp.escape(directory)}\//, '')
    source_refs[directory] << [path, group.new_file(relative)]
  end
  Dir.glob("#{directory}/**/*.xcassets").sort.each do |path|
    relative = path.sub(/^#{Regexp.escape(directory)}\//, '')
    source_refs[directory] << [path, group.new_file(relative)]
  end
end

make_target = lambda do |name, type, platform, identifier, info, directories|
  target = project.new_target(type, name, platform, '26.0')
  target.build_configurations.each do |config|
    config.build_settings.merge!({
      'PRODUCT_BUNDLE_IDENTIFIER' => identifier,
      'PRODUCT_NAME' => '$(TARGET_NAME)',
      'INFOPLIST_FILE' => info,
      'GENERATE_INFOPLIST_FILE' => 'NO',
      'CODE_SIGN_ENTITLEMENTS' => '$(PUNCHINO_ENTITLEMENTS)',
      'SWIFT_VERSION' => '5.0',
      'MARKETING_VERSION' => '1.0.0',
      'CURRENT_PROJECT_VERSION' => '1',
      'CODE_SIGN_STYLE' => 'Automatic',
      'DEVELOPMENT_TEAM' => '',
      'ENABLE_PREVIEWS' => 'YES',
      'SWIFT_EMIT_LOC_STRINGS' => 'YES',
      'DEBUG_INFORMATION_FORMAT' => config.name == 'Debug' ? 'dwarf' : 'dwarf-with-dsym',
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => config.name == 'Debug' ? '$(inherited) DEBUG' : '$(inherited)',
      'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
      'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS' => 'YES'
    })
    if platform == :watchos
      config.build_settings['SDKROOT'] = 'watchos'
      config.build_settings['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
      config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
      config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '26.0'
    else
      config.build_settings['SDKROOT'] = 'iphoneos'
      config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
      config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
      config.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
      config.build_settings['SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
      config.build_settings['SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
    end
    if type == :app_extension
      config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      config.build_settings['SKIP_INSTALL'] = 'YES'
      config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] += ' PUNCHINO_WIDGET'
      config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
    else
      config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
      config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
    end
  end
  directories.each do |directory|
    source_refs.fetch(directory, []).each do |path, ref|
      if File.extname(path) == '.swift'
        target.source_build_phase.add_file_reference(ref)
      else
        target.resources_build_phase.add_file_reference(ref)
      end
    end
  end
  target
end

phone = make_target.call('Punchino', :application, :ios, 'com.xuming.PunchinoColor', 'Config/Phone-Info.plist', %w[Phone Shared])
watch = make_target.call('PunchinoWatch', :application, :watchos, 'com.xuming.PunchinoColor.watchkitapp', 'Config/Watch-Info.plist', %w[Watch Shared])
phone_widgets = make_target.call('PunchinoWidgets', :app_extension, :ios, 'com.xuming.PunchinoColor.widgets', 'Config/Widget-Info.plist', %w[Widgets Shared])
watch_widgets = make_target.call('PunchinoWatchWidgets', :app_extension, :watchos, 'com.xuming.PunchinoColor.watchkitapp.widgets', 'Config/Widget-Info.plist', %w[Widgets Shared])
watch.build_configurations.each { |config| config.build_settings['SKIP_INSTALL'] = 'YES' }

embed = lambda do |host, child, name, destination, path|
  host.add_dependency(child)
  phase = host.new_copy_files_build_phase(name)
  phase.dst_subfolder_spec = destination.to_s
  phase.dst_path = path
  build_file = phase.add_file_reference(child.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
end
embed.call(phone, phone_widgets, 'Embed App Extensions', 13, '')
embed.call(watch, watch_widgets, 'Embed App Extensions', 13, '')
embed.call(phone, watch, 'Embed Watch Content', 16, '$(CONTENTS_FOLDER_PATH)/Watch')

make_ui_tests = lambda do |name, host, platform, directory|
  target = project.new_target(:ui_test_bundle, name, platform, '26.0')
  target.add_dependency(host)
  target.build_configurations.each do |config|
    config.build_settings.merge!({
      'PRODUCT_BUNDLE_IDENTIFIER' => "#{host.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER']}.UITests",
      'PRODUCT_NAME' => '$(TARGET_NAME)',
      'GENERATE_INFOPLIST_FILE' => 'YES',
      'SWIFT_VERSION' => '5.0',
      'TEST_TARGET_NAME' => host.name,
      'CODE_SIGN_STYLE' => 'Automatic',
      'DEVELOPMENT_TEAM' => '',
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => config.name == 'Debug' ? '$(inherited) DEBUG' : '$(inherited)'
    })
    if platform == :watchos
      config.build_settings['SDKROOT'] = 'watchos'
      config.build_settings['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
      config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
      config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '26.0'
    else
      config.build_settings['SDKROOT'] = 'iphoneos'
      config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
      config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
    end
  end
  source_refs.fetch(directory, []).each do |path, ref|
    target.source_build_phase.add_file_reference(ref) if File.extname(path) == '.swift'
  end
  target
end
ui_tests = make_ui_tests.call('PunchinoUITests', phone, :ios, 'Tests/UITests')
watch_ui_tests = make_ui_tests.call('PunchinoWatchUITests', watch, :watchos, 'Tests/WatchUITests')
project.root_object.attributes['TargetAttributes'] = {
  ui_tests.uuid => { 'TestTargetID' => phone.uuid },
  watch_ui_tests.uuid => { 'TestTargetID' => watch.uuid }
}

project.save
phone_scheme = Xcodeproj::XCScheme.new
phone_scheme.configure_with_targets(phone, ui_tests, launch_target: true)
phone_scheme.test_action.build_configuration = 'Debug'
phone_scheme.test_action.code_coverage_enabled = false
phone_scheme.save_as(project_path, 'Punchino', true)
watch_scheme = Xcodeproj::XCScheme.new
watch_scheme.configure_with_targets(watch, watch_ui_tests, launch_target: true)
watch_scheme.save_as(project_path, 'PunchinoWatch', true)
puts "Generated #{project_path}"
puts "Targets: #{project.targets.map(&:name).join(', ')}"
