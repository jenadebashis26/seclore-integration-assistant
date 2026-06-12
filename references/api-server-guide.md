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

The standard protection flow is:

```
1. Login           →  POST /auth/login
                      Returns: accessToken + refreshToken

2. Upload File     →  POST /filestorage/upload  (multipart/form-data)
                      Returns: fileStorageId

3. Protect         →  POST /protect/{type}
                      Input: fileStorageId + protection params
                      Returns: new fileStorageId (protected file) + secloreFileId

4. Download        →  GET  /filestorage/download/{fileStorageId}
                      Returns: the protected (HTML-wrapped) file

5. Delete original →  DELETE /filestorage/delete/{fileStorageId}
                      (Delete the unprotected copy uploaded in step 2)
```

The unprotection flow is symmetrical:
```
1. Login
2. Upload protected file  →  POST /filestorage/upload
3. Unprotect              →  POST /unprotect/
                              Returns: new fileStorageId (unprotected file)
4. Download unprotected file
5. Delete
```

**Important behaviour:**
- Protected files are **automatically deleted** from the API Server after download
- Unprotected (uploaded) copies are **automatically deleted** after a configurable timeout
- The `/delete` and `/deleteall` APIs can be used to clean up explicitly
- Every API call except `/health` requires a valid Bearer token in the `Authorization` header

---

## 6. Authentication

### 6.1 Login

**POST** `/seclore/drm/1.0/auth/login`

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
- The access token defaults to **15-minute expiry** (configurable)
- Pass the access token as `Authorization: Bearer <accessToken>` on every subsequent call
- The `x-api-key` header is only required when calling a Seclore-hosted (cloud) instance; it is not needed for a customer-deployed instance

### 6.2 Refresh

**POST** `/seclore/drm/1.0/auth/refresh`

```json
{ "refreshToken": "eyJhbGci..." }
```

Returns a new `accessToken` + `refreshToken`. Use this when the access token expires to avoid
re-authenticating from scratch.

### 6.3 Invalidate

**POST** `/seclore/drm/1.0/auth/invalidate`

Explicitly invalidates both tokens (logout).

```json
{
  "accessToken": "...",
  "refreshToken": "..."
}
```

### 6.4 Token handling best practices

- Cache the access token and reuse it across requests until it expires — do not call `/login` before every file operation
- Implement refresh-on-401: catch `DRM-1013` (token expired), call `/refresh`, retry the original request
- Store tokens in memory only — do not persist to disk or logs
- The API Server validates the token signature on every call; a tampered token returns `DRM-1014`

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

> **Note:** Protected files are automatically deleted from the API Server after download.

### 7.3 List Files

**GET** `/seclore/drm/filestorage/1.0/files`

Returns metadata for **all** files currently stored in the file storage for the logged-in
tenant. Returns an array of `FileMetadataDTO` objects.

### 7.4 Get File Info

**GET** `/seclore/drm/filestorage/1.0/file/{fileStorageId}`

Returns metadata for a **specific** file by its storage ID.

| Parameter     | Type   | Required | Description                        |
|---------------|--------|----------|------------------------------------|
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

| Parameter     | Type   | Required | Description                      |
|---------------|--------|----------|----------------------------------|
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

### 8.1 Protect with Hot Folder

**POST** `/seclore/drm/1.0/protect/hf`

Protects the file using a pre-defined policy from a Hot Folder in Policy Server. The policy
(who can access, what they can do) is configured centrally in PS — the application just
supplies the Hot Folder ID.

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

