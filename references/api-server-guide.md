# Seclore DRM API Server — Integration Guide

## 1. Overview

The Seclore DRM API Server is a RESTful middleware component that exposes Seclore file
protection and rights management capabilities as HTTP APIs. It sits between the integrating
application and the Seclore Policy Server, handling file storage, protection, unprotection,
and permission management without requiring the integrating application to use the Java SDK.

**Base path:** All endpoints are under `/seclore/drm/`

**Protocol:** HTTPS, JSON request/response bodies (except file upload which is multipart)

---

## 2. Architecture

```
CUSTOMER ENVIRONMENT
┌────────────────────────────────────────────┐
│  INTERNAL NETWORK                          │
│  ┌──────────────────────┐                  │
│  │  Integrating          │  (CCP/ERP/DLP/  │
│  │  Application          │   Custom App)    │
│  └────────┬─────────────┘                  │
│           │ HTTPS REST                     │
│           │ (Upload • Protect • Download)  │
│           ▼                                │
│  ┌──────────────────────┐  ┌─────────────┐ │
│  │  2. DRM API Server   │  │ DATA STORES │ │
│  │  REST/HTTPS Port 443 │◄►│ App DB      │ │
│  │  Customer-owned       │  │ File Storage│ │
│  │  (On-prem or Cloud)  │  └─────────────┘ │
│  └────────┬─────────────┘                  │
└───────────┼────────────────────────────────┘
            │ HTTPS REST (Port 443)
            ▼
┌────────────────────────────────────┐
│  SECLORE POLICY SERVER PLATFORM    │
│  Option A: Seclore-managed (AWS)   │
│  Option B: Customer-deployed       │
└────────────────────────────────────┘
```

Key points from the architecture:
- The DRM API Server is **customer-owned** and deployed in the customer's environment (on-premises or cloud)
- It is the only component that holds the actual file data — Policy Server never receives raw files
- It communicates with Policy Server over HTTPS on port 443
- It requires its own **Application Database** (tokens, PS config, file metadata) and **File Storage**
- The integrating application communicates only with the DRM API Server — never directly with Policy Server

---

## 3. API Server vs SDK — When to Use Which

Both achieve the same outcome (Seclore-protected files) but differ in deployment model
and integration effort.

| Factor | DRM API Server | Server SDK (Java) |
|--------|---------------|-------------------|
| **Integration language** | Any language (REST/HTTP) | Java only |
| **File handling** | Files uploaded to API Server over HTTP, then protected | Files must exist on disk of the machine running the SDK — file path required, no binary stream |
| **Output format** | HTML-wrapped only | HTML-wrapped (`protectAndWrap`) or native (`protectX`) |
| **Deployment** | API Server deployed as a separate on-premises service; integrating app calls it over HTTP | SDK JAR embedded directly in the integrating application |
| **3rd-party dependencies** | No Java SDK required in the integrating application | Requires Seclore SDK JARs and log4j2 in the application classpath |
| **Policy Federation** | Supported via External Reference ID endpoint | Supported via `PROTECT_WITH_HF_EXT_REF` |
| **Performance** | File travels over HTTP to API Server before protection; introduces network overhead | File stays on the local machine — no network transfer for the file itself; lower latency |
| **Maintenance** | Customers manage API Server upgrades independently | SDK JAR version must be updated in the application and redeployed |
| **Best for** | Non-Java applications, or Java apps that want to avoid SDK dependencies | Java applications where performance, security, and keeping the file local are priorities |

**Rule of thumb:**
- If your application **cannot use Java libraries** → use the DRM API Server
- If your application is **Java, or performance and data security are priorities** → use the Server SDK (the file never travels over the network for protection)
- A **Java application can also use the API Server** if the team wants to avoid consuming 3rd-party SDK libraries in their codebase

---

## 4. Use Cases

| Solution | Use Case |
|----------|----------|
| **CCP / Content Management** | Files downloaded or uploaded through the CCP are automatically protected by calling the Seclore API. The relevant Rights Management policy ensures secure information flow. |
| **DLP / CASB** | Files downloaded or uploaded through sanctioned or unsanctioned CASB applications are automatically protected. The policy allows files to be shared freely across and outside the enterprise boundary. |
| **Transactional Systems (ERP/CRM/HRM)** | Auto-generated and manually exported reports are automatically protected on export. |
| **Custom Applications** | A custom application (e.g., Risk Containment at a bank) protects files shared with external verification agencies — only authorized users can view them. |
| **BI & Analytics Tools** | Reports downloaded or shared as emails are automatically protected. Sensitive reports remain secure outside the application. |

---

## 5. File Lifecycle and Communication Flow

**Verified directly against the DRM API Server 3.5.0.0 offline deployment package** (the
compiled server JAR, the installation/admin-console/swagger-testing guides, and the bundled
sanity-test script) — this is the ground truth for the current release, superseding anything
in this guide sourced only from the public developer portal. See Section 6 for how the two
sources agree and the handful of places the portal turned out to be wrong.

**There is no login step in the current model.** Generate an API key once from the Admin
Console and send it as `Authorization: Bearer <api-key>` on every call:

```
1. Upload File     →  POST /filestorage/1.0/upload  (multipart/form-data)
                      Returns: fileStorageId

2. Protect         →  POST /1.0/protect/{type}
                      Input: fileStorageId + protection params
                      Returns: new fileStorageId (protected file) + secloreFileId

3. Download        →  GET  /filestorage/1.0/download/{fileStorageId}
                      Returns: the protected (HTML-wrapped) file

4. Delete original →  DELETE /filestorage/1.0/{fileStorageId}
                      (Delete the unprotected copy uploaded in step 1)
```

The unprotection flow is symmetrical:
```
1. Upload protected file  →  POST /filestorage/1.0/upload
2. Unprotect              →  POST /1.0/unprotect
                              Returns: new fileStorageId (unprotected file)
3. Download unprotected file
4. Delete
```

**Important behaviour:**
- Protected files are **automatically deleted** from the API Server after download
- Unprotected (uploaded) copies are **automatically deleted** after a configurable timeout
- The delete-one and delete-all file storage APIs can be used to clean up explicitly
- Every API call except `/health`, `/healthcheck`, and `/version` requires a valid `Authorization: Bearer <api-key>` header

---

## 6. Authentication

**Current model: API Key.** Generate a key from the Admin Console (`https://<FQDN>/seclore/drm/admin`)
for the Application you're integrating, and send it on every request:

```
Authorization: Bearer <api-key>
```

`/health`, `/healthcheck`, and `/version` are public and don't require it. Everything else does.

**The JWT login/refresh/invalidate flow (Section 6.4 below) is deprecated but still works.**
Straight from the source shipped with the 3.5.0.0 offline package:
- `drm_secrets.properties`: *"DEPRECATED: JWT-based REST API authentication is deprecated in
  favor of API Key authentication (see the Admin Console API key management endpoints)."*
- The Swagger Testing Guide: *"The JWT-based Login/Refresh/Invalidate endpoints in the
  auth-controller section are deprecated and will be removed in a future release — do not use
  them for new integrations."*
- The Admin Console Usage Guide FAQ: *"Can JWT and API key authentication be used at the same
  time? Yes. Both methods work on all the same protected endpoints in this release. An
  individual API call uses whichever token is present in its Authorization header. Different
  integrations can use different methods against the same server. Future release will not be
  supporting JWT."*

