# Seclore Policy Federation — ARA Callback API Reference

This document covers the Access Right Adaptor (ARA) HTTP callback API that an integrating
application must implement to support Policy Federation (Full Federation mode).

Load this file when someone asks about implementing Policy Federation in their application,
the ARA callback format, the request/response XML, how to handle specific response scenarios,
or troubleshooting Policy Federation errors.

---

## What is the ARA Callback API?

When a user opens a Seclore-protected file, Policy Server (PS) calls back to the integrating
application to ask: *"Does this user have access to this file, and if so, what rights?"*

The integrating application exposes an HTTP service — the ARA — that receives this call,
looks up the user's permissions in its own system, and returns the answer to PS. PS then
enforces whatever the application says.

This is what makes Policy Federation so powerful and unique — the access decision lives entirely
in the integrating application, not in a static Seclore policy.

---

## Policy Server Configuration

Policy Server Admin Console (root or GSA): **Configuration → Enterprise Application → Policy Federation**

| Field | Value |
|-------|-------|
| Policy Federation | Enabled |
| Access Right Adaptor type | Full Federation |
| ARA HTTP service base URL | Your service URL, e.g. `https://app.example.com/seclore/services/request/` |
| Authentication scheme | `0` = No authentication, `1` = Basic Auth |
| Basic Auth username | (only if scheme = 1) |
| Basic Auth password | (only if scheme = 1) |

**URL routing:** PS appends the service path to your base URL:
- `{base-url}/ping`
- `{base-url}/getaccessright`
- `{base-url}/getfileinformation`

**Authentication:** Only Basic Auth is supported — no OAuth or token-based auth. Since only
Policy Server calls this endpoint, **IP-based restrictions are strongly recommended** as an
additional security measure.

---

## Endpoints to Implement

Your application must expose three HTTP POST endpoints:

| Endpoint | Service type | When PS calls it |
|----------|-------------|-----------------|
| `POST {base-url}/ping` | 1 | Periodic health check — is your ARA alive? |
| `POST {base-url}/getaccessright` | 2 | Every time a user opens a protected file |
| `POST {base-url}/getfileinformation` | 3 | When PS needs file metadata from your app |

---

## 1. Ping — `/ping`

PS calls this periodically to verify the ARA service is reachable and responding correctly.

### Request

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ara-request-ping type="1">
    <ara-request-header>
        <protocol-version>1</protocol-version>
        <request-id>0.774678771994797_40_2014:11:3:17:52:57_PS_10</request-id>
    </ara-request-header>
    <!-- No request details for ping -->
    <ara-request-details-ping/>
</ara-request-ping>
```

### Response

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ara-response-ping type="1">
    <ara-response-header>
        <request-id>0.774678771994797_40_2014:11:3:17:52:57_PS_10</request-id>  <!-- echo back -->
        <protocol-version>1</protocol-version>
        <status>1</status>
    </ara-response-header>
    <ara-response-details-ping>
        <ara-supported-protocol-versions>
            <protocol-version>1</protocol-version>
        </ara-supported-protocol-versions>
        <ara-supported-services>
            <service-type>1</service-type>  <!-- Ping -->
            <service-type>2</service-type>  <!-- GetAccessRight -->
            <service-type>3</service-type>  <!-- GetFileInformation -->
        </ara-supported-services>
    </ara-response-details-ping>
</ara-response-ping>
```

**Critical rules:**
- Always echo back the `<request-id>` from the request header in the response header
- `<protocol-version>` must be `1`
- `<status>` must be `1` (success)
- Declare only service types 1, 2, and 3 — do not declare type 4

---

## 2. GetAccessRight — `/getaccessright`

This is the core callback. PS calls it every time a user opens a protected file. Your
service must determine what rights the user has for that file and return them.

### Request