```json
{
  "protectionDetails": {
    "classification": "CONFIDENTIAL",
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
    ],
    "credentialIds": [],
    "ownerEmailId": "owner@example.com"
  },
  "fileStorageId": "abc123"
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
gets the same policy, same encryption key, and the same Seclore File ID as the original.

```json
{
  "existingProtectedFileId": "SECLORE-FILE-UUID",
  "fileStorageId": "new-upload-id"
}
```

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

**When to use:** Access control is managed in the integrating application, not in PS. Rights
can change after protection without re-protecting the file.

For ARA callback implementation, see `references/policy-federation-api.md`.

---

## 9. Unprotect API

**POST** `/seclore/drm/1.0/unprotect/`

Unprotects a Seclore-protected file that belongs to the same tenant (EA).

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

> The API Server can only unprotect files belonging to its configured EA. It does not have
> an equivalent of the SDK's "Unprotect Any File" advanced privilege via the API.

---

## 10. Permission Management APIs

### 10.1 Get File Permissions

**GET** `/seclore/drm/1.0/filepermission/{fileStorageId}`

Returns the full access rights structure of a protected file — all users/groups, their
rights, expiry settings, IP restrictions, Hot Folder details, and applied policies.

**Response includes:**
- `accessRightMappings` — array of all user/group permission entries
- `ownerEmailId`
- `secloreFileId`
- `hotFolderDetails` — Hot Folder ID, name, external reference ID
- `policies` — predefined policies applied to the file

### 10.2 Update File Permissions

**POST** `/seclore/drm/1.0/updatefilepermission`

Add, remove, or update permissions on an already-protected file without re-protecting it.

```json
{
  "secloreFileId": "SECLORE-FILE-UUID",
  "addAccessRightMappings": [
    {
      "entity": [{ "emailId": "newuser@example.com", "type": "user" }],
      "primaryAccessRight": ["read"],
      "offline": false,
      "redistribute": false,
      "lockToFirstMachine": false,
      "daysSinceProtection": null,
      "daysSinceFirstAccess": null,
      "ipRangeAccess": []
    }
  ],
  "removeAccessRightMappings": [
    {
      "entity": [{ "emailId": "olduser@example.com", "type": "user" }],
      "accessRightId": "access-right-mapping-id"
    }
  ],
  "updateAccessRightMappings": [],
  "addCredentialIds": [],
  "removeCredentialIds": []
}
```

This is a powerful post-protection operation — rights changes take effect immediately for
all subsequent file opens.

---

## 11. Policy APIs

### 11.1 Get Policy Details

**GET** `/seclore/drm/1.0/policy/{identifier}`

Retrieve policy details by either:
- A **user email address** — returns all policies mapped to that user
- A **policy ID** — returns details of a specific policy

Returns policy name, owner, status, access right mappings, and creation metadata.

**Response (200)**:
```json
{
  "credentials": [
    { "credentialId": "string", "credentialName": "string" }
  ]
}
```

### 11.2 Send Custom Request

**POST** `/seclore/drm/1.0/sendrequest`

Sends a custom XML request directly to the Policy Server configured for the logged-in
tenant. Use this for advanced or non-standard Policy Server operations not covered by
the other protection or permission APIs (e.g. proprietary policy queries, custom
federation requests).

Requires `Authorization: Bearer <access_token>`

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
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"requestType": "GetUserDetails", "requestBody": "<xml>...</xml>"}'
```

> Use `sendrequest` when the SDK's `FSHelper.sendRequest()` equivalent is needed via
> the REST API — useful in environments where the Java SDK cannot be deployed directly.

---

## 12. Classification APIs

Apply, update, query, and remove classification labels on files. Labels are configured
in the Policy Server and control how files are categorised for sensitivity, compliance,
and visual marking. All endpoints require `Authorization: Bearer <access_token>`.

---

### 12.1 Classify File

**POST** `/seclore/drm/1.0/classification/classify`

Applies a classification label to a file using a `labelId` from the Policy Server.

| Field             | Type    | Required | Description                                  |
|-------------------|---------|----------|----------------------------------------------|
| fileStorageId     | string  | true     | File to classify                             |
| labelId           | string  | true     | Classification label ID from Policy Server   |
| forceLabelRefresh | boolean | false    | Force refresh of label cache before applying |

**Response (200)**:
```json
{ "fileStorageId": "string", "labelId": "string", "labelName": "string" }
```

**Example**:
```bash
curl -X POST https://your-server/seclore/drm/1.0/classification/classify \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"fileStorageId": "<id>", "labelId": "<label_id>"}'
```

---

### 12.2 Reclassify File

**POST** `/seclore/drm/1.0/classification/reclassify`

Updates the label on an already-classified file. Response includes both `currentLabel`
and `oldLabel`.

| Field             | Type    | Required | Description                  |
|-------------------|---------|----------|------------------------------|
| fileStorageId     | string  | true     | File to reclassify           |
| labelId           | string  | true     | New classification label ID  |
| forceLabelRefresh | boolean | false    | Force refresh of label cache |