So the two mechanisms coexist for now — a Swagger UI "Authorize" field or an `Authorization`
header will accept either an API key or a legacy JWT access token, auto-detected by the
server — but only the API key model has a future. Build new integrations on it.

### 6.1 Getting an API key

API keys can **only** be created or revoked through the Admin Console — there is no REST
endpoint for API key management. The flow:
1. An admin logs into the Admin Console and creates (or already has) an **Application** —
   this maps to an Enterprise Application (EA) configured on the Policy Server, and needs the
   EA ID, EA passphrase, and Policy Server URL.
2. On that Application, the admin creates an API key with a label (e.g. `ERP Integration`).
   The full key is shown **once**, at creation time, and can't be retrieved again — it must be
   copied immediately into a secrets manager or vault.
3. Give that key to the integrating application; it doesn't expire on a timer, so there's no
   refresh flow to build. Rotate it periodically by creating a new key, cutting the
   integration over, then deleting the old one (the old key keeps working during the overlap).

If you don't have Admin Console access yourself, this is the point where you loop in whoever
runs your DRM API Server deployment — see `references/api-server-config-guide.md` for the
full walkthrough and who to contact.

### 6.2 Common request headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | **Mandatory** (except `/health`, `/healthcheck`, `/version`) | `Bearer <api-key>` |
| `X-SECLORE-CORRELATION-ID` | Optional | Custom request ID passed through to server logs — use it to correlate a request across your logs and Seclore's for debugging |
| `Content-Type` | Conditional | `application/json` for JSON bodies; `multipart/form-data` for file upload |

> **Note:** this header's name is confirmed directly from the `AuthController`/`FileStorageController`
> classes in the shipped server JAR: `X-SECLORE-CORRELATION-ID`. If you've seen a different
> name (e.g. `X-SECLORE-REQUEST-ID`) in an older integration or sample script, that script is
> just choosing its own local variable name for a value it sends under this header, or is
> simply out of date — `X-SECLORE-CORRELATION-ID` is what the server itself defines.

### 6.3 Error response schema

```json
{
  "errorCode":    "string",
  "errorMessage": "string"
}
```

### 6.4 Legacy JWT flow (deprecated, still functional in 3.5.0.0)

Kept here for integrations still migrating off it — do not build new integrations against this.

**Login — POST** `/seclore/drm/1.0/auth/login`

Generates an access token and refresh token using the tenant credentials configured in the
API Server's environment variables.

**Request:**
```json
{
  "tenantId": "your-tenant-id",
  "tenantSecret": "your-tenant-secret"
}
```

**Response (200):**
```json
{
  "accessToken": "eyJhbGci...",
  "refreshToken": "eyJhbGci..."
}
```

- `tenantId` and `tenantSecret` are set in the API Server's configuration (environment variables), not in Policy Server
- The access token defaults to **15-minute expiry** (configurable); the refresh token to 60 minutes
- Pass the access token as `Authorization: Bearer <accessToken>` on every subsequent call

**Refresh — POST** `/seclore/drm/1.0/auth/refresh`

```json
{ "refreshToken": "eyJhbGci..." }
```

Returns a new `accessToken` + `refreshToken`. Use this when the access token expires to avoid
re-authenticating from scratch.

**Invalidate — POST** `/seclore/drm/1.0/auth/invalidate`

Explicitly invalidates both tokens (logout).

```json
{
  "accessToken": "...",
  "refreshToken": "..."
}
```

### 6.5 Token handling best practices (legacy JWT flow only)

- Cache the access token and reuse it across requests until it expires — do not call `/login` before every file operation
- Implement refresh-on-401: catch `DRM-1013` (token expired), call `/refresh`, retry the original request
- Store tokens in memory only — do not persist to disk or logs
- The API Server validates the token signature on every call; a tampered token returns `DRM-1014`

On the API key model, the equivalent practice is: store the key in a secrets manager, not in
code or logs, and rotate it from the Admin Console per your security policy.

---

## 7. File Storage APIs

All file storage endpoints are under `/seclore/drm/filestorage/`.

### 7.1 Upload File

**POST** `/seclore/drm/filestorage/1.0/upload`

Upload a file to the API Server before protection or unprotection. The file is stored with a
unique `fileStorageId`.

**Content-Type:** `multipart/form-data`

The file is sent as a binary multipart field (see Section 11 — File Transfer Concepts).

**Response:**
```json
{
  "fileStorageId": "abc123",
  "fileName": "report.docx",
  "downloadUrl": "https://api-server/download/abc123",
  "fileType": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "fileSize": 204800,
  "secloreFileId": null,
  "protected": false
}
```

`fileStorageId` is the handle used in all subsequent protect/download/delete calls.

### 7.2 Download File

**GET** `/seclore/drm/filestorage/1.0/download/{fileStorageId}`

Returns the file binary. Use this after protection to retrieve the HTML-wrapped file, or
after unprotection to retrieve the decrypted file.

The response includes a `Content-Disposition: attachment; filename="<originalname>.html"`
header — use this to derive the output filename rather than hardcoding it:

```python
cd = response.headers.get("Content-Disposition", "")
filename = cd.split("filename=")[-1].strip('"') if "filename=" in cd else "protected_file.html"
```

> **Note:** Protected files are automatically deleted from the API Server after download.
> You get one attempt — if the download fails mid-stream, you must re-protect with the same file storage ID.
> Buffer the response to a temp file first, then move to the final destination to avoid
> partial-write failures.

### 7.3 List Files

**GET** `/seclore/drm/filestorage/1.0/files`

Returns metadata for **all** files currently stored in the file storage for the logged-in
tenant.

**Response (200)** — array of the same object shape as Upload File / Get File Info:
```json
[
  {
    "fileStorageId": "string",
    "fileName": "string",
    "downloadUrl": "string",
    "fileType": "string",
    "fileSize": 0,
    "secloreFileId": "string | null",
    "protected": true
  }
]
```

### 7.4 Get File Info

**GET** `/seclore/drm/filestorage/1.0/file/{fileStorageId}`

Returns metadata for a **specific** file by its storage ID.

| Parameter     | Type   | Required | Description                        |
|---------------|--------|----------|-------------------------------------|
| fileStorageId | string | true     | Storage ID of the file to retrieve |

**Response (200)**:
```json
{
  "fileStorageId": "string",
  "fileName": "string",
  "downloadUrl": "string",
  "fileType": "string",
  "fileSize": 0,
  "secloreFileId": "string | null",
  "protected": true
}
```

### 7.5 Delete File

**DELETE** `/seclore/drm/filestorage/1.0/{fileStorageId}`

Deletes a specific file. Use this to clean up the unprotected original after protection is
confirmed.

> **Path correction, confirmed against the `FileStorageController` class in the server JAR:**
> earlier versions of this guide used `/seclore/drm/filestorage/1.0/delete/{fileStorageId}` —
> with a `/delete/` segment. There is no such segment; the mapping is a bare `DELETE` on
> `/{fileStorageId}` under the `/filestorage/1.0` base path. Update any hardcoded URLs.

| Parameter     | Type   | Required | Description                      |
|---------------|--------|----------|-----------------------------------|
| fileStorageId | string | true     | Storage ID of the file to delete |

### 7.6 Delete All Files

**DELETE** `/seclore/drm/filestorage/1.0`

Deletes **all** files from the file storage of the currently logged-in tenant. Use with
caution — this action cannot be undone.

---

## 8. Protection APIs

All protection endpoints are under `/seclore/drm/1.0/protect/`.

