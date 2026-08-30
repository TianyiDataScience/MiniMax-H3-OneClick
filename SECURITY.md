# Security policy

## Supported versions

Only the latest tagged release is supported. Manifests pin remote URLs, sizes,
and SHA-256 values; updating any upstream artifact requires a reviewed manifest
change and a new release.

## Reporting a vulnerability

Do not post credentials, private logs, prompts, local paths, or exploitable
details in a public issue. Contact the repository maintainer privately through
the security-reporting channel configured on the hosting platform. Include the
affected version, impact, reproduction conditions, and a minimal redacted log.

The project will acknowledge a complete report within seven days and will not
publish details before a fix or mitigation is available.

## Trust boundary

The installer downloads executables and model files only from pinned upstream
HTTPS URLs and verifies SHA-256 before use. A matching hash proves byte identity
with the pinned artifact, not that upstream code is vulnerability-free. Users
remain responsible for reviewing upstream licenses and security advisories.
