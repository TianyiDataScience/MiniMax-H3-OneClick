# Release checklist

Do not publish a release until every applicable item is complete.

- [ ] Confirm the maintainer has the right to publish all original files.
- [ ] Obtain legal review or required MiniMax authorization for the maintainer's
      territory and intended distribution/use. Do not describe the model as OSI open source.
- [ ] Re-read the current MiniMax H3 license and acceptable-use policy; compare
      it with `MODEL-LICENSE-NOTICE.md`.
- [ ] Re-check the licenses and notices for ComfyUI, workflow_templates,
      7-Zip, Qwen3-VL and the Turbo LoRA.
- [ ] Verify every remote URL, byte size and SHA-256 from a clean machine.
- [ ] Run `tests\Validate-Package.ps1` and require CI success.
- [ ] Test extraction plus `00-START-HERE.cmd` from a short ASCII path on a clean
      Windows 11 x64 machine.
- [ ] Complete full-hash verification and save a real 5-second H3 MP4 on every
      configuration claimed as verified.
- [ ] Confirm the release archive contains no runtime, weights, generated media,
      projects, logs, diagnostics, API keys, personal paths or backup folders.
- [ ] Generate and publish the release archive SHA-256.
- [ ] Sign the tag or release artifact if signing infrastructure is available.
- [ ] State the exact verified hardware and known limitations in release notes.

The initial public release should be marked prerelease until a second clean
machine reproduces installation and generation without maintainer intervention.