PS sends full context about the file, the user, the hot folder, and the client being used:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ara-request-get-access-right type="2">
    <ara-request-header>
        <protocol-version>1</protocol-version>
        <request-id>8cc8cb9733504cd387fd0ac4f215142b_PS_3068544</request-id>
    </ara-request-header>
    <ara-request-details-get-access-right>

        <!-- The protected file -->
        <ara-file-details>
            <fs-id>100058198</fs-id>               <!-- Seclore File ID (mandatory) -->
            <ext-id>47_SF</ext-id>                 <!-- Your app's File External Reference ID -->
            <ext-name/>                             <!-- Optional: your app's file name -->
            <ext-data/>                             <!-- Optional: any extra data you passed at protect time -->
            <protection-type>1</protection-type>   <!-- 0=Basic Protection, 1=Advanced Protection-->
            <file-status>1</file-status>            <!-- 1=Active -->
            <protection-time>2024:6:7:16:11:20</protection-time>
        </ara-file-details>

        <!-- The Hot Folder used to protect this file -->
        <ara-hot-folder-details>
            <fs-id>10003</fs-id>                   <!-- Seclore Hot Folder ID -->
            <ext-id>VFI</ext-id>                   <!-- Your HF External Reference ID -->
        </ara-hot-folder-details>

        <!-- The user trying to open the file -->
        <ara-user-details>
            <rep-code>10001</rep-code>             <!-- Repository code (mandatory unless using email-only service) -->
            <ext-id>b3891c5c-e2e9-40a4-b65e-4fb75f1bb216</ext-id>  <!-- User's SID or external ID -->
            <email-id>user@example.com</email-id>  <!-- User email -->
            <name>User Name</name>
        </ara-user-details>

        <!-- Classification of the file in Seclore -->
        <ara-classification-details>
            <name>Unclassified</name>
            <fs-id>1</fs-id>
        </ara-classification-details>

        <!-- File owner details -->
        <ara-owner-details>
            <ara-user-details>
                <rep-code>10001</rep-code>
                <ext-id>owner-ext-id</ext-id>
                <email-id>owner@example.com</email-id>
                <name>Owner Name</name>
            </ara-user-details>
        </ara-owner-details>

        <!-- When the user last accessed the file (empty if first access) -->
        <ara-file-usage-details/>

        <!-- Which Seclore client is being used to open the file -->
        <ara-client-details>
            <client-number>11</client-number>
            <client-name>Seclore Online</client-name>
        </ara-client-details>

        <!-- Who protected the file -->
        <ara-protector-details>
            <ara-user-details>
                <rep-code>10001</rep-code>
                <ext-id>protector-ext-id</ext-id>
                <email-id>protector@example.com</email-id>
                <name>Protector Name</name>
            </ara-user-details>
        </ara-protector-details>

        <!-- IP address of the request -->
        <ara-environment-details>
            <request-ip-address>49.43.225.35:12345</request-ip-address>
        </ara-environment-details>

    </ara-request-details-get-access-right>
