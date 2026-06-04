# Seclore Integration Assistant

A Claude AI skill that helps developers and architects integrate the **Seclore Server SDK (Java)** into their applications.

Ask it questions about Seclore SDK setup, protection types, method signatures, XML structures, error codes, and get ready-to-run Java code samples — all without digging through Javadocs or trial-and-error.

---

## What it covers

- **SDK setup** — required JARs, log4j2.xml configuration, initialization sequence, App Config and Tenant Config XML
- **All four protection types** — Hot Folder, Independent Rights, External Reference (Policy Federation), and Protect with File ID
- **All SDK operations** — `protectAndWrap`, `protectX`, `unwrapAndUnprotect`, `unprotectX`, `wrap`, `unwrap`, `sendRequest`
- **Advanced Security** — RSA key pair setup, `DefaultCryptoHandler`, advanced privileges (Unprotect Any File, Add/Update other EAs)
- **Troubleshooting** — error codes `-220133`, `-220372`, `-220473`, `-240003`, `-210001` and more, with specific fixes
- **Java code samples** — complete, runnable samples for every protection and unprotection pattern
- **Starter packages** — ask for a "starter kit" for any protection type and get a full folder with source, run scripts, config, and README

---

## Installing in Claude Cowork

1. Clone or download this repository
2. In Claude Cowork, go to **Skills → Install from folder**
3. Select the `seclore-integration-assistant` folder
4. The skill is now available as `/seclore-integration-assistant`

---

## Example questions

```
What JARs do I need to include in my project?

How do I initialize the SDK for Hot Folder protection?

Give me sample code for Independent Rights protection.

I'm getting error -220133 when protecting a file. What's wrong?

What is the difference between Advanced Security and Advanced Privileges?

What XML do I pass for PROTECT_WITH_FILE_ID?

Create a starter package for External Reference protection.

What does protectX() return compared to protectAndWrap()?
```

---

## SDK version

This skill is written for **Seclore Server SDK Java 4.4.19.0**.

Core SDK behaviour and XML structures are stable across minor versions, but always validate
against the Javadoc shipped with your specific SDK version.

---

## Repository structure

```
seclore-integration-assistant/
├── SKILL.md                        ← Skill instructions and operating modes
└── references/
    ├── sdk-guide.md                ← PS configuration checklist, troubleshooting,
    │                                  integration patterns, Policy Federation deep dive,
    │                                  Advanced EA setup, Access Rights reference,
    │                                  SDK API quick reference, integration verticals
    └── code-samples.md             ← Complete Java code samples for all protection types,
                                       XML reference, log4j2.xml spec, starter package spec
```

---

## Contributing

Found an error, confirmed a new XML structure, or encountered an undocumented error code?
Contributions are welcome.

1. Fork the repository
2. Make your changes with a clear description of what you confirmed and how
3. Open a pull request

**Please only contribute information that has been tested against a live Policy Server.**
Unconfirmed guesses in a skill create more problems than they solve.

---

## Versioning

| Version | Notes |
|---------|-------|
| v1.0 | Initial release — all four protection types, Advanced Security/Privileges distinction, confirmed XML for PROTECT_WITH_FILE_ID |

---

## License

MIT License — free to use, fork, and adapt.