Each returns the `fileStorageId` of the **newly protected** file and the `secloreFileId`
assigned by Policy Server:

```json
{
  "fileStorageId": "protected-xyz",
  "secloreFileId": "SECLORE-FILE-UUID"
}
```

> **`DL_` prefix:** The `fileStorageId` returned by all protect endpoints is always prefixed
> with `DL_`. This prefix signals that the file will be **auto-deleted after download** —
> it is how the API Server distinguishes protected output files from raw uploaded files in
> storage. Upload IDs have no prefix. You can use this as a lightweight guard in your code:
> ```python
> if not protected_file_storage_id.startswith("DL_"):
>     raise ValueError(f"Protect response returned unexpected ID: {protected_file_storage_id}")
> ```

### 8.1 Protect with Hot Folder

**POST** `/seclore/drm/1.0/protect/hf`

Protects the file using a pre-defined policy from a Hot Folder in Policy Server. The policy
(who can access, what they can do) is configured centrally in PS — the application just
supplies the Hot Folder ID.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `hotfolderId` | **Mandatory** | ID of the Hot Folder created in Policy Server |
| `fileStorageId` | **Mandatory** | File Storage ID received from the Upload API |

```json
{
  "hotfolderId": "12345",
  "fileStorageId": "abc123"
}
```

**When to use:** Policy is uniform across many files (e.g., all documents in a department
use the same access rules). Simplest integration path.

### 8.2 Protect with Independent Rights

**POST** `/seclore/drm/1.0/protect/independent`

Protects the file with access rights defined at protection time. The application specifies
exactly who can access the file, what rights they have, and any expiry or IP restrictions.

**Parameter reference** (field names confirmed against the `ProtectionDetail` and
`AccessRightDetail` request classes in the server JAR):

| Parameter | Required | Description |
|-----------|----------|-------------|
| `fileStorageId` | **Mandatory** | File Storage ID received from the Upload API |
| `protectionDetails` | **Mandatory** | Protection configuration object |
| `protectionDetails.ownerEmailId` | **Mandatory** | Email address of the document owner |
| `protectionDetails.classificationId` | Optional | Seclore Classification label ID for the document |
| `protectionDetails.credentialIds` | Optional | Policy credential IDs to associate with the file |
| `protectionDetails.accessRightMappings` | Optional (schema-level) | List of access right configurations for users/groups — omit only if the file needs no recipients |
| `accessRightMappings[].entities` | **Mandatory** if the mapping is present | Recipient email(s)/group email(s) to grant access to |
| `accessRightMappings[].primaryAccessRight` | **Mandatory** if the mapping is present | Access permissions list (see table below) |
| `accessRightMappings[].offline` | **Mandatory** if the mapping is present | Allow offline access to the document |
| `accessRightMappings[].redistribute` | **Mandatory** if the mapping is present | Allow sharing/forwarding the document |
| `accessRightMappings[].lockToFirstMachine` | Optional | Restrict access to the first device on which the file is opened |
| `accessRightMappings[].daysSinceProtection` | Optional | Expire access N days after protection date |
| `accessRightMappings[].daysSinceFirstAccess` | Optional | Expire access N days after first open |
| `accessRightMappings[].ipRangeAccess` | Optional | Block access from specified IP ranges |

> **Correction:** this field was previously documented here as `protectionDetails.classification`
> (a plain string). The server's `ProtectionDetail` class annotates it `@JsonProperty("classificationId")`
> — the correct field is `protectionDetails.classificationId`.

```json
{
  "fileStorageId": "abc123",
  "protectionDetails": {
    "ownerEmailId": "owner@example.com",
    "classificationId": "your-classification-id",
    "credentialIds": [],
    "accessRightMappings": [
      {
        "entities": [
          { "emailId": "alice@example.com", "type": "user" }
        ],
        "primaryAccessRight": ["read", "print"],
        "offline": false,
        "redistribute": false,
        "lockToFirstMachine": false,
        "daysSinceProtection": 30,
        "daysSinceFirstAccess": null,
        "ipRangeAccess": []
      }
    ]
  }
}
```

**`primaryAccessRight` values:**

| Value | What it grants |
|-------|---------------|
| `read` | View only (requires Seclore Agent) |
| `liteviewer` | View in browser (no agent needed) |
| `print` | Print |
| `edit` | Edit (Office files) |
| `full_control` | All rights except owner |
| `copy_data` | Copy/paste content |
| `screen_capture` | Screen capture |
| `macro` | Run macros |

**When to use:** Recipients and their rights are known at protection time and vary per file.
Examples: contracts with named parties, reports for specific users.

### 8.3 Protect with Seclore File ID

**POST** `/seclore/drm/1.0/protect/fileid`