</ara-request-get-access-right>
```

**Key fields to use in your access decision:**
- `<ara-file-details><ext-id>` — your app's File External Reference ID (use this to look up the file in your system)
- `<ara-hot-folder-details><ext-id>` — your app's HF External Reference ID (identifies which integration)
- `<ara-user-details><email-id>` — user's email (use this to look up the user)
- `<ara-client-details><client-number>` — which client is opening the file (see Client Numbers below)

### Client Numbers

| Number | Client |
|--------|--------|
| 1 | Desktop Client (Seclore Agent) |
| 2 | Web Portal |
| 3 | HotFolder Server |
| 4 | Web Services |
| 5 | WebConnect |
| 6 | AppConnect |
| 7 | FileSecure Lite (iOS) |
| 8 | FileSecure Lite (Android) |
| 9 | FileSecure Lite (Windows) |
| 10 | FileSecure Lite (Mac) |
| 11 | Seclore Online (browser-based viewer) |

Note: access right `2` (View) applies to the Desktop Agent only — it does not grant access
in Seclore Online (client 11). This typically only surfaces as an issue during troubleshooting;
see the Troubleshooting section.

### Response — User has access (Case 1)

**Always use the full response structure below — do not return only `<primary-access-right>`.
Missing optional fields default to restrictive values (e.g. `<offline-access-right>` defaults
to `false`, `<redistribute-access-right>` defaults to `false`). Include all fields explicitly
to avoid unexpected behaviour.**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ara-response-get-access-right type="2">
    <ara-response-header>
        <request-id>8cc8cb9733504cd387fd0ac4f215142b_PS_3068544</request-id>  <!-- echo back -->
        <protocol-version>1</protocol-version>
        <status>1</status>
    </ara-response-header>
    <ara-response-details-get-access-right>
        <ara-access-right-details>
            <primary-access-right>34</primary-access-right>      <!-- User's rights — see Access Rights table -->
            <offline-access-right>false</offline-access-right>   <!-- true to grant offline access -->
            <redistribute-access-right>false</redistribute-access-right>
            <lock-to-first-machine>false</lock-to-first-machine>
            <no-of-days-since-protection/>   <!-- empty = no limit -->
            <no-of-days-since-first-access/> <!-- empty = no limit -->
            <date-embargo>
                <end-time/>                  <!-- empty = no expiry; see Offline Access for format -->
            </date-embargo>
        </ara-access-right-details>

        <!-- Optional: include only if your use case requires watermarks -->
        <ara-watermark-details>
            <lines>
                <line>$USERNAME$</line>
                <line>$USEREMAIL$ $VIEWTIME$</line>
            </lines>
            <font>
                <face>Arial</face>
                <bold>false</bold>
                <italic>false</italic>
            </font>
            <color>DCDCDC</color>
        </ara-watermark-details>

        <!-- Optional -->
        <ara-owner-details>
            <ara-user-details>
                <rep-code>10001</rep-code>
                <ext-id>owner-ext-id</ext-id>
                <email-id>owner@example.com</email-id>
                <name>Owner Name</name>
            </ara-user-details>
        </ara-owner-details>
    </ara-response-details-get-access-right>
</ara-response-get-access-right>
```

**PS action:** Opens the file with the returned rights.

---

### Response — User has no access (Case 2)

```xml
<ara-response-get-access-right type="2">
    <ara-response-header>
        <request-id><!-- echo back --></request-id>
        <protocol-version>1</protocol-version>
        <status>1</status>         <!-- status is STILL 1 — success means you processed the request -->
    </ara-response-header>
    <ara-response-details-get-access-right>
        <ara-access-right-details>
            <primary-access-right>0</primary-access-right>  <!-- 0 = no access -->
        </ara-access-right-details>
        <!-- IMPORTANT: ara-display-message is at THIS level, NOT inside ara-access-right-details -->
        <ara-display-message>You do not have access to this document. Contact your administrator.</ara-display-message>
    </ara-response-details-get-access-right>
</ara-response-get-access-right>
```

**PS action:** Denies access and displays the `<ara-display-message>` to the user.

> **Critical:** `<status>` must be `1` even when denying access. The denial is communicated
> through `<primary-access-right>0</primary-access-right>`, not through the status code.
> `<status>0</status>` is not a valid value and will cause PS to throw an ARAException.

---

### Response — Your service has an internal error (Case 3)

```xml
<ara-response-get-access-right type="2">
    <ara-response-header>
        <request-id><!-- echo back --></request-id>
        <protocol-version>1</protocol-version>
        <status>-290013</status>
        <error-message>Internal database error while looking up user permissions.</error-message>
        <display-message>Unable to verify your access. Please contact your administrator.</display-message>
    </ara-response-header>
</ara-response-get-access-right>
```

**PS action:** Logs `<error-message>` and displays `<display-message>` to the user.

> Use `-290013` for internal errors. You may use other negative codes for different error
> conditions — PS logs the code, which aids troubleshooting.

---

### Case 4 — PS cannot reach your service

When your ARA URL is misconfigured or unreachable, PS never gets a response. It logs the
HTTP error (e.g. 500, 401, connection refused) and shows a standard "contact administrator"
message to the user. Your service receives no request.

**Common causes:** Wrong URL configured in PS, service not running, firewall blocking PS's
IP. Verify by checking the Ping endpoint.

