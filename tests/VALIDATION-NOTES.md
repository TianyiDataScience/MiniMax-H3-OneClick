# Installer reliability validation, September 2026

## Passed

- Package syntax, JSON, bundled asset hashes, release hygiene, and secret/path checks.
- Existing shortcut and installer feedback tests under Windows PowerShell 5.1.
- New reliability suite under Windows PowerShell 5.1 and PowerShell 7: installed vs visible RAM, UUID/index conversion and reorder, matching/mismatched server identities, complete/corrupt/oversized partials, curl 33 and HTTP 416 recovery, ordinary network interruption retention, hash rejection, remaining-space estimates and low-space rejection.
- Twelve full mocked preflight cases: nominal 16GB/15.22GiB, true 12GB, Turing, Ampere, Ada, Blackwell, Pascal, 6GB VRAM, old driver, multiple GPUs, network failure, insufficient fresh-install disk space. These are simulated inputs, not twelve hardware tests.
- RTX 5050 Laptop real synchronized FP32/FP16/BF16 CUDA operations and selected UUID matching.
- All five immutable Hugging Face URLs: linked byte sizes and SHA-256 match the previously fully verified local model files. No model weights changed.

Prior actual T2V/I2V generation results and the limited hardware matrix are documented in ../COMPATIBILITY.md.

## Latest startup recheck: not passed

On 2026-09-16, a bounded ComfyUI startup recheck could not complete in the current host environment. A normal-permission retry reported that Windows application-control policy blocked loading SciPy's `_dop` DLL. Importing `scipy.integrate._dop` directly with the existing portable Python, without running any modified installer/launcher, reproduced the same error. A sandboxed attempt also reported a blocked CUDA extension and timed out during dependency imports.

The runtime/dependencies and Windows security policy were not modified by this fix. Do not interpret unit tests, CI success, or earlier generation evidence as proof that this current host's full startup recheck passed. Security-policy investigation requires reviewing the relevant Windows protection events/administrator policy; disabling protection is not an installer remedy.

No new GPU model, multi-GPU hardware run, Windows 10 install, or D/E-drive hardware installation was added to the verified list.