Protects a new file using the Seclore File ID of an already-protected file. The new file
gets the same policy, same encryption key, and the same Seclore File ID as the original —
this is the API Server's equivalent of the SDK's `PROTECT_WITH_FILE_ID` / the Hot Folder
"protect with same file external reference ID" dedup behaviour described in
`references/sdk-guide.md` (reuse the file storage identifier and Seclore copies over the
original's policy, key, and permissions).

| Parameter | Required | Description |
|-----------|----------|-------------|
| `fileStorageId` | **Mandatory** | New file to protect |
| `existingProtectedFileId` | **Mandatory** | Seclore file ID to copy permissions from |

```json
{
  "fileStorageId": "new-upload-id",
  "existingProtectedFileId": "SECLORE-FILE-UUID"
}
```

> **Field name confirmed against the server's `FileIdProtectionDetail` request class:**
> `@JsonProperty("existingProtectedFileId")`. The public developer portal's field reference
> table names this `existingSecloreProtectedFileId` (its own cURL example on the same page
> contradicts that and uses `existingProtectedFileId`) — that table is wrong. The field is
> `existingProtectedFileId`, full stop.

**When to use:** Multiple downloads of the same source document (e.g., a report generated
for many users). All copies are treated as identical from a DRM perspective.

### 8.4 Protect with External Reference ID (Policy Federation)

**POST** `/seclore/drm/1.0/protect/externalref`

Protects the file with the integrating application's unique file identifier. Policy Server
will call back to the application's ARA service at file-open time to fetch access rights
dynamically.

```json
{
  "hotfolderExternalReference": {
    "externalReferenceId": "FOLDER-123",
    "externalReferenceName": "HR Documents",
    "externalReferenceData": null,
    "externalAppId": null
  },
  "fileExternalReference": {
    "externalReferenceId": "FILE-456",
    "externalReferenceName": "Q1 Payroll",
    "externalReferenceData": null,
    "externalAppId": null
  },
  "fileStorageId": "abc123"
}
```

**Parameter guidance:**

| Field | Required | Notes |
|-------|----------|-------|
| `hotfolderExternalReference.externalReferenceId` | Yes | Must match the External Reference ID configured on the Hot Folder in Policy Server (case-sensitive) |
| `fileExternalReference.externalReferenceId` | Recommended | This is the ID returned in the ARA callback as `<ext-id>`. Use your application's file ID. If no file-level ID exists, construct one (e.g., `fileId_folderId_dept`) |
| `*Name`, `*Data`, `*AppId` | Optional | Metadata passed to your ARA service in the callback |

**When to use:** Access control is managed in the integrating application, not in Policy Server. Rights
can change after protection without re-protecting the file.

For ARA callback implementation, see `references/policy-federation-api.md`.

---

## 9. Unprotect API

**POST** `/seclore/drm/1.0/unprotect`

There is a single unprotect endpoint — the same one is used for both standard unprotect and
Unprotect Any File. Which behavior you get depends entirely on how the calling **Application**
is configured in the Admin Console, not on a different endpoint or request parameter:

| Application configuration | What `/unprotect` can decrypt |
|---|---|
| Standard (Advanced Security off, or on without Advanced Privileges) | Only files protected under a Hot Folder owned by this Application's mapped EA |
| Advanced Security **+ Allow Advanced Privileges** checked in the Admin Console, **and** the "Unprotect any file" privilege also enabled on that EA in Policy Server | **Any** file on that Policy Server, regardless of which EA originally protected it |

This mirrors the Server SDK's Advanced Security + Advanced Privileges model exactly (Mode 4 /
`references/sdk-guide.md` Section 7) — Unprotect Any File is fully available through the REST
API, it's just an Application-configuration choice rather than a separate call. See
`references/api-server-config-guide.md` Section 2 for the Admin Console walkthrough (the "Allow
Advanced Privileges" checkbox).

```json
{
  "fileStorageId": "protected-xyz"
}
```

**Response:**
```json
{
  "fileStorageId": "unprotected-new-id"
}
```

The response contains a **new** `fileStorageId` pointing to the decrypted file. Download
it using the Download API.

---

## 10. Permission Management APIs

### 10.1 Get File Permissions

**GET** `/seclore/drm/1.0/filepermission/{fileStorageId}`

Returns the full access rights structure of a protected file — all users/groups, their
rights, expiry settings, IP restrictions, Hot Folder details, and applied policies.

**Response body:**
```json
{
  "classification": { "id": "string" },
  "accessRightMappings": [
    {
      "id": "string",
      "entity": {
        "id": "string",
        "repcode": 0,
        "type": 0
      },
      "primaryAccessRight": ["string"],
      "offline": true,
      "redistribute": true,
      "lockToFirstMachine": true,
      "daysSinceProtection": 0,
      "daysSinceFirstAccess": 0,
      "ipRangeAccess": [
        { "startIp": "string", "endIp": "string" }
      ],
      "creationTime": "string",
      "lastModifiedTime": "string"
    }
  ],
  "ownerEmailId": "string",
  "secloreFileId": "string",
  "fileName": "string",
  "hotFolderDetails": {
    "id": 0,
    "name": "string",
    "location": "string",
    "fileServerId": "string",
    "extnReferenceId": "string",
    "extnRefName": "string"
  },
  "policies": [
    { "policyId": 0, "policyName": "string" }
  ]
}
```

**Key response fields:**

| Field | Description |
|-------|-------------|
| `classification.id` | Classification label ID applied to the file (note: nested object in response, unlike flat string in request) |
| `accessRightMappings[].id` | ID of this access right entry — use as `accessRightId` in `removeAccessRightMappings` / `updateAccessRightMappings` |
| `accessRightMappings[].entity.id` | User/group identifier in Policy Server |
| `accessRightMappings[].entity.type` | Entity type (0 = user, etc.) |
| `hotFolderDetails` | Populated when file was protected via Hot Folder or External Reference |
| `policies` | Policies applied when protection used `credentialIds` |

### 10.2 Update File Permissions

**POST** `/seclore/drm/1.0/updatefilepermission`

Add, remove, or update permissions on an already-protected file without re-protecting it.
Rights changes take effect immediately for all subsequent file opens.

```json
{
  "secloreFileId": "SECLORE-FILE-UUID",
  "addCredentialIds": ["policy-id-1"],
  "removeCredentialIds": ["policy-id-2"],
  "addAccessRightMappings": [
    {
      "entity": [{ "emailId": "newuser@example.com", "type": "user" }],
      "primaryAccessRight": ["read"],
      "offline": false,
      "redistribute": false,
      "lockToFirstMachine": false,
      "daysSinceProtection": 0,
      "daysSinceFirstAccess": 0,
      "ipRangeAccess": [{ "startIp": "string", "endIp": "string" }]
    }
  ],
  "removeAccessRightMappings": [
    {
      "entity": [{ "emailId": "olduser@example.com", "type": "user" }],
      "primaryAccessRight": ["read"],
      "offline": true,
      "redistribute": true,
      "lockToFirstMachine": false,
      "daysSinceProtection": 0,
      "daysSinceFirstAccess": 0,
      "ipRangeAccess": [],
      "accessRightId": "access-right-mapping-id"
    }
  ],
  "updateAccessRightMappings": [
    {
      "entity": [{ "emailId": "existinguser@example.com", "type": "user" }],
      "primaryAccessRight": ["read", "print"],
      "offline": false,
      "redistribute": false,
      "lockToFirstMachine": false,
      "daysSinceProtection": 30,
      "daysSinceFirstAccess": 0,
      "ipRangeAccess": [],
      "accessRightId": "access-right-mapping-id"
    }
  ]
}
```

**Parameter notes:**

| Field | Description |
|-------|-------------|
| `secloreFileId` | Seclore File ID of the document to modify (from protect response or Get File Permissions) |
| `addCredentialIds` | Policy IDs to attach to the document |
| `removeCredentialIds` | Policy IDs to detach from the document |
| `addAccessRightMappings` | New user/group entries to add |
| `removeAccessRightMappings` | Entries to remove — include `accessRightId` (the `id` from Get File Permissions response) to target the exact mapping |
| `updateAccessRightMappings` | Existing entries to modify — include `accessRightId` to identify which mapping to update |

> **Tip:** Always call Get File Permissions first to retrieve the `accessRightMappings[].id`
> values needed in `removeAccessRightMappings.accessRightId` and
> `updateAccessRightMappings.accessRightId`.

**Success response:**
```json
{ "response": "Update is made successfully" }
```

---

## 11. Policy APIs

### 11.1 Get Policy Details

**GET** `/seclore/drm/1.0/policy/{identifier}`

Retrieve policy details by either:
- A **user email address** — returns all policies mapped to that user
- A **policy ID** — returns details of a specific policy

**Response (200)**:
```json
{
  "credentials": [
    {
      "id": "string",
      "name": "string",
      "owner": {
        "type": "string",
        "container": {
          "repCode": "string",
          "id": "string",
          "code": "string"
        }
      },
      "description": "string",
      "status": "string",
      "locked": "string",
      "creationTime": "string",
      "lmTime": "string",
      "createdBy": { "entity": { "id": "string", "repcode": 0, "type": 0 } },
      "lmBy":      { "entity": { "id": "string", "repcode": 0, "type": 0 } },
      "defaultApplicable": "string",
      "details": {
        "accessRightMappings": [
          {
            "entity": { "id": "string", "repcode": 0, "type": 0 },
            "primaryAccessRight": ["string"],
            "offline": 0,
            "redistibute": 0,
            "LockToFirstMachine": 0,
            "daysSinceProtection": 0,
            "daysSinceFirstAccess": 0,
            "ipRangeAccess": [{ "startIp": "string", "endIp": "string" }]
          }
        ]
      }
    }
  ]
}
```

> **Field-name quirk, confirmed against the `AccessRightResponse` class in the server JAR:**
> in this specific response (`GET /policy/{identifier}`), the redistribution flag is
> `@JsonProperty("redistibute")` — spelled without the second "r" — unlike every other
> endpoint in this guide (Update File Permission, Independent Rights, etc.), which use the
> correctly-spelled `redistribute`. This is a genuine inconsistency in the server's own JSON
> mapping, not a typo in this guide. If you're parsing this response into a typed object, use
> the misspelled key here specifically, or you'll silently get `null`/`undefined`.

Use `credentials[].id` as the `credentialId` when passing policies to `addCredentialIds` /
`removeCredentialIds` in the Update Permission API.

### 11.2 Send Custom Request

**POST** `/seclore/drm/1.0/sendrequest`

Sends a custom XML request directly to the Policy Server configured for the logged-in
tenant. Use this for advanced or non-standard Policy Server operations not covered by
the other protection or permission APIs (e.g. proprietary policy queries, custom
federation requests).

Requires `Authorization: Bearer <api-key>`

| Field       | Type   | Required | Description                                   |
|-------------|--------|----------|-----------------------------------------------|
| requestType | string | true     | The type of request to send to Policy Server  |
| requestBody | string | false    | XML body content for the request              |

**Response (200)**:
```json
{ "response": "<raw Policy Server XML response>" }
```

**Example**:
```bash
curl -X POST https://your-server/seclore/drm/1.0/sendrequest \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -d '{"requestType": "GetUserDetails", "requestBody": "<xml>...</xml>"}'
```

> Use `sendrequest` when the SDK's `FSHelper.sendRequest()` equivalent is needed via
> the REST API — useful in environments where the Java SDK cannot be deployed directly.

---

## 12. Classification APIs

Apply, update, query, and remove classification labels on files. Labels are configured
in the Policy Server and control how files are categorised for sensitivity, compliance,
and visual marking. All endpoints require `Authorization: Bearer <api-key>`. Classification
works automatically whenever Advanced Security is enabled for the Application/EA — there's no
separate feature flag for it; if Advanced Security isn't enabled, these calls won't work.

> **Response schema correction, confirmed against the server's `FileClassificationResponse`
> and `ClassificationLabelInfo` response classes:** an earlier version of this guide documented
> Classify/Reclassify/Declassify as returning a flat `{ fileStorageId, labelId, labelName }`
> shape. That's wrong. All three actually return `{ id, currentLabel, oldLabel }`, where `id`
> is `@JsonProperty("id")` on the classification ID field and `currentLabel`/`oldLabel` are
> each the **full label object** shown below. Update any parsing code built against the old
> flat shape.

The full label object shape returned by `currentLabel` / `oldLabel` (Classify, Reclassify,
Declassify) and by `classificationInfo` (Get File Classification) and by each entry in
`labels[]` (Get All Labels) is:

```json
{
  "id":               "string",
  "parentId":         "string",
  "sensitivity":      0,
  "name":             "string",
  "description":      "string",
  "tooltip":           "string",
  "color":            "string",
  "visualMarking": {
    "email": {
      "headerText": "string", "footerText": "string",
      "fontColor": "string", "fontSize": 0, "textAlignment": "string"
    },
    "document": {
      "headerText": "string", "footerText": "string",
      "fontColor": "string", "fontSize": 0, "textAlignment": "string"
    }
  },
  "sublabels":        ["string"],
  "status":           "string",
  "creationTime":     "string",
  "lastModifiedTime": "string",
  "createdByUserId":  "string"
}
```

---

### 12.1 Classify File

**POST** `/seclore/drm/1.0/classification/classify`

Applies a classification label to a file using a `labelId` from the Policy Server.

| Field             | Type    | Required | Description                                  |
|-------------------|---------|----------|----------------------------------------------|
| fileStorageId     | string  | true     | File to classify                             |
| labelId           | string  | true     | Classification label ID from Policy Server   |
| forceLabelRefresh | boolean | false    | Force refresh of the label cache before applying |

**Response (200)** — returns the applied label and the previous label (see full shape above):
```json
{
  "id": "string",
  "currentLabel": { "...": "full label object" },
  "oldLabel":     { "...": "full label object" }
}
```

**Example**:
```bash
curl -X POST https://your-server/seclore/drm/1.0/classification/classify \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -d '{"fileStorageId": "<id>", "labelId": "<label_id>"}'
```

---

### 12.2 Reclassify File

**POST** `/seclore/drm/1.0/classification/reclassify`

Updates the label on an already-classified file.

| Field             | Type    | Required | Description                  |
|-------------------|---------|----------|-------------------------------|
| fileStorageId     | string  | true     | File to reclassify           |
| labelId           | string  | true     | New classification label ID  |
| forceLabelRefresh | boolean | false    | Force refresh of label cache |

**Response (200)** — same `{ id, currentLabel, oldLabel }` shape as Classify (Section 12.1),
with `currentLabel` holding the new label and `oldLabel` the previous one.

---

### 12.3 Declassify File

**POST** `/seclore/drm/1.0/classification/declassify`

Removes the classification label from a file. DRM protection is unaffected — only the
label is removed.

| Field             | Type    | Required | Description                  |
|-------------------|---------|----------|-------------------------------|
| fileStorageId     | string  | true     | File to declassify           |
| forceLabelRefresh | boolean | false    | Force refresh of label cache |

**Response (200)** — same `{ id, currentLabel, oldLabel }` shape as Classify (Section 12.1),
returning the removed label and the previous label state.

---

### 12.4 Get All Classification Labels

**GET** `/seclore/drm/1.0/classification/labels`

Returns all labels configured in the Policy Server, including nested sublabels,
sensitivity levels, colours, and visual markings.

| Field             | Type    | Required | Description                      |
|-------------------|---------|----------|----------------------------------|
| fileStorageId     | string  | **true** | File providing the classification context for this request |
| forceLabelRefresh | boolean | false    | Force refresh of the label cache |

> **Confirmed against the server's `GetClassificationLabelsRequest` class:** `fileStorageId`
> is annotated `@NotNull` there ("fileStorageId is required."), so it **is** mandatory. An
> earlier pass at this guide — sourced only from the public developer portal — said this field
> wasn't required at all; that portal page is wrong. The compiled server code is authoritative.

Use `forceLabelRefresh: true` when label config changes recently; avoid in
high-throughput paths due to cache rebuild cost.

---

### 12.5 Get File Classification

**GET** `/seclore/drm/1.0/classification/{fileStorageId}`

Returns the current classification label on a specific file.

**Response (200)**:
```json
{
  "classified": true,
  "classificationInfo": { "...": "full label object, see Section 12 intro" }
}
```

---

### 12.6 Classification Workflow Notes

- To classify during protection, pass `protectionDetails.classificationId` (plain string,
  the label ID) inside the request body of `/protect/independent` — see Section 8.2. This
  field was previously documented as `protectionDetails.classification`; the server's
  `ProtectionDetail` class annotates it `@JsonProperty("classificationId")`.
- The *response* from Get File Permissions returns classification as a nested
  `{ "id": "string" }` object under the `classification` key (confirmed against
  `FilePermissionResponse`/`ClassificationResponse`, Section 10.1), while the
  classify/reclassify/declassify/get endpoints in this section return the full label object
  under `currentLabel`/`classificationInfo` — different shapes for different purposes.
- Declassification removes only the label — DRM rights remain intact.
- `forceLabelRefresh` bypasses the server-side label cache; use sparingly.
- Labels (`labelId`) must be pre-configured in the Policy Server before calling these APIs.
- Classification requires Advanced Security to be enabled on the Application/EA — it isn't a
  separate toggle.

---

## 13. Utility APIs (App Info)

There are **three** distinct health-related endpoints — confirmed against `AppInfoController`
in the server JAR, and the third (`/healthcheck`) isn't on the public developer portal at all:

### 13.1 Health Check

**GET** `/seclore/drm/health`

Returns overall health status, including the Policy Server. Per the endpoint's own Javadoc in
the server code: *"depends on the policy server; use /healthcheck instead"* for a check that
doesn't depend on an external system. No authentication required.

```json
{
  "status": "UP",
  "components": {
    "policyServer": "UP",
    "<fileStorageComponent>": "UP",
    "applicationDatabase": "UP"
  }
}
```

> **Correction:** an earlier version of this guide showed the file-storage component key as a
> fixed `"databaseFileStorage"`. It isn't fixed — the key name comes from whichever storage
> backend is configured via `filestorage_repository_impl` (Section 16.3 / the config guide):
> `diskFileStorage` (disk/NAS, the on-prem default), `databaseFileStorage` (DB-backed storage),
> or `s3FileStorage` (S3). Only one of the three appears, matching your deployment's actual
> configuration — don't assume any single name.

`status` is `DOWN` (HTTP 503) if any component is down. Use this endpoint for a full readiness
probe when Policy Server reachability matters to you.

### 13.2 Core Health Check

**GET** `/seclore/drm/healthcheck`

Checks only the DRM API Server's own components (file storage, application database) — **not**
the Policy Server. No authentication required. Same response shape as 13.1, minus the
`policyServer` entry. Use this when you want to know the API Server process itself is up
without that check's result depending on an external Policy Server being reachable.

### 13.3 Application Health

**GET** `/seclore/drm/application/health`

Health status scoped to the specific Application/tenant identified by your API key, rather
than the DRM API Server as a whole. Requires `Authorization: Bearer <api-key>`.

```json
{
  "status": "UP",
  "components": {
    "policyServer": "UP",
    "<fileStorageComponent>": "UP",
    "applicationDatabase": "UP"
  }
}
```

Responses: `200` (UP), `503` (DOWN), `404` (application not found for the given API key), `500`
(internal server error). Use this when you specifically need to know whether *your* tenant's
connectivity is healthy, as distinct from the shared service overall (13.1/13.2).

### 13.4 Version

**GET** `/seclore/drm/version`

Returns the current version string of the DRM API Service as plain text (not JSON). No
authentication required. Useful for verifying which build is deployed — e.g. to confirm you're
actually on 3.5.0.0 before relying on API-key auth.

---

## 14. File Transfer Concepts

### 14.1 Multipart Upload

File upload uses `multipart/form-data` — the standard HTTP mechanism for binary file transfer.
The file is sent as a binary part of the request body, not as a base64 string.

**curl example:**
```bash
curl -X POST "https://api-server/seclore/drm/filestorage/1.0/upload" \
  -H "Authorization: Bearer <accessToken>" \
  -F "file=@/path/to/document.docx"
```

**Java (OkHttp) example:**
```java
RequestBody fileBody = RequestBody.create(
    MediaType.parse("application/octet-stream"),
    new File("/path/to/document.docx")
);

RequestBody requestBody = new MultipartBody.Builder()
    .setType(MultipartBody.FORM)
    .addFormDataPart("file", "document.docx", fileBody)
    .build();

Request request = new Request.Builder()
    .url("https://api-server/seclore/drm/filestorage/1.0/upload")
    .addHeader("Authorization", "Bearer " + accessToken)
    .post(requestBody)
    .build();
```

### 14.2 Binary vs Stream

The Seclore DRM API Server does **not** support streaming input — the file must be
completely uploaded before protection starts. This is a two-step process:

1. **Upload** — full file transferred to API Server (returns `fileStorageId`)
2. **Protect** — API Server protects the stored file (returns new `fileStorageId`)

This differs from the Server SDK, which requires the file on the local disk of the server
running the SDK. With the API Server, the file is transferred over HTTP and held in the
configured storage backend (disk, S3, or database) during processing.

### 14.3 Download after protection

The Download API returns the file as a binary response stream. The integrating application
reads the response body directly and writes it to disk or forwards it to the end user.

```java
// Java (HttpClient) — stream to file
HttpResponse<InputStream> response = httpClient.send(request,
    HttpResponse.BodyHandlers.ofInputStream());

try (InputStream in = response.body();
     FileOutputStream out = new FileOutputStream("protected-doc.html")) {
    in.transferTo(out);
}
```

### 14.4 File size considerations

Large files increase upload latency. For high-throughput environments:
- Use storage backends co-located with the API Server (S3 in same AWS region, or local disk)
- Avoid database file storage for large files (> a few MB) — it is best suited for metadata or small documents
- Set appropriate HTTP client timeouts — a large file upload + protection cycle may take several seconds

---

## 15. Storage Options

The API Server supports three storage backends for the files it handles:

| Storage | Best for | Notes |
|---------|----------|-------|
| **Disk / Shared Folder** | On-premises deployments | Can use network shares, AWS EFS, Azure Files for horizontal scaling |
| **S3** | AWS deployments | Preferred for AWS — files stored directly in S3; no shared filesystem needed |
| **Database** | Simple deployments or small files | MSSQL Server, Oracle, PostgreSQL, or MySQL. Not recommended for large file volumes. |

The **Application Database** (always required) stores only transient metadata: access tokens,
Policy Server identifiers, and file metadata. The database itself does not need to be
large — any supported RDBMS works.

---

## 16. Deployment and Setup

### 16.1 Where to deploy

| Option | Description |
|--------|-------------|
| **Seclore-managed (AWS)** | Seclore hosts and manages the API Server on AWS. The integrating application calls it over the internet. Requires an `x-api-key` header on every call. |
| **Customer-deployed (On-prem or cloud)** | Customer deploys the API Server in their own environment — on-premises servers, AWS, Azure, or any cloud. No `x-api-key` required. Recommended for data-sensitive environments. |

> **Don't confuse this with the `Authorization: Bearer <api-key>` header from Section 6.**
> `x-api-key` here is a separate, deployment-level header that only applies if Seclore is
> hosting your API Server instance on AWS. The 3.5.0.0 offline package (which this guide is
> otherwise verified against) is the **customer-deployed** artifact and doesn't cover the
> Seclore-managed path, so this row is carried over from the public developer portal, not
> independently reverified this pass. The `Authorization` header is the per-application
> authentication credential and is required regardless of deployment model.

### 16.2 Why customer-side deployment is recommended

The API Server handles **raw, unencrypted files** during the upload → protect → download
cycle. Files are in plaintext on the API Server storage between upload and protection.
Deploying in the customer environment ensures:
- Files never leave the customer's network boundary in plaintext
- Full control over storage, logging, and network access
- Compliance with data residency requirements

### 16.3 Required configuration

Before the first API call, the API Server must be configured with:
- **Seclore Policy Server** URL, EA ID, and EA Passphrase — entered per Application, via the Admin Console (Section 6.1) rather than a single server-wide value
- **Database** connection string (any supported RDBMS) — for the required Application Database
- **File Storage** backend (`filestorage_repository_impl`): disk/NAS (`DiskFileStorage`, the on-prem default), S3 (`S3FileStorage`), or database (`DBFileStorage`) — this choice also determines which key name shows up in the health check response (Section 13.1)
- **Admin Console credentials** (`DRM_ADMIN_PASSWORD`, username fixed as `drmadmin`) and `DRM_INTERNAL_SECRET_KEY` — new as of 3.5.0.0, for the Admin Console itself
- **Tenant ID and Tenant Secret** — only needed if you're still using the deprecated JWT Login flow (Section 6.4); not required for the API Key model
- **File cleanup timeout** for unprotected uploads

Configuration is typically done via properties files supplied at deployment time — this is set
up by whoever administers the server, not something a developer configures via the API. For what
needs to exist before you can call the API, the Admin Console API key walkthrough, and who to
contact for each part, see `references/api-server-config-guide.md`.

---

## 17. Error Codes

### Generic

| Code | HTTP | Description |
|------|------|-------------|
| DRM-1000 | 500 | Unhandled exception — check server logs |
| DRM-1001 | 400 | Bad request |
| DRM-1002 | 404 | Resource not found |
| DRM-1003 | 404 | Endpoint not found |
| DRM-1004 | 400 | HTTP message parse error |
| DRM-1005 | 500 | Startup error |
| DRM-1006 | 429 | Too many requests |
| DRM-1007 | — | Generic message from API Server |

### Authentication

| Code | Description | Fix |
|------|-------------|-----|
| DRM-1010 | Unauthorised request | API key (or, on the legacy flow, token) missing or invalid |
| DRM-1011 | Access token not sent | Add `Authorization: Bearer <api-key>` header |
| DRM-1012 | Error generating tokens | Legacy JWT flow only — check tenant credentials in API Server config |
| DRM-1013 | Token expired | Legacy JWT flow only — call `/auth/refresh` to get a new token; not applicable to the API key model, which doesn't expire on a timer |
| DRM-1014 | JWT signature mismatch | Legacy JWT flow only — token tampered or from wrong issuer; re-login |
| DRM-1015 | Invalid refresh token | Legacy JWT flow only — refresh token expired or invalid; re-login |

> DRM-1012/1013/1014/1015 apply to the deprecated JWT login flow (Section 6.4). On the current
> API key model, an invalid or revoked key surfaces as DRM-1010/1011 (401) — there's no
> separate "expired" code because API keys don't expire on a timer, only on manual revocation.

### Seclore SDK (returned when API Server calls PS on your behalf)

| Code | Description | Fix |
|------|-------------|-----|
| DRM-1100 | File already protected | Pre-check: do not upload already-protected files for re-protection |
| DRM-1101 | File extension not supported | Check Seclore's supported file types list |
| DRM-1102 | File does not support HTML wrapping | API Server only produces HTML-wrapped output — unsupported file |
| DRM-1104 | Error fetching users from PS | Check PS connectivity and EA config |
| DRM-1105 | Failed to initialize EA | EA ID or passphrase wrong in API Server config; verify in PS admin |

### File Storage

| Code | Description | Fix |
|------|-------------|-----|
| DRM-1200 | File does not exist | Verify `fileStorageId` is correct |
| DRM-1201 | Failed to update file timestamp | Storage permissions issue |
| DRM-1202 | File with storage ID not present | File may have been auto-deleted after download or timeout |
| DRM-1203 | File not found on path | Storage backend issue — check disk/S3/DB configuration |

---

## 18. Best Practices

### 18.1 Security

**API key management (current model):**
- Store the API key in a secrets manager, not in code, config files committed to source control, or logs
- Generate a distinct API key per integrating application/team — don't share one key across unrelated integrations (the Admin Console's key label is designed for this: "CI Pipeline - Production", "ERP Integration", etc.)
- Rotate without downtime: create the new key, cut the integration over, verify it, then delete the old one — the old key keeps working until you explicitly delete it
- Transmit it only over HTTPS; never embed it in client-side code
- A deleted key stops working immediately on the node it was deleted from; on other nodes in a multi-instance deployment, within about a minute

