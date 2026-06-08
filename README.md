# Seclore Integration Assistant

A Claude AI skill that helps developers and architects integrate the **Seclore Server SDK (Java)** into their applications.

Ask it questions about Seclore SDK setup, protection types, method signatures, XML structures, error codes, and get ready-to-run Java code samples — all without digging through Javadocs or trial-and-error.

---

## What it covers

- **SDK setup** — required JARs, log4j2.xml configuration, initialization sequence, App Config and Tenant Config XML
- **Different protection types** — Hot Folder, Independent Rights, External Reference (Policy Federation), and Protect with File ID
- **All SDK operations** — Protect, Unprotect, SendRequest
- **Advanced Security** — RSA key pair setup, `DefaultCryptoHandler`, advanced privileges (Unprotect Any File, Add/Update other EAs)
- **Custom Logger Implementation** — Using your own logger for Seclore SDK
- **Policy Federation ARA callback service** — implementing the 3 HTTP endpoints (Ping, GetAccessRight, GetFileInformation), request/response XML, access rights, offline access, watermark, response scenarios, testing with Postman, and troubleshooting
- **DRM API Server integration** — architecture, API vs SDK decision, all REST endpoints, file upload/protect/download lifecycle, authentication (JWT tokens, refresh), storage options (disk/S3/DB), deployment, error codes, best practices, and sample code in Java and curl
- **Troubleshooting** — error codes `-220133`, `-220372`, `-220473`, `-240003`, `-210001`, `-2500020` and more, with specific fixes
- **Java code samples** — complete, runnable samples for every protection and unprotection pattern
- **Starter packages** — ask for a "starter kit" for any protection type and get a full folder with source, run scripts, config, and README

---

## Installing in Claude Cowork

1. Clone or download this repository
2. In Claude, Go to Settings → Capabilities → Skills → Customize → Upload a skill
3. Import the zip to use the skill
4. The skill will be available as `/seclore-integration-assistant`

---

## Example questions

```

How do I initialize the SDK?

Give me sample code for Independent Rights protection.

I'm getting error -220133 when protecting a file. What's wrong?

What is Advanced Security and Advanced Privileges?

What XML do I pass for PROTECT_WITH_FILE_ID?

Create a sample code for External Reference protection.

What is the difference between protectX() and protectAndWrap()?

How do I implement the Policy Federation ARA callback service?

I'm getting ARAException: Unknown Response Status '0' — how do I fix it?

What XML should my /getaccessright endpoint return when a user has no access?

Should I use the DRM API Server or the Server SDK for my Python application?

Walk me through the full protect flow using the DRM API Server.

What storage options does the API Server support?

I'm getting DRM-1013 on every API call — how do I fix it?

What is the difference between fileStorageId and secloreFileId?
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
    ├── code-samples.md             ← Complete Java code samples for all protection types,
    │                                  XML reference, log4j2.xml spec, starter package spec
    ├── policy-federation-api.md   ← ARA callback API — request/response XML for Ping,
    │                                  GetAccessRight, GetFileInformation; access right values;
    │                                  offline access; watermark; testing guide; troubleshooting
    └── api-server-guide.md        ← DRM API Server — architecture, API vs SDK decision, all
                                       REST endpoints, file lifecycle, auth, storage options,
                                       deployment, error codes, best practices, sample code
```

---

## Versioning

| Version | Notes |
|---------|-------|
| v1.0 | Initial release — Seclore Java SDK Queries, Troubleshooting, Sample Codes |
| v1.1 | Added Policy Federation ARA callback API reference, testing guide, and troubleshooting |
| v1.2 | Added DRM API Server integration guide — REST endpoints, file lifecycle, auth, storage options, best practices, sample code |

---

## License

MIT License — free to use, fork, and adapt.
