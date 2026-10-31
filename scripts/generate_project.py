#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project after adding Swift files."""
from pathlib import Path
from hashlib import sha1

root = Path(__file__).resolve().parent.parent
project = root / 'AdaptiveTouch.xcodeproj'
project.mkdir(exist_ok=True)
def uid(name): return sha1(name.encode()).hexdigest()[:24].upper()
def q(s): return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'
app = sorted((root / 'AdaptiveTouch').rglob('*.swift'))
tests = sorted((root / 'AdaptiveTouchTests').rglob('*.swift'))
objects = []
def add(name, value): objects.append(f'\t\t{uid(name)} = {{ {value} }};')
for target, files in [('app', app), ('tests', tests)]:
    for f in files:
        path = f.relative_to(root).as_posix()
        add('ref:'+path, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path)}; sourceTree = "<group>";')
        add('build:'+path, f'isa = PBXBuildFile; fileRef = {uid("ref:"+path)};')
    add('sources:'+target, 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ' '.join(uid('build:'+f.relative_to(root).as_posix())+',' for f in files) + '); runOnlyForDeploymentPostprocessing = 0;')
    add('frameworks:'+target, 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    add('resources:'+target, 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
add('appProduct', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AdaptiveTouch.app; sourceTree = BUILT_PRODUCTS_DIR;')
add('testProduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = AdaptiveTouchTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
add('mainGroup', 'isa = PBXGroup; children = (' + ' '.join(uid('ref:'+f.relative_to(root).as_posix())+',' for f in app+tests) + f' {uid("productsGroup")},); sourceTree = "<group>";')
add('productsGroup', f'isa = PBXGroup; children = ({uid("appProduct")}, {uid("testProduct")},); name = Products; sourceTree = "<group>";')
add('proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("appTarget")}; remoteInfo = AdaptiveTouch;')
add('dependency', f'isa = PBXTargetDependency; target = {uid("appTarget")}; targetProxy = {uid("proxy")};')
for target, label, product, kind in [('app','AdaptiveTouch','appProduct','com.apple.product-type.application'),('tests','AdaptiveTouchTests','testProduct','com.apple.product-type.bundle.unit-test')]:
    deps = uid('dependency')+',' if target == 'tests' else ''
    add(target+'Target', f'isa = PBXNativeTarget; buildConfigurationList = {uid(target+"Configs")}; buildPhases = ({uid("sources:"+target)}, {uid("frameworks:"+target)}, {uid("resources:"+target)},); buildRules = (); dependencies = ({deps}); name = {label}; productName = {label}; productReference = {uid(product)}; productType = {q(kind)};')
for scope in ['project','app','tests']:
    for config in ['Debug','Release']:
        settings = {'SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'16.0','SDKROOT':'iphoneos'}
        if scope == 'app': settings.update({'PRODUCT_BUNDLE_IDENTIFIER':'org.example.AdaptiveTouch','PRODUCT_NAME':'AdaptiveTouch','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_CADisableMinimumFrameDurationOnPhone':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':'UIInterfaceOrientationPortrait','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0'})
        if scope == 'tests': settings.update({'PRODUCT_BUNDLE_IDENTIFIER':'org.example.AdaptiveTouchTests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/AdaptiveTouch.app/AdaptiveTouch','BUNDLE_LOADER':'$(TEST_HOST)','TARGETED_DEVICE_FAMILY':'1'})
        if config == 'Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG $(inherited)'; settings['ENABLE_TESTABILITY']='YES'
        st = ' '.join(f'{k} = {q(v)};' for k,v in settings.items())
        add(scope+config, f'isa = XCBuildConfiguration; buildSettings = {{ {st} }}; name = {config};')
    add(scope+'Configs', f'isa = XCConfigurationList; buildConfigurations = ({uid(scope+"Debug")}, {uid(scope+"Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
add('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600; }}; buildConfigurationList = {uid("projectConfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base,); mainGroup = {uid("mainGroup")}; productRefGroup = {uid("productsGroup")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("appTarget")}, {uid("testsTarget")},);')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + f'\n\t}};\n\trootObject = {uid("project")};\n}}\n')
scheme = project/'xcshareddata/xcschemes/AdaptiveTouch.xcscheme'
scheme.parent.mkdir(parents=True,exist_ok=True)
scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('appTarget')}" BuildableName="AdaptiveTouch.app" BlueprintName="AdaptiveTouch" ReferencedContainer="container:AdaptiveTouch.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('testsTarget')}" BuildableName="AdaptiveTouchTests.xctest" BlueprintName="AdaptiveTouchTests" ReferencedContainer="container:AdaptiveTouch.xcodeproj"/></TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('appTarget')}" BuildableName="AdaptiveTouch.app" BlueprintName="AdaptiveTouch" ReferencedContainer="container:AdaptiveTouch.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('appTarget')}" BuildableName="AdaptiveTouch.app" BlueprintName="AdaptiveTouch" ReferencedContainer="container:AdaptiveTouch.xcodeproj"/></BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(f'Generated project with {len(app)} app files and {len(tests)} test files')