**File handling:**
- Delete the unprotected upload immediately after protection is confirmed:
  `DELETE /seclore/drm/filestorage/1.0/{originalFileStorageId}`
- Do not store `fileStorageId` values beyond the immediate request/response lifecycle — they are transient handles

**Network:**
- Deploy the API Server in the DMZ / Integration Zone, not in the public internet segment
- Restrict API Server → Policy Server traffic to port 443 from the API Server's IP only
- Use TLS 1.2 or higher for all connections

**If you're still on the deprecated JWT flow (Section 6.4):**
- Implement token refresh on 401 / DRM-1013; do not re-login from scratch every time
- Never log access or refresh tokens
- Restrict the Login endpoint to your application's IP range at the network/firewall level
- Plan your migration to the API key model — JWT and API key both work today, but Seclore has
  stated a future release will not support JWT

### 18.2 URL Construction

A common integration bug is duplicating the base path. If `base_url` already contains
`/seclore/drm/`, appending `seclore/drm/1.0/protect/hf` produces a doubled path that
returns a 404.

**Safe pattern — keep base_url as the host only:**

```python
BASE_URL = "https://drmapi.example.com"   # no trailing path
protect_url = f"{BASE_URL}/seclore/drm/1.0/protect/hf"
upload_url  = f"{BASE_URL}/seclore/drm/filestorage/1.0/upload"
```

