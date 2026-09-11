#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
voca_configuration="${VOCA_BUILD_CONFIGURATION:-Debug}"
product="${VOCA_PACKAGE_INPUT:-$project_root/DerivedData/Build/Products/$voca_configuration/VOCA.app}"
output="$project_root/../VOCA.app"
stage="$(mktemp -d "$project_root/DerivedData/package.XXXXXX")"
ditto "$product" "$stage/VOCA.app"
# Xcode test runs inject these into the host app; never ship test runners.
rm -rf "$stage/VOCA.app/Contents/PlugIns/FluidDictationIntegrationTests.xctest"
for test_artifact in MediaRemoteAdapter.framework Testing.framework XCTAutomationSupport.framework XCTest.framework XCTestCore.framework XCTestSupport.framework XCUIAutomation.framework XCUnit.framework libXCTestBundleInject.dylib libXCTestSwiftSupport.dylib; do
  rm -rf "$stage/VOCA.app/Contents/Frameworks/$test_artifact"
done
if [[ -d "$stage/VOCA.app/Contents/Frameworks/CTranscribe.framework" ]]; then
  "$project_root/scripts/normalize-framework.sh" "$stage/VOCA.app/Contents/Frameworks/CTranscribe.framework"
fi
# Packaged builds must use their embedded, signed frameworks, not an Xcode
# product path that may contain a rebuilt or unsigned development copy.
for executable in "$stage/VOCA.app/Contents/MacOS/"*(N); do
  if [[ "$voca_configuration" == "Release" ]]; then
    # Retain global/exported symbols, Swift metadata and all model resources.
    # Keep Xcode's separate dSYM locally; do not ship debug/local symbol tables.
    xcrun strip -S -x "$executable"
  fi
  development_rpath="$project_root/DerivedData/Build/Products/$voca_configuration/PackageFrameworks"
  if otool -l "$executable" 2>/dev/null | rg -Fq "path $development_rpath ("; then
    install_name_tool -delete_rpath "$development_rpath" "$executable"
  fi
done
voca_sign_args=(--force --sign "${SIGNING_IDENTITY:--}")
voca_entitlements="$project_root/Fluid.entitlements"
if [[ "$voca_configuration" == "Release" ]]; then voca_entitlements="$project_root/Release.entitlements"; fi
if [[ "${SIGNING_IDENTITY:--}" != "-" ]]; then
  voca_sign_args+=(--options runtime --timestamp)
  voca_entitlements="$project_root/Release.entitlements"
fi
for framework in "$stage/VOCA.app/Contents/Frameworks/"*.framework(N); do
  codesign "${voca_sign_args[@]}" "$framework"
done
cp "$project_root/LICENSE" "$stage/VOCA.app/Contents/Resources/FluidVoice-GPL-3.0.txt"
cp "$project_root/VOCA-CHANGES.md" "$stage/VOCA.app/Contents/Resources/"
cp "$project_root/THIRD-PARTY-NOTICES.txt" "$stage/VOCA.app/Contents/Resources/"
codesign "${voca_sign_args[@]}" --entitlements "$voca_entitlements" "$stage/VOCA.app"
codesign --verify --deep --strict "$stage/VOCA.app"
if [[ -d "$output" ]]; then
  backup="$(mktemp -d "$project_root/DerivedData/previous.XXXXXX")"
  mv "$output" "$backup/VOCA.app"
fi
mv "$stage/VOCA.app" "$output"
rmdir "$stage"
print "Built $output"
