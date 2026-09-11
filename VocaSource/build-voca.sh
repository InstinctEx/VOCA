#!/bin/zsh
set -euo pipefail
project_root="${0:A:h}"
cd "$project_root"
cache="${VOCA_PACKAGE_CACHE:-$project_root/DerivedData/SourcePackages}"
voca_configuration="${VOCA_BUILD_CONFIGURATION:-Debug}"
xcodebuild -project Fluid.xcodeproj -scheme Fluid -configuration "$voca_configuration" -destination 'platform=macOS' -derivedDataPath DerivedData -clonedSourcePackagesDirPath "$cache" build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
./scripts/package-voca.sh