**Response (200)**:
```json
{
  "fileStorageId": "string",
  "currentLabel": { "labelId": "string", "labelName": "string" },
  "oldLabel":     { "labelId": "string", "labelName": "string" }
}
```

---

### 12.3 Declassify File

**POST** `/seclore/drm/1.0/classification/declassify`

Removes the classification label from a file. DRM protection is unaffected — only the
label is removed. Returns `labelId: null` and `labelName: null` on success.

| Field             | Type    | Required | Description                  |
|-------------------|---------|----------|------------------------------|
| fileStorageId     | string  | true     | File to declassify           |
| forceLabelRefresh | boolean | false    | Force refresh of label cache |

**Response (200)**:
```json
{ "fileStorageId": "string", "labelId": null, "labelName": null }
```

---

### 12.4 Get All Classification Labels

**GET** `/seclore/drm/1.0/classification/labels`

Returns all labels configured in the Policy Server, including nested sublabels,
sensitivity levels, colours, and visual markings.

| Field             | Type    | Required | Description                      |
|-------------------|---------|----------|----------------------------------|
| fileStorageId     | string  | true     | Context file storage ID          |
| forceLabelRefresh | boolean | false    | Force refresh of the label cache |

Use `forceLabelRefresh: true` when label config changes recently; avoid in
high-throughput paths due to cache rebuild cost.

---

### 12.5 Get File Classification

**GET** `/seclore/drm/1.0/classification/{fileStorageId}`

Returns the current classification label on a specific file.

**Response (200)**:
```json
{ "classified": true, "classificationInfo": { ... } }
```

---

### 12.6 Classification Workflow Notes

- To classify during protection, pass `classificationId` in `protectionDetails` of
  `/protect/independent`.
- Declassification removes only the label — DRM rights remain intact.
- `forceLabelRefresh` bypasses the server-side label cache; use sparingly.
- Labels (`labelId`) must be pre-configured in the Policy Server before calling these APIs.

---

## 13. Utility APIs (App Info)

### 13.1 Health Check

**GET** `/seclore/drm/health`

Returns the health status of all three components the API Server depends on.

```json
{
  "status": "UP",
  "components": {
    "databaseFileStorage": "UP",
    "applicationDatabase": "UP",
    "policyServer": "UP"
  }
}
```

`status` is `UP` only when all three components are `UP`. Use this endpoint for readiness
probes in Kubernetes or load balancer health checks.

### 13.2 Version

**GET** `/seclore/drm/version`

Returns the current version string of the DRM API Service. Useful for verifying which build
is deployed.

---

## 13. File Transfer Concepts

### 13.1 Multipart Upload

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

### 13.2 Binary vs Stream

The Seclore DRM API Server does **not** support streaming input — the file must be
completely uploaded before protection starts. This is a two-step process:

1. **Upload** — full file transferred to API Server (returns `fileStorageId`)
2. **Protect** — API Server protects the stored file (returns new `fileStorageId`)

This differs from the Server SDK, which requires the file on the local disk of the server
running the SDK. With the API Server, the file is transferred over HTTP and held in the
configured storage backend (disk, S3, or database) during processing.

### 13.3 Download after protection

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

### 13.4 File size considerations

Large files increase upload latency. For high-throughput environments:
- Use storage backends co-located with the API Server (S3 in same AWS region, or local disk)
- Avoid database file storage for large files (> a few MB) — it is best suited for metadata or small documents
- Set appropriate HTTP client timeouts — a large file upload + protection cycle may take several seconds

---

## 14. Storage Options

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

## 15. Deployment and Setup

### 15.1 Where to deploy

| Option | Description |
|--------|-------------|
| **Seclore-managed (AWS)** | Seclore hosts and manages the API Server on AWS. The integrating application calls it over the internet. Requires `x-api-key` header on every call. |
| **Customer-deployed (On-prem or cloud)** | Customer deploys the API Server in their own environment — on-premises servers, AWS, Azure, or any cloud. No `x-api-key` required. Recommended for data-sensitive environments. |

### 15.2 Why customer-side deployment is recommended

