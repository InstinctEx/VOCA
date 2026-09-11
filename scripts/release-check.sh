#!/bin/zsh
# Read-only release gate. Does not sign, upload, charge, or publish anything.
set -u
voca_app="${1:-VOCA.app}"
voca_failed=0
voca_channel="${VOCA_DISTRIBUTION_CHANNEL:-notarized}"
voca_details="$(codesign -dvv "$voca_app" 2>&1)"
function voca_fail() { print "BLOCKED: $1"; voca_failed=1; }
if ! codesign --verify --deep --strict "$voca_app"; then voca_fail "Invalid bundle signature"; fi
if [[ "$voca_channel" == "notarized" ]]; then
if ! print -r -- "$voca_details" | rg -q 'Authority=Developer ID Application:'; then voca_fail "Developer ID Application signature required"; fi
if ! print -r -- "$voca_details" | rg -q 'flags=.*runtime'; then voca_fail "Hardened runtime required"; fi
if ! xcrun stapler validate "$voca_app"; then voca_fail "A valid notarization ticket must be stapled"; fi
  if ! spctl --assess --type execute "$voca_app"; then voca_fail "Gatekeeper assessment failed"; fi
elif [[ "$voca_channel" == "unsigned-beta" ]]; then
  print "BETA: Local signature only. No Apple notarization; manual installation approval may be required."
else
  voca_fail "Unknown distribution channel"
fi
if find "$voca_app" -iname '*MediaRemoteAdapter*' -print | rg -q .; then voca_fail "Removed private media adapter is still bundled"; fi
[[ -f "$voca_app/Contents/Resources/FluidVoice-GPL-3.0.txt" ]] || voca_fail "Packaged GPL license missing"
[[ -f "$voca_app/Contents/Resources/THIRD-PARTY-NOTICES.txt" ]] || voca_fail "Third-party notices missing"
[[ "${VOCA_DEPENDENCIES_CLEARED:-}" == "yes" ]] || voca_fail "Pinned dependency and model rights need documented clearance"
[[ "${VOCA_SOURCE_URL:-}" == https://* ]] || voca_fail "Provide the actual corresponding-source download URL"
[[ "${VOCA_SUPPORT_EMAIL:-}" == *@* ]] || voca_fail "Provide an owned support address"
if (( voca_failed == 0 )); then print "Automated gates passed. Complete the manual distribution checklist before release."; fi
exit $voca_failed
