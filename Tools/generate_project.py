#!/usr/bin/env python3
"""
Generates PassportProof.xcodeproj/project.pbxproj from the contents of
PassportProof/, PassportProofTests/ and PassportProofUITests/.

Why a generator instead of a checked-in binary-ish project file: the project is
authored on Windows, where Xcode cannot open or validate it. Generating from the
directory tree removes the entire class of bug where a source file exists on disk
but was never added to the target -- a failure that only shows up as a link error
in CI, twenty minutes later.

Run:  python3 Tools/generate_project.py
"""

from __future__ import annotations

import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

APP_NAME = "PassportProof"
TEST_NAME = "PassportProofTests"
UI_TEST_NAME = "PassportProofUITests"
APP_DIR = "PassportProof"
TEST_DIR = "PassportProofTests"
UI_TEST_DIR = "PassportProofUITests"
BUNDLE_ID = "com.passportproof.app"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"
MARKETING_VERSION = "1.1.0"
BUILD_NUMBER = "2"

TAB = "\t"


def uid(*parts: str) -> str:
    """Deterministic 24-char hex identifier, stable across runs."""
    digest = hashlib.md5("::".join(parts).encode("utf-8")).hexdigest()
    return digest[:24].upper()


def walk(root_rel: str):
    """Return (relative_dirs, swift_files, resource_bundles) under root_rel."""
    dirs: list[str] = []
    swift: list[str] = []
    assets: list[str] = []
    abs_root = os.path.join(ROOT, root_rel)
    for dirpath, dirnames, filenames in os.walk(abs_root):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
        rel_dir = os.path.relpath(dirpath, ROOT).replace("\\", "/")
        if rel_dir != root_rel:
            dirs.append(rel_dir)
        # A .xcassets directory is a bundle: record it, do not descend.
        for d in list(dirnames):
            if d.endswith(".xcassets"):
                assets.append(f"{rel_dir}/{d}")
                dirnames.remove(d)
        for f in sorted(filenames):
            if f.endswith(".swift"):
                swift.append(f"{rel_dir}/{f}")
            elif f.endswith(".xcprivacy"):
                # The privacy manifest is a compiled-in resource, not a source.
                assets.append(f"{rel_dir}/{f}")
    return sorted(dirs), sorted(swift), sorted(assets)


def file_type(path: str) -> str:
    if path.endswith(".swift"):
        return "sourcecode.swift"
    if path.endswith(".xcassets"):
        return "folder.assetcatalog"
    if path.endswith(".plist"):
        return "text.plist.xml"
    if path.endswith(".xcprivacy"):
        return "text.xml"
    return "text"


def build_tree(paths: list[str], base: str) -> dict:
    """Nested dict describing the group hierarchy."""
    tree: dict = {"name": os.path.basename(base), "path": base, "children": {}}
    for p in paths:
        rel = os.path.relpath(p, base).replace("\\", "/")
        parts = rel.split("/")
        node = tree
        for i, part in enumerate(parts[:-1]):
            node = node["children"].setdefault(
                "/".join(parts[: i + 1]),
                {"name": part, "path": part, "children": {}},
            )
        node["children"][rel] = {"name": parts[-1], "path": parts[-1], "leaf": p}
    return tree


