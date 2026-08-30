# Privacy

The installer does not send project telemetry. Preflight makes direct HEAD
requests to GitHub and Hugging Face, and installation downloads from GitHub,
Hugging Face, and optionally 7-zip.org. Those services receive ordinary network
metadata such as the user's IP address and user agent.

`08-COLLECT-DIAGNOSTICS.ps1` creates a local ZIP containing hardware and system
configuration, GPU status, model filenames/check results, output filenames,
and optional ComfyUI service statistics. Logs are excluded unless the user
explicitly passes `-IncludeLogs`. Logs may contain prompts, local paths,
filenames or other private information.

No diagnostic package is uploaded automatically. Inspect and redact every file
before sharing it in an issue or with another person.
