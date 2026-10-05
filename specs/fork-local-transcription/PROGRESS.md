# Local transcription latency fix

## October 5 follow-up experiments

Baseline: `88f3655` on `fix/local-transcription-latency` in
`/Users/ryan/Source/metawhisp`. The user speaks English only, accepts the 200ms
paste settling delay for reliability, authorizes timestamp/concurrency
experiments, and reserves incremental transcription for a last resort.

User story: as an English dictator on the M2 Pro, I want less waiting without
missing words or degrading meeting timing. Keep only measured improvements;
retain retry and confidence safeguards. Test short phrases, numbers, a final
sentence surrounded by silence, multi-window audio, and competing inference.

- [x] Save `com.metawhisp.app` transcriptionLanguage as `en`; verify with defaults.
  Live UI confirmation unavailable: computer-use app lookup timed out. Running
  app may require a restart to observe the externally written preference.
- [x] Keep paste delay and defer incremental transcription.
- [x] Run opt-in, release-mode `WhisperKitTuningTests` on synthetic local speech.
  Three tests passed; 38 measurements in 252.56 seconds, excluding build.
- [x] Compare transcripts and timings; keep or reject each candidate explicitly.
  See `TUNING-2026-10-05.md`. English preference retained; timestamp and worker
  changes rejected for now. Contention measured, but meeting advice is disabled.
- [x] Run the regression gate and record results: PASS, 1,486 tests, zero
  failures, all 69 critical suites, layout corpus within floor. Log:
  `/tmp/metawhisp-tuning-regression-oct5.log`. Persisted language rechecked: `en`.

The experiment harness never opens the microphone, changes settings, or writes
clipboard/history. Timestamp settings alternate within each clip to reduce order
bias. Worker order reverses on the second pass. Raw synthetic-only results go to
`/tmp/metawhisp-tuning-oct5.log`.

## October 1 packaged-app readiness correction

User story: as a dictator launching the fork, I need a truthful preparation
status and recording disabled until inference is ready, so my audio is not lost.
Failure must be distinguished from preparation; a successful load enables capture.

The earlier verification covered engine tests and bundle integrity, NOT launched
app behavior. The user's screenshot exposed the gap: the old UI mapped idle to
READY, accepted 3.2 seconds of audio during preparation, then discarded it with
an incorrect download message. The launched package eventually prepared Turbo
in 171.53s. A later real microphone dictation took 1.28s engine time and ~1.33s
from stop to clipboard for 1.79s of audio. Auto-paste was blocked by Accessibility.

- [x] Reproduce all four recording entry points with a failing coordinator test
  (14 assertions failed before the fix; no real microphone used).
- [x] Publish preparation lifecycle from the engine to the coordinator; guard
  capture before microphone access; show truthful menu/dashboard state and disable
  start controls. Clear only readiness errors when preparation changes. Preserve
  an existing prepared model during replacement loads.
- [x] Preserve recovery audio if the engine disappears after capture starts.
- [x] Unit coverage for preparation, cancellation/failure, unload, and all recording
  entry points; positive ready-to-record coverage in opt-in real-model tests.
- [x] Full gate PASS: 1483 tests, zero failures, 69 critical suites, layout corpus.
- [x] Real-model release tests and rebuilt bundle verification.
- [x] Launch packaged app and run its opt-in fixture transcription smoke check.
- [ ] Native UI rendering and live auto-paste verification (automation blocked).

Final gate PASS again after the last source edit: 1483 tests, zero failures,
69 critical suites, layout corpus. Eight focused release tests passed; Auto
2.555/2.437/2.422s for 5.282s audio, English 1.015/0.970/0.970s for 1.554s audio.
Logs: `/tmp/metawhisp-readiness-final-regression.log`,
`/tmp/metawhisp-readiness-real-model.log`, `/tmp/metawhisp-readiness-package.log`.

