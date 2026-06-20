# Seclore Server SDK — Integration Reference Guide

> **Who this is for:** Developers and architects integrating the Seclore Server SDK (Java)
> into their applications.

---

## Contents

1. [Policy Server Configuration Checklist](#1-policy-server-configuration-checklist)
2. [Common Developer Questions](#2-common-developer-questions)
3. [Troubleshooting & Error Reference](#3-troubleshooting--error-reference)
4. [Developer Integration Reference — All Patterns](#4-developer-integration-reference--all-patterns)
5. [Policy Federation Deep Dive](#5-policy-federation-deep-dive)
6. [HTML Wrapping — Concept and API](#6-html-wrapping--concept-and-api)
7. [Advanced EA Setup Walkthrough](#7-advanced-ea-setup-walkthrough)
8. [Access Rights Reference](#8-access-rights-reference)
9. [SDK API Quick Reference](#9-sdk-api-quick-reference)
10. [Integration Verticals — Common Patterns](#10-integration-verticals--common-patterns)
11. [Checking File Protection Status](#11-checking-file-protection-status)
12. [Querying File Protection Details and User Access Permission](#12-querying-file-protection-details-and-user-access-permission)

---

## 1. Policy Server Configuration Checklist

Run through this before starting an integration. Missing items here are the #1 cause of demo failures.

### For Hot Folder Protection (PROTECT_WITH_HF)

- [ ] At least one **Hot Folder** configured in Policy Server (note its numeric ID)
- [ ] Hot Folder is created **inside the EA used for initialization of SDK**
- [ ] EA ID and passphrase are known

### For Independent Rights Protection (PROTECT)

- [ ] Owner email address is known (can be a test account)
- [ ] At least one recipient email is known for access rights mapping

### For External Reference Protection (PROTECT_WITH_HF_EXT_REF)

- [ ] A **Hot Folder configured with an External Reference ID** exists in Policy Server
  - Policy Server GSA: go to the Hot Folder settings and set an External Reference ID (e.g., `DEMO-HF-001`)
- [ ] The **Policy Federation** setting is enabled on the EA in Policy Server. This is not mandatory.
  - Policy Server admin: EA → Policy Federation → set type to "Full Policy Federation"
  - The adapter URL must point to the integrating app's policy callback endpoint
- [ ] Hot Folder is created **inside the EA used for initialization of SDK**
- [ ] HF External Reference ID is known
- [ ] A unique **File External Reference ID** is ready (your app's file identifier, e.g., `DOC-2024-00789`). This should be your application's actual file identifier.

### For Unprotect Any File (Advanced EA)

Advanced Security and Advanced Privileges are configured independently. All three steps below are required:

- [ ] **Advanced Security configured in Policy Server:** EA has Advanced Security enabled; RSA public key registered (see Section 4 and Section 11)
- [ ] **Privilege flag enabled in Policy Server:** "Unprotect any file" privilege is set to Enabled for the EA in Policy Server
- [ ] **Active Key ID** from Policy Server is entered in the demo configuration
- [ ] **`allow-advanced-privileges` = `true`** in the tenant config XML (the demo sets this when "Enable Advanced EA" is checked)

> Note: Enabling Advanced Security alone does not grant Unprotect Any File. The privilege flag in Policy Server must also be set, and `allow-advanced-privileges` must be `true` in the config.

### General

- [ ] The demo machine can reach the Policy Server URL on the configured port
- [ ] SSL certificates — if self-signed, the demo handles this automatically (trust-all is built in for testing; NOT for production)
- [ ] EA passphrase is correct — verify by initialising the SDK; an immediate error means wrong passphrase

---


---

## 2. Common Developer Questions

**Q: What file formats are supported?**

The SDK supports Office formats (.docx, .xlsx, .pptx), PDF, text files, images (JPEG, PNG,
TIFF), CAD files, and many others. Call `tenantObj.isSupportedFile(path)` to check at
runtime. Always check the latest version of Seclore File Format Support document published at [Seclore File Format Support](https://docs.seclore.com/home/supported-environments-and-file-formats)


---

**Q: Does the file have to be on local disk? Can we stream the file in binary?**

The SDK requires physical access to the file to apply encryption, and therefore expects
the absolute path of the file. Binary streams are not supported.

However, the application does not need to provide the path of the original source file.
The recommended approach is:

1. Copy the source file to a temporary location on the server.
2. Pass the temporary file path to the SDK — Seclore will protect that file in place.
3. The application can then stream the protected file to the user (for a download flow)
   or store it for future delivery and delete the temp file.

The original source file remains unaffected.

---

**Q: Do we need to manage SDK connections manually, or does the SDK handle connection pooling?**

`protectAndWrap` and `unwrapAndUnprotect` accept a `PSConnection` as the first parameter.
Pass `null` to let the SDK use a pooled session from the tenant configuration (recommended
for server-side use). Using the pooled session is the standard approach for server-side pipelines.

---

**Q: Can we protect files in bulk? What is the performance?**

Yes — the SDK is designed for server-side bulk operations. The session pool in the tenant
config controls concurrency: `<max-size>50</max-size>`. Each `protectAndWrap` call is
independent and thread-safe. For large volumes, run multiple threads each with their own
`FSHelper` reference.

---
**Q: Can we configure the number of concurrent connections to the Policy Server? Is there a risk in setting the pool size too high?**

Yes. The connection pool size is defined in the tenant configuration file using the
`<max-size>` parameter:

```xml
<session-pool>
    <max-size>50</max-size>
</session-pool>
```

The default value is **50**. Set this based on the number of files your application
intends to protect or unprotect concurrently.
Each connection in the pool maps to an active session on the Policy Server.
Increasing the pool size adds load on the Policy Server — so the hardware sizing of
the PS environment must be factored in before scaling up. Coordinate with your
infrastructure team to ensure the Policy Server can handle the expected concurrency
before increasing `<max-size>` beyond the default.

---
**Q: What happens if Policy Server is unreachable?**

The SDK throws an exception. Protection always requires Policy Server reachability.

---

**Q: What user details do we pass for Independent Rights — email or entity ID?**

The SDK operates on **entity IDs** assigned by the Policy Server, not email addresses
directly. Integrating application is responsible for resolving emails to entity IDs before
calling `protectAndWrap()`. The flow is:

1. Call `sendRequest()` **(Type 74)** with the user's email to query PS and retrieve
   their entity ID.
2. For external user, if the user does not exist in PS, call `sendRequest()` **(Type 109)** to create
   the user first. User gets created in Seclore FIM.
3. Build the Independent Rights XML using the entity IDs returned.
4. Call `protectAndWrap()` with the constructed XML.

The demo portal performs all these steps automatically and shows the exact
`sendRequest()` calls and XML structure in the code walkthrough panel — that is the
most reliable reference for implementing this in your application.

---

**Q: What if our Policy Server is integrated with Active Directory or SSO?**

The flow is the same. Pass the user's corporate email address to `sendRequest()`
(Type 74). When PS is integrated with AD or SSO, users are searched from the AD/SSO with their
corporate email as the identifier, so the lookup resolves correctly to the
user record in the customer's identity system. No SIDs, UPNs, or AD-specific attributes are needed
in your application code.

**Q: How do we know who protected or unprotected a file?**

Every SDK operation is recorded in the Policy Server audit trail. The `activityComments` parameter
passed to `protectAndWrap` / `unwrapAndUnprotect` appears alongside the operation in the
Policy Server activity log. The EA identity and Hot Folder details is also logged.

---

**Q: Is the trust-all SSL setup safe for production?**

No. The trust-all `SSLContext` in the demo is for convenience in test environments with
self-signed Policy Server certificates. In production, import the Policy Server certificate into the JVM
truststore and remove the trust-all initialiser from your code.

---

**Q: Can we use a specific Policy Server connection instead of the pooled session?**

Yes. Pass a `PSConnection` object as the first parameter instead of `null`:
```java
// Use pooled session (recommended for server-side use):
tenantObj.protectAndWrap(null, inputFilePath, protectionXml);
// Use a specific PSConnection:
tenantObj.protectAndWrap(psConnection, inputFilePath, protectionXml);
// Unprotect with pooled session:
tenantObj.unwrapAndUnprotect(null, inputFilePath, activityComments);
```
For most server deployments, passing `null` (pooled session) is the correct choice.

---

**Q: What format should the file path be in? Can we use a network path?**

The SDK requires an **absolute path** accessible from the server process running the SDK.
Relative paths are not supported. Examples:

| Environment | Example path |
|-------------|-------------|
| Windows — local disk | `C:\demo\files\report.docx` |
| Windows — network share (UNC) | `\\fileserver\shared\documents\report.docx` |
| Linux — local disk | `/home/app/files/report.docx` |
| Linux — network mount (NFS) | `/mnt/nas/documents/report.docx` |

The path is resolved on the machine where the SDK is running — not the machine calling
the API. For server-side integrations, ensure the file is either on the server's local
disk or on a network share mounted and accessible to the server process. SDK should have read and write access on the path.

---

## 3. Troubleshooting & Error Reference

### "Connection Error: Failed to fetch"

The browser can't reach the backend server on port 8080.
- **Cause:** The server is not running, or port 8080 is blocked.
- **Fix:** Confirm `launch.bat` or `demo-setup.bat` command window is still open.
- **Check:** `netstat -ano | findstr :8080` — if nothing shows, the server stopped.
- **Firewall:** Check Windows Defender Firewall is not blocking port 8080.

---

### "Initialization Failed: Failed to verify configuration XML"

The app config XML sent to `FSHelperLibrary.initialize()` is malformed.
- **Cause:** One or more SDK Configuration fields are blank.
- **Fix:** Fill in ALL fields (Policy Server URL, Port, App Name, EA ID, Passphrase) before
  clicking Initialize.

---

### "Sorry, authentication failed due to missing authentication token" / "Failed to authenticate the session"

- **Cause:** Policy Server rejected the EA login. This error surfaces at the first SDK operation —
  `initializeHelper()` does not contact Policy Server; it only stores the config locally. Any of the
  following can trigger it:
  1. **Wrong or blank passphrase** — Re-enter the correct passphrase and click Initialize SDK again.
  2. **"Enable Advanced EA" not checked** — If the EA has Advanced Authentication enabled in Policy
     Server, the "Enable Advanced EA (requires CryptoHandler)" checkbox must be checked before
     initializing. Check it and re-initialize.
  3. **EA is disabled in Policy Server** — Confirm the EA is active (not disabled) in PS admin.
  4. **Wrong EA ID** — Verify the numeric ID (not the EA name) in PS.
- **Log evidence:** In `logs\WSClient.log`:
  ```
  Sorry, authentication failed due to missing authentication token.
  PSCPException: Failed to authenticate the session.
    at PSConnection.login(...)
  ```

---

### "Invalid EA credentials" / "EA Authentication failed" (-220001 or similar)

- **Cause:** Wrong EA ID or passphrase.
- **Fix:** Verify EA ID (it is the numeric ID shown in Policy Server under the EA listing, not the EA
  name) and the passphrase.

---

### "SSLHandshakeException" / "PKIX path building failed"

**Who rejects the cert:** The JVM — not the SDK and not Policy Server. The rejection happens during the TLS handshake before the SDK sends any request. The SDK surfaces it as "Failed to open output stream" because the connection was never established.

**Root causes (in order of likelihood):**

1. **Self-signed or private CA cert on Policy Server** — Java's `cacerts` truststore doesn't include private/internal CAs. Most common in on-prem PS deployments.
2. **SSL inspection proxy (e.g. Zscaler, Blue Coat)** — A network proxy is intercepting HTTPS and re-signing with its own cert. The JVM sees the proxy's cert, not the PS cert. Identifiable by checking the cert issuer in a browser — if it shows a proxy/security vendor instead of the PS domain's actual CA, SSL inspection is active.
3. **Outdated JDK** — Missing newer public CA roots in an old `cacerts`.
4. **Trust-all initialiser removed from demo code or JAR changed** — Demo-specific; rebuild with `demo-setup.bat`.

---

**Temporary unblock (testing/demo only — never use in production):**

Add this static block to the class that initialises the SDK. It bypasses all cert validation:

```java
static {
    try {
        TrustManager[] trustAll = new TrustManager[]{
            new X509TrustManager() {
                public X509Certificate[] getAcceptedIssuers() { return null; }
                public void checkClientTrusted(X509Certificate[] certs, String authType) {}
                public void checkServerTrusted(X509Certificate[] certs, String authType) {}
            }
        };
        SSLContext sc = SSLContext.getInstance("TLS");
        sc.init(null, trustAll, new java.security.SecureRandom());
        HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory());
        HttpsURLConnection.setDefaultHostnameVerifier((hostname, session) -> true);
    } catch (Exception e) {
        throw new RuntimeException("Failed to initialize trust-all SSL", e);
    }
}
```

The demo portal's `UnifiedProtectionServer.java` already includes this static block — if the error appears in the demo, delete the `build\` folder and re-run `demo-setup.bat` to force a full recompile.

---

**Permanent fix — import the PS cert into the JVM truststore:**

Step 1 — Export the cert (from any browser, or via CLI):

```bash
openssl s_client -connect <ps-host>:<port> -showcerts </dev/null 2>/dev/null \
  | openssl x509 -outform DER -out PS.cer
```

When saving from a browser: select DER-encoded binary, single certificate (`*.der`).

Step 2 — Import into the JVM truststore:

```cmd
"<jre>\bin\keytool.exe" -import -alias seclore-ps -file PS.cer ^
  -keystore "<jre>\lib\security\cacerts" -storepass changeit
```

Type `yes` when prompted. Restart the application after import.

Step 3 — Verify the import:

```cmd
"<jre>\bin\keytool.exe" -list -alias seclore-ps ^
  -keystore "<jre>\lib\security\cacerts" -storepass changeit
```

---

**If an SSL inspection proxy is involved:**

Importing the PS cert will not help — the JVM is seeing the proxy's cert, not the PS cert. Two options:
- (a) Import the proxy's Root CA cert into the JVM truststore
- (b) Ask the network team to whitelist the PS hostname from SSL inspection

Option (b) is cleaner and the recommended approach.

---

**Important — identify the correct JVM:**

The JVM truststore location varies by runtime. Always identify which JVM the integrating application actually uses — it may not be the system default JRE. On Windows:

```cmd
wmic process where "name='java.exe'" get ExecutablePath
```

This shows the exact JVM binary in use. Import the cert into that JVM's `cacerts`, not the system default.

---

### Server closes immediately on launch / `logs\WSClient.log` not created

- **Cause:** `config\log4j2.xml` is incompatible with the Seclore SDK logger. The SDK
  requires an `<AsyncLogger>` named `WSCLIENT` and a `<RollingRandomAccessFile>` appender
  named `WSCLIENT_APPENDER`, with `${ctx:applicationPath}` as the dynamic log base path.
  A mis-generated file (e.g., using `<RollingFile>` + `<Root>` logger + hardcoded path)
  causes the logger to fail at startup, which may crash the SDK initialization.
- **Fix:** Delete `config\log4j2.xml` and re-run `demo-setup.bat` — it now generates the
  correct format automatically. Alternatively, replace the file with this exact content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="info" >
  <Properties>
    <Property name="basePath">${ctx:applicationPath}/logs</Property>
  </Properties>
  <Loggers>
    <AsyncLogger name="WSCLIENT" level="info" additivity="false" >
      <appender-ref ref="WSCLIENT_APPENDER"  />
    </AsyncLogger>
  </Loggers>
  <Appenders>
    <RollingRandomAccessFile name="WSCLIENT_APPENDER"
        fileName="${basePath}/WSClient.log"
        filePattern="${basePath}/WSClient_%d{yyyy-MM-dd}_%i.log.zip">
      <PatternLayout>
        <charset>UTF-8</charset>
        <pattern>%d{MMM dd, yyyy HH:mm:ss.SSS}: %t: %p: %m%n</pattern>
      </PatternLayout>
      <Policies>
        <TimeBasedTriggeringPolicy interval="1" modulate="true" />
        <SizeBasedTriggeringPolicy size="10MB"/>
      </Policies>
      <DefaultRolloverStrategy fileIndex="nomax"/>
    </RollingRandomAccessFile>
  </Appenders>
</Configuration>
```

- **Signs:** Command window closes within a second of running `launch.bat`; no
  `logs\WSClient.log` file appears; the browser shows "Connection Error: Failed to fetch"
  immediately.

---

### "Missing parameter 'id'" / Hot Folder protection fails with -240,003

- **Cause:** The Hot Folder ID field was left blank. The SDK sends `<hot-folder><id></id></hot-folder>`
  with an empty `<id>` element. Policy Server requires a non-empty `<id>` and returns -240,003.
- **Fix:** Enter the numeric Hot Folder ID (from Policy Server) in the Hot Folder ID field before
  clicking Protect or Protect Only.
- **Confirm:** Open `logs\WSClient.log` and look for `server error: -240,003 Missing parameter 'id'`.
  This message distinguishes the empty-ID scenario from the "owner not found" scenario below.
- **Note:** This applies to both the **Protect** button (`protectAndWrap`) and the **Protect Only**
  button (`protectX`) — both build the same XML and will fail identically if the ID is blank.

---

### "owner not found in repository" (-240003)

- **Cause:** The owner email entered for Independent Rights does not exist in Policy Server and could
  not be auto-created.
- **Fix 1:** Verify the email address is correct (typos are common).
- **Fix 2:** Create the user manually in Policy Server before the demo.

---

### "User is not authenticated with the Enterprise Application 'X'" (-220133)

Four scenarios. The EA number in the error message is the clue:

1. **Protect — Hot Folder belongs to a different EA:**
   - **Cause:** You initialized with EA *X* but the Hot Folder ID entered belongs to EA *Y*. Policy Server looks up which EA owns that Hot Folder, finds it's EA *Y*, checks if EA *Y* is authenticated (it's not — you authenticated as EA *X*), and returns `-220,133` with EA *Y*'s name/number.
   - **Clue:** The EA number in the error is *different* from the Cabinet ID you entered in the Configuration tab.
   - **Fix:** Switch to the correct EA credentials that own the Hot Folder, or verify the Hot Folder ID in Policy Server admin and use one that belongs to your current EA.

2. **Unprotect Any File — Advanced privilege not enabled:**
   - **Fix:** `allow-advanced-privileges` is not set to `true`. Ensure "Enable Advanced EA" is checked in the Configuration tab before clicking Initialize.

3. **Standard Unprotect — Wrong EA for this file:**
   - **Fix:** You are trying to unprotect a file that was protected by a different EA. Either use Unprotect Any File mode (Advanced EA), or use the same EA credentials that protected the file.

4. **External Reference Protect — Hot Folder has no External Reference ID configured:**
   - **Cause:** You are using `PROTECT_WITH_HF_EXT_REF` and the `hfExtRefId` value you sent does not match any External Reference ID configured on the Hot Folder in Policy Server. Policy Server cannot resolve the Hot Folder via external reference and returns `-220,133`.
   - **Clue:** The EA number in the error matches your current EA (not a different EA) and the operation is an External Reference protect. The error occurs even though your EA credentials are correct.
   - **Fix:** In Policy Server admin, open the Hot Folder settings and set the **External Reference ID** field to match exactly what your application sends as `hfExtRefId` in the protection XML. External Reference IDs are case-sensitive.

---

### "Not protected with any HotFolder managed by you" (-220,473)

- **Cause:** The file was protected by a different EA than the one currently initialized.
  Standard unprotect checks whether the initialized EA owns one of the Hot Folders
  associated with the file — if it does not, Policy Server rejects the operation.
- **Distinction from -220133:** -220133 = EA lacks advanced privileges; -220473 = EA
  simply does not own this file's Hot Folder.
- **Fix:** Use **Unprotect Any File** mode. Check "Enable Advanced EA" in the
  Configuration tab, click Initialize SDK again, then retry unprotect.
- **When you see this:** Typically when unprotecting a file that was protected by a
  different EA, a different team member's configuration, or a different environment.

---

### "Invalid file format 'X' for HTML unwrapping" (WSClientException)

- **Cause:** The file was protected with `protectX()` (native format, no HTML envelope). You clicked *Unprotect & Unwrap* which internally calls `unwrapAndUnprotect()` → `unwrap()` — and `unwrap()` requires an HTML file.
- **Log evidence:** In `logs\WSClient.log`:
  ```
  WSClient :: unwrap : File 'filename.docx' is not a html file.
  WSClientException: Invalid file format 'docx' for HTML unwrapping.
  ```
- **Fix:** Use the **Unprotect Native File** section in the Unprotect tab. This calls `unprotectX()` instead. Enter the same file path and click *Unprotect Native File*.
- **Rule of thumb:**
  - Protected with *Protect + Wrap (HTML)* button → decrypt with *Unprotect & Unwrap* (`unwrapAndUnprotect`)
  - Protected with *Protect Only (No Wrap)* button → decrypt with *Unprotect Native File* (`unprotectX`)

---

### "Failed to parse RSA Key XML" / "Failed to fetch Session Key"

- **Cause:** The private key XML format is invalid (usually happens after manually editing
  `config/keypair.properties`).
- **Fix:** Delete `config/keypair.properties`, regenerate the key pair with the Generate
  button in the demo, re-register the new public key in Policy Server, enter the new Active Key ID,
  re-initialize.

---

### "Hot folder not found" (-240005) or "-240004"

- **Cause (PROTECT_WITH_HF):** The Hot Folder ID entered does not exist on the Policy Server, or the
  EA does not have rights in it.
- **Cause (PROTECT_WITH_HF_EXT_REF):** The HF External Reference ID entered does not
  match any Hot Folder configured on the Policy Server.
- **Fix:** Verify the Hot Folder exists in Policy Server and the ID / external reference ID matches
  exactly (case-sensitive for external reference IDs).

---

### "Search user failed: ()" — empty result

- **Cause:** XPath parsing error in an older build (known issue, fixed).
- **Fix:** Rebuild with `setup.bat`. Should not occur in the current build.

---

### Error code quick reference

| Code | Meaning |
|------|---------|
| -220001 | EA authentication failed (wrong ID or passphrase) |
| -220133 | EA not authorized for this operation |
| -240003 | User/owner not found in repository — OR — Hot Folder `<id>` element is empty (check log for "Missing parameter 'id'") |
| -240004 | Hot Folder not found |
| -240005 | Hot Folder not accessible to EA |
| -240006 | File format not supported |
| -250001 | Policy Server connection error |
| -260001 | Invalid XML in request |
| -220473 | File not protected with any Hot Folder managed by this EA |
---

### Log file location

Detailed SDK logs: `logs/WSClient.log`  
This is always the first place to look — it contains the full Policy Server request/response XML
and the exact error code. Most errors have a `-XXXXXX` code that maps to a Policy Server error table.

---

## 4. Developer Integration Reference — All Four Patterns

### SDK initialization (required before any operation)

```java
// App-level config (call once at application startup)
String appConfigXml =
    "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
    "<fs-helper-config>" +
    "  <locale/>" +
    "  <app-path>.</app-path>" +
    "  <initalize-logger>true</initalize-logger>" +   // note: "initalize" (single i) — SDK spelling
    "</fs-helper-config>";

FSHelperLibrary.initialize(appConfigXml);

// Tenant config (call once per Policy Server connection)
String psUrl      = "https://your-policy-server.example.com";
int    psPort     = 443;
String appName    = "YourAppName";
String eaId  = "your-ea-id";
String passphrase = "your-ea-passphrase";

String tenantConfigXml =
    "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
    "<fs-helper-ps-config>" +
    "  <ps-details>" +
    "    <urls>" +
    "      <url>" +
    "        <server>" + psUrl + "</server>" +
    "        <port>" + psPort + "</port>" +
    "        <app-name>" + appName + "</app-name>" +
    "      </url>" +
    "    </urls>" +
    "  </ps-details>" +
    "  <login-details>" +
    "    <user-type>1</user-type>" +
    "    <hotfolder-cabinet>" +
    "      <id>" + eaId + "</id>" +
    "      <passphrase>" + passphrase + "</passphrase>" +
    "      <allow-advanced-privileges>false</allow-advanced-privileges>" +
    "    </hotfolder-cabinet>" +
    "  </login-details>" +
    "  <include-inline-attachment-in-mail-body>false</include-inline-attachment-in-mail-body>" +
    "  <session-pool>" +
    "    <max-size>50</max-size>" +
    "    <default-session-timeout>900</default-session-timeout>" +
    "  </session-pool>" +
    "</fs-helper-ps-config>";

// Second parameter is always "" (reserved); tenantId can be any unique string
FSHelperLibrary.initializeHelper("myTenantId", "", tenantConfigXml);

// Get helper for file operations (call per request)
FSHelper tenantObj = FSHelperLibrary.getHelper("myTenantId");

// At application shutdown:
FSHelperLibrary.terminate();
```

---

### Pattern 1: Hot Folder Protection (PROTECT_WITH_HF)

**When to use:** Policy is pre-configured in Policy Server.

```java
public void protectWithHotFolder(String inputFile, String outputFile, String hotFolderId)
        throws Exception {

    FSHelper tenantObj = FSHelperLibrary.getHelper("myTenantId");

    // Check if already protected
    if (tenantObj.isProtectedFile(inputFile)) {
        System.out.println("File is already protected");
        return;
    }

    // Check if the file format is supported
    if (!tenantObj.isSupportedFile(inputFile)) {
        System.out.println("File format not supported");
        return;
    }

    // Build hot folder XML
    String hotFolderXml = "<hot-folder><id>" + hotFolderId + "</id></hot-folder>";

    // Protect and wrap the file
    // psConnection=null → SDK uses pooled session; protectorDetails="" → always empty (reserved)
    ProtectedFile result = tenantObj.protectAndWrap(
        null,                          // PSConnection — null = pooled session
        inputFile,                     // source file path
        inputFile,                     // displayFileName — shown in Policy Server audit trail
        ProtectionType.PROTECT_WITH_HF,// protection type enum
        hotFolderXml,                  // protection details XML
        "",                            // protectorDetails — reserved, always ""
        ""                             // activityComments — optional audit note
    );

    System.out.println("Protected. File ID: " + result.getFileId());
    System.out.println("Output: " + result.getFilePath());
}
```

**Policy Server requirement:** Enterprise Applicaiton must be created with a Hot Folder configured in the EA.

---

### Pattern 2: Independent Rights Protection (PROTECT)

**When to use:** Rights must be set programmatically at runtime.

```java
public void protectWithIndependentRights(
        String inputFile, String outputFile,
        String ownerEmail, String ownerRepCode, String ownerExtId,
        List<String[]> recipients  // each entry: [repCode, extId, accessRightDecimal]
) throws Exception {

    FSHelper tenantObj = FSHelperLibrary.getHelper("myTenantId");

    if (tenantObj.isProtectedFile(inputFile)) { return; }
    if (!tenantObj.isSupportedFile(inputFile)) { return; }

    // Build protection-details XML with owner and recipients
    StringBuilder xml = new StringBuilder();
    xml.append("<protection-details>");
    xml.append("  <classification><id>1</id></classification>");  // classification ID from Policy Server

    xml.append("  <file-access-right-mappings>");

    // Owner gets full control
    xml.append("  <file-access-right-mapping>");
    xml.append("    <action>1</action>");
    xml.append("    <access-right>");
    xml.append("      <entity><rep-code>" + ownerRepCode + "</rep-code><id>" + ownerExtId + "</id><type>1</type></entity>");
    xml.append("      <primary-access-right>170</primary-access-right>"); // Full Control = 170
    xml.append("      <offline>1</offline>");
    xml.append("      <redistribute>1</redistribute>");
    xml.append("    </access-right>");
    xml.append("  </file-access-right-mapping>");

    // Recipients
    for (String[] recipient : recipients) {
        xml.append("  <file-access-right-mapping>");
        xml.append("    <action>1</action>");
        xml.append("    <access-right>");
        xml.append("      <entity><rep-code>" + recipient[0] + "</rep-code><id>" + recipient[1] + "</id><type>1</type></entity>");
        xml.append("      <primary-access-right>" + recipient[2] + "</primary-access-right>"); // e.g., 2 = Read
        xml.append("      <offline>0</offline>");
        xml.append("      <redistribute>0</redistribute>");
        xml.append("    </access-right>");
        xml.append("  </file-access-right-mapping>");
    }

    xml.append("  </file-access-right-mappings>");

    xml.append("  <owner><entity>");
    xml.append("    <rep-code>" + ownerRepCode + "</rep-code>");
    xml.append("    <id>" + ownerExtId + "</id>");
    xml.append("  </entity></owner>");
    xml.append("</protection-details>");

    ProtectedFile result = tenantObj.protectAndWrap(
        null,                    // PSConnection — null = pooled session
        inputFile,               // source file path
        inputFile,               // displayFileName — shown in Policy Server audit trail
        ProtectionType.PROTECT,  // protection type enum
        xml.toString(),          // protection details XML
        "",                      // protectorDetails — reserved, always ""
        ""                       // activityComments — optional audit note
    );
    System.out.println("Protected. File ID: " + result.getFileId());
}
```

**Getting entity IDs from email addresses** (required before building the XML above):
```java
// Look up user by email — Policy Server request type 74
// Returns String[] { id, repCode, type } on success, or -220372 (int) if not found
String lookupXml =
    "<search-user>" +
    "  <email>" + email + "</email>" +
    "</search-user>";

Object searchResult = tenantObj.sendRequest(null, 74, lookupXml);
if (searchResult instanceof String[]) {
    String[] entity = (String[]) searchResult; // [id, repCode, type]
} else {
    // -220372 = not found; create the user with request type 109
    String createXml =
        "<create-user>" +
        "  <email>" + email + "</email>" +
        "  <first-name>" + email.split("@")[0] + "</first-name>" +
        "  <last-name>User</last-name>" +
        "</create-user>";
    String[] entity = (String[]) tenantObj.sendRequest(null, 109, createXml);
}
```

**Policy Server requirement:** EA must be created in Policy Server and used for initialization of the SDK.

---

### Pattern 3: External Reference / Policy Federation (PROTECT_WITH_HF_EXT_REF)

**When to use:** Your application manages its own access control. You want Seclore to
inherit it without replicating permissions in Policy Server.

```java
public void protectWithExternalReference(
        String inputFile, String outputFile,
        String hfExtRefId,    // Hot Folder's external reference ID (set in Policy Server)
        String hfExtRefName,  // optional HF display name
        String hfExtRefData,  // optional metadata
        String fileExtRefId,  // YOUR app's unique file ID — the key linking field
        String fileExtRefName,// optional file name/metadata
        String fileExtRefData,// optional additional metadata
        String activityComments
) throws Exception {

    FSHelper tenantObj = FSHelperLibrary.getHelper("myTenantId");

    if (tenantObj.isProtectedFile(inputFile)) { return; }
    if (!tenantObj.isSupportedFile(inputFile)) { return; }

    // Build Hot Folder external reference XML
    StringBuilder hfXml = new StringBuilder();
    hfXml.append("<hot-folder-extn-reference>\n");
    hfXml.append("  <extn-reference>\n");
    hfXml.append("    <extn-ref-id>").append(hfExtRefId).append("</extn-ref-id>\n");
    if (hfExtRefName != null && !hfExtRefName.isEmpty())
        hfXml.append("    <extn-ref-name>").append(hfExtRefName).append("</extn-ref-name>\n");
    if (hfExtRefData != null && !hfExtRefData.isEmpty())
        hfXml.append("    <extn-ref-data>").append(hfExtRefData).append("</extn-ref-data>\n");
    hfXml.append("  </extn-reference>\n");
    hfXml.append("</hot-folder-extn-reference>");

    // Build File external reference XML
    // This is what Policy Server sends back to your app in the Policy Federation callback
    StringBuilder fileRefXml = new StringBuilder();
    fileRefXml.append("<file-extn-reference>\n");
    fileRefXml.append("  <extn-reference>\n");
    fileRefXml.append("    <extn-ref-id>").append(fileExtRefId).append("</extn-ref-id>\n");
    if (fileExtRefName != null && !fileExtRefName.isEmpty())
        fileRefXml.append("    <extn-ref-name>").append(fileExtRefName).append("</extn-ref-name>\n");
    if (fileExtRefData != null && !fileExtRefData.isEmpty())
        fileRefXml.append("    <extn-ref-data>").append(fileExtRefData).append("</extn-ref-data>\n");
    fileRefXml.append("  </extn-reference>\n");
    fileRefXml.append("</file-extn-reference>");

    // Combined XML = HF reference + File reference
    String protectionXml = hfXml.toString() + "\n" + fileRefXml.toString();

    ProtectedFile result = tenantObj.protectAndWrap(
        null,                                   // PSConnection — null = pooled session
        inputFile,                              // source file path
        inputFile,                              // displayFileName — shown in Policy Server audit trail
        ProtectionType.PROTECT_WITH_HF_EXT_REF,// protection type enum
        protectionXml,                          // HF + file external reference XML
        "",                                     // protectorDetails — reserved, always ""
        activityComments                        // optional audit note
    );

    System.out.println("Protected with Policy Federation.");
    System.out.println("File ID: " + result.getFileId());
    System.out.println("Your app's file ref: " + fileExtRefId +
                       " is now embedded in the protected file.");
}
```

**Critical:** The `fileExtRefId` is stored inside the protected file. When any user opens
the file, Policy Server reads this ID and calls your application's Policy Federation API with it.
Your app responds with the user's access rights.

**Policy Server requirements:**
- Hot Folder must have an External Reference ID configured that matches `hfExtRefId`
- EA must have the Policy Federation adapter (AR Adaptor) configured pointing to your API (this is required to test end to end flow including file opening)
- EA protection type must be `PROTECT_WITH_HF_EXT_REF` (configured automatically by the
  Hot Folder's external reference setting)

---

### Pattern 4: Unprotect Any File (Elevated EA)

**When to use:** DLP scanning, content inspection, AI ingestion — need to unprotect files
protected by any EA or user.

#### Step 1: Generate RSA key pair and register with Policy Server

```java
// Generate key pair (do once, save to config)
DefaultCryptoHandler.generateKeyPair(
    "config/keypair.properties",  // save location
    2048                          // key size
);
// After generating, read the public key and register it in Policy Server:
// Policy Server → EA → Advanced Security → paste the Base64 public key → Apply
// Note the Active Key ID Policy Server generates
```

#### Step 2: Initialize with CryptoHandler

```java
// Load the private key from saved file
Properties keyProps = new Properties();
keyProps.load(new FileInputStream("config/keypair.properties"));
String privateKeyXml = keyProps.getProperty("privateKeyXml");
String activeKeyId   = "12345";  // the Active Key ID from Policy Server

DefaultCryptoHandler cryptoHandler = new DefaultCryptoHandler(
    privateKeyXml,   // hex-XML encoded RSA private key
    256,             // key length parameter
    activeKeyId,     // Active Key ID as shown in Policy Server
    "ECB",           // chaining mode
    "PKCS1Padding"   // padding scheme
);

// Tenant config MUST include allow-advanced-privileges=true
String tenantConfigXml =
    "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
    "<fs-helper-ps-config>" +
    "  <ps-details>" +
    "    <urls>" +
    "      <url>" +
    "        <server>https://your-policy-server.example.com</server>" +
    "        <port>443</port>" +
    "        <app-name>YourAppName</app-name>" +
    "      </url>" +
    "    </urls>" +
    "  </ps-details>" +
    "  <login-details>" +
    "    <user-type>1</user-type>" +
    "    <hotfolder-cabinet>" +
    "      <id>your-ea-id</id>" +
    "      <passphrase>your-ea-passphrase</passphrase>" +
    "      <allow-advanced-privileges>true</allow-advanced-privileges>" +   // REQUIRED
    "    </hotfolder-cabinet>" +
    "  </login-details>" +
    "  <include-inline-attachment-in-mail-body>false</include-inline-attachment-in-mail-body>" +
    "  <session-pool>" +
    "    <max-size>10</max-size>" +
    "    <default-session-timeout>900</default-session-timeout>" +
    "  </session-pool>" +
    "</fs-helper-ps-config>";

// Second parameter is always "" (reserved)
FSHelperLibrary.initializeHelper("myTenantId", "", tenantConfigXml, cryptoHandler);
```

#### Step 3: Unprotect the file

```java
public void unprotectAnyFile(String inputFile, String outputFile, String comments)
        throws Exception {

    FSHelper tenantObj = FSHelperLibrary.getHelper("myTenantId");

    // Check if it's a Seclore-protected file
    if (!tenantObj.isHTMLWrapped(inputFile)) {
        System.out.println("File is not a Seclore-protected file.");
        return;
    }

    UnprotectedFile result = tenantObj.unwrapAndUnprotect(
        null,      // PSConnection — null = pooled session
        inputFile, // protected .html file path
        inputFile, // displayFilePath — shown in Policy Server audit trail
        comments   // activity comments for audit log
    );

    System.out.println("Unprotected. Output: " + result.getFilePath());
}
```

**Important:** The `DefaultCryptoHandler` is constructed at startup and passed to
`initializeHelper()`. The first call to `unwrapAndUnprotect()` is when the Policy Server actually
validates the advanced privilege — the initialization call does NOT fail if the privilege
is not configured; only the first unprotect call will fail.

---

### Full initialization for advanced EA (production template)

```java
public class SecloreService {

    private static final String TENANT_ID = "myTenant";

    public static void init(String psUrl, int port, String appName,
                            int eaId, String passphrase,
                            boolean enableAdvanced, String privateKeyXml,
                            String activeKeyId) throws Exception {

        String appConfigXml =
            "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
            "<fs-helper-config>" +
            "  <locale/>" +
            "  <app-path>.</app-path>" +
            "  <initalize-logger>true</initalize-logger>" +
            "</fs-helper-config>";

        FSHelperLibrary.initialize(appConfigXml);

        String advancedPriv = enableAdvanced ? "true" : "false";

        String tenantConfigXml =
            "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
            "<fs-helper-ps-config>" +
            "  <ps-details>" +
            "    <urls>" +
            "      <url>" +
            "        <server>" + psUrl + "</server>" +
            "        <port>" + port + "</port>" +
            "        <app-name>" + appName + "</app-name>" +
            "      </url>" +
            "    </urls>" +
            "  </ps-details>" +
            "  <login-details>" +
            "    <user-type>1</user-type>" +
            "    <hotfolder-cabinet>" +
            "      <id>" + eaId + "</id>" +
            "      <passphrase>" + passphrase + "</passphrase>" +
            "      <allow-advanced-privileges>" + advancedPriv + "</allow-advanced-privileges>" +
            "    </hotfolder-cabinet>" +
            "  </login-details>" +
            "  <include-inline-attachment-in-mail-body>false</include-inline-attachment-in-mail-body>" +
            "  <session-pool>" +
            "    <max-size>50</max-size>" +
            "    <default-session-timeout>900</default-session-timeout>" +
            "  </session-pool>" +
            "</fs-helper-ps-config>";

        DefaultCryptoHandler cryptoHandler = null;
        if (enableAdvanced && privateKeyXml != null) {
            cryptoHandler = new DefaultCryptoHandler(
                privateKeyXml, 256, activeKeyId, "ECB", "PKCS1Padding"
            );
        }

        // Second parameter is always "" (reserved)
        FSHelperLibrary.initializeHelper(TENANT_ID, "", tenantConfigXml, cryptoHandler);
    }

    public static FSHelper getHelper() {
        return FSHelperLibrary.getHelper(TENANT_ID);
    }

    public static void shutdown() {
        FSHelperLibrary.terminate();
    }
}
```

---

## 5. Policy Federation Deep Dive

### What is Policy Federation?

Policy Federation is Seclore's mechanism for delegating access control decisions to the
integrating application. When a user tries to open a Policy Federated file, Policy Server
does not make the access decision itself — instead, it calls the integrating application's
API and asks: *"Should this user be allowed to open this file, and what rights should
they have?"*

### The three-party flow

```
User opens     →  Seclore Client     →  Policy Server     →  Your App API
protected file     reads file ID          reads fileExtRefId    checks own DB
                   contacts Policy Server           calls AR Adaptor URL   returns rights JSON/XML
                   applies rights     ←  Policy Server enforces rights  ←  (online callback)
```

1. **At protection time (your code):** You call `protectAndWrap()` with the
   `<hot-folder-extn-reference>` + `<file-extn-reference>` XML. The `extn-ref-id` inside
   `file-extn-reference` is YOUR application's unique file identifier (e.g., a database
   record ID, a document ID, a content ID). This gets stored inside the protected file.

2. **At file-open time (automatic):** The Seclore client contacts Policy Server. Policy Server reads the
   `file-extn-reference` embedded in the file and calls the URL configured in the EA's
   Policy Federation settings, passing the `extn-ref-id` and the requesting user's identity.

3. **Your API responds:** Your application queries its own access control and returns the
   access rights for this user on this file. Policy Server enforces exactly what your app says.

### Why use Policy Federation?

- **No permission sync required:** You don't need to mirror your app's ACLs into Policy Server.
  Rights are evaluated in real time by your app.
- **Dynamic rights:** Revoking access in your app immediately revokes access to the file —
  even files that were distributed weeks ago.
- **Single source of truth:** Your application's database is the only place permissions
  live.
- **Compliance:** For ECM/DLP scenarios, the integrating app's audit log + Seclore's
  audit log together provide complete traceability.

### Hot Folder External Reference vs File External Reference

| Field | Purpose | Who sets it |
|-------|---------|------------|
| `hot-folder-extn-reference.extn-ref-id` | Identifies WHICH Hot Folder (protection policy) to use. One HF per integration, typically. | Policy Server admin configures HF with this ID; your code passes it at protect time |
| `file-extn-reference.extn-ref-id` | Identifies THIS SPECIFIC FILE in your application. Used in the Policy Server callback to your app. | Your code generates it at protect time; your DB stores it |

**Practical guidance:**
- Create one Hot Folder per integration (or one per business unit / document type)
- Set a stable External Reference ID on that HF (e.g., `FINANCE-HF-001`)
- At protect time, hard-code `hfExtRefId = "FINANCE-HF-001"` and vary only `fileExtRefId`
- The `fileExtRefId` should be whatever unique key your app uses for the document

### Policy Server configuration for Policy Federation

In Policy Server (System Admin view):
1. Create or select a Hot Folder under your EA
2. In Hot Folder settings, set **External Reference ID** (e.g., `DEMO-HF-001`)
3. Go to EA → **Policy Federation**
4. Set Adaptor Type = **Full Policy Federation**
5. Set the adapter URL = your app's callback endpoint
6. Apply and verify

The demo portal does not configure the Policy Server-side adapter (that is a Policy Server admin step), but it
correctly builds and passes the XML structures at protection time.

### Implementing the ARA callback service

The integrating application must expose three HTTP POST endpoints that Policy Server calls:

| Endpoint | When PS calls it |
|----------|-----------------|
| `POST {base-url}/ping` | Periodic health check |
| `POST {base-url}/getaccessright` | Every time a user opens a protected file |
| `POST {base-url}/getfileinformation` | When PS needs file metadata from your app |

The complete request/response XML for each endpoint, access right values, offline access
configuration, watermark support, response scenarios, and real-world troubleshooting cases
are documented in **`references/policy-federation-api.md`**. Load that file for any question
about implementing the ARA service.

Key rules to communicate upfront to any developer building the ARA:
- `<protocol-version>` must always be `1` in every response
- `<status>` must be `1` (success) or a negative code — never `0`
- Deny access by returning `<status>1</status>` with `<primary-access-right>0</primary-access-right>`
- Always echo back `<request-id>` in the response header
- The `type` attribute on the response element must match the request

---

## 6. HTML Wrapping — Concept and API

### What is HTML Wrapping?

HTML Wrapping is a Seclore feature that encapsulates an already-protected (natively encrypted) Seclore file inside an HTML container. The result is a `.html` file — for example, `report.docx` becomes `report.docx.html` after wrapping.

HTML wrapping is a **presentation layer** added on top of native protection. The underlying encryption and policy remain unchanged — only the delivery format changes.

### Why use HTML Wrapping?

| Scenario | Without HTML Wrap | With HTML Wrap |
|----------|-------------------|----------------|
| Seclore agent installed | Native file opens in application | `.html` file → double-click → opens in native app |
| No Seclore agent | File cannot be opened | `.html` file opens in browser → Seclore Viewer in browser |

HTML-wrapped files enable platform-agnostic distribution — recipients can open protected files even if they haven't installed the Seclore desktop agent.

### Key Concepts

- **Wrap** — Adds an HTML envelope to a natively-protected file. File remains Seclore-encrypted inside the HTML container.
- **Unwrap** — Strips the HTML envelope, reverting to the natively-protected Seclore file. **Unwrapping does NOT remove Seclore protection** — the file is still encrypted and policy-controlled.
- **protectAndWrap** — Protect + wrap in one step (used in Hot Folder, Independent Rights, External Reference tabs).
- **protectX + wrap separately** — Protection and wrapping as two independent steps (Wrap / Unwrap tab demonstrates this).

### Prerequisite

For HTML wrapping to work, your Policy Server administrator must enable **Universal Protection > HTML Wrapping** in the Policy Server system settings.

### SDK Methods

```java
// Wrap a natively-protected file
tenantObj.wrap(null, inputFilePath, outputFilePath);
// Output: inputFilePath + ".html" — e.g., report.docx → report.docx.html
// Note: getFileId() returns null for wrap() — no new PS file ID is assigned

// Unwrap an HTML-wrapped file
tenantObj.unwrap(inputFilePath);
// Output: file with .html extension removed — still Seclore-protected
// Note: getFileId() returns null for unwrap()
```

### Common Mistakes

| Mistake | Result |
|---------|--------|
| Calling `unwrapAndUnprotect()` on a natively-protected file (no HTML wrapper) | `WSClientException: Invalid file format 'X' for HTML unwrapping` |
| Calling `unwrap()` thinking it removes protection | File is still protected — unwrap only removes the HTML envelope |
| Calling `wrap()` on an already HTML-wrapped file | SDK wraps again — creates a double-wrapped file |

---

## 7. Advanced EA Setup Walkthrough

### Purpose

An EA with Advanced Security can use `DefaultCryptoHandler` to authenticate with a
cryptographic challenge-response, enabling the `allow-advanced-privileges` mode. This
unlocks "Unprotect Any File" — the ability to unprotect files protected by any EA or user
on the same Policy Server.

### Step-by-step

#### Part A: Generate the RSA key pair (in the demo portal)

1. In the Configuration tab, check **Enable Advanced EA**
2. Click **Generate RSA Key Pair**
   - The demo calls `DefaultCryptoHandler.generateKeyPair()` internally
   - A 2048-bit RSA key pair is generated and saved to `config/keypair.properties`
3. The **Public Key (Base64)** field populates with the X.509-encoded public key

#### Part B: Register the public key in Policy Server

1. Open Policy Server Admin console
2. Navigate to **Enterprise Applications** → select your EA → **Edit**
3. Go to **Advanced Security** tab
4. Paste the Base64 public key into the **RSA Public Key** field
5. Enable the **"Unprotect any file"** privilege
6. Click **Apply / Save**
7. Policy Server generates a cryptographic key record — note the **Active Key ID** displayed

#### Part C: Complete demo configuration

1. Copy the **Active Key ID** from Policy Server
2. Paste it into the **Active Key ID** field in the Configuration tab
3. Click **Initialize SDK**
4. If initialization succeeds (green SDK Ready badge), advanced privilege is configured

#### What happens under the hood

When `initializeHelper()` is called with a `DefaultCryptoHandler`:
- The SDK sends an EA authentication request (WS type 46) with `<allow-advanced-privileges>1</allow-advanced-privileges>`
- Policy Server issues a cryptographic challenge encrypted with the registered public key
- The `DefaultCryptoHandler` decrypts the challenge using the private key
- Policy Server verifies the response — if correct, the session has advanced privileges

The `initializeHelper()` call itself succeeds even if the advanced privilege is NOT
configured in Policy Server — it only verifies EA credentials. The first `unwrapAndUnprotect()` call
is where Policy Server checks the privilege and will return error `-220133` if not set up correctly.

---

### DefaultCryptoHandler constructor parameters

```java
new DefaultCryptoHandler(
    privateKeyXml,   // String: hex-XML encoded RSA private key
                     //   from DefaultCryptoHandler.generateKeyPair()
                     //   or from config/keypair.properties
    256,             // int: key length parameter (always 256 for the SDK)
    activeKeyId,     // String: Active Key ID from Policy Server (the numeric ID after registering)
    "ECB",           // String: chaining mode (always "ECB" for Seclore)
    "PKCS1Padding"   // String: padding (always "PKCS1Padding" for Seclore)
)
```

### Tenant config XML for Advanced EA

```xml
<fs-helper>
  <ps-details>
    <urls><url>https://Policy Server.company.com:443/seclore</url></urls>
  </ps-details>
  <hotfolder-cabinet>
    <id>5</id>
    <passphrase>YourPassphrase</passphrase>
  </hotfolder-cabinet>
  <allow-advanced-privileges>true</allow-advanced-privileges>  <!-- MUST be true -->
  <session-pool><max-size>10</max-size></session-pool>
</fs-helper>
```

---

## 8. Access Rights Reference

These are the access right values to use in Independent Rights XML (`<primary-access-right>`).

### Primary access rights (for individual entities)

| Hex value | Decimal | Right |
|-----------|---------|-------|
| 0x00000002 | **2** | Read |
| 0x00000006 | **6** | Lite Viewer (view-only, no download) |
| 0x0000000A | **10** | Print |
| 0x00000022 | **34** | Edit |
| 0x000000AA | **170** | Full Control |
| 0x00000102 | **258** | Copy Data |
| 0x00000202 | **514** | Screen Capture |
| 0x00000402 | **1026** | Macro |

**Combining rights:** Use bitwise OR on the decimal values:
- Read + Print = 2 OR 10 = **10** (10 is a superset; 0x0A contains Read bit)
- Edit + Print = 34 OR 10 = **42** (0x22 OR 0x0A = 0x2A)
- Full Control = **170** (0xAA — includes Read, Print, Edit, and more)
- Full Control + Copy Data = 170 OR 258 = **426** (for users who need clipboard too)

### Group access rights (for predefined credential groups)

| Hex value | Decimal | Right |
|-----------|---------|-------|
| 0x00000002 | **2** | Read |
| 0x00000004 | **4** | Change |
| 0x00000008 | **8** | Print |
| 0x00007FFF | **32767** | Full Control |

### Access right XML structure

```xml
<file-access-right-mapping>
  <action>1</action>                    <!-- 1=map, 2=unmap -->
  <access-right>
    <entity>
      <rep-code>REPO-CODE</rep-code>    <!-- repository code for the user -->
      <id>USER-EXT-ID</id>              <!-- user's external ID in that repo -->
      <type>1</type>                    <!-- 1=User, 2=Group -->
    </entity>
    <primary-access-right>34</primary-access-right>  <!-- decimal value -->
    <offline>0</offline>                <!-- 1=allow offline, 0=online only -->
    <redistribute>0</redistribute>     <!-- 1=can share, 0=cannot -->
    <lock-to-first-machine>0</lock-to-first-machine>
    <date-embargo>
      <start-time/>                     <!-- format: yyyy:MM:dd:HH:mm:ss -->
      <end-time/>
    </date-embargo>
    <no-of-days-since-protection>0</no-of-days-since-protection>
    <no-of-days-since-first-access>0</no-of-days-since-first-access>
  </access-right>
</file-access-right-mapping>
```

---

## 9. SDK API Quick Reference

### Core methods on FSHelper

| Method | Description | Returns |
|--------|-------------|---------|
| `isProtectedFile(path)` | Check if file is already Seclore-protected | `boolean` |
| `isSupportedFile(path)` | Check if file format can be protected | `boolean` |
| `isHTMLWrapped(path)` | Check if file is Seclore HTML-wrapped | `boolean` |
| `protectAndWrap(null, filePath, displayFileName, protectionType, protectionXML, "", activityComments)` | Protect a file and wrap it in an HTML envelope in one step | `ProtectedFile` (File ID + output path) |
| `protectX(null, filePath, displayFileName, protectionType, protectionXML, "", activityComments)` | Protect a file without HTML wrapping — natively protected output only | `String` (output path; no File ID) |
| `wrap(null, filePath, displayFileName)` | Add HTML envelope to an already natively-protected file | `ProtectedFile` (File ID always `null`; use `.getFilePath()` only) |
| `unwrap(filePath)` | Strip HTML envelope from a wrapped file, returning the natively-protected file | `ProtectedFile` (File ID always `null`; use `.getFilePath()` only) |
| `unwrapAndUnprotect(null, filePath, displayFilePath, activityComments)` | Unprotect an HTML-wrapped file (`protectAndWrap` output) — strips HTML wrapper then decrypts | `UnprotectedFile` (output path) |
| `unprotectX(null, protectedFilePath, displayName, activityComment)` | Unprotect a natively-protected file (`protectX` output) — no HTML wrapper to strip; output written alongside input | `void` |
| `sendRequest(null, type, xml)` | Send raw Policy Server web service request | raw XML response |

### Core methods on FSHelperLibrary

| Method | Description |
|--------|-------------|
| `initialize(appConfigXml)` | Initialize the library (once per app) — uses SDK's own Log4j2 logger |
| `initialize(logger, appConfigXml)` | Initialize with a custom `ISecloreSDKLogger` — routes all SDK log output through your implementation |
| `initializeHelper(id, tenantXml, appXml, cryptoHandler)` | Connect to a Policy Server tenant |
| `getHelper(tenantId)` | Get FSHelper for a tenant |
| `terminate()` | Shut down all sessions cleanly |

---

### Custom Logging — ISecloreSDKLogger

The SDK provides a callback interface for integrating SDK log output into your application's existing logging framework. Use this instead of the SDK's built-in Log4j2 logger when your application already manages its own logging (Spring Boot, enterprise app server, etc.).

**Interface** — package `com.seclore.fs.ws.client.logger.interfaces`:
```java
public interface ISecloreSDKLogger extends Serializable {
    void logDebug(String pRequestId, String pMessage);
    void logInfo(String pRequestId, String pMessage);
    void logException(String pRequestId, String pMessage, Throwable pThrowable);
}
```

`pRequestId` — unique ID for the current SDK operation; prefix all log lines with this for distributed tracing/correlation.

**Step 1 — Implement for your framework:**

```java
// Log4j2
public class SecloreLog4j2Logger implements ISecloreSDKLogger {
    private static final Logger log = LogManager.getLogger(SecloreLog4j2Logger.class);
    @Override public void logDebug(String id, String msg)                         { log.debug("[SDK][{}] {}", id, msg); }
    @Override public void logInfo(String id, String msg)                          { log.info("[SDK][{}] {}", id, msg); }
    @Override public void logException(String id, String msg, Throwable t)        { log.error("[SDK][{}] {}", id, msg, t); }
}

// SLF4J
public class SecloreSlf4jLogger implements ISecloreSDKLogger {
    private static final Logger log = LoggerFactory.getLogger(SecloreSlf4jLogger.class);
    @Override public void logDebug(String id, String msg)                         { log.debug("[SDK][{}] {}", id, msg); }
    @Override public void logInfo(String id, String msg)                          { log.info("[SDK][{}] {}", id, msg); }
    @Override public void logException(String id, String msg, Throwable t)        { log.error("[SDK][{}] {}", id, msg, t); }
}

// Java Util Logging (JUL)
public class SecloreJULLogger implements ISecloreSDKLogger {
    private static final java.util.logging.Logger log = java.util.logging.Logger.getLogger(SecloreJULLogger.class.getName());
    @Override public void logDebug(String id, String msg)                         { log.fine(String.format("[SDK][%s] %s", id, msg)); }
    @Override public void logInfo(String id, String msg)                          { log.info(String.format("[SDK][%s] %s", id, msg)); }
    @Override public void logException(String id, String msg, Throwable t)        { log.log(Level.SEVERE, String.format("[SDK][%s] %s", id, msg), t); }
}
```

**Step 2 — Set `<initalize-logger>false</initalize-logger>` in App Config XML:**

```xml
<fs-helper-config>
  <locale/>
  <app-path>.</app-path>
  <initalize-logger>false</initalize-logger>   <!-- prevents SDK's own Log4j2 from running in parallel -->
</fs-helper-config>
```

Without this, the SDK will still initialise its own Log4j2 appender alongside your custom logger, causing double-logging and potential conflicts.

**Step 3 — Pass to the 2-argument `initialize()` overload:**

```java
ISecloreSDKLogger myLogger = new SecloreLog4j2Logger(); // or Slf4j / JUL variant
FSHelperLibrary.initialize(myLogger, appConfigXML);     // 2-arg overload
```

**Comparison — three logging options:**

| Approach | SDK manages logger? | When to use |
|----------|-------------------|-------------|
| `initialize(appConfigXML)` — 1-arg | Yes — writes to `WSClient.log` via log4j2.xml | Standalone demo / app without existing logging framework |
| `initialize(logger, appConfigXML)` — 2-arg with `ISecloreSDKLogger` | No — SDK calls your methods | Spring Boot, enterprise app, or any app that already bootstraps logging |

### Key Policy Server web service request types (for sendRequest)

| Type | Description |
|------|-------------|
| 5 | Ping — validate Policy Server connection |
| 27 | Protect file (with protection-details or hot-folder) |
| 46 | Authenticate as Enterprise Application user |
| 57 | Unprotect file |
| 66 | Protect file using external reference (Policy Federation) |
| 74 | Look up user/entity by email or login ID |
| 100 | Configure Advanced Security for EA |
| 29 | Get full protection details of an already-protected file (see Section 12) |
| 31 | Get a specific user's access permission on a file — requires entity `rep-code`+`id` (see Section 12) |

### XML namespaces used by Policy Server

The Policy Server web service uses XML structures for both requests and responses. Key structures:
- `<hot-folder>` — references a Hot Folder by numeric ID
- `<hot-folder-extn-reference>` — references a HF by external reference ID
- `<file-extn-reference>` — embeds your app's file ID for Policy Federation
- `<protection-details>` — full rights definition for Independent Rights
- `<entity>` — a Policy Server user or group (identified by rep-code + id + type)

---

## 10. Integration Verticals — Common Patterns

### ECM (SharePoint, Documentum, Alfresco)

**Recommended pattern:** External Reference / Policy Federation  
- Use the document's repository ID as `fileExtRefId`
- Configure one Hot Folder per content type or classification
- At open time, your ECM adapter queries the repository's ACL and returns rights to Policy Server
- Users never see a difference — Seclore enforcement is transparent

### ERP (SAP, Oracle)

**Recommended pattern:** Hot Folder for batch outputs; External Reference for interactive
- SAP report outputs → protect immediately using the appropriate HF for the report type
- Interactive documents (contracts, POs) → use External Reference + Policy Federation
  with the ERP document number as `fileExtRefId`

### DLP / Security Operations

**Recommended pattern:** Unprotect Any File (Advanced EA)
- Protect all outbound files using Hot Folder in the DLP integration
- For content inspection or incident response, use Advanced EA to unprotect and scan
- `activityComments` field carries the DLP event ID for correlation in Policy Server audit log

### Data Migration / Archival

**Recommended pattern:** Unprotect Any File (Advanced EA)
- Migration tool uses the elevated EA to unprotect files from the source system
- Re-protects on the target system using the new Policy Server/tenant Hot Folder
- Preserves Seclore protection chain without requiring original protector credentials

### AI / ML Pipelines

**Recommended pattern:** External Reference or Hot Folder for input; Unprotect for
processing; re-protect for output
- Unprotect input documents using Advanced EA
- Process with AI model
- Re-protect output/results using Hot Folder or Independent Rights
- `activityComments` should record the pipeline run ID for audit

### PLM / CAD Systems

**Recommended pattern:** Hot Folder by document type
- Create one Hot Folder per document classification (drawings, specs, BOMs)
- Each HF has appropriate credentials (internal vs external recipients)
- Integration calls `protectAndWrap` with the appropriate HF ID based on document type

### CASB / Cloud Storage

**Recommended pattern:** Protect on upload, Unprotect on download (same EA)
- On file upload to cloud storage: `protectAndWrap` using HF or External Reference
- On file download for authorized users: `unwrapAndUnprotect` (standard, not elevated)
- For compliance scanning of cloud content: Elevated EA unprotect

---

## 11. Checking File Protection Status

There are two ways to check if a file is Seclore-protected: using the SDK (requires
initialization) and without the SDK (pure byte-level signature detection, no SDK dependency).

---

### Method 1 — With SDK

After SDK initialization, call the following methods on the `FSHelper` instance:

| Method | Returns | What it checks |
|--------|---------|----------------|
| `isProtectedFile(String filePath)` | `boolean` | `true` if file is natively Seclore-protected |
| `isHTMLWrapped(String filePath)` | `boolean` | `true` if file is an HTML-wrapped Seclore file |
| `isSupportedFile(String filePath)` | `boolean` | `true` if file format can be Seclore-protected |

```java
FSHelper tenantObj = FSHelperLibrary.getHelper("myTenantId");

boolean isProtected = tenantObj.isProtectedFile(filePath);
boolean isWrapped   = tenantObj.isHTMLWrapped(filePath);
boolean isSupported = tenantObj.isSupportedFile(filePath);
```

- `isProtectedFile` and `isHTMLWrapped` are mutually exclusive — a file is natively protected
  or HTML-wrapped, never both.
- Always call `isProtectedFile` before any protect operation, and `isHTMLWrapped` before
  `unwrapAndUnprotect`, to prevent errors on already-protected files.

---

### Method 2 — Without SDK (byte-level signature detection)

**Use case:** An application needs to identify Seclore-protected or wrapped files without
integrating the SDK — for example, a content management system, storage layer, or DLP tool
that wants to flag Seclore files without taking a Java SDK dependency.

**Two detectable states:**
- **Seclore Protected** — file is natively protected (non-HTML format)
- **Seclore Wrapped** — file is HTML-wrapped (`.html` extension with Seclore container)
- **Neither** — file is smaller than 64 KB, or signature not found

#### Signatures

| Type | Signature string |
|------|-----------------|
| Native protection | `FXIMLHDESAACAIDNUIIABMURME.DTDL.ETVPYGSOKTLOOPCNHCLIETEEROLCESNT` |
| HTML wrapper | `<!--FXIMLHDESAACAIDNUIIABMURME.DTDL.ETVPYGSOKTLOOPCNHCLIETEEROLCESNT-->` |

#### Detection algorithm

1. **If file size < 64 KB** → not Seclore (return immediately)
2. **If extension is `.html`** → read first 1 MB as UTF-8; check for the HTML wrapper signature
3. **For all other extensions** (native protection check):
   - Starting offset: `FILE_BYTE_START_OFFSET = 60` (KB)
   - At each iteration: read 64 bytes at `FILE_BYTE_START_OFFSET × 1024`; compare to the
     native signature as UTF-8
   - If match → file is natively protected
   - If no match: advance using the progression formula: `next = (2 × current) + 4`
   - Stop when offset ≥ 1024 KB (1 MB)

#### Buffer boundary table

| Original content size | Seclore buffer size | Signature offset |
|-----------------------|---------------------|------------------|
| ≤ 60 KB               | 64 KB               | 60 KB            |
| > 60 KB, ≤ 124 KB     | 128 KB              | 124 KB           |
| > 124 KB, ≤ 252 KB    | 256 KB              | 252 KB           |
| > 252 KB, ≤ 508 KB    | 512 KB              | 508 KB           |
| > 508 KB, ≤ 1020 KB   | 1024 KB (1 MB)      | 1020 KB          |

**Offset progression formula:** `next_offset_KB = (2 × current_offset_KB) + 4`

For a complete Java implementation see `references/code-samples.md` →
*Code Sample: Check File Protection Status*.

---

## 12. Querying File Protection Details and User Access Permission

Two `sendRequest()` types let you query an already-protected file instead of changing its
protection: Type 29 returns the file's overall protection details; Type 31 returns one
specific user's access rights on that file.

---

### Type 29 — Get File Protection Details (`sendRequest`, type 29)

Returns the full protection record for an already-protected file: classification, owner,
protector, hot-folder mapping, and either the credential mapping or the independent
access-right mappings, depending on how the file was protected.

**You need the file's Seclore File ID first.** Two ways to get it:

- **From a prior protect call's return value** — `protectAndWrap`/`protectX` returns the
  Seclore File ID at protection time; if your code already captured that, use it directly.
- **From the file path, when you only have the file on disk:**

```java
String fileId = tenantObj.getFileId(filePath);
```

**Request:**

```xml
<request>
  <request-header/>
  <request-details>
    <file-details>
      <file-id>SECLORE_FILE_ID</file-id>
      <file-name>FILE_NAME</file-name>
    </file-details>
    <verbose>1</verbose>
  </request-details>
</request>
```

```java
String responseXML = tenantObj.sendRequest(null, 29, requestXML);
```

**`<verbose>` controls how much comes back — pick deliberately, it doesn't error either way:**

- **`verbose=1`** — full detail: file-level `<protection-details>` is present, with the
  complete credential/access-right mappings and the full owner entity (name + email).
- **`verbose=0`** — summary only: file-level `<protection-details>` is **absent**. If the file
  is Hot-Folder-protected, `<hot-folder>` still carries its own `<protection-details>` with
  classification and the HF owner — that part doesn't depend on the verbose flag.

**Response structure (key elements):**

| Element | Contains |
|---|---|
| `<file-details><file-name>` | original filename at protection time |
| `<file-details><irm-aware>` | always `1` for a Seclore-protected file |
| Top-level `<owner>/<entity>`, `<protector>/<entity>` | **minimal** entity (id + rep-code + type only) — full name/email is in `<protection-details><owner>`, not here |
| `<protection-details><classification><name>` | classification label applied — verbose=1 only |
| `<protection-details><owner>` (use the **last** `<owner>` block) | full owner entity (name + email) — verbose=1 only; see parsing gotcha #1 below |
| `<protection-details><file-credential-mappings>` | populated for Hot Folder / Predefined Policy ID protection — lists each credential (id, name, status) and how it was granted |
| `<protection-details><file-access-right-mappings><file-access-right-mapping><access-right><primary-access-right>` | populated for Independent Rights protection — one mapping per user/group with distinct rights (see Section 8 for the bitmask legend) |
| `<hot-folder><name>` | hot-folder name — present only if the file was protected via Hot Folder |
| `<hot-folder><file-server><id>` | the Enterprise Application (EA) id that owns the Hot Folder |
| `<hot-folder><extn-reference><extn-ref-id>` | the Hot Folder's own external reference ID |
| Root-level `<extn-reference>` (after `</hot-folder>`) | the **file's** external reference ID — only present for files protected via `PROTECT_WITH_HF_EXT_REF`; see parsing gotcha #3 |

**Important — which mapping list populates (and what else comes with it) depends on how the
file was protected. At most one of the two mapping lists is non-empty:**

| Protection type | `<file-credential-mappings>` | `<file-access-right-mappings>` | `<hot-folder>` |
|---|---|---|---|
| Hot Folder | Populated (HF credential) | Empty | Present |
| Predefined Policy ID | Populated | Empty | May be present |
| Independent Rights | Empty/absent | Populated (per-user rights) | Absent |

If you need "does this specific user have access," and the file uses Hot Folder/Predefined
Policy protection, Type 29 won't show you that user directly — use Type 31 instead (below).

**Four parsing gotchas — these are easy to get wrong silently rather than via an error:**

1. **File-level owner is the *last* `<owner>` block, not the first.** In verbose=1, the first
   `<owner>` inside `<protection-details>` belongs to the `<credential>` and has no entity
   detail. The file-level owner — with full name/email — is the *last* `<owner>` block in that
   section. Grab it with something like `extractLastBlock(protectionDetailsBlock, "owner")`.
2. **`<hot-folder>` appears twice in verbose=1.** A minimal stub shows up nested inside
   `<granted-by>`; the real, full top-level `<hot-folder>` comes later in the response. Use
   `extractLastBlock(response, "hot-folder")` to get the right one.
3. **`<extn-reference>` appears twice and means different things each time.** Once inside
   `<hot-folder>` (the Hot Folder's own external reference) and once at the response root after
   `</hot-folder>` (the file's external reference, `PROTECT_WITH_HF_EXT_REF` only). Parse these
   as two separate fields — don't assume the first match is the one you want.
4. **`<hot-folder>` may be absent entirely.** It's only present for Hot-Folder-protected files
   (and sometimes for Predefined Policy ID). Check for its presence before parsing into it —
   don't assume it's always there.

---

### Type 31 — Get a User's Access Permission (`sendRequest`, type 31)

Returns one specific user's effective access rights on a file — the right answer to "can
user X access this file, and what can they do."

#### What the request needs — entity `id`, not email

The request identifies the user with an `<entity>` block requiring `<rep-code>` and `<id>`:

```xml
<request>
  <request-header/>
  <request-details>
    <file-details>
      <file-id>SECLORE_FILE_ID</file-id>
      <file-name>FILE_NAME</file-name>
    </file-details>
    <entity>
      <rep-code>REP_CODE</rep-code>
      <id>ENTITY_ID</id>
    </entity>
  </request-details>
</request>
```

- `rep-code` — the Repository (e.g. AD/LDAP directory) the user belongs to in Policy Server.
- `id` — the entity's actual unique identifier in that repository (a GUID/SID-style value),
  **not** the email address and not `<ext-id>`. Sending email here fails with
  `-240003 Missing parameter 'id'.`

**If you only have the user's email, resolve it first with Type 74** (the same lookup used
elsewhere in this skill for Independent Rights — see Section 2):

```xml
<request>
  <request-header/>
  <request-details>
    <email-id>user@example.com</email-id>
  </request-details>
</request>
```

```java
String responseXML = tenantObj.sendRequest(null, 74, lookupXml);
// parse <entities><entity><rep-code>...</rep-code><id>...</id></entity></entities>
```

Take the `rep-code` and `id` from the returned `<entity>` and use them in the Type 31 request.
If the lookup returns no `<entities>` (or `-220372`), the user doesn't exist in Policy Server.

> Querying another user's access permission this way is expected to require the EA/session to
> have the SUPER USER role on Policy Server. If Type 31 fails with a permission-style error,
> that's the likely cause — check the EA's role configuration in Policy Server.

#### Response structure

```xml
<response>
  ...
  <request-status><return-value>1</return-value>...</request-status>
  <access-permissions>
    <online><permission>
      <primary-access-right>N</primary-access-right>
      <offline>0|1</offline>
      <validity-start-time>...</validity-start-time>
      <validity-end-time>...</validity-end-time>
    </permission></online>
    <redistribute><permission>...</permission></redistribute>
    <offline><permissions><permission>...</permission></permissions></offline>
    <redistribute-online><permission>...</permission></redistribute-online>
    <redistribute-offline><permission>...</permission></redistribute-offline>
  </access-permissions>
  <protection-details>...</protection-details>
  <file-details>...</file-details>
</response>
```

**`<request-status><return-value>1</return-value>` only means the request itself succeeded —
it is not an indicator of whether the user has access.** Whether the user can actually open
the file is determined entirely by the contents of `<access-permissions>`.

#### Interpreting `<primary-access-right>` in plain English

Use the same decimal legend as Section 8 (Access Rights Reference):

| Decimal | Right |
|---|---|
| 2 | Read |
| 6 | Lite Viewer |
| 10 | Print |
| 34 | Edit |
| 170 | Full Control |
| 258 | Copy Data |
| 514 | Screen Capture |
| 1026 | Macro |

A value of **1** does not correspond to any named right in that table — in practice it shows
up as the baseline value for a permission block the user has *not* been granted (see the
worked comparison below). Treat `1` as "no right granted for this access mode," and any value
≥ 2 as a real (or combined, via bitwise OR) right from the table.

#### Worked example: has permission vs. no permission

Two real responses for the same file (`Test.pdf.html`, file-id `1000362117`), same protector,
same classification — only `<access-permissions>` differs:

**User with no access** — every permission block (`online`, `redistribute`, `offline`,
`redistribute-online`, `redistribute-offline`) reads:
```xml
<primary-access-right>1</primary-access-right>
...
<validity-end-time>-1</validity-end-time>
```
Uniform `1` / `-1` across all five blocks → no granted access of any kind.

**User with access** — the `online` and `offline` blocks read:
```xml
<primary-access-right>2</primary-access-right>
...
<validity-end-time>9000000</validity-end-time>
```
`2` = Read, and the validity end time is a real (non-sentinel) value — this user can open the
file online and offline with Read rights. The `redistribute`, `redistribute-online`, and
`redistribute-offline` blocks in this same response stayed at the baseline `1`/`-1` — this
user was not granted redistribute rights.

**Reading rule:** for each of the five permission blocks, `primary-access-right >= 2` (matched
against the Section 8 table) means the user has that right for that access mode; `1` means
they don't.

---

