#!/bin/zsh
# Package an already-built beta and the exact tracked source that produced it.
# Run from a clean source checkout after building and package-voca.sh.
set -euo pipefail
repo="${0:A:h:h}"
app="${1:-$repo/VOCA.app}"
out="${2:-$repo/artifacts/unsigned-beta}"
cd "$repo"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { print -u2 'Commit tracked changes before packaging matching source.'; exit 1; }
codesign --verify --deep --strict "$app"
[[ -f "$app/Contents/Resources/THIRD-PARTY-NOTICES.txt" ]] || { print -u2 'Dependency notices missing'; exit 1; }
if /usr/bin/find "$app" -iname '*MediaRemoteAdapter*' -print | /usr/bin/grep -q .; then
  print -u2 'Removed media adapter remains in app; rebuild cleanly.'; exit 1
fi
mkdir -p "$out"
revision="$(git rev-parse HEAD)"
[[ ! -e "$out/VOCA-beta.zip" ]] || { print -u2 'Choose a fresh output directory; existing releases are immutable.'; exit 1; }
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/VOCA-beta.zip"
git archive --format=zip --prefix=VOCA-source/ HEAD > "$out/VOCA-source.zip"
cp "$repo/docs/BETA-INSTALL.md" "$out/READ-ME-FIRST.md"
print -r -- "$revision" > "$out/SOURCE-REVISION.txt"
(cd "$out" && shasum -a 256 VOCA-beta.zip VOCA-source.zip READ-ME-FIRST.md SOURCE-REVISION.txt > SHA256SUMS)
print "Local beta artifacts prepared in $out. Not notarized; nothing uploaded."
