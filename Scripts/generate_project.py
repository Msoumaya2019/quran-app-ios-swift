#!/usr/bin/env python3
"""Generate a real, deterministic Xcode project without a macOS-only generator."""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parent.parent
objects={}
def uid(label):return hashlib.sha1(label.encode()).hexdigest()[:24].upper()
def add(label,isa,**values):
 i=uid(label);objects[i]={'isa':isa,**values};return i
project=uid('project'); app=uid('target:CoranNative')
products=[];refs=[];targets=[]
package=add('Supabase','XCRemoteSwiftPackageReference',repositoryURL='https://github.com/supabase/supabase-swift.git',requirement={'kind':'exactVersion','version':'2.33.1'})
packageProduct=add('SupabaseProduct','XCSwiftPackageProductDependency',package=package,productName='Supabase')
for name,kind,folders in [('CoranNative','application',['App','Core','Models','Features','Components','Services','Repositories','Networking','Storage']),('CoranNativeTests','bundle.unit-test',['Tests']),('CoranNativeUITests','bundle.ui-testing',['UITests'])]:
 buildfiles=[]
 for folder in folders:
  for file in sorted((root/folder).rglob('*.swift')):
   path=file.relative_to(root).as_posix();ref=add('file:'+path,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=path,sourceTree='<group>');refs.append(ref);buildfiles.append(add('build:'+path,'PBXBuildFile',fileRef=ref))
 source=add('sources:'+name,'PBXSourcesBuildPhase',buildActionMask='2147483647',files=buildfiles,runOnlyForDeploymentPostprocessing='0')
 frameworks=[];resourcefiles=[];dependencies=[];phases=[source]
 if name=='CoranNative':
  frameworks=[add('SupabaseFramework','PBXBuildFile',productRef=packageProduct)]
  for path,ft in [('Resources/Assets.xcassets','folder.assetcatalog'),('Resources/quran-meta.json','text.json'),('Resources/quran-pages.json','text.json'),('Resources/Backend.plist','text.plist.xml')]:
   ref=add('file:'+path,'PBXFileReference',lastKnownFileType=ft,path=path,sourceTree='<group>');refs.append(ref);resourcefiles.append(add('build:'+path,'PBXBuildFile',fileRef=ref))
 else:
  proxy=add('proxy:'+name,'PBXContainerItemProxy',containerPortal=project,proxyType='1',remoteGlobalIDString=app,remoteInfo='CoranNative');dependencies=[add('dep:'+name,'PBXTargetDependency',target=app,targetProxy=proxy)]
 phases.append(add('frameworks:'+name,'PBXFrameworksBuildPhase',buildActionMask='2147483647',files=frameworks,runOnlyForDeploymentPostprocessing='0'))
 phases.append(add('resources:'+name,'PBXResourcesBuildPhase',buildActionMask='2147483647',files=resourcefiles,runOnlyForDeploymentPostprocessing='0'))
 if name=='CoranNative':
  phases.append(add('config-script','PBXShellScriptBuildPhase',buildActionMask='2147483647',files=[],inputPaths=[],outputPaths=[],runOnlyForDeploymentPostprocessing='0',shellPath='/bin/sh',shellScript='if [ -f "$SRCROOT/Resources/Backend.local.plist" ]; then\n  cp "$SRCROOT/Resources/Backend.local.plist" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/Backend.local.plist"\nfi\n',name='Inject local backend configuration',alwaysOutOfDate='1'))
 configurations=[]
 for config in ['Debug','Release']:
  settings={'PRODUCT_NAME':name,'PRODUCT_BUNDLE_IDENTIFIER':'com.coranmemoire.native.'+('ios' if name=='CoranNative' else name),'SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','GENERATE_INFOPLIST_FILE':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if config=='Debug' else '', 'ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO','ONLY_ACTIVE_ARCH':'YES' if config=='Debug' else 'NO'}
  if name=='CoranNative':settings.update({'INFOPLIST_FILE':'Config/Info.plist','MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1','ENABLE_USER_SCRIPT_SANDBOXING':'NO','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks']})
  elif name=='CoranNativeTests':settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/CoranNative.app/CoranNative','BUNDLE_LOADER':'$(TEST_HOST)'})
  else:settings['TEST_TARGET_NAME']='CoranNative'
  configurations.append(add('config:'+name+config,'XCBuildConfiguration',name=config,buildSettings=settings))
 configlist=add('configs:'+name,'XCConfigurationList',buildConfigurations=configurations,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
 product=add('product:'+name,'PBXFileReference',explicitFileType='wrapper.application' if kind=='application' else 'wrapper.cfbundle',includeInIndex='0',path=name+('.app' if kind=='application' else '.xctest'),sourceTree='BUILT_PRODUCTS_DIR');products.append(product)
 targets.append(add('target:'+name,'PBXNativeTarget',buildConfigurationList=configlist,buildPhases=phases,buildRules=[],dependencies=dependencies,name=name,productName=name,productReference=product,productType='com.apple.product-type.'+kind,packageProductDependencies=[packageProduct] if name=='CoranNative' else []))
productGroup=add('Products','PBXGroup',children=products,name='Products',sourceTree='<group>')
mainGroup=add('rootgroup','PBXGroup',children=refs+[productGroup],sourceTree='<group>')
configs=[add('projectconfig:'+name,'XCBuildConfiguration',name=name,buildSettings={'SDKROOT':'iphoneos','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'}) for name in ['Debug','Release']]
projectConfig=add('projectconfigs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
add('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1600'},buildConfigurationList=projectConfig,compatibilityVersion='Xcode 14.0',developmentRegion='fr',hasScannedForEncodings='0',knownRegions=['fr','en','Base'],mainGroup=mainGroup,productRefGroup=productGroup,projectDirPath='',projectRoot='',targets=targets,packageReferences=[package])
def encode(v,indent=0):
 if isinstance(v,dict):return '{\n'+''.join('  '*(indent+1)+json.dumps(str(k))+ ' = '+encode(value,indent+1)+';\n' for k,value in v.items())+'  '*indent+'}'
 if isinstance(v,list):return '('+','.join(encode(x,indent) for x in v)+')'
 return json.dumps(v,ensure_ascii=False)
pbx='// !$*UTF8*$!\n'+encode({'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':project})+'\n'
dir=root/'CoranNative.xcodeproj';dir.mkdir(exist_ok=True)
if '--check' in sys.argv:
 assert (dir/'project.pbxproj').read_text(encoding='utf-8')==pbx,'Regenerate Xcode project after changing sources'
else:(dir/'project.pbxproj').write_text(pbx,encoding='utf-8',newline='\n')
schemeDir=dir/'xcshareddata/xcschemes';schemeDir.mkdir(parents=True,exist_ok=True)
def buildref(name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{name}.{ "app" if name=="CoranNative" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:CoranNative.xcodeproj"/>'
scheme=f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildref('CoranNative')}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES" codeCoverageEnabled="YES"><Testables><TestableReference skipped="NO">{buildref('CoranNativeTests')}</TestableReference><TestableReference skipped="NO">{buildref('CoranNativeUITests')}</TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('CoranNative')}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('CoranNative')}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
"""
(schemeDir/'CoranNative.xcscheme').write_text(scheme,encoding='utf-8')
print('Xcode project validated' if '--check' in sys.argv else 'Xcode project generated')
