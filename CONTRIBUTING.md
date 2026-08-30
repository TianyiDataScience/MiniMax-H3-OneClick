# Contributing

Contributions are welcome for installer reliability, documentation, hardware
evidence, and reproducible tests.

1. Open an issue before a change that expands platform scope, changes model
   files, changes licenses, or changes security behavior.
2. Keep model weights, generated media, runtimes, diagnostics and logs out of
   commits.
3. Run `pwsh -NoProfile -File .\tests\Validate-Package.ps1`.
4. For a new verified device, attach a redacted preflight result, full-hash
   verification result, CUDA device details, and evidence of a saved 5-second
   H3 MP4. A CUDA probe alone is not enough.
5. State whether a change was tested on real hardware or only statically
   reviewed.

By submitting a contribution, you agree that your original contribution is
licensed under the repository's MIT License and that you have the right to
submit it. Do not submit third-party assets without their license and required
notices.