**If base_url already includes the prefix** (e.g., from config), append only the
version-relative segment:

```python
BASE_URL = "https://drmapi.example.com/seclore/drm/"  # note trailing /
protect_url = f"{BASE_URL}1.0/protect/hf"
```

Check every endpoint in your integration for the same duplication — upload, protect,
download, and delete calls are all equally susceptible.

### 18.3 Performance

**Token caching (legacy JWT flow only — not applicable to the API key model):**
- Cache the access token in memory and reuse it for its full 15-minute lifespan
- A single token can handle many concurrent file operations — do not create one per file

**Concurrency:**
- The API Server is stateless (per request) — horizontal scaling behind a load balancer is supported
- Use shared file storage (S3 or shared disk) when running multiple API Server instances, not local disk

**File operations:**
- Upload, protect, and download are three separate HTTP calls — pipeline them asynchronously for bulk operations
- Clean up files promptly via the Delete API; stale files consume storage quota

**Storage selection:**
- For high volume (> 100 files/hour) choose disk (EFS/Azure Files) or S3 over database storage
- Co-locate file storage with the API Server to minimise transfer latency within the protection cycle

**Retry strategy:**
- Implement exponential backoff on DRM-1000 (transient server errors) and DRM-1006 (rate limit)
- Do not retry DRM-1100 (already protected) or DRM-1101 (unsupported file) — these are client errors

