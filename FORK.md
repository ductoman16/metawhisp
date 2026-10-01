# Local-transcription performance fork

Personal fork of MetaWhisp's `architecture-phase-1-3` branch, based on 1.3.37.

## Changes

- WhisperKit uses CPU/Neural Engine compute for both audio encoding and decoding.
- Local recognition does not ingest the built-in glossary. Cloud prompting and
  post-transcription corrections are unchanged.
- Model loading includes one bounded inference on silence before reporting ready.
  Its output never enters dictation, history, or billing.
- Menu and dashboard status track model preparation, not just idle recording.
  Recording hotkeys and buttons cannot capture audio before the engine is ready.
- The fork bundle disables the upstream updater. Ordinary upstream-style builds
  retain their existing update behavior.

Auto detection, explicit languages, VAD, the two-retry limit, and confidence /
hallucination handling are preserved. Without glossary bias, some proper names
may need correction afterward; identical results on a synthetic test are not a
general accuracy guarantee.

## Build and verify

On the diagnosed M2 Pro, the real app-engine tests measured 1.02s for the first
short English dictation (0.97s repeated), and 2.63s for the first 5.28-second Auto
dictation (2.44s repeated). First preparation took 147s while Core ML compiled;
the next load plus warm-up took 2.87s. These exclude microphone capture and paste.

Requires full Xcode, its accepted license / first-launch components, and the
Metal toolchain. No Developer ID certificate is required for this local build.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift package resolve
bash scripts/prepare-fork-dependencies.sh
bash scripts/regression.sh
METAWHISP_PERF_MODEL=openai_whisper-large-v3_turbo \
  swift test -c release --filter WhisperKitLatencyTests
bash scripts/build-fork.sh
```

The hardware benchmark uses macOS's local Samantha voice, never the microphone.
Its latency limits are calibrated for an M2 Pro; the normal suite skips these
opt-in hardware tests. Keyboard tests use real installed Apple layouts without
enabling or switching the user's input sources. Production stays enabled-only.

The build script produces `dist/MetaWhisp-Fork.app`, verifies signatures and
resources, and never installs, quits, or launches an app. It refuses to overwrite
an existing artifact. The output is ad-hoc signed, not notarized or a public release.

`prepare-fork-dependencies.sh` applies the checked-in `hub-app-resources.patch`
to the resolved swift-transformers checkout. It makes app builds find bundled
tokenizer resources under `Contents/Resources`; CLI/test lookup is unchanged.
This avoids both an absolute build-directory dependency and unsigned files in
the app root. An incompatible dependency update fails the patch check loudly.

## Trying the fork

Bundle signing and engine benchmarks alone do not verify a launched application.
For a packaged startup/engine smoke check, quit the running app, create a local
fixture, then launch the packaged executable with explicit diagnostic arguments:

```sh
say -v Samantha -r 190 -o /tmp/metawhisp-smoke.aiff 'Hello, this is a test.'
dist/MetaWhisp-Fork.app/Contents/MacOS/MetaWhisp \
  --transcription-smoke-test /tmp/metawhisp-smoke.aiff 'this is a test'
```

The fork-only flag verifies the normally initialized coordinator is ready and
transcribes the fixture twice. Look for two `[ForkSmoke] PASS` entries in
`~/Library/Logs/MetaWhisp.log` for the current launch's PID and timestamp; any
`[ForkSmoke] FAIL` or missing PASS is a failure. Older PASS entries do not count.
It does not write transcripts to clipboard/history, and does not verify native
UI rendering, microphone capture, hotkeys, or automatic paste. Those require a
live dictation and the relevant macOS permissions.

Quit the original MetaWhisp, then open `dist/MetaWhisp-Fork.app`. Do not run both:
the bundle identifier remains `com.metawhisp.app`, so they share preferences,
models, history, and the single-instance guard. Keep the original app intact
for rollback. The new signature may require granting macOS permissions again.

Wait for model preparation before dictating. First-time Neural Engine compilation
can take several minutes; later loads can reuse Core ML's compiled cache. OS,
toolchain, or model changes can invalidate that cache. No periodic keep-alive
inference is performed. To return to the original, quit the fork and launch the
original app; keep language on Auto there to avoid the English glossary overhead.
