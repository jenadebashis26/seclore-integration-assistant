# Seclore Online Integration — Developer Guide

## 1. What is Seclore Online Integration?

Seclore Online Integration enables users to open Seclore-protected files directly inside a
browser or native desktop application — without downloading the file first. The user clicks
a file name in the enterprise application (DMS, CMS, SharePoint-style portal) and the file
opens in-browser, fully decrypted and rights-enforced, without any local download.

This is analogous to how Microsoft Office files open from SharePoint or Teams — click the
file name, it opens in the browser or Office app directly.

**What makes this different from the standard download flow:**

| | Standard Download Flow | Seclore Online Integration |
|-|----------------------|---------------------------|
| User action | Downloads file, opens locally with Seclore Agent | Clicks file name in browser |
| File on user's machine | Yes — downloaded protected file | No — file never leaves the server |
| Seclore Agent required | Yes (for native protected files) | No (for online view/edit); optional for CFAD |
| Experience | Explicit download step | In-app, seamless |

**Performance note:** In the Seclore Online flow, the protected file is uploaded from the
enterprise application to the Seclore Online Server before being rendered. This adds
network overhead. For high-throughput or large-file scenarios where performance is critical,
the standard download flow may be preferable.

---

## 2. Security Model

- The file is **always protected** (encrypted) during transmission to Seclore Online Server
- Once received, Seclore Online decrypts the file **in memory only** — never to disk
- Decrypted content is streamed to a **secure container in the user's browser** over HTTPS
- The browser-based viewer and editor enforce all Seclore DRM controls (view-only, print, edit, etc.)
- The enterprise application's access control decision is applied at open time — the user's
  rights at that moment are honoured
- The file content is never exposed to the browser's standard storage (no local caching of decrypted content)

---

## 3. iFrame Support — Deprecated

iFrame support for embedding the Seclore Online Editor inside an enterprise application's
page was deprecated after major browsers (Chrome, Safari) changed their default privacy
settings to **block third-party cookies and cross-site tracking**.

When Seclore Online Editor is loaded inside an iFrame, it is treated as a third-party
context. The browser blocks the cookies and session state Seclore Online needs for
authentication and rights enforcement. This causes auth failures and inconsistent behaviour.

**Recommendation:** Open the Seclore Online Editor in a **top-level browser window or tab**.
Do not attempt to use iFrame workarounds — they are not supported and create security risks.

---

## 4. Architecture

Three parties are involved:

```
Enterprise Application          Seclore Online Server          Policy Server
(Your app — DMS/CMS/Portal)    (Seclore-deployed or           (Seclore PS)
                                 customer-deployed)
        │                               │                           │
        │──── 1. Pre-flight ───────────►│                           │
        │◄─── Supported? ──────────────│                           │
        │                               │                           │
        │──── 2. POST /open ───────────►│                           │
        │      (redirect to SO)         │                           │
        │                               │──── Authenticate ────────►│
        │◄─────────────────────────────│◄─── Rights check ─────────│
        │◄─── 3. checkFile ────────────│                           │
        │──── file metadata ───────────►│                           │
        │◄─── 4. getFile ──────────────│                           │
        │──── file contents ───────────►│   [decrypt in memory]     │
        │                               │──── stream to browser ───►│
        │◄─── 5. open event ───────────│                           │
        │◄─── 6. putFile (on save) ────│                           │
        │◄─── 7. close event ──────────│                           │
```

The enterprise application implements a set of callback endpoints that Seclore Online calls
to fetch file metadata, file contents, and to notify the app of open/save/close events.

---

## 5. Key Concepts

### File Token
A unique string that represents a specific file in the enterprise application. Seclore Online
includes the file token in all requests back to the enterprise application, allowing the app
to locate the file. Must be URL-safe and represent a single file.

### Access Token
A JWT (or equivalent string) issued by the enterprise application, scoped to a single user
and file. Seclore Online passes it back on all subsequent requests so the enterprise app
can verify the caller's identity and permissions.

Access token rules:
- Scoped to **one user + one file**
- Must remain valid for the entire session (view → edit transitions reuse the same token)
- Has an explicit expiry (`access_token_ttl`) — expressed as **milliseconds since epoch (Jan 1, 1970 UTC)**, an absolute timestamp, not a duration
- Only revoked if the user's permissions change; not revoked on normal close
- On expiry (SO receives 401 from the EA), Seclore Online calls the **Renew Access Token** endpoint

