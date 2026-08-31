# Changelog

## Unreleased

- Prepared a clean source-only release layout.
- Added MIT licensing for original installer code and explicit model-license boundaries.
- Added a verified/candidate/unsupported device matrix.
- Clarified the verified RTX 5050 Laptop GPU baseline, supported higher RTX tiers, and untested lower NVIDIA tiers.
- Added model-license confirmation before model downloads.
- Removed the bundled 7-Zip executable; it is now downloaded and hash-verified when needed.
- Added Turing-or-newer compute-capability validation and multi-GPU selection.
- Improved launchers for ZIP/backup misuse and already-running ComfyUI instances.
- Made diagnostic log collection opt-in and added privacy warnings.
- Added repository validation, CI, contribution, security, privacy and release guidance.
- Added location-independent Desktop and Start Menu shortcuts created after installation.
- Added a shortcut rebuild tool for installations moved to a new folder.
- Changed the missing-runtime path from a dead-end error into safe install guidance.
- Removed GPU-model and vendor prefixes from generated workflow filenames.