Launched the rebuilt packaged executable at 16:11:33 (PID 24685), with the
fork-only smoke arguments, selected large-v3-turbo and Auto unchanged. Normal
startup prepared the model in 3.16s. Two correct fixture transcriptions passed
at 16:11:41 and 16:11:42: 1.283s / 1.223s for 1.554s audio, coordinator Ready.
Evidence: `[ForkSmoke] PASS` entries for that PID in `~/Library/Logs/MetaWhisp.log`.
The app remains running. This launch reports Accessibility trusted, but that
does not prove a successful live paste. The smoke check does not touch history
or clipboard. Previous idle fork was stopped before moving its bundle to
`dist/MetaWhisp-Fork-before-readiness.app`; `/Applications/MetaWhisp.app` is intact.

Native UI inspection timed out for the exact fork path, including after the
rebuild and successful smoke check; the bundle ID is
ambiguous because the original and fork intentionally share it. Do not substitute
unit tests or log-derived readiness for visual verification. The package smoke
check uses the actual startup-loaded engine and coordinator, but deliberately
does not exercise microphone capture, paste, history, or global hotkeys.

Consumer assumptions checked: all recording entry points share startRecording;
idle does not imply a prepared engine. MenuBarView and DashboardView must observe
engine transitions as well as recording-stage changes. Existing model-loading
call sites all use WhisperKitEngine.loadModel, so lifecycle reporting belongs
there rather than only in AppDelegate startup. Floating recording variants are
stage-driven overlays; they do not authorize capture. Cloud readiness continues
to use its existing isModelLoaded contract.

## User stories and acceptance criteria

- As an on-device English dictator, I want short turbo dictations to finish promptly without processing a fixed brand glossary before my words. A real-engine, warmed short-audio test must finish within five seconds on the diagnosed M2 Pro.
- As a multilingual dictator, I want Auto to detect the spoken language, and explicit languages to stay pinned. Preserve decoder prefill, the existing two-retry limit, VAD, and confidence/hallucination handling.
- As a user of replacements or cloud transcription, I want their existing behavior preserved. Keep post-transcription corrections and cloud prompt selection unchanged.

## Master checklist / iteration 1

- [x] Create personal fork from active upstream branch and inspect all local engine callers.
- [x] Reproduce slow stage in isolated WhisperKit benchmark (109 prompt tokens; ~14 seconds warm vs ~1.9 without prompt).
- [x] Build active upstream source and reproduce through the actual app engine with a failing integration test.
- [x] Fix local decoding and add deterministic configuration tests.
- [x] Run the full repository regression gate and real-engine performance test.
- [x] Build a release artifact without overwriting or launching the installed application.
- [x] Commit and publish the verified fix to the personal fork.

## October 1 continuation (authorized)

- User story: as a local Turbo user, I want both first and repeated dictations
  ready after model preparation, with Auto and replacement behavior preserved.
- Acceptance: the real-engine short English fixture stays under 2s; the longer
  5.28s Auto fixture stays under 2.8s, including first inference. These are opt-in
  M2 Pro hardware benchmarks, not portable unit-test deadlines.
- [x] Repair enabled-keyboard dependencies without changing system preferences:
  explicit installed-layout mapper shared through the existing controller seam.
  All 56 tests in the five previously failing suites now pass; no assertions removed.
- [x] Observe first-dictation readiness regression red, then use Neural Engine
  for both stages and warm up before publishing a loaded model.
- [x] Disable upstream updates only for the packaged fork; test the policy.
- [x] Full gate, real-model test, standalone bundle validation.
- [x] Publish verified commits to the personal fork.

New caller assumption: loadModel completion and isModelLoaded advertise readiness
to the coordinator and AppDelegate's startup / selection / best-model-swap paths.
Preparation belongs before that publication; failures must propagate through the
existing load error UI. Keyboard production defaults remain enabled-only; tests
use installed Apple layouts so US-only host preferences do not change semantics.

## Consumer assumptions

Dictation, voice questions, and meeting chunks all call WhisperKitEngine through TranscriptionEngine. They expect resolved language, confidence metrics, segments, and text; none requires prompt words to be echoed or retained. The coordinator and meeting paths apply output corrections separately. CloudWhisperEngine consumes the same protocol's promptWords, so changing the shared glossary resolver would unintentionally change cloud behavior; keep this change local to WhisperKitEngine.

## Status / constraints

