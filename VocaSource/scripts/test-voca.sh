#!/bin/zsh
set -euo pipefail
voca_root="${0:A:h:h}"
cd "$voca_root"
voca_args=(-project Fluid.xcodeproj -scheme Fluid -configuration Debug -destination 'platform=macOS' -derivedDataPath DerivedData -clonedSourcePackagesDirPath "${VOCA_PACKAGE_CACHE:-$voca_root/DerivedData/SourcePackages}" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
if [[ "${VOCA_TEST_WITHOUT_BUILD:-0}" != "1" ]]; then
  xcodebuild "${voca_args[@]}" build-for-testing
fi
voca_suites=(VocaInterfaceTests KeychainServiceCacheTests HotkeyShortcutTests SettingsNavigationStateTests CustomDictionaryManualEntryTests LLMClientRequestBodyTests TemperatureSupportTests StripThinkingTagsTests SupportedFileExtensionsTests SpeakerTurnMergingTests WhisperLanguageSelectionTests PrivateAIProviderPromptFormatTests PrivateAIDictationTokenBudgetTests AudioBufferConverterTests SpokenSendTests TypingServiceTransientPasteboardTests AnalyticsDatabaseTests DictationE2ETests MediaPlaybackServiceTests)
voca_selected=()
for suite in "${voca_suites[@]}"; do voca_selected+=("-only-testing:FluidDictationIntegrationTests/$suite"); done
xcodebuild "${voca_args[@]}" test-without-building "${voca_selected[@]}" -skip-testing:FluidDictationIntegrationTests/DictationE2ETests/testDictationEndToEnd_whisperTiny_transcribesFixture