### Access Token TTL
The expiry of the access token, as an **absolute Unix millisecond timestamp** (not a relative
duration). Example: `System.currentTimeMillis() + 3600000` for 1 hour from now.

### File Hash
A hash of the file contents sent in the `checkFile` response. If Seclore Online already
has a cached copy with the same hash, it skips calling `getFile`. Use this to avoid
redundant file transfers for unchanged files.

### Session Context
A base64-encoded JSON string the enterprise application uses to carry session state.
Seclore Online echoes it back in all subsequent requests. The sample app uses it to
carry a session ID that maps to an in-memory session state object.

### Discovery
Seclore Online exposes a `/seclore/discovery` endpoint that returns the RSA proof keys
used to sign all requests from Seclore Online to the enterprise application. Cache the
discovery response; refresh every 12–24 hours, or immediately when proof key validation fails.

### CFAD — Cloud File Access on Desktop
A variant of Seclore Online that opens the file natively on the user's desktop (via the
Seclore Desktop Client) instead of in the browser. The enterprise application sets
`agentless=0` in the open request to trigger CFAD. After editing, the file is saved back
to the enterprise application.

---

## 6. Communication Flows

### Flow A — File Open (View, optionally switch to Edit)

```
User          Enterprise App          Seclore Online
  │                  │                       │
  │── click file ───►│                       │
  │                  │── 1. Preflight ───────►│  GET /seclore/1.0/files/preflight
  │                  │◄── supported? ────────│
  │                  │── 2. Redirect ────────►│  POST /seclore/1.0/files/open
  │                  │   (accessToken,        │   (browser form POST)
  │                  │    fileToken,          │
  │                  │    serviceUrl...)      │
  │                  │                       │── 3. checkFile ──► EA
  │                  │◄──────────────────────│◄── file metadata ─ EA
  │                  │                       │── 4. getFile ────► EA
  │                  │◄──────────────────────│◄── file binary ─── EA
  │◄── file opens in browser (view mode) ───│
  │                  │                       │── 5. open event ─► EA (notify)
  │── click Edit ───►│                       │
  │                  │                       │── 6. initEdit ───► EA
  │                  │◄──────────────────────│◄── OK ─────────── EA
  │                  │◄── 7. edit POST ──────│  (EA calls /open again for edit)
  │                  │── 8. Redirect ────────►│  POST /seclore/1.0/files/open (edit)
  │◄── file opens in browser (edit mode) ───│
```

### Flow B — File Open with Save-back

```
User          Enterprise App          Seclore Online
  │                  │                       │
  │                  │ (preflight + open as above)
  │◄── file opens in browser ───────────────│
  │                  │                       │── open event ────► EA
  │── make changes ──►│                      │
  │── save ──────────►│                      │── putFile ───────► EA (binary body)
  │                  │◄── file saved ────────│
  │── close ─────────►│                      │── close event ───► EA
```

### Flow C — CFAD (Open Natively on Desktop)

```
User          Enterprise App          Seclore Online          Desktop Client
  │                  │                       │                      │
  │                  │── preflight ──────────►│  (agentless=0)      │
  │                  │── open POST ──────────►│                     │
  │                  │                       │── redirect ─────────►│
  │                  │                       │   Desktop Client      │
  │                  │                       │   takes over          │
  │                  │◄──────────────────────│◄─ checkFile ─────────│
  │                  │◄──────────────────────│◄─ getFile ───────────│
  │◄── file opens natively ────────────────────────────────────────│
  │                  │◄──────────────────────│◄─ putFile (on save) ─│
  │                  │◄──────────────────────│◄─ close event ───────│
```

---

## 7. Seclore Online Endpoints (Calls Your App Makes to Seclore Online)

Prefix the **Seclore Online base URL** to all paths.

### GET /seclore/discovery
Returns RSA proof keys for request verification. Call once at startup; cache 12–24 hours.