---

## 19. Sample Integration Code

### 19.1 Complete flow — curl

```bash
# API key is generated once from the Admin Console — no login call needed.
API_KEY="your-api-key"

# Step 1: Upload
STORAGE_ID=$(curl -s -X POST "https://api-server/seclore/drm/filestorage/1.0/upload" \
  -H "Authorization: Bearer $API_KEY" \
  -F "file=@document.docx" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['fileStorageId'])")

# Step 2: Protect (Hot Folder)
PROTECTED_ID=$(curl -s -X POST "https://api-server/seclore/drm/1.0/protect/hf" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"hotfolderId\":\"12345\",\"fileStorageId\":\"$STORAGE_ID\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['fileStorageId'])")

# Step 3: Download protected file
curl -s -X GET "https://api-server/seclore/drm/filestorage/1.0/download/$PROTECTED_ID" \
  -H "Authorization: Bearer $API_KEY" \
  -o document-protected.html

# Step 4: Delete original upload
curl -s -X DELETE "https://api-server/seclore/drm/filestorage/1.0/$STORAGE_ID" \
  -H "Authorization: Bearer $API_KEY"
```

### 19.2 Java — full protect cycle (OkHttp)

```java
import okhttp3.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.*;
import java.util.*;

public class SecloreApiClient {

    private static final String BASE_URL = "https://api-server";
    private static final OkHttpClient client = new OkHttpClient();
    private static final ObjectMapper mapper = new ObjectMapper();

    // API key generated once from the Admin Console — no login/refresh flow needed.
    private final String apiKey;

    public SecloreApiClient(String apiKey) {
        this.apiKey = apiKey;
    }

    // --- 1. Upload file ---
    public String uploadFile(File file) throws IOException {
        RequestBody multipart = new MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("file", file.getName(),
                RequestBody.create(MediaType.parse("application/octet-stream"), file))
            .build();
        Request req = new Request.Builder()
            .url(BASE_URL + "/seclore/drm/filestorage/1.0/upload")
            .addHeader("Authorization", "Bearer " + apiKey)
            .post(multipart)
            .build();
        try (Response resp = client.newCall(req).execute()) {
            Map<?,?> result = mapper.readValue(resp.body().string(), Map.class);
            return (String) result.get("fileStorageId");
        }
    }

    // --- 2. Protect with Hot Folder ---
    public String protectHotFolder(String fileStorageId, String hotFolderId) throws IOException {
        String body = mapper.writeValueAsString(Map.of(
            "hotfolderId", hotFolderId,
            "fileStorageId", fileStorageId
        ));
        Request req = new Request.Builder()
            .url(BASE_URL + "/seclore/drm/1.0/protect/hf")
            .addHeader("Authorization", "Bearer " + apiKey)
            .post(RequestBody.create(MediaType.parse("application/json"), body))
            .build();
        try (Response resp = client.newCall(req).execute()) {
            Map<?,?> result = mapper.readValue(resp.body().string(), Map.class);
            return (String) result.get("fileStorageId");
        }
    }

    // --- 3. Download to file ---
    public void download(String fileStorageId, File destination) throws IOException {
        Request req = new Request.Builder()
            .url(BASE_URL + "/seclore/drm/filestorage/1.0/download/" + fileStorageId)
            .addHeader("Authorization", "Bearer " + apiKey)
            .get()
            .build();
        try (Response resp = client.newCall(req).execute();
             InputStream in = resp.body().byteStream();
             FileOutputStream out = new FileOutputStream(destination)) {
            in.transferTo(out);
        }
    }

    // --- 4. Delete file ---
    public void deleteFile(String fileStorageId) throws IOException {
        Request req = new Request.Builder()
            .url(BASE_URL + "/seclore/drm/filestorage/1.0/" + fileStorageId)
            .addHeader("Authorization", "Bearer " + apiKey)
            .delete()
            .build();
        client.newCall(req).execute().close();
    }

    // --- Convenience: full protect flow ---
    public File protectFile(File sourceFile, String hotFolderId) throws IOException {
        String uploadId = uploadFile(sourceFile);
        try {
            String protectedId = protectHotFolder(uploadId, hotFolderId);
            File output = new File(sourceFile.getParent(),
                sourceFile.getName() + ".html");
            download(protectedId, output);
            return output;
        } finally {
            deleteFile(uploadId);  // Always delete the unprotected copy
        }
    }
}
```