def emit_groups(tree: dict, lines: list[str], key_prefix: str, node_key: str) -> str:
    # node_key is the full path relative to the target root ("Core/Export"), not
    # the bare directory name, so two directories that share a basename in
    # different parents (Core/Export vs Features/Export) get distinct ids.
    gid = uid("group", key_prefix, node_key)
    lines.append(f"\t\t{gid} /* {tree['name']} */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for key in sorted(tree["children"]):
        child = tree["children"][key]
        if "leaf" in child:
            lines.append(f"\t\t\t\t{uid('file', child['leaf'])} /* {child['name']} */,")
        else:
            lines.append(f"\t\t\t\t{uid('group', key_prefix, key)} /* {child['name']} */,")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tpath = {tree['path']};")
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append("\t\t};")
    for key in sorted(tree["children"]):
        child = tree["children"][key]
        if "leaf" not in child:
            emit_groups(child, lines, key_prefix, key)
    return gid


def main() -> int:
    app_dirs, app_swift, app_assets = walk(APP_DIR)
    _, test_swift, test_assets = walk(TEST_DIR)
    _, ui_test_swift, ui_test_assets = walk(UI_TEST_DIR)

    if not app_swift:
        print("error: no Swift sources found under", APP_DIR, file=sys.stderr)
        return 1

    # One canonical configuration is copied only into the two test bundles.
    shared_test_resources = ["StoreKit/PassportProof.storekit"]

    app_target = uid("target", APP_NAME)
    test_target = uid("target", TEST_NAME)
    ui_test_target = uid("target", UI_TEST_NAME)
    project_obj = uid("project", APP_NAME)

    app_sources_phase = uid("phase", APP_NAME, "sources")
    app_frameworks_phase = uid("phase", APP_NAME, "frameworks")
    app_resources_phase = uid("phase", APP_NAME, "resources")
    test_sources_phase = uid("phase", TEST_NAME, "sources")
    test_frameworks_phase = uid("phase", TEST_NAME, "frameworks")
    test_resources_phase = uid("phase", TEST_NAME, "resources")
    ui_test_sources_phase = uid("phase", UI_TEST_NAME, "sources")
    ui_test_frameworks_phase = uid("phase", UI_TEST_NAME, "frameworks")
    ui_test_resources_phase = uid("phase", UI_TEST_NAME, "resources")

    app_product = uid("product", APP_NAME)
    test_product = uid("product", TEST_NAME)
    ui_test_product = uid("product", UI_TEST_NAME)
    products_group = uid("group", "Products")

    main_group = uid("group", "main")

    app_cfg_list = uid("cfglist", APP_NAME)
    test_cfg_list = uid("cfglist", TEST_NAME)
    ui_test_cfg_list = uid("cfglist", UI_TEST_NAME)
    proj_cfg_list = uid("cfglist", "project")

    out: list[str] = []
    w = out.append

    w("// !$*UTF8*$!")
    w("{")
    w(f"{TAB}archiveVersion = 1;")
    w(f"{TAB}classes = {{")
    w(f"{TAB}}};")
    w(f"{TAB}objectVersion = 56;")
    w(f"{TAB}objects = {{")

    # ---------------------------------------------------------------- build files
    w("")
    w("/* Begin PBXBuildFile section */")
    for p in app_swift:
        w(
            f"\t\t{uid('build', p)} /* {os.path.basename(p)} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file', p)} /* {os.path.basename(p)} */; }};"
        )
    for p in app_assets:
        w(
            f"\t\t{uid('build', p)} /* {os.path.basename(p)} in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file', p)} /* {os.path.basename(p)} */; }};"
        )
    for p in test_swift:
        w(
            f"\t\t{uid('build', p)} /* {os.path.basename(p)} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file', p)} /* {os.path.basename(p)} */; }};"
        )
    for p in test_assets:
        w(
            f"\t\t{uid('build', p)} /* {os.path.basename(p)} in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file', p)} /* {os.path.basename(p)} */; }};"
        )
    for p in ui_test_swift:
        w(
            f"\t\t{uid('build', p)} /* {os.path.basename(p)} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file', p)} /* {os.path.basename(p)} */; }};"
        )
    for p in ui_test_assets:
        w(
            f"\t\t{uid('build', p)} /* {os.path.basename(p)} in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file', p)} /* {os.path.basename(p)} */; }};"
        )
    for target_name in (TEST_NAME, UI_TEST_NAME):
        for p in shared_test_resources:
            w(f"\t\t{uid('shared-resource', target_name, p)} /* {os.path.basename(p)} in Resources */ = "
              f"{{isa = PBXBuildFile; fileRef = {uid('file', p)} /* {os.path.basename(p)} */; }};")
    w("/* End PBXBuildFile section */")

    # ------------------------------------------------------------ container proxy
    w("")
    w("/* Begin PBXContainerItemProxy section */")
    for target_name in (TEST_NAME, UI_TEST_NAME):
        w(f"\t\t{uid('proxy', target_name)} /* PBXContainerItemProxy */ = {{")
        w(f"{TAB}{TAB}{TAB}isa = PBXContainerItemProxy;")
        w(f"{TAB}{TAB}{TAB}containerPortal = {project_obj} /* Project object */;")
        w(f"{TAB}{TAB}{TAB}proxyType = 1;")
        w(f"{TAB}{TAB}{TAB}remoteGlobalIDString = {app_target};")
        w(f"{TAB}{TAB}{TAB}remoteInfo = {APP_NAME};")
        w(f"{TAB}{TAB}}};")
    w("/* End PBXContainerItemProxy section */")

    # -------------------------------------------------------------- file refs
    w("")
    w("/* Begin PBXFileReference section */")
    w(
        f"\t\t{app_product} /* {APP_NAME}.app */ = {{isa = PBXFileReference; "
        f"explicitFileType = wrapper.application; includeInIndex = 0; "
        f"path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    w(
        f"\t\t{test_product} /* {TEST_NAME}.xctest */ = {{isa = PBXFileReference; "
        f"explicitFileType = wrapper.cfbundle; includeInIndex = 0; "
        f"path = {TEST_NAME}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    w(
        f"\t\t{ui_test_product} /* {UI_TEST_NAME}.xctest */ = {{isa = PBXFileReference; "
        f"explicitFileType = wrapper.cfbundle; includeInIndex = 0; "
        f"path = {UI_TEST_NAME}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    for p in app_swift + test_swift + ui_test_swift + app_assets + test_assets + ui_test_assets:
        w(
            f"\t\t{uid('file', p)} /* {os.path.basename(p)} */ = {{isa = PBXFileReference; "
            f"lastKnownFileType = {file_type(p)}; path = {os.path.basename(p)}; "
            f'sourceTree = "<group>"; }};'
        )
    for p in shared_test_resources:
        w(f"\t\t{uid('file', p)} /* {os.path.basename(p)} */ = {{isa = PBXFileReference; "
          f'lastKnownFileType = text; path = "{p}"; sourceTree = SOURCE_ROOT; }};')
    w("/* End PBXFileReference section */")

    # -------------------------------------------------------------- frameworks
    w("")
    w("/* Begin PBXFrameworksBuildPhase section */")
    for phase, label in (
        (app_frameworks_phase, APP_NAME),
        (test_frameworks_phase, TEST_NAME),
        (ui_test_frameworks_phase, UI_TEST_NAME),
    ):
        w(f"\t\t{phase} /* Frameworks */ = {{")
        w(f"{TAB}{TAB}{TAB}isa = PBXFrameworksBuildPhase;")
        w(f"{TAB}{TAB}{TAB}buildActionMask = 2147483647;")
        w(f"{TAB}{TAB}{TAB}files = (")
        w(f"{TAB}{TAB}{TAB});")
        w(f"{TAB}{TAB}{TAB}runOnlyForDeploymentPostprocessing = 0;")
        w(f"{TAB}{TAB}}};")
    w("/* End PBXFrameworksBuildPhase section */")

    # ------------------------------------------------------------------ groups
    w("")
    w("/* Begin PBXGroup section */")
    app_tree = build_tree(app_swift + app_assets, APP_DIR)
    test_tree = build_tree(test_swift + test_assets, TEST_DIR) if (test_swift or test_assets) else None
    ui_test_tree = build_tree(ui_test_swift + ui_test_assets, UI_TEST_DIR) if (ui_test_swift or ui_test_assets) else None

    w(f"\t\t{main_group} = {{")
    w(f"{TAB}{TAB}{TAB}isa = PBXGroup;")
    w(f"{TAB}{TAB}{TAB}children = (")
    w(f"{TAB}{TAB}{TAB}{TAB}{uid('group', 'app', APP_DIR)} /* {APP_DIR} */,")
    if test_tree:
        w(f"{TAB}{TAB}{TAB}{TAB}{uid('group', 'test', TEST_DIR)} /* {TEST_DIR} */,")
    if ui_test_tree:
        w(f"{TAB}{TAB}{TAB}{TAB}{uid('group', 'uitest', UI_TEST_DIR)} /* {UI_TEST_DIR} */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{uid('group', 'Tools', 'Tools')} /* Tools */,")
    for p in shared_test_resources:
        w(f"{TAB}{TAB}{TAB}{TAB}{uid('file', p)} /* {os.path.basename(p)} */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{products_group} /* Products */,")
    w(f"{TAB}{TAB}{TAB});")
    w(f'{TAB}{TAB}{TAB}sourceTree = "<group>";')
    w(f"{TAB}{TAB}}};")

    # Tools group (the generator itself, so it is visible in Xcode)
    w(f"\t\t{uid('group', 'Tools', 'Tools')} /* Tools */ = {{")
    w(f"{TAB}{TAB}{TAB}isa = PBXGroup;")
    w(f"{TAB}{TAB}{TAB}children = (")
    w(f"{TAB}{TAB}{TAB}{TAB}{uid('file', 'Tools/generate_project.py')} /* generate_project.py */,")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}path = Tools;")
    w(f'{TAB}{TAB}{TAB}sourceTree = "<group>";')
    w(f"{TAB}{TAB}}};")
    w(
        f"\t\t{uid('file', 'Tools/generate_project.py')} /* generate_project.py */ = "
        f'{{isa = PBXFileReference; lastKnownFileType = text.script.python; '
        f'path = generate_project.py; sourceTree = "<group>"; }};'
    )

    # Rename the app root group id to a stable key
    app_group_id = emit_groups(app_tree, out, "app", APP_DIR)
    # emit_groups derives its id from ("group", key_prefix, relative path)
    if test_tree:
        emit_groups(test_tree, out, "test", TEST_DIR)
    if ui_test_tree:
        emit_groups(ui_test_tree, out, "uitest", UI_TEST_DIR)

    w(f"\t\t{products_group} /* Products */ = {{")
    w(f"{TAB}{TAB}{TAB}isa = PBXGroup;")
    w(f"{TAB}{TAB}{TAB}children = (")
    w(f"{TAB}{TAB}{TAB}{TAB}{app_product} /* {APP_NAME}.app */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{test_product} /* {TEST_NAME}.xctest */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{ui_test_product} /* {UI_TEST_NAME}.xctest */,")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}name = Products;")
    w(f'{TAB}{TAB}{TAB}sourceTree = "<group>";')
    w(f"{TAB}{TAB}}};")
    w("/* End PBXGroup section */")

    # ------------------------------------------------------------ native targets
    w("")
    w("/* Begin PBXNativeTarget section */")
    w(f"\t\t{app_target} /* {APP_NAME} */ = {{")
    w(f"{TAB}{TAB}{TAB}isa = PBXNativeTarget;")
    w(f"{TAB}{TAB}{TAB}buildConfigurationList = {app_cfg_list};")
    w(f"{TAB}{TAB}{TAB}buildPhases = (")
    w(f"{TAB}{TAB}{TAB}{TAB}{app_sources_phase} /* Sources */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{app_frameworks_phase} /* Frameworks */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{app_resources_phase} /* Resources */,")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}buildRules = (")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}dependencies = (")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}name = {APP_NAME};")
    w(f"{TAB}{TAB}{TAB}productName = {APP_NAME};")
    w(f"{TAB}{TAB}{TAB}productReference = {app_product} /* {APP_NAME}.app */;")
    w(f'{TAB}{TAB}{TAB}productType = "com.apple.product-type.application";')
    w(f"{TAB}{TAB}}};")

    w(f"\t\t{test_target} /* {TEST_NAME} */ = {{")
    w(f"{TAB}{TAB}{TAB}isa = PBXNativeTarget;")
    w(f"{TAB}{TAB}{TAB}buildConfigurationList = {test_cfg_list};")
    w(f"{TAB}{TAB}{TAB}buildPhases = (")
    w(f"{TAB}{TAB}{TAB}{TAB}{test_sources_phase} /* Sources */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{test_frameworks_phase} /* Frameworks */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{test_resources_phase} /* Resources */,")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}buildRules = (")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}dependencies = (")
    w(f"{TAB}{TAB}{TAB}{TAB}{uid('dep', TEST_NAME)} /* PBXTargetDependency */,")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}name = {TEST_NAME};")
    w(f"{TAB}{TAB}{TAB}productName = {TEST_NAME};")
    w(f"{TAB}{TAB}{TAB}productReference = {test_product} /* {TEST_NAME}.xctest */;")
    w(f'{TAB}{TAB}{TAB}productType = "com.apple.product-type.bundle.unit-test";')
    w(f"{TAB}{TAB}}};")

    w(f"\t\t{ui_test_target} /* {UI_TEST_NAME} */ = {{")
    w(f"{TAB}{TAB}{TAB}isa = PBXNativeTarget;")
    w(f"{TAB}{TAB}{TAB}buildConfigurationList = {ui_test_cfg_list};")
    w(f"{TAB}{TAB}{TAB}buildPhases = (")
    w(f"{TAB}{TAB}{TAB}{TAB}{ui_test_sources_phase} /* Sources */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{ui_test_frameworks_phase} /* Frameworks */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{ui_test_resources_phase} /* Resources */,")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}buildRules = (")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}dependencies = (")
    w(f"{TAB}{TAB}{TAB}{TAB}{uid('dep', UI_TEST_NAME)} /* PBXTargetDependency */,")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}name = {UI_TEST_NAME};")
    w(f"{TAB}{TAB}{TAB}productName = {UI_TEST_NAME};")
    w(f"{TAB}{TAB}{TAB}productReference = {ui_test_product} /* {UI_TEST_NAME}.xctest */;")
    w(f'{TAB}{TAB}{TAB}productType = "com.apple.product-type.bundle.ui-testing";')
    w(f"{TAB}{TAB}}};")
    w("/* End PBXNativeTarget section */")

    # ------------------------------------------------------------------ project
    w("")
    w("/* Begin PBXProject section */")
    w(f"\t\t{project_obj} /* Project object */ = {{")
    w(f"{TAB}{TAB}{TAB}isa = PBXProject;")
    w(f"{TAB}{TAB}{TAB}attributes = {{")
    w(f"{TAB}{TAB}{TAB}{TAB}BuildIndependentTargetsInParallel = 1;")
    w(f"{TAB}{TAB}{TAB}{TAB}LastSwiftUpdateCheck = 1600;")
    w(f"{TAB}{TAB}{TAB}{TAB}LastUpgradeCheck = 1600;")
    w(f"{TAB}{TAB}{TAB}{TAB}TargetAttributes = {{")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}{app_target} = {{")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}{TAB}CreatedOnToolsVersion = 16.0;")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}}};")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}{test_target} = {{")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}{TAB}CreatedOnToolsVersion = 16.0;")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}{TAB}TestTargetID = {app_target};")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}}};")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}{ui_test_target} = {{")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}{TAB}CreatedOnToolsVersion = 16.0;")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}{TAB}TestTargetID = {app_target};")
    w(f"{TAB}{TAB}{TAB}{TAB}{TAB}}};")
    w(f"{TAB}{TAB}{TAB}{TAB}}};")
    w(f"{TAB}{TAB}{TAB}}};")
    w(f"{TAB}{TAB}{TAB}buildConfigurationList = {proj_cfg_list};")
    w(f'{TAB}{TAB}{TAB}compatibilityVersion = "Xcode 14.0";')
    w(f"{TAB}{TAB}{TAB}developmentRegion = en;")
    w(f"{TAB}{TAB}{TAB}hasScannedForEncodings = 0;")
    w(f"{TAB}{TAB}{TAB}knownRegions = (")
    w(f"{TAB}{TAB}{TAB}{TAB}en,")
    w(f"{TAB}{TAB}{TAB}{TAB}Base,")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}{TAB}mainGroup = {main_group};")
    w(f"{TAB}{TAB}{TAB}productRefGroup = {products_group} /* Products */;")
    w(f'{TAB}{TAB}{TAB}projectDirPath = "";')
    w(f'{TAB}{TAB}{TAB}projectRoot = "";')
    w(f"{TAB}{TAB}{TAB}targets = (")
    w(f"{TAB}{TAB}{TAB}{TAB}{app_target} /* {APP_NAME} */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{test_target} /* {TEST_NAME} */,")
    w(f"{TAB}{TAB}{TAB}{TAB}{ui_test_target} /* {UI_TEST_NAME} */,")
    w(f"{TAB}{TAB}{TAB});")
    w(f"{TAB}{TAB}}};")
    w("/* End PBXProject section */")

    # ---------------------------------------------------------------- resources
    w("")
    w("/* Begin PBXResourcesBuildPhase section */")
    for phase, files in (
        (app_resources_phase, app_assets),
        (test_resources_phase, test_assets),
        (ui_test_resources_phase, ui_test_assets),
    ):
        w(f"\t\t{phase} /* Resources */ = {{")
        w(f"{TAB}{TAB}{TAB}isa = PBXResourcesBuildPhase;")
        w(f"{TAB}{TAB}{TAB}buildActionMask = 2147483647;")
        w(f"{TAB}{TAB}{TAB}files = (")
        for p in files:
            w(f"{TAB}{TAB}{TAB}{TAB}{uid('build', p)} /* {os.path.basename(p)} in Resources */,")
        target_name = TEST_NAME if phase == test_resources_phase else UI_TEST_NAME
        if phase != app_resources_phase:
            for p in shared_test_resources:
                w(f"{TAB}{TAB}{TAB}{TAB}{uid('shared-resource', target_name, p)} /* {os.path.basename(p)} in Resources */,")
        w(f"{TAB}{TAB}{TAB});")
        w(f"{TAB}{TAB}{TAB}runOnlyForDeploymentPostprocessing = 0;")
        w(f"{TAB}{TAB}}};")
    w("/* End PBXResourcesBuildPhase section */")

    # ------------------------------------------------------------------ sources
    w("")
    w("/* Begin PBXSourcesBuildPhase section */")
    for phase, files in (
        (app_sources_phase, app_swift),
        (test_sources_phase, test_swift),
        (ui_test_sources_phase, ui_test_swift),
    ):
        w(f"\t\t{phase} /* Sources */ = {{")
        w(f"{TAB}{TAB}{TAB}isa = PBXSourcesBuildPhase;")
        w(f"{TAB}{TAB}{TAB}buildActionMask = 2147483647;")
        w(f"{TAB}{TAB}{TAB}files = (")
        for p in files:
            w(f"{TAB}{TAB}{TAB}{TAB}{uid('build', p)} /* {os.path.basename(p)} in Sources */,")
        w(f"{TAB}{TAB}{TAB});")
        w(f"{TAB}{TAB}{TAB}runOnlyForDeploymentPostprocessing = 0;")
        w(f"{TAB}{TAB}}};")
    w("/* End PBXSourcesBuildPhase section */")

    # ------------------------------------------------------------------ targets
    w("")
    w("/* Begin PBXTargetDependency section */")
    for target_name in (TEST_NAME, UI_TEST_NAME):
        w(f"\t\t{uid('dep', target_name)} /* PBXTargetDependency */ = {{")
        w(f"{TAB}{TAB}{TAB}isa = PBXTargetDependency;")
        w(f"{TAB}{TAB}{TAB}target = {app_target} /* {APP_NAME} */;")
        w(f"{TAB}{TAB}{TAB}targetProxy = {uid('proxy', target_name)} /* PBXContainerItemProxy */;")
        w(f"{TAB}{TAB}}};")
    w("/* End PBXTargetDependency section */")

    # ----------------------------------------------------------- configurations
    project_common = [
        "ALWAYS_SEARCH_USER_PATHS = NO;",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;",
        "CLANG_ANALYZER_NONNULL = YES;",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;",
        "CLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";",
        "CLANG_ENABLE_MODULES = YES;",
        "CLANG_ENABLE_OBJC_ARC = YES;",
        "CLANG_ENABLE_OBJC_WEAK = YES;",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;",
        "CLANG_WARN_BOOL_CONVERSION = YES;",
        "CLANG_WARN_COMMA = YES;",
        "CLANG_WARN_CONSTANT_CONVERSION = YES;",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;",
        "CLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
        "CLANG_WARN_EMPTY_BODY = YES;",
        "CLANG_WARN_ENUM_CONVERSION = YES;",
        "CLANG_WARN_INFINITE_RECURSION = YES;",
        "CLANG_WARN_INT_CONVERSION = YES;",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;",
        "CLANG_WARN_STRICT_PROTOTYPES = YES;",
        "CLANG_WARN_SUSPICIOUS_MOVE = YES;",
        "CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;",
        "CLANG_WARN_UNREACHABLE_CODE = YES;",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;",
        "COPY_PHASE_STRIP = NO;",
        "ENABLE_STRICT_OBJC_MSGSEND = YES;",
        "ENABLE_USER_SCRIPT_SANDBOXING = YES;",
        "GCC_C_LANGUAGE_STANDARD = gnu17;",
        "GCC_NO_COMMON_BLOCKS = YES;",
        "GCC_WARN_64_TO_32_BIT_CONVERSION = YES;",
        "GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;",
        "GCC_WARN_UNDECLARED_SELECTOR = YES;",
        "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
        "GCC_WARN_UNUSED_FUNCTION = YES;",
        "GCC_WARN_UNUSED_VARIABLE = YES;",
        f'IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};',
        "LOCALIZATION_PREFERS_STRING_CATALOGS = YES;",
        "MTL_FAST_MATH = YES;",
        "SDKROOT = iphoneos;",
        f"SWIFT_VERSION = {SWIFT_VERSION};",
    ]
    project_debug = [
        "DEBUG_INFORMATION_FORMAT = dwarf;",
        "ENABLE_TESTABILITY = YES;",
        "GCC_DYNAMIC_NO_PIC = NO;",
        "GCC_OPTIMIZATION_LEVEL = 0;",
        "GCC_PREPROCESSOR_DEFINITIONS = (",
        f'{TAB}{TAB}{TAB}{TAB}{TAB}"DEBUG=1",',
        f'{TAB}{TAB}{TAB}{TAB}{TAB}"$(inherited)",',
        f"{TAB}{TAB}{TAB}{TAB});",
        "MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;",
        "ONLY_ACTIVE_ARCH = YES;",
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";',
        'SWIFT_OPTIMIZATION_LEVEL = "-Onone";',
    ]
    project_release = [
        'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";',
        "ENABLE_NS_ASSERTIONS = NO;",
        "MTL_ENABLE_DEBUG_INFO = NO;",
        'SWIFT_COMPILATION_MODE = wholemodule;',
        "VALIDATE_PRODUCT = YES;",
    ]

    def config_block(cid: str, name: str, settings: list[str]) -> None:
        w(f"\t\t{cid} /* {name} */ = {{")
        w(f"{TAB}{TAB}{TAB}isa = XCBuildConfiguration;")
        w(f"{TAB}{TAB}{TAB}buildSettings = {{")
        for line in settings:
            w(f"{TAB}{TAB}{TAB}{TAB}{line}")
        w(f"{TAB}{TAB}{TAB}}};")
        w(f"{TAB}{TAB}{TAB}name = {name};")
        w(f"{TAB}{TAB}}};")

    app_settings = [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
        "CODE_SIGN_STYLE = Automatic;",
        f"CURRENT_PROJECT_VERSION = {BUILD_NUMBER};",
        "ENABLE_PREVIEWS = YES;",
        # The Info.plist is explicit and checked in (PassportProof/Resources/Info.plist):
        # launch screen, privacy descriptions and the export-compliance answer are
        # auditable in review rather than assembled from INFOPLIST_KEY_* at build time.
        "GENERATE_INFOPLIST_FILE = NO;",
        f'INFOPLIST_FILE = "{APP_DIR}/Resources/Info.plist";',
        f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};",
        'LD_RUNPATH_SEARCH_PATHS = (',
        f'{TAB}{TAB}{TAB}{TAB}{TAB}"$(inherited)",',
        f'{TAB}{TAB}{TAB}{TAB}{TAB}"@executable_path/Frameworks",',
        f"{TAB}{TAB}{TAB}{TAB});",
        f"MARKETING_VERSION = {MARKETING_VERSION};",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
        'PRODUCT_NAME = "$(TARGET_NAME)";',
        "SWIFT_EMIT_LOC_STRINGS = YES;",
        'TARGETED_DEVICE_FAMILY = "1,2";',
    ]
    test_settings = [
        'BUNDLE_LOADER = "$(TEST_HOST)";',
        "CODE_SIGN_STYLE = Automatic;",
        f"CURRENT_PROJECT_VERSION = {BUILD_NUMBER};",
        "GENERATE_INFOPLIST_FILE = YES;",
        f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};",
        f"MARKETING_VERSION = {MARKETING_VERSION};",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.tests;",
        'PRODUCT_NAME = "$(TARGET_NAME)";',
        "SWIFT_EMIT_LOC_STRINGS = NO;",
        'TARGETED_DEVICE_FAMILY = "1,2";',
        'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/PassportProof.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/PassportProof";',
    ]
    ui_test_settings = [
        "CODE_SIGN_STYLE = Automatic;",
        f"CURRENT_PROJECT_VERSION = {BUILD_NUMBER};",
        "GENERATE_INFOPLIST_FILE = YES;",
        f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};",
        f"MARKETING_VERSION = {MARKETING_VERSION};",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.uitests;",
        'PRODUCT_NAME = "$(TARGET_NAME)";',
        "SWIFT_EMIT_LOC_STRINGS = NO;",
        'TARGETED_DEVICE_FAMILY = "1,2";',
        f"TEST_TARGET_NAME = {APP_NAME};",
    ]

    w("")
    w("/* Begin XCBuildConfiguration section */")
    config_block(uid("cfg", "project", "Debug"), "Debug", project_common + project_debug)
    config_block(uid("cfg", "project", "Release"), "Release", project_common + project_release)
    config_block(uid("cfg", APP_NAME, "Debug"), "Debug", app_settings)
    config_block(uid("cfg", APP_NAME, "Release"), "Release", app_settings)
    config_block(uid("cfg", TEST_NAME, "Debug"), "Debug", test_settings)
    config_block(uid("cfg", TEST_NAME, "Release"), "Release", test_settings)
    config_block(uid("cfg", UI_TEST_NAME, "Debug"), "Debug", ui_test_settings)
    config_block(uid("cfg", UI_TEST_NAME, "Release"), "Release", ui_test_settings)
    w("/* End XCBuildConfiguration section */")

    w("")
    w("/* Begin XCConfigurationList section */")
    for lst, entries in (
        (proj_cfg_list, (("project", "Debug"), ("project", "Release"))),
        (app_cfg_list, ((APP_NAME, "Debug"), (APP_NAME, "Release"))),
        (test_cfg_list, ((TEST_NAME, "Debug"), (TEST_NAME, "Release"))),
        (ui_test_cfg_list, ((UI_TEST_NAME, "Debug"), (UI_TEST_NAME, "Release"))),
    ):
        w(f"\t\t{lst} = {{")
        w(f"{TAB}{TAB}{TAB}isa = XCConfigurationList;")
        w(f"{TAB}{TAB}{TAB}buildConfigurations = (")
        for e in entries:
            w(f"{TAB}{TAB}{TAB}{TAB}{uid('cfg', *e)} /* {e[1]} */,")
        w(f"{TAB}{TAB}{TAB});")
        w(f"{TAB}{TAB}{TAB}defaultConfigurationIsVisible = 0;")
        w(f"{TAB}{TAB}{TAB}defaultConfigurationName = Release;")
        w(f"{TAB}{TAB}}};")
    w("/* End XCConfigurationList section */")

    w("")
    w(f"{TAB}}};")
    w(f"{TAB}rootObject = {project_obj} /* Project object */;")
    w("}")

    proj_dir = os.path.join(ROOT, f"{APP_NAME}.xcodeproj")
    os.makedirs(os.path.join(proj_dir, "xcshareddata", "xcschemes"), exist_ok=True)
    with open(os.path.join(proj_dir, "project.pbxproj"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")

    write_scheme(os.path.join(proj_dir, "xcshareddata", "xcschemes", f"{APP_NAME}.xcscheme"),
                 app_target, test_target, ui_test_target)

    print(f"wrote {APP_NAME}.xcodeproj")
    print(f"  app sources : {len(app_swift)}")
    print(f"  app assets  : {len(app_assets)}")
    print(f"  test sources: {len(test_swift)}")
    print(f"  UI sources  : {len(ui_test_swift)}")
    return 0


SCHEME = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target}"
               BuildableName = "{app_name}.app"
               BlueprintName = "{app_name}"
               ReferencedContainer = "container:{app_name}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "{app_name}.app"
            BlueprintName = "{app_name}"
            ReferencedContainer = "container:{app_name}.xcodeproj">
         </BuildableReference>
      </MacroExpansion>
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target}"
               BuildableName = "{test_name}.xctest"
               BlueprintName = "{test_name}"
               ReferencedContainer = "container:{app_name}.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ui_test_target}"
               BuildableName = "{ui_test_name}.xctest"
               BlueprintName = "{ui_test_name}"
               ReferencedContainer = "container:{app_name}.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "{app_name}.app"
            BlueprintName = "{app_name}"
            ReferencedContainer = "container:{app_name}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
      <StoreKitConfigurationFileReference identifier="../../StoreKit/PassportProof.storekit">
      </StoreKitConfigurationFileReference>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "{app_name}.app"
            BlueprintName = "{app_name}"
            ReferencedContainer = "container:{app_name}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


def write_scheme(path: str, app_target: str, test_target: str, ui_test_target: str) -> None:
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(
            SCHEME.format(
                app_target=app_target,
                test_target=test_target,
                ui_test_target=ui_test_target,
                app_name=APP_NAME,
                test_name=TEST_NAME,
                ui_test_name=UI_TEST_NAME,
            )
        )


if __name__ == "__main__":
    raise SystemExit(main())