```json
{
  "proof-keys": {
    "old": { "proof-key": { "modulus": "<BASE64>", "exponent": "<BASE64>", "algo": "SHA256withRSA" } },
    "new": { "proof-key": { "modulus": "<BASE64>", "exponent": "<BASE64>", "algo": "SHA256withRSA" } }
  },
  "versions": [1.0],
  "supported-features": [1.0]
}
```

`supported-features: [1.0]` means CFAD is supported on this instance.

### GET /seclore/1.0/files/preflight
Check whether a file can be opened online or natively before calling `/open`.

Query parameters: `name` (filename with extension, use `.html` for HTML-wrapped files),
`size` (bytes), `agentless` (`1` = online, `0` = native/CFAD).

Header required: `X-Seclore-PolicyServerURL`

Response: `{ "allowed-action": [ "view" | "edit" ] }`

Always call preflight before opening. It validates file extension, size limits, and whether
the file is supported. If it returns an error, redirect to the `X-Seclore-ErrorURL` in the
response header to show a contextual error page.

### POST /seclore/1.0/files/open
The browser redirect that initiates file opening. This is a **browser-side form POST** —
the enterprise application's page submits this form to Seclore Online, redirecting the user.

Form parameters:

| Parameter | Description |
|-----------|-------------|
| `accessToken` | JWT access token for this user + file |
| `accessTokenExpiry` | Absolute Unix millisecond timestamp (expiry) |
| `fileToken` | Your application's unique file identifier |
| `serviceUrl` | Your enterprise application's base URL — Seclore Online builds callback URLs from this |
| `agentless` | `1` = online (browser); `0` = native/CFAD |
| `policyServerURL` | Policy Server URL that protected the file |
| `sessionContext` | Base64-encoded session state JSON (mandatory — pass a random string if none needed) |
| `requestId` | Request ID for logging |

**Java — generating the open form parameters:**

```java
// From the sample app's FileOpenService.generateOpenRequestDetails()
OpenRequestDetails details = new OpenRequestDetails();
details.setAccessToken(SecurityService.generateAccessToken(fileToken));
details.setAccessTokenTTL(String.valueOf(System.currentTimeMillis() + TOKEN_TTL_MS));
details.setFileToken(fileToken);
details.setPolicyServerURL(appConfig.getPSURL());
details.setServiceURL(appConfig.getEnterpriseAppURL());
details.setAgentless("1");  // "1" = online, "0" = CFAD

SessionContext sessionContext = new SessionContext();
sessionContext.setSessionID(generateSessionId());
details.setSessionContext(Base64.encode(toJSON(sessionContext)));

// Then forward to open.jsp which does:
// <form method="POST" action="{secloreOnlineURL}/seclore/1.0/files/open">
//   <input type="hidden" name="accessToken" value="${accessToken}">
//   ... other fields ...
// </form>
// <script>document.forms[0].submit();</script>
```

---

## 8. Enterprise Application Endpoints (What You Must Implement)

All paths below are prefixed with the **serviceUrl** you passed in the `/open` call.
Seclore Online calls these endpoints as needed during the file session.

### Security — Verify Every Incoming Request

Every request from Seclore Online (except `/renewToken` and `/edit`) must be validated in
this order:

1. **Access token** — extract from `Authorization: Bearer <token>`, verify JWT signature and expiry
2. **File token** — extract from URL path, verify it matches the claim in the JWT
3. **Proof keys** — verify `X-Seclore-Proof` and `X-Seclore-ProofOld` headers

