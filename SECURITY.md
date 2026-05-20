# Security Policy

## Reporting a vulnerability

If you find a security issue in Jtech, please **do not** open a public GitHub issue. Instead, report it privately via GitHub's "Report a vulnerability" link on this repository's Security tab, or email the maintainer listed in `plugin.rb`'s `authors:` field.

Please include:

- Which sub-plugin (or shared code) is affected.
- The Discourse version and Jtech commit you reproduced against.
- A minimal proof-of-concept (PoC) — request payloads, reproduction steps, or a patch demonstrating the issue.
- The expected impact (data exposure, privilege escalation, RCE, denial of service, etc.).

We aim to acknowledge within **3 business days** and to ship a fix or disclose a workaround within **30 days** of triage, depending on severity. Critical issues (unauthenticated RCE, admin-level privilege escalation) take priority.

## Supported versions

Only the `main` branch receives security fixes. If you're running an older commit, upgrade and re-test.

## Disclosure

We coordinate disclosure with reporters. Once a fix is merged and a release tagged, we publish a [GitHub Security Advisory](https://docs.github.com/en/code-security/security-advisories) describing the vulnerability and crediting the reporter (unless you'd rather stay anonymous).