The API Server handles **raw, unencrypted files** during the upload → protect → download
cycle. Files are in plaintext on the API Server storage between upload and protection.
Deploying in the customer environment ensures:
- Files never leave the customer's network boundary in plaintext
- Full control over storage, logging, and network access
- Compliance with data residency requirements

### 15.3 Required configuration

Before the first API call, the API Server must be configured with:
- **Seclore Policy Server** URL, EA ID, and EA Passphrase
- **Tenant ID and Tenant Secret** (used for the Login API — distinct from EA credentials)
- **Database** connection string (any supported RDBMS)
- **File Storage** type and path/connection (disk path, S3 bucket, or DB)
- **Token expiry** (default 15 minutes; configurable)
- **File cleanup timeout** for unprotected uploads

Configuration is typically done via environment variables or a config file supplied at startup.
Contact your Seclore implementation team for the full deployment guide.

---

## 16. Error Codes

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
| DRM-1010 | Unauthorised request | Token missing or invalid |
| DRM-1011 | Access token not sent | Add `Authorization: Bearer <token>` header |
| DRM-1012 | Error generating tokens | Check tenant credentials in API Server config |
| DRM-1013 | Token expired | Call `/auth/refresh` to get a new token |
| DRM-1014 | JWT signature mismatch | Token tampered or from wrong issuer; re-login |
| DRM-1015 | Invalid refresh token | Refresh token expired or invalid; re-login |

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

## 17. Best Practices

### 17.1 Security

**Token management:**
- Implement token refresh on 401 / DRM-1013; do not re-login from scratch every time
- Never log access or refresh tokens
- Use short token expiry (15 minutes is the default and is appropriate)
- If the API Server is customer-deployed, restrict the Login endpoint to your application's
  IP range at the network/firewall level

**File handling:**
- Delete the unprotected upload immediately after protection is confirmed:
  `DELETE /filestorage/delete/{originalFileStorageId}`
- Do not store `fileStorageId` values beyond the immediate request/response lifecycle — they are transient handles
- If using Seclore-hosted (cloud) API Server, transmit the `x-api-key` only over HTTPS; never embed it in client-side code

**Network:**
- Deploy the API Server in the DMZ / Integration Zone, not in the public internet segment
- Restrict API Server → Policy Server traffic to port 443 from the API Server's IP only
- Use TLS 1.2 or higher for all connections

### 17.2 Performance

**Token caching:**
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

## 18. Sample Integration Code

### 18.1 Complete flow — curl

```bash
# Step 1: Login
TOKEN=$(curl -s -X POST "https://api-server/seclore/drm/1.0/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"tenantId":"my-tenant","tenantSecret":"my-secret"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# Step 2: Upload
STORAGE_ID=$(curl -s -X POST "https://api-server/seclore/drm/filestorage/1.0/upload" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@document.docx" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['fileStorageId'])")

# Step 3: Protect (Hot Folder)
PROTECTED_ID=$(curl -s -X POST "https://api-server/seclore/drm/1.0/protect/hf" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"hotfolderId\":\"12345\",\"fileStorageId\":\"$STORAGE_ID\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['fileStorageId'])")

# Step 4: Download protected file
curl -s -X GET "https://api-server/seclore/drm/filestorage/1.0/download/$PROTECTED_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -o document-protected.html

# Step 5: Delete original upload
curl -s -X DELETE "https://api-server/seclore/drm/filestorage/1.0/delete/$STORAGE_ID" \
  -H "Authorization: Bearer $TOKEN"
```

### 18.2 Java — full protect cycle (OkHttp)