If any check fails, return the appropriate HTTP error code (`401` for auth failures,
`500` for proof failures). The `/renewToken` endpoint skips the expiry check (the token
is intentionally expired); the `/edit` endpoint skips all validation (Seclore Online
itself redirects the user's browser to this endpoint).

**Proof key verification (Java — from sample app SecurityService):**

```java
// Build the expected proof bytes from: URL + accessToken + timestamp
private static byte[] getExpectedProofBytes(String url, String accessToken, String timestamp) {
    byte[] tokenBytes = accessToken.getBytes(StandardCharsets.UTF_8);
    byte[] urlBytes = url.toUpperCase().getBytes(StandardCharsets.UTF_8);  // URL must be uppercase
    long ts = Long.valueOf(timestamp);

    ByteBuffer buf = ByteBuffer.allocate(4 + tokenBytes.length + 4 + urlBytes.length + 4 + 8);
    buf.putInt(tokenBytes.length);   buf.put(tokenBytes);
    buf.putInt(urlBytes.length);     buf.put(urlBytes);
    buf.putInt(8);                   buf.putLong(ts);
    return buf.array();
}

// Verify: try three combinations; pass if any one succeeds
boolean valid = verifyProof(newKey.modulus, newKey.exponent, xSecloreProof,      expected)  // new key + new proof
             || verifyProof(newKey.modulus, newKey.exponent, xSecloreProofOld,   expected)  // new key + old proof
             || verifyProof(oldKey.modulus, oldKey.exponent, xSecloreProof,      expected); // old key + new proof

// If all fail: reload discovery, retry once. If still failing, return 500.

private static boolean verifyProof(String modulus, String exponent,
        String proofKey, byte[] expected) throws Exception {
    BigInteger mod = new BigInteger(1, Base64.getDecoder().decode(modulus));
    BigInteger exp = new BigInteger(1, Base64.getDecoder().decode(exponent));
    PublicKey pub = KeyFactory.getInstance("RSA")
        .generatePublic(new RSAPublicKeySpec(mod, exp));
    Signature verifier = Signature.getInstance("SHA256withRSA");
    verifier.initVerify(pub);
    verifier.update(expected);
    return verifier.verify(Base64.getDecoder().decode(proofKey));
}
```

**Important:** `X-Seclore-TimeStamp` is 100-nanosecond intervals since January 1, 0001 UTC
(Windows FILETIME format) — not a Unix timestamp.

---

### GET /seclore/1.0/files/{fileToken} — checkFile

Called by Seclore Online before fetching the file. Returns file metadata and what actions
the enterprise application allows.

**Response (200):**
```json
{
  "file-name": "quarterly-report.docx",
  "file-hash": "sha256:abc123...",
  "file-hash-algo": "SHA-256",
  "file-size": "204800",
  "options": {
    "allow-edit": true,
    "allow-download": false,
    "allow-unprotected-download": 0,
    "email-copy": false,
    "allow-saveback": true
  },
  "allowed-action": ["view"]
}
```

`allowed-action` controls the mode the file opens in. Seclore Online intersects this with
the user's actual Seclore rights — if you return `edit` but the user's Seclore rights are
view-only, the file opens in view mode.

---

### GET /seclore/1.0/files/{fileToken}/contents — getFile

Returns the binary protected file to Seclore Online. Response body is the raw file bytes.

Required response headers: `Content-Type: application/octet-stream`,
`Content-Disposition: attachment; filename="..."`, `X-Seclore-FileName`.

**Java — streaming the file (from sample app):**

```java
@GET
@Path("{file-token}/contents")
public void getFile(@PathParam("file-token") String fileToken,
                    @Context HttpServletResponse response) {
    // Set headers
    response.setHeader("X-Seclore-FileName", fileMetaData.getFileName());
    response.setHeader("Content-Disposition",
        "attachment; filename=\"" + fileMetaData.getFileName() + "\"");
    response.setContentType("application/octet-stream");

    // Stream file bytes to response
    try (InputStream in = new FileInputStream(fileMetaData.getFilePath());
         OutputStream out = response.getOutputStream()) {
        byte[] buffer = new byte[8 * 1024];
        int read;
        while ((read = in.read(buffer)) != -1) {
            out.write(buffer, 0, read);
        }
    }
}
```

If the file hash in `checkFile` matches Seclore Online's cached hash, `getFile` is not
called. This caching behaviour reduces repeated file transfers.

---

### GET /seclore/1.0/files/{fileToken}/download — downloadFile

Called when the user downloads a protected copy from the Seclore Online error page.
Request/response is identical to `getFile`.

---

### POST /seclore/1.0/files/{fileToken}/contents — putFile

Called by Seclore Online to save the edited file back to the enterprise application.
The edited file bytes arrive in the request body.

Header `SAVE_EVENT_MODE`: `Manual` (user explicitly saved) or `Automatic` (auto-save).

```java
@POST
@Path("{file-token}/contents")
public Response putFile(@PathParam("file-token") String fileToken,
                        @Context HttpServletRequest request) throws IOException {
    // Consume and store the file from request input stream
    try (InputStream in = request.getInputStream()) {
        // Save to your file store
        fileStore.save(fileToken, in);
    }
    return Response.ok().build();
}
```

The sample app's `putFile` acknowledges the call without saving (it has no persistent store).
In a real integration, implement file versioning and conflict resolution here.

---

### POST /seclore/1.0/files/{fileToken}/initedit — initEdit

Called when the user clicks Edit while viewing. The enterprise application should verify
the user has edit permissions and prepare for the edit session.

Return `200 OK` if editing is permitted. Return `403` or `500` to deny.

---

### POST /seclore/1.0/files/{fileToken}/edit — edit (Browser Redirect)

Seclore Online redirects the user's browser to this endpoint to switch to edit mode.
The enterprise application should perform preflight for edit mode, then re-submit the
`/open` form to Seclore Online with `edit` mode parameters.

```java
@POST
@Path("{file-token}/edit")
public void edit(@FormParam("accessToken") String accessToken,
                 @FormParam("fileToken") String fileToken,
                 @Context HttpServletRequest request,
                 @Context HttpServletResponse response) throws Exception {
    // Perform preflight for edit mode
    OpenRequestDetails details = FileOpenService.openEditMode(fileToken, sessionContext);

    // Set attributes and forward to open.jsp (which re-POSTs to /seclore/1.0/files/open)
    request.setAttribute("accessToken", details.getAccessToken());
    request.setAttribute("accessTokenExpiry", details.getAccessTokenTTL());
    // ... other attributes ...
    request.getRequestDispatcher("/WEB-INF/pages/open.jsp").forward(request, response);
}
```

---

### POST /seclore/1.0/renewToken — Renew Access Token

Called by Seclore Online when it receives a `401` from the enterprise application. The
expired access token is passed in the `Authorization` header.

The enterprise application should:
1. Verify the JWT signature (but skip expiry check — the token is intentionally expired)
2. Validate the file token in the JWT still corresponds to a valid session
3. Return a new token with a new TTL

```java
@POST
@Path("/seclore/1.0/renewToken")
public Response renewToken(@HeaderParam("Authorization") String authHeader) {
    String expiredToken = extractBearerToken(authHeader);

    // Skip expiry check; validate signature and file token claim
    RenewAccessTokenResponse renewed = SecurityService.getRenewedToken(expiredToken);
    return Response.ok(toJSON(renewed)).build();
}
```

**Response:**
```json
{
  "access-token": "eyJhbGci...",
  "access-token-ttl": 1680000000000
}
```

---

### POST /seclore/1.0/files/{fileToken}/events/open — Open Event

Notification from Seclore Online that the user has successfully opened the file.
Body: `{ "actual-allowed-action": "view" | "edit" }`.

Return `200 OK`. Use this to log file access events in your audit trail.

---

### POST /seclore/1.0/files/{fileToken}/events/close — Close Event

Notification from Seclore Online that the user has closed the file.
Body: `{ "mode": "manual" | "automatic" }`.

Return `200 OK`. Use this to clean up session state and log close events.

---

## 9. Access Token Implementation

The sample application uses **HMAC-SHA256 signed JWTs** (via the Nimbus JOSE library).
The JWT contains three custom claims:

| Claim | Value |
|-------|-------|
| `File-Token` | The file token this token is scoped to |
| `File-Expiry` | Expiry as Unix millis |
| `URL` | Seclore Online URL |

```java
// Generating the access token (from SecurityService.generateAccessToken)
Map<String, Object> payload = Map.of(
    "File-Token", fileToken,
    "File-Expiry", System.currentTimeMillis() + TOKEN_TTL_MS,
    "URL", secloreOnlineURL
);
// Sign with HMAC-SHA256; expiry set as JWT standard expirationTime claim
```

**Important:** The sample app uses a hardcoded signing key for demo purposes. In production,
use a securely generated key stored in a secret manager.

**Access token lifecycle:**
1. Generated fresh for each file open request
2. Passed to Seclore Online in the `/open` form POST
3. Seclore Online includes it in `Authorization: Bearer <token>` on every callback
4. On expiry, Seclore Online calls `/renewToken`; the enterprise app returns a new token
5. Seclore Online retries the failed request with the renewed token

---

## 10. Configuration

Before anything works, the enterprise application URL must be **whitelisted** in the
Seclore Online configuration. Without this, Seclore Online rejects all requests from
the application.

Steps:
1. Follow the *Seclore Online Installation Manual* to whitelist the enterprise application URL
2. Restart Seclore Online for the change to take effect

One Seclore Online instance supports multiple whitelisted enterprise applications. If you
add a new Policy Server URL:
1. Configure the PS URL in your enterprise application
2. Whitelist it in Seclore Online
3. Restart Seclore Online

---

## 11. Design Considerations

### Version Conflict Resolution (simultaneous edits)

If multiple users open the same file in edit mode simultaneously, you must handle conflicts
in `putFile`. Two strategies:

1. **Lock on edit:** Once a file is opened for editing, open it in view mode for all other
   users until the first editor closes it.
2. **Allow concurrent edits:** Let all users edit, create a new version on each save, and
   let users manually reconcile. Track `SAVE_EVENT_MODE` header (`Manual` vs `Automatic`)
   to distinguish user-triggered saves from auto-saves.

### Error URL Handling

Seclore Online returns an `X-Seclore-ErrorURL` header on most error responses. This URL,
when POSTed to with the access token and file token, displays a contextual Seclore error
page (e.g. "file too large", "unsupported extension", with secondary actions like "download
locally instead"). Implement this redirect in your error handling rather than showing a
generic error page.

### Failed Access Token Renewal

If `/renewToken` returns `401` or `500`, Seclore Online stops the session. The user sees
an error. Ensure the token renewal endpoint is robust and returns new tokens reliably.

---

## 12. Header Reference

| Header | Direction | Description |
|--------|-----------|-------------|
| `Authorization: Bearer <token>` | SO → EA | Access token on all EA callbacks |
| `X-Seclore-TimeStamp` | SO → EA | 100ns intervals since 0001-01-01 UTC (Windows FILETIME) |
| `X-Seclore-Proof` | SO → EA | RSA signature (new key) — verify with current proof key |
| `X-Seclore-ProofOld` | SO → EA | RSA signature (old key) — verify with previous proof key |
| `X-Seclore-SessionContext` | Both | Base64-encoded session state; EA sets, SO echoes |
| `X-Seclore-FileHash` | SO → EA | Hash of file SO last saw — if matches checkFile hash, getFile is skipped |
| `X-Seclore-FileName` | EA → SO | File name in getFile response |
| `X-Seclore-PolicyServerURL` | EA → SO | PS URL for preflight requests |
| `X-Seclore-ErrorCode` | EA → SO | Error code on 4xx/5xx responses |
| `X-Seclore-ErrorMsg` | EA → SO | Error message on 4xx/5xx responses |
| `X-Seclore-ErrorURL` | SO → EA | Redirect URL to show contextual error page |
| `SAVE_EVENT_MODE` | SO → EA | `Manual` or `Automatic` on putFile |
| `Content-Disposition` | EA → SO | Mandatory on getFile: `attachment; filename="..."` |

---

## 13. Endpoint Summary

### Seclore Online Endpoints (EA calls these)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/seclore/discovery` | Get proof keys for request verification |
| GET | `/seclore/1.0/files/preflight` | Check if file can be opened |
| POST | `/seclore/1.0/files/open` | Open file in browser/CFAD (browser form POST) |

### Enterprise Application Endpoints (Implement these)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/seclore/1.0/files/{fileToken}` | checkFile — return metadata + options |
| GET | `/seclore/1.0/files/{fileToken}/contents` | getFile — return file binary |
| GET | `/seclore/1.0/files/{fileToken}/download` | downloadFile — same as getFile |
| POST | `/seclore/1.0/files/{fileToken}/contents` | putFile — receive saved file |
| POST | `/seclore/1.0/files/{fileToken}/initedit` | initEdit — confirm edit is permitted |
| POST | `/seclore/1.0/files/{fileToken}/edit` | edit — re-open in edit mode (browser redirect) |
| POST | `/seclore/1.0/renewToken` | Renew expired access token |
| POST | `/seclore/1.0/files/{fileToken}/events/open` | Open event notification |
| POST | `/seclore/1.0/files/{fileToken}/events/close` | Close event notification |