The active upstream branch includes the installed glossary and Auto language gating absent from the stale release-tag source used in the initial investigation. Auto already removes English glossary hints at the coordinator boundary; the original isolated Auto-plus-prompt benchmark did not model that boundary.

The user accepted the Xcode license. Xcode first-launch components and Metal Toolchain 17F109 are now installed. The unmodified app passes `swift build` with per-command DEVELOPER_DIR pointing at full Xcode; no global tool selection is changed. Installed MetaWhisp and user data are untouched.

Local branch: `fix/local-transcription-latency`; public fork: `ductoman16/metawhisp`.

## Verified latency result

The real app engine with the exact 33-word/109-token glossary failed the
five-second limit at 14.055 and 14.112 seconds. With promptTokens nil and
CPU/Neural Engine decoding it passes at 1.520 and 1.510 seconds, retaining
the expected transcript on 1.554 seconds of synthesized English audio.
Three deterministic decoding-option tests also pass (Auto aliases, pinned
languages, retry/prefill/VAD safeguards). Release test log:
`/tmp/metawhisp-fork-green.log`; baseline: `/tmp/metawhisp-fork-red.log`.

The release suite initially failed to compile because GlobalInputEventTapProbe
is DEBUG-only but its tests were unconditional. The tests now have the same
DEBUG guard; all three remain in the normal debug gate.

## September 29 full-suite blocker (resolved October 1)

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/regression.sh`
builds successfully, but FAILS: 1474 tests, 8 skipped, 68 failures. All 69
critical suites run and the layout corpus floor passes. A second full test
run reproduces exactly the same 68 failures, all in unchanged keyboard suites:
LayoutConfidenceEngineTests (18), LayoutSwitchControllerDispatchTests (14),
LayoutTypingRaceTests (13), LayoutWordBufferTests (4), SystemLayoutLexiconTests (19).

This Mac enables only the US keyboard layout. Several tests unconditionally
use the live US/Russian mapper, whose loader reads only enabled input sources;
only one mapper test explicitly skips when those layouts are unavailable.
Some failures also involve dynamic punctuation assumptions. Do not claim all
68 are fixed merely by enabling Russian; no keyboard settings were changed.
Full logs: `/tmp/metawhisp-fork-regression.log` and
`/tmp/metawhisp-fork-full-tests.log`.

Resolved by passing real installed layouts explicitly through the existing
mapper / confidence / word-buffer / controller seams in tests. Production uses
enabled-only layouts as before. No assertions removed or skips added.

## Final October 1 verification

Published branch: `ductoman16/metawhisp:fix/local-transcription-latency`.
Personal-fork PR: https://github.com/ductoman16/metawhisp/pull/1 (no upstream PR).

- First-dictation regression failed before the preparation/encoder change:
  Auto 10.54s first / 2.94s repeated; short English 5.30s first / 1.50s repeated.
- Fixed real-engine test: Auto 2.626 / 2.440 / 2.437s for 5.282s audio; English
  1.020 / 0.970 / 0.973s for 1.554s audio. No test-side warm-up. Model preparation
  was 147.04s on first compilation and 2.87s on the next load.
- All seven release latency/configuration/update-policy tests pass.
  Log: `/tmp/metawhisp-ready-green.log` (red: `/tmp/metawhisp-ready-red.log`).
- Full regression gate PASS twice, including after the final dependency patch:
  1477 tests, zero failures, 69 critical suites, layout corpus floor preserved.
  Log: `/tmp/metawhisp-final-regression.log`.
- `dist/MetaWhisp-Fork.app` built and strictly signature/resource verified.
  Log: `/tmp/metawhisp-fork-package.log`. Ad-hoc signed, not notarized, not launched.
- Packaging fixes: exclude dist from SPM source scanning, make copied resources
  writable before xattr cleanup, relocate Hub resources through a checked-in
  dependency patch to the standard signed app Resources path. The patch is
  idempotent and fails against incompatible dependency source; lockfile unchanged.
- Original `/Applications/MetaWhisp.app` remains running; preference remains Auto.
  Fork shares the original bundle ID / data, so quit the original before trying it.