---

## 3. GetFileInformation — `/getfileinformation`

PS calls this to retrieve file metadata from your application.

### Request

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ara-request-get-file-information type="3">
    <ara-request-header>
        <protocol-version>1</protocol-version>
        <request-id>0.774678771994797_40_2014:11:3:17:52:57_PS_11</request-id>
    </ara-request-header>
    <ara-request-details-get-file-information>
        <ara-file-details>
            <fs-id>10</fs-id>
            <ext-id>Unique Identifier of the file in your application</ext-id>
            <ext-name>MISReport Aug-2014.xls</ext-name>
            <ext-data>Any metadata passed at protect time</ext-data>
            <protection-type>0</protection-type>
            <file-status>1</file-status>
            <protection-time>2016:01:20:11:02:56</protection-time>
        </ara-file-details>
        <ara-hot-folder-details>
            <fs-id>200</fs-id>
            <ext-id>Unique Identifier of the HotFolder in your system</ext-id>
            <ext-name>MIS Reports</ext-name>
        </ara-hot-folder-details>
        <ara-owner-details>
            <ara-user-details>
                <ext-id>owner-SID</ext-id>
                <rep-code>1</rep-code>
                <name>Test Owner</name>
                <email-id>testowner@example.com</email-id>
            </ara-user-details>
        </ara-owner-details>
        <ara-classification-details>
            <fs-id>3</fs-id>
            <name>Restricted</name>
        </ara-classification-details>
    </ara-request-details-get-file-information>
</ara-request-get-file-information>
```

### Response

**Implementation guidance:** For most integrations, simply echo back the same `<ara-owner-details>`
and `<ara-classification-details>` values received in the request. You only need to return
different values if your application tracks file ownership or classification changes over time
and wants PS to reflect those updates.

```xml
<ara-response-get-file-information type="3">
    <ara-response-header>
        <request-id><!-- echo back from request --></request-id>
        <protocol-version>1</protocol-version>
        <status>1</status>
    </ara-response-header>
    <ara-response-details-get-file-information>
        <!-- Echo back the owner from the request, or supply updated details if your app tracks ownership changes -->
        <ara-owner-details>
            <ara-user-details>
                <ext-id>owner-SID</ext-id>
                <rep-code>1</rep-code>
                <name>Owner Name</name>
                <email-id>owner@example.com</email-id>
            </ara-user-details>
        </ara-owner-details>
        <!-- Echo back the classification from the request, or supply updated details if required -->
        <ara-classification-details>
            <fs-id>1</fs-id>
            <name>Unclassified</name>
        </ara-classification-details>
    </ara-response-details-get-file-information>
</ara-response-get-file-information>
```

---

## Access Rights Reference

Values for `<primary-access-right>` in the GetAccessRight response:

| Value | Right | Notes |
|-------|-------|-------|
| 0 | No access | Deny access — still return `<status>1</status>` |
| 2 | View | Desktop Agent only — does NOT grant Seclore Online access |
| 6 | Light View | |
| 10 | Print | |
| 34 | Edit | |
| 170 | Full Control | Do not combine with bitwise OR |
| 258 | Copy Data | |
| 514 | Screen Capture | |
| 1026 | Macro | |
| 65535 | Owner | Do not combine with bitwise OR |

**Combining rights:** Use bitwise OR for combinations — e.g. View + Print = `2 | 10 = 10`.
Do not apply bitwise OR to Full Control (170) or Owner (65535).

---

## Offline Access

To grant offline access, set `<offline-access-right>true</offline-access-right>` in the
GetAccessRight response.

To control how long offline access lasts, set the expiry via `<date-embargo><end-time>`:

```xml
<ara-access-right-details>
    <primary-access-right>34</primary-access-right>
    <offline-access-right>true</offline-access-right>
    <date-embargo>
        <end-time>2026-06-15T23:59:59.000+00:00</end-time>  <!-- UTC -->
    </date-embargo>
