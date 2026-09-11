#!/bin/zsh
# Synthetic fixtures only. No microphone recording or personal text.
set -euo pipefail
say -v Samantha -r 165 -o /tmp/voca-test-en.aiff 'this is a test in English'
say -v Melina -r 165 -o /tmp/voca-test-el.aiff 'αυτό είναι ένα τεστ στα ελληνικά'
TEST_RUNNER_VOCA_TEST_MIXED=1 "${0:A:h}/test-voca.sh"