### 19.3 Independent Rights protect example (Java body only)

```java
Map<String, Object> entity = Map.of("emailId", "alice@example.com", "type", "user");
Map<String, Object> arm = Map.of(
    "entities", List.of(entity),
    "primaryAccessRight", List.of("read", "print"),
    "offline", false,
    "redistribute", false,
    "lockToFirstMachine", false
);
Map<String, Object> body = Map.of(
    "protectionDetails", Map.of(
        "accessRightMappings", List.of(arm),
        "ownerEmailId", "owner@example.com"
    ),
    "fileStorageId", uploadId
);
// POST body to /seclore/drm/1.0/protect/independent
```

### 19.4 External Reference (Policy Federation) protect example (Java body only)

```java
Map<String, Object> body = Map.of(
    "hotfolderExternalReference", Map.of(
        "externalReferenceId", "FOLDER-123",
        "externalReferenceName", "HR Documents"
    ),
    "fileExternalReference", Map.of(
        "externalReferenceId", "FILE-456",
        "externalReferenceName", "Q1 Payroll Report"
    ),
    "fileStorageId", uploadId
);
// POST body to /seclore/drm/1.0/protect/externalref
```

---

## 20. API Endpoint Summary

Routes confirmed directly against the `@RequestMapping`/`@GetMapping`/`@PostMapping`/`@DeleteMapping`
annotations in the server JAR's controller classes (3.5.0.0).

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/seclore/drm/version` | None | API Server version (plain text) |
| GET | `/seclore/drm/health` | None | Health status of the service (PS, file storage, app DB) |
| GET | `/seclore/drm/healthcheck` | None | Core health status — API Server's own components only, not PS |
| GET | `/seclore/drm/application/health` | API key | Health status scoped to your application/tenant |
| POST | `/seclore/drm/1.0/auth/login` | — | **Deprecated.** Get access + refresh tokens (legacy JWT flow) |
| POST | `/seclore/drm/1.0/auth/refresh` | — | **Deprecated.** Refresh expired access token |
| POST | `/seclore/drm/1.0/auth/invalidate` | — | **Deprecated.** Invalidate tokens (logout) |
| POST | `/seclore/drm/filestorage/1.0/upload` | API key | Upload file for protection/unprotection |
| GET | `/seclore/drm/filestorage/1.0/download/{id}` | API key | Download file by storage ID |
| GET | `/seclore/drm/filestorage/1.0/files` | API key | List all stored files |
| GET | `/seclore/drm/filestorage/1.0/file/{id}` | API key | Get metadata for a specific stored file |
| DELETE | `/seclore/drm/filestorage/1.0/{id}` | API key | Delete specific file |
| DELETE | `/seclore/drm/filestorage/1.0` | API key | Delete all files |
| POST | `/seclore/drm/1.0/protect/hf` | API key | Protect with Hot Folder |
| POST | `/seclore/drm/1.0/protect/independent` | API key | Protect with Independent Rights |
| POST | `/seclore/drm/1.0/protect/fileid` | API key | Protect using existing Seclore File ID |
| POST | `/seclore/drm/1.0/protect/externalref` | API key | Protect with External Reference (Policy Federation) |
| POST | `/seclore/drm/1.0/unprotect` | API key | Unprotect a file |
| POST | `/seclore/drm/1.0/updatefilepermission` | API key | Add/update/remove permissions |
| GET | `/seclore/drm/1.0/policy/{identifier}` | API key | Get policy details by user email or policy ID |
| GET | `/seclore/drm/1.0/filepermission/{id}` | API key | Get file permissions |
| POST | `/seclore/drm/1.0/sendrequest` | API key | Send a custom XML request to Policy Server |
| POST | `/seclore/drm/1.0/classification/classify` | API key | Apply a classification label |
| POST | `/seclore/drm/1.0/classification/reclassify` | API key | Change a file's classification label |
| POST | `/seclore/drm/1.0/classification/declassify` | API key | Remove a file's classification label |
| GET | `/seclore/drm/1.0/classification/labels` | API key | List all classification labels (requires `fileStorageId`) |
| GET | `/seclore/drm/1.0/classification/{id}` | API key | Get a file's current classification |

> The three deprecated auth endpoints use tenant credentials, not an API key, and Seclore has
> stated a future release will not support them — see Section 6.4. API keys themselves can
> only be created/managed through the Admin Console, never via a REST call — see Section 6.1
> and `references/api-server-config-guide.md`.
