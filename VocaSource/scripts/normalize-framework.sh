#!/bin/zsh
set -euo pipefail
framework="$1"
# The upstream ZIP expands symlinks into duplicate directories. Normalize only
# the app's copied framework, never the downloaded/verified package artifact.
test -f "$framework/Versions/A/CTranscribe"
for entry in CTranscribe Headers Modules Resources; do
    if [[ ! -L "$framework/$entry" ]]; then
        rm -rf "$framework/$entry"
        ln -s "Versions/Current/$entry" "$framework/$entry"
    fi
done
if [[ ! -L "$framework/Versions/Current" ]]; then
    rm -rf "$framework/Versions/Current"
    ln -s A "$framework/Versions/Current"
fi
