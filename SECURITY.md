# Security policy

## Scope

The skill and prompts instruct an AI agent to run PowerShell on the user's machine. Reports of any path where the agent could change the system before approval, delete personal data, disable security features or send data off the machine are treated as security issues.

## Reporting

Please open a private security advisory on the repository (GitHub: Security > Report a vulnerability) rather than a public issue. Include the agent used, Windows version and the steps or prompt that triggered the behaviour.

## Design guarantees

- Read-only until the user approves codes and types CONFIRM.
- Metadata only: no reading of document contents, cookies, passwords or keys; nothing is sent to the Internet.
- No downloaded scripts, no third-party optimisers, no disabling of Windows Update, Defender, Firewall, UAC, BitLocker or VBS.
