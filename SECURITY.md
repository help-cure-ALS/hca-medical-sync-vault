# Security Policy

TENOS Sync Vault is designed for encrypted medical data transport. Please report suspected vulnerabilities privately.

## Reporting a Vulnerability

Do not open a public GitHub issue for security vulnerabilities.

Use GitHub private vulnerability reporting if it is enabled for this repository. If it is not enabled, contact the maintainers through the project's private communication channel.

When reporting, include:

- A concise description of the issue.
- Affected endpoint, component, or configuration.
- Reproduction steps.
- Impact assessment.
- Suggested mitigation, if known.

Do not include real patient data, medical payloads, private keys, JWTs, app tokens, admin tokens, or production secrets in the report.

## Security Scope

In scope:

- Authentication and authorization bypasses.
- Device capability or revocation bypasses.
- Leakage of subject IDs, device IDs, keys, JWTs, or payloads.
- Quota and rate-limit bypasses with operational impact.
- Unsafe logging or error responses.
- Deployment configuration that could expose secrets or plaintext.

Out of scope:

- Medical app UI behavior outside this repository.
- Vulnerabilities that require access to a compromised client device and do not change server-side guarantees.
- Denial-of-service reports without a practical mitigation path.

## Design Expectations

- The server must never receive medical plaintext.
- The server must never store medical encryption keys.
- A leaked `subject_id` must not be enough to obtain sync access.
- Owner-only operations must remain unavailable to recipient devices.
- Admin endpoints must expose aggregate operational data only.
