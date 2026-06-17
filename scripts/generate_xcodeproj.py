#!/usr/bin/env python3
"""Generate MQUP.xcodeproj for the iOS demo app."""

from __future__ import annotations

import pathlib
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT_DIR = ROOT / "MQUP.xcodeproj"
APP_DIR = ROOT / "MQUPApp"

SOURCE_FILES = [
    "MQUPApp.swift",
    "AppModel.swift",
    "ContentView.swift",
    "UI/SearchResultsScreen.swift",
    "UI/ResultRow.swift",
    "UI/NavigationLauncher.swift",
    "Intents/SearchPlacesIntent.swift",
    "Services/POIService.swift",
]

def uid() -> str:
    return uuid.uuid4().hex[:24].upper()


def main() -> None:
    project_id = uid()
    target_id = uid()
    build_config_list = uid()
    debug_config = uid()
    release_config = uid()
    project_config_list = uid()
    package_ref = uid()
    package_product = uid()
    framework_build = uid()
    sources_phase = uid()
    resources_phase = uid()
    product_ref = uid()
    app_group = uid()

    file_refs = {}
    build_files = {}
    for rel in SOURCE_FILES:
        file_id = uid()
        build_id = uid()
        file_refs[rel] = (file_id, build_id)

    pois_file = uid()
    pois_build = uid()
    plist_ref = uid()
    entitlements_ref = uid()

    pbx = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{}};
\tobjectVersion = 60;
\tobjects = {{

/* Begin PBXBuildFile section */
"""
    for rel, (_, build_id) in file_refs.items():
        file_id = file_refs[rel][0]
        pbx += f"\t\t{build_id} /* {pathlib.Path(rel).name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {pathlib.Path(rel).name} */; }};\n"
    pbx += f"\t\t{pois_build} /* pois.json in Resources */ = {{isa = PBXBuildFile; fileRef = {pois_file} /* pois.json */; }};\n"
    pbx += f"\t\t{framework_build} /* MQUPEngine in Frameworks */ = {{isa = PBXBuildFile; productRef = {package_product} /* MQUPEngine */; }};\n"
    pbx += """/* End PBXBuildFile section */

/* Begin PBXFileReference section */
"""
    pbx += f"\t\t{product_ref} /* MQUP.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MQUP.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
    for rel, (file_id, _) in file_refs.items():
        pbx += f"\t\t{file_id} /* {pathlib.Path(rel).name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {rel}; sourceTree = \"<group>\"; }};\n"
    pbx += f"\t\t{pois_file} /* pois.json */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = pois.json; sourceTree = \"<group>\"; }};\n"
    pbx += f"\t\t{plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n"
    pbx += f"\t\t{entitlements_ref} /* MQUP.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = MQUP.entitlements; sourceTree = \"<group>\"; }};\n"
    pbx += f"""/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{uid()} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{framework_build} /* MQUPEngine in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{app_group} /* MQUPApp */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
"""
    for rel, (file_id, _) in file_refs.items():
        pbx += f"\t\t\t\t{file_id} /* {pathlib.Path(rel).name} */,\n"
    pbx += f"\t\t\t\t{pois_file} /* pois.json */,\n"
    pbx += f"\t\t\t\t{plist_ref} /* Info.plist */,\n"
    pbx += f"\t\t\t\t{entitlements_ref} /* MQUP.entitlements */,\n"
    pbx += f"""\t\t\t);
\t\t\tpath = MQUPApp;
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{uid()} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{product_ref} /* MQUP.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{uid()} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_group} /* MQUPApp */,
\t\t\t\t{uid()} /* Products */,
\t\t\t);
\t\t\tsourceTree = \"<group>\";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_id} /* MQUP */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {build_config_list} /* Build configuration list for PBXNativeTarget \"MQUP\" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase} /* Sources */,
\t\t\t\t{resources_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = MQUP;
\t\t\tpackageProductDependencies = (
\t\t\t\t{package_product} /* MQUPEngine */,
\t\t\t);
\t\t\tproductName = MQUP;
\t\t\tproductReference = {product_ref} /* MQUP.app */;
\t\t\tproductType = \"com.apple.product-type.application\";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{project_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1540;
\t\t\t\tLastUpgradeCheck = 1540;
\t\t\t}};
\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"MQUP\" */;
\t\t\tcompatibilityVersion = \"Xcode 15.0\";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {uid()};
\t\t\tpackageReferences = (
\t\t\t\t{package_ref} /* XCLocalSwiftPackageReference */,
\t\t\t);
\t\t\tproductRefGroup = {uid()} /* Products */;
\t\t\tprojectDirPath = \"\";
\t\t\tprojectRoot = \"\";
\t\t\ttargets = (
\t\t\t\t{target_id} /* MQUP */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{pois_build} /* pois.json in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
"""
    for rel, (_, build_id) in file_refs.items():
        pbx += f"\t\t\t\t{build_id} /* {pathlib.Path(rel).name} in Sources */,\n"
    pbx += f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{debug_config} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MQUPApp/MQUP.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = \"\";
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = MQUPApp/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/Frameworks\";
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.marcospolanco.mqup;
\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.9;
\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{release_config} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MQUPApp/MQUP.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = \"\";
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = MQUPApp/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/Frameworks\";
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.marcospolanco.mqup;
\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.9;
\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{uid()} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{uid()} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{build_config_list} /* Build configuration list for PBXNativeTarget \"MQUP\" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_config} /* Debug */,
\t\t\t\t{release_config} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{project_config_list} /* Build configuration list for PBXProject \"MQUP\" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uid()} /* Debug */,
\t\t\t\t{uid()} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
\t\t{package_ref} /* XCLocalSwiftPackageReference */ = {{
\t\t\tisa = XCLocalSwiftPackageReference;
\t\t\trelativePath = .;
\t\t}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
\t\t{package_product} /* MQUPEngine */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tproductName = MQUPEngine;
\t\t}};
/* End XCSwiftPackageProductDependency section */
\t}};
\trootObject = {project_id} /* Project object */;
}}
"""
    PROJECT_DIR.mkdir(parents=True, exist_ok=True)
    (PROJECT_DIR / "project.pbxproj").write_text(pbx)
    print(f"Wrote {PROJECT_DIR / 'project.pbxproj'}")


if __name__ == "__main__":
    main()