</ara-access-right-details>
```

**Date format:** `yyyy-MM-dd'T'HH:mm:ss.SSSZZZ:ZZ`

Example: `2019-03-04T16:30:50.241+05:30`

| Part | Example | Description |
|------|---------|-------------|
| `yyyy` | `2026` | Year |
| `MM` | `06` | Month |
| `dd` | `15` | Day |
| `HH` | `23` | Hours (24h) |
| `mm` | `59` | Minutes |
| `ss` | `59` | Seconds |
| `SSS` | `000` | Milliseconds |
| `ZZZ:ZZ` | `+00:00` | Timezone offset |

**Always send UTC.** Convert from your local timezone before sending.

**Dynamic expiry:** If your UI lets users configure "10 days offline access", calculate:
`end-time = current UTC time at moment of ARA request + 10 days`, formatted as above.

---

## Watermark Support

You can include a dynamic watermark in the GetAccessRight response. PS applies it when
the user opens the file.

```xml
<ara-watermark-details>
    <lines>
        <line>$USERNAME$</line>               <!-- replaced with user's display name -->
        <line>$USEREMAIL$ $VIEWTIME$</line>   <!-- replaced with email and view time -->
        <line>Confidential</line>             <!-- static text -->
    </lines>
    <font>
        <face>Arial Black</face>   <!-- font name, case sensitive -->
        <bold>false</bold>
        <italic>false</italic>
    </font>
    <color>DCDCDC</color>          <!-- 6-digit hex, e.g. DCDCDC = light grey -->
</ara-watermark-details>
```

**Available variables:** `$USERNAME$`, `$USEREMAIL$`, `$VIEWTIME$`, `$FILEID$`, `$FILECLASS$`

Maximum 4 `<line>` elements inside `<lines>`. Each `<line>` is one row of the watermark displayed
on the document. Multiple variables and static text can be combined within a single `<line>`.

---

## Critical Implementation Rules

Three rules that must be correct in every response:

1. **Always echo `<request-id>` back in the response header.** PS uses this for correlation.

2. **`<protocol-version>` must always be `1`.** Never `0`.

3. **`<status>` must be `1` (success) or a negative error code.** Never `0`.
   Deny access by returning `<status>1</status>` with `<primary-access-right>0</primary-access-right>` —
   never use `<status>0</status>`. Status `0` is not a recognized value and causes PS to throw
   an `ARAException` (-2500020).

---

## Troubleshooting

### `ARAException: Unknown Response Status '0'` (-2500020)

**Symptom:** User is denied access. PS logs show: `ARAException: Unknown Response Status '0'- (-2500020)`

**Cause:** The ARA service is returning `<status>0</status>` in the response header — typically
when the user has no rights and the service incorrectly maps "no access" to status `0`.
`0` is not a recognized status value.

**What happens:** PS receives an invalid response and throws an ARAException. The request
flow terminates.

**Fix:** Always return `<status>1</status>`. Communicate "no access" through
`<primary-access-right>0</primary-access-right>`.

**Incorrect:**
```xml
<ara-response-header>
    <protocol-version>0</protocol-version>  <!-- wrong -->
    <status>0</status>                      <!-- wrong -->
</ara-response-header>
```

**Correct:**
```xml
<ara-response-header>
    <request-id><!-- echo back --></request-id>
    <protocol-version>1</protocol-version>  <!-- always 1 -->
    <status>1</status>                      <!-- always 1 for successful processing -->