```java
import okhttp3.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.*;
import java.util.*;

public class SecloreApiClient {

    private static final String BASE_URL = "https://api-server";
    private static final OkHttpClient client = new OkHttpClient();
    private static final ObjectMapper mapper = new ObjectMapper();

    private String accessToken;
    private String refreshToken;

    // --- 1. Login ---
    public void login(String tenantId, String tenantSecret) throws IOException {
        String body = mapper.writeValueAsString(Map.of(
            "tenantId", tenantId,
            "tenantSecret", tenantSecret
        ));
        Request req = new Request.Builder()
            .url(BASE_URL + "/seclore/drm/1.0/auth/login")
            .post(RequestBody.create(MediaType.parse("application/json"), body))
            .build();
        try (Response resp = client.newCall(req).execute()) {
            Map<?,?> result = mapper.readValue(resp.body().string(), Map.class);
            this.accessToken  = (String) result.get("accessToken");
            this.refreshToken = (String) result.get("refreshToken");
        }
    }

    // --- 2. Upload file ---
    public String uploadFile(File file) throws IOException {
        RequestBody multipart = new MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("file", file.getName(),
                RequestBody.create(MediaType.parse("application/octet-stream"), file))
            .build();
        Request req = new Request.Builder()
            .url(BASE_URL + "/seclore/drm/filestorage/1.0/upload")
            .addHeader("Authorization", "Bearer " + accessToken)
            .post(multipart)
            .build();
        try (Response resp = client.newCall(req).execute()) {
            Map<?,?> result = mapper.readValue(resp.body().string(), Map.class);
            return (String) result.get("fileStorageId");
        }
    }

    // --- 3. Protect with Hot Folder ---
    public String protectHotFolder(String fileStorageId, String hotFolderId) throws IOException {
        String body = mapper.writeValueAsString(Map.of(
            "hotfolderId", hotFolderId,
            "fileStorageId", fileStorageId
        ));
        Request req = new Request.Builder()
            .url(BASE_URL + "/seclore/drm/1.0/protect/hf")
            .addHeader("Authorization", "Bearer " + accessToken)
            .post(RequestBody.create(MediaType.parse("application/json"), body))
            .build();
        try (Response resp = client.newCall(req).execute()) {
            Map<?,?> result = mapper.readValue(resp.body().string(), Map.class);
            return (String) result.get("fileStorageId");
        }
    }

    // --- 4. Download to file ---
    public void download(String fileStorageId, File destination) throws IOException {
        Request req = new Request.Builder()
            .url(BASE_URL + "/seclore/drm/filestorage/1.0/download/" + fileStorageId)
            .addHeader("Authorization", "Bearer " + accessToken)
            .get()
            .build();
        try (Response resp = client.newCall(req).execute();
             InputStream in = resp.body().byteStream();
             FileOutputStream out = new FileOutputStream(destination)) {
            in.transferTo(out);
        }
    }

    // --- 5. Delete file ---
    public void deleteFile(String fileStorageId) throws IOException {
        Request req = new Request.Builder()
            .url(BASE_URL + "/seclore/drm/filestorage/1.0/delete/" + fileStorageId)
            .addHeader("Authorization", "Bearer " + accessToken)
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

### 18.3 Independent Rights protect example (Java body only)

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

### 18.4 External Reference (Policy Federation) protect example (Java body only)

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

## 19. API Endpoint Summary

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/seclore/drm/version` | API Server version |
| GET | `/seclore/drm/health` | Health status (PS, DB, storage) |
| POST | `/seclore/drm/1.0/auth/login` | Get access + refresh tokens |
| POST | `/seclore/drm/1.0/auth/refresh` | Refresh expired access token |
| POST | `/seclore/drm/1.0/auth/invalidate` | Invalidate tokens (logout) |
| POST | `/seclore/drm/filestorage/1.0/upload` | Upload file for protection/unprotection |
| GET | `/seclore/drm/filestorage/1.0/download/{id}` | Download file by storage ID |
| GET | `/seclore/drm/filestorage/1.0/files` | List all stored files |
| DELETE | `/seclore/drm/filestorage/1.0/delete/{id}` | Delete specific file |
| DELETE | `/seclore/drm/filestorage/1.0/` | Delete all files |
| POST | `/seclore/drm/1.0/protect/hf` | Protect with Hot Folder |
| POST | `/seclore/drm/1.0/protect/independent` | Protect with Independent Rights |
| POST | `/seclore/drm/1.0/protect/fileid` | Protect using existing Seclore File ID |
| POST | `/seclore/drm/1.0/protect/externalref` | Protect with External Reference (Policy Federation) |
| POST | `/seclore/drm/1.0/unprotect/` | Unprotect a file |
| GET | `/seclore/drm/1.0/filepermission/{id}` | Get file permissions |
| POST | `/seclore/drm/1.0/updatefilepermission` | Add/update/remove permissions |
| GET | `/seclore/drm/1.0/policy/{identifier}` | Get policy details by user email or policy ID |