</ara-response-header>
```

---

### User gets "Request Access" page when opening file in Seclore Online

**Symptom:** File opens fine in the Desktop Agent but "Request Access" is shown in
Seclore Online (browser viewer).

**Cause:** ARA returning `<primary-access-right>2</primary-access-right>` — right `2`
(View) applies only to the Desktop Agent and does not grant access in Seclore Online.

**Diagnosis:** Check `<ara-client-details><client-number>` in the ARA request.
Client `11` = Seclore Online. If the user is using client 11, right `2` alone is
insufficient.

**Fix:** Return rights appropriate for browser-based access when `<client-number>11</client-number>`.
Also check whether a hardcoded test value was left in the ARA response instead of
a real lookup — this is a common cause.

**Log to check:** Enable ARA request/response logging in PS (Correlation ID is logged)
and verify the exact `<primary-access-right>` value being returned.

---

### PF connection reported as "down" by PS monitoring

**Cause:** PS cannot reach the `/ping` endpoint, or the Ping response is invalid.

**Checks:**
1. Is the ARA service running?
2. Is the base URL configured in PS correct (including trailing slash if needed)?
3. Is PS's IP address allowed through your firewall?
4. Does your `/ping` endpoint return a valid response with `<status>1</status>` and the
   correct `<ara-supported-services>` block?

---

### Testing Your ARA Service

Before connecting Policy Server, verify the ARA endpoints independently.

**Tools:** Postman, Insomnia, curl, or SoapUI. All work — Postman is the most common choice.

**How PS sends requests:**
- HTTP POST to each endpoint
- `Content-Type: application/xml`
- Request XML is sent in the request body (not as a query parameter)
- If Basic Auth is configured in PS, include the same credentials in your test request

**Test sequence:**
1. Send a sample Ping XML to `{base-url}/ping` — verify you get `<status>1</status>` back
2. Send a sample GetAccessRight XML to `{base-url}/getaccessright` with a known user and file
3. Send a sample GetFileInformation XML to `{base-url}/getfileinformation`

Use the sample XML from the sections above as your Postman request bodies. Connectivity failures
typically show up at the Ping step first, so always test Ping before the other endpoints.

**Common HTTP errors during testing:**

| HTTP code | Likely cause | Action |
|-----------|-------------|--------|
| 400 Bad Request | Your service rejected the request — malformed XML or missing content-type | Check your endpoint's input parsing; verify `Content-Type: application/xml` |
| 401 Unauthorized | Basic Auth credentials mismatch between PS config and your service | Verify the username/password configured in PS matches what your service expects |
| 404 Not Found | Wrong URL path — endpoint not mapped correctly | Check the base URL + path suffix (`/ping`, `/getaccessright`, `/getfileinformation`) |
| 500 Internal Server Error | Your service threw an unhandled exception | Check your application logs; add error handling around the XML parsing and DB lookup |
| Connection refused / timeout | PS cannot reach your service — network or firewall issue | Verify the ARA service is running and that PS's server IP is allowed through your firewall |

**Network access check:** The ARA endpoints must be reachable from the server where Policy Server
is hosted, not just from your local machine. If you can reach the endpoint locally but PS reports
it as down, the issue is network/firewall between the PS host and your service.

**Certificate issues:** If your ARA service runs on HTTPS with a self-signed certificate or an
internal CA certificate, Policy Server (which runs on a JVM) will reject the connection with an
SSL handshake error. Fix options:
- **Recommended:** Use a certificate signed by a public CA or your organisation's trusted CA
- **Internal CA:** Import your CA's root certificate into the JVM truststore on the Policy Server
  host (`cacerts` file in the JRE, using `keytool -importcert`)
- **Self-signed (non-production only):** Import the specific certificate into the PS JVM truststore

The symptom in PS logs is typically `SSLHandshakeException` or `PKIX path building failed` — the
same pattern as SDK-to-PS SSL issues.

---

## Behavioral Notes

**Policy Federation overrides predefined policies:** When PF is enabled on a Hot Folder,
PS queries the ARA for every file open. The ARA response determines access. If the ARA
throws an exception (due to invalid response), the request fails completely — predefined
Seclore policies are not used as a fallback.

**When both PF and predefined policies exist:** In a correctly working setup, PS queries
the ARA first and then also checks predefined policies. However, this fallback only occurs
when the ARA responds successfully. An ARA exception breaks the entire flow.

**User identification:** PS sends `<rep-code>` + `<ext-id>` (SID or external ID) to
identify users. Use `<email-id>` for lookups if your system stores users by email.

**File identification:** Use `<ara-file-details><ext-id>` — this is the File External
Reference ID your application passed at protection time via the `<file-extn-reference>`
protection XML. This is what links the file back to your system's record.
