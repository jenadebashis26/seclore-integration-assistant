# Seclore SDK — Code Samples & XML Reference

This file contains all shareable Java code samples, XML structures, and the starter
package specification for the Seclore Server SDK.

Load this file when a team member asks to "generate sample code", "give me code for",
"export shareable code", or "create a starter kit / package" for a specific protection type.

**Produce ONLY the code and files for the one type requested. Do not dump all samples.**

---

## Starter Package Generation Spec

When generating a shareable starter package for a customer, produce ALL of the following
files. Never omit any of them.

### Required folder structure

```
seclore-sdk-starter/
├── src/
│   └── Seclore[Type]Sample.java     ← Java source
├── lib/
│   └── PLACE_SDK_JAR_HERE.txt       ← Placeholder; customer drops JAR here
├── input/
│   └── PUT_YOUR_FILE_HERE.txt       ← Placeholder; customer drops input file here
├── config/
│   └── log4j2.xml                   ← MUST be included (see content below)
├── run.bat                          ← Windows compile + run script
├── run.sh                           ← Linux/Mac compile + run script
└── README.md                        ← Short developer reference (see spec below)
```

The `logs/` and `build/` directories are created automatically by the run scripts — do not
include them in the package.

---

### Java source file rules

Every protection sample MUST include:
1. **isProtectedFile check** before any `protectAndWrap` / `protectX` call
2. **isSupportedFile check** before any `protectAndWrap` / `protectX` call
3. **isHTMLWrapped check** before any `unwrapAndUnprotect` call
4. **isProtectedFile check** before any `unprotectX` call
5. `FSHelperLibrary.terminate()` called before every `return` and at the end of `main`
6. Console output at each step (Step 1…Step N) so the customer can see progress
7. All constants (PS URL, EA credentials, file paths, IDs) declared at the top as
   `private static final String` so customers only need to edit one block
8. Comment on file paths: relative paths work when run via the provided scripts;
   production integrations should use absolute paths
9. **Windows path escaping warning** — include this comment block above any file path constant:
   ```
   // Windows paths in Java strings require double backslashes OR forward slashes:
   //   WRONG : "D:\demo\file.docx"    ← \d, \f are illegal escape sequences
   //   CORRECT: "D:\\demo\\file.docx"  ← double backslash
   //   CORRECT: "D:/demo/file.docx"    ← forward slash also works on Windows
   ```

---

### config/log4j2.xml — exact content

This file MUST be included in every generated package. The Seclore SDK logger will
fail to initialize without it, causing the JVM to exit immediately with no error output.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="info">
  <Properties>
    <Property name="basePath">${ctx:applicationPath}/logs</Property>
  </Properties>
  <Loggers>
    <AsyncLogger name="WSCLIENT" level="info" additivity="false">
      <appender-ref ref="WSCLIENT_APPENDER"/>
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
        <TimeBasedTriggeringPolicy interval="1" modulate="true"/>
        <SizeBasedTriggeringPolicy size="10MB"/>
      </Policies>
      <DefaultRolloverStrategy fileIndex="nomax"/>
    </RollingRandomAccessFile>
  </Appenders>
</Configuration>
```

**Critical constraints (from actual demo source):**
- `<Configuration status="info">` — not `WARN`
- `basePath` property = `${ctx:applicationPath}/logs` — SDK sets `applicationPath` at runtime from `<app-path>` in App Config XML
- `fileName` and `filePattern` use `${basePath}` — not `${ctx:applicationPath}` directly
- Logger name MUST be `WSCLIENT` (uppercase)
- Appender name MUST be `WSCLIENT_APPENDER` and type MUST be `RollingRandomAccessFile` — not `RollingFile`
- `<Loggers>` block comes BEFORE `<Appenders>` block
- No `<Root>` logger — omit it entirely

---

### run.bat — required behaviours

1. `cd /d "%~dp0"` — first line, changes to the script's own directory
2. Create `logs\`, `build\`, `config\` directories if missing
3. Create `config\log4j2.xml` if missing (use PowerShell to write the XML)
4. Check for Java on PATH; error and pause if missing
5. Check for `lib\*.jar`; error and pause if missing
6. Compile to `build\` directory: `javac -cp "lib\*" -d build src\[ClassName].java`
7. Run from `build\`: `java -cp "build;lib\*" [ClassName]`
8. `pause` at the end so the window stays open

### run.sh — required behaviours

Same checks as run.bat, adapted for bash:
1. `cd "$(dirname "$0")"` — first line
2. `mkdir -p logs build config`
3. Write `config/log4j2.xml` via heredoc if missing
4. Compile to `build/`: `javac -cp "lib/*" -d build src/[ClassName].java`
5. Run: `java -cp "build:lib/*" [ClassName]`

---

### README.md spec — keep it short

The README must be a short developer reference, not a marketing or tutorial document.
Target: 50–70 lines. Structure:

```
# Seclore SDK Starter — [Protection Type]

**Policy Server:** [url] | **Port:** [port] | **App:** [app-name]

---

## Setup

**1. Add the SDK JAR**
Copy FSHelper-*.jar into the lib/ folder.

**2. Fill in credentials**
Open src/[ClassName].java and set:
[table of constants and what to enter — only the ones that apply]

**3. Add a file**
Place the file to protect in input/.

**4. Run**
Windows: run.bat
Linux/Mac: chmod +x run.sh && ./run.sh

---

## Expected Output
[exact console output block showing success]
Output file appears next to the input file as filename.html.
Logs: logs/WSClient.log

---

## Common Errors
[table: Error | Fix — only errors relevant to this protection type]
```

Do not include concept explanations, "Next Steps" sections, or marketing copy in the README.

---

---

## XML Reference

### App Config XML

```xml
<?xml version="1.0" encoding="UTF-16" ?>
<fs-helper-config>
    <locale/>
    <app-path>.</app-path>
    <initalize-logger>true</initalize-logger>
</fs-helper-config>
```

> **Note:** `<initalize-logger>` is spelled with a single "i" in "initalize" — this is
> the actual SDK tag. Using the correct spelling ("initialize") causes the tag to be silently ignored.

---

### Tenant Config XML

```xml
<?xml version="1.0" encoding="UTF-16" ?>
<fs-helper-ps-config>
    <ps-details>
        <urls>
            <url>
                <server>your-policy-server.example.com</server>
                <port>443</port>
                <app-name>YourAppName</app-name>
            </url>
        </urls>
    </ps-details>
    <login-details>
        <user-type>1</user-type>
        <hotfolder-cabinet>
            <id>your-ea-id</id>
            <passphrase>your-ea-passphrase</passphrase>
            <allow-advanced-privileges>false</allow-advanced-privileges>
        </hotfolder-cabinet>
    </login-details>
    <include-inline-attachment-in-mail-body>false</include-inline-attachment-in-mail-body>
    <session-pool>
        <max-size>50</max-size>
        <default-session-timeout>900</default-session-timeout>
    </session-pool>
</fs-helper-ps-config>
```

> Root element is `<fs-helper-ps-config>`. PS details go in `<ps-details>` — not `<Policy Server-details>`.
> Set `<allow-advanced-privileges>true</allow-advanced-privileges>` only when using Unprotect Any File (Advanced EA).
> The `<server>` value is the hostname only — do not include `https://` or `http://`.

---

### Hot Folder Protection XML

```xml
<hot-folder><id>7</id></hot-folder>
```

---

### External Reference Protection XML

```xml
<hot-folder-extn-reference>
  <extn-reference>
    <extn-ref-id>HF-REF-001</extn-ref-id>       <!-- Required -->
    <extn-ref-name>My Policy</extn-ref-name>      <!-- Optional -->
    <extn-ref-data>any metadata</extn-ref-data>   <!-- Optional -->
  </extn-reference>
</hot-folder-extn-reference>
<file-extn-reference>
  <extn-reference>
    <extn-ref-id>DOC-12345</extn-ref-id>          <!-- Required — your app's file ID -->
    <extn-ref-name>Document Name</extn-ref-name>  <!-- Optional -->
    <extn-ref-data>any metadata</extn-ref-data>   <!-- Optional -->
  </extn-reference>
</file-extn-reference>
```

---

### Independent Rights Protection XML

```xml
<protection-details>
  <classification><id>1</id></classification>
  <file-access-right-mappings>
    <file-access-right-mapping>
      <action>1</action>
      <access-right>
        <entity>
          <id>recipientId</id>          <!-- From Policy Server sendRequest type 74 or 109 -->
          <rep-code>recipientRepCode</rep-code>
          <type>recipientType</type>
        </entity>
        <primary-access-right>1</primary-access-right>  <!-- Rights value from Policy Server -->
        <offline>0</offline>
        <redistribute>0</redistribute>
        <lock-to-first-machine>0</lock-to-first-machine>
        <no-of-days-since-protection>-1</no-of-days-since-protection>
        <no-of-days-since-first-access>-1</no-of-days-since-first-access>
      </access-right>
    </file-access-right-mapping>
  </file-access-right-mappings>
  <owner>
    <entity>
      <id>ownerId</id>
      <rep-code>ownerRepCode</rep-code>
      <type>ownerType</type>
    </entity>
  </owner>
</protection-details>
```

---

### PROTECT_WITH_FILE_ID — Protection XML (confirmed)

```xml
<file-details><file-id>EXISTING_SECLORE_FILE_ID</file-id></file-details>
```

No permission details, owner, or access rights needed. Policy Server inherits the original
file's policy automatically. `result.getFileId()` returns the same File ID as the original.

**Alternative (also confirmed):** Using `PROTECT_WITH_HF_EXT_REF` with the same
`FILE_EXT_REF_ID` as an already-protected file produces the same result — same Seclore
File ID, same encryption key. Use this when the integration already tracks files by
External Reference ID.

---

### sendRequest XML — User Lookup (type 74)

```xml
<request>
  <request-header/>
  <request-details>
    <email-id>user@example.com</email-id>
  </request-details>
</request>
```

`sendRequest()` always returns the full **response XML as a String** (same as every other
request type in this skill) — never a `String[]`. Parse `<entities><entity>...</entity></entities>`
out of it. Response shape:

```xml
<response>
  <request-status><return-value>1</return-value></request-status>
  <entities>
    <entity>
      <type>1</type>                  <!-- 1=User, 2=Group -->
      <rep-code>REP_CODE</rep-code>
      <id>ENTITY_ID</id>
      <container><rep-code>REP_CODE</rep-code><id>...</id><code>...</code></container>
      <is-external>0</is-external>
      <name>USER_NAME</name>
      <email-id>user@example.com</email-id>
      <user-details>
        <login-id>user@example.com</login-id>
        <email-id>user@example.com</email-id>
        <domain></domain>
      </user-details>
    </entity>
  </entities>
</response>
```

Use `id` + `rep-code` from the returned `<entity>` (not the email) wherever the SDK or another
sendRequest call expects an entity reference. If `<entities>` is empty (or `return-value` is
negative, e.g. `-220372`), the user doesn't exist in Policy Server.

You can also search by `<login-id>` instead of `<email-id>` (send exactly one, not both), and
optionally scope to one repository with `<repositories><repository><rep-code>.../rep-code></repository></repositories>`.
`login-id` alone is confirmed to work identically to `email-id` alone (in a Policy Server
integrated with AD/SSO, these two fields can hold the same value for a given user, but the
server accepts either one independently).

Sending **both** `login-id` and `email-id` in the same request fails cleanly with
`return-value -220371`, `error-message "Both Email Id and Login Id found for search"`.
Sending **neither** fails cleanly with `return-value -220370`,
`error-message "Email Id/Login Id is missing."`. Always send exactly one.

---

### sendRequest XML — Create IM User (type 109)

Use this when a type-74 lookup finds no existing user for an email.

```xml
<request>
  <request-header/>
  <request-details>
    <im-user>
      <email-id>newuser@example.com</email-id>
      <requestor-comments>Created via SDK</requestor-comments>
      <referrer-email-id>existing.user@example.com</referrer-email-id>
    </im-user>
  </request-details>
</request>
```

`email-id`, `requestor-comments`, and `referrer-email-id` are all **mandatory**:
- Omitting `referrer-email-id` entirely fails with `-210001 Missing parameter 'referrer-email-id'`.
- Sending it empty/invalid fails with `-220517 Referrer Email Id '' is invalid`.
- `referrer-email-id` must be the email of an **already-existing** Policy Server user — any
  existing user works (it does not have to be an EA, admin, or the file owner specifically),
  but it can't be the same email you're creating.

`<repository><rep-code>...</rep-code></repository>` can optionally be added alongside `<im-user>`
inside `<request-details>` to force a specific repository. If omitted, Policy Server auto-assigns
the new user to its **Internal Users** or **External Users** repository based on whether the
email's domain matches the tenant's internal domain.

`sendRequest()` returns the full response XML as a String (never a `String[]`). Confirmed live
response on success (`return-value=1`):

```xml
<response>
  <request-status><return-value>1</return-value></request-status>
  <im-user>
    <rep-code>REP_CODE</rep-code>
    <is-external>0</is-external>           <!-- 0=internal repo, 1=external repo -->
    <id>NEW_USER_ID</id>
    <container>...</container>
    <name>USER_NAME</name>
    <email-id>newuser@example.com</email-id>
    <login-id>newuser@example.com</login-id>
    <status>1</status>
    <approval-status>1</approval-status>   <!-- 0=rejected, 1=approved, 2=requested -->
    <referrer-email-id>existing.user@example.com</referrer-email-id>
    <requestor-email-id>existing.user@example.com</requestor-email-id>
    <requestor-comments>Created via SDK</requestor-comments>
    ...
  </im-user>
  <repository>...</repository>             <!-- the repository the new user landed in -->
</response>
```

Use the returned `<im-user><id>` + `<rep-code>` as the entity reference for this user in any
subsequent call (e.g. building Independent Rights XML).

---

## Code Sample: Hot Folder Protection

```java
import com.seclore.fs.helper.library.FSHelperLibrary;
import com.seclore.fs.helper.library.FSHelper;
import com.seclore.fs.helper.core.ProtectedFile;
import com.seclore.fs.helper.enums.ProtectionType;

public class SecloreHotFolderSample {

    private static final String TENANT_ID = "Tenant-1";

    public static void main(String[] args) throws Exception {

        // 1. App config — initialize once at application startup
        String appConfigXML =
            "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
            "<fs-helper-config>" +
            "  <locale/>" +
            "  <app-path>.</app-path>" +
            "  <initalize-logger>true</initalize-logger>" +
            "</fs-helper-config>";

        FSHelperLibrary.initialize(appConfigXML);

        // 2. Tenant config — initialize once per tenant
        String psUrl        = "https://your-policy-server.example.com";
        int    psPort       = 443;
        String appName      = "YourAppName";
        String eaId    = "your-ea-id";
        String passphrase   = "your-ea-passphrase";

        String tenantConfigXML =
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

        FSHelperLibrary.initializeHelper(TENANT_ID, "", tenantConfigXML);

        // 3. Per-request: get the FSHelper and protect a file
        FSHelper tenantObj = FSHelperLibrary.getHelper(TENANT_ID);

        String filePath    = "C:\\demo\\document.docx";
        String hotFolderId = "7";                         // Hot Folder ID from Policy Server
        String comments    = "Protected by sample app";

        // Optional pre-checks (recommended)
        if (tenantObj.isProtectedFile(filePath)) {
            System.out.println("File is already protected.");
            return;
        }
        if (!tenantObj.isSupportedFile(filePath)) {
            System.out.println("File format not supported.");
            return;
        }

        // Build Hot Folder protection XML
        String protectionXML = "<hot-folder><id>" + hotFolderId + "</id></hot-folder>";

        // Protect the file
        // psConnection=null → SDK uses a pooled session; output written to same directory as input, appended with .html
        // protectorDetails="" → reserved, always empty string
        ProtectedFile result = tenantObj.protectAndWrap(
            null,
            filePath,
            filePath,
            ProtectionType.PROTECT_WITH_HF,
            protectionXML,
            "",
            comments
        );

        System.out.println("Protected file ID : " + result.getFileId());
        System.out.println("Protected file path: " + result.getFilePath());

        // 4. Shutdown
        FSHelperLibrary.terminate();
    }
}
```

---

## Code Sample: Independent Rights Protection

```java
import com.seclore.fs.helper.library.FSHelperLibrary;
import com.seclore.fs.helper.library.FSHelper;
import com.seclore.fs.helper.core.ProtectedFile;
import com.seclore.fs.helper.enums.ProtectionType;

public class SecloreIndependentRightsSample {

    private static final String TENANT_ID = "Tenant-1";

    public static void main(String[] args) throws Exception {

        // 1. App config
        String appConfigXML =
            "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
            "<fs-helper-config>" +
            "  <locale/>" +
            "  <app-path>.</app-path>" +
            "  <initalize-logger>true</initalize-logger>" +
            "</fs-helper-config>";

        FSHelperLibrary.initialize(appConfigXML);

        // 2. Tenant config
        String psUrl     = "https://your-policy-server.example.com";
        int    psPort    = 443;
        String appName   = "YourAppName";
        String eaId = "your-ea-id";
        String passphrase = "your-ea-passphrase";

        String tenantConfigXML =
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

        FSHelperLibrary.initializeHelper(TENANT_ID, "", tenantConfigXML);

        // 3. Resolve emails to Policy Server entity IDs
        FSHelper tenantObj = FSHelperLibrary.getHelper(TENANT_ID);

        String ownerEmail     = "owner@example.com";
        String recipientEmail = "recipient@example.com";

        // Owner must already exist in Policy Server — you cannot auto-create the owner,
        // because creating a user requires a referrer-email-id that must itself already
        // exist (see resolveOrCreateUser() below). Throws if the owner isn't found.
        String[] ownerEntity = lookupUser(tenantObj, ownerEmail);
        if (ownerEntity == null) {
            throw new RuntimeException("Owner " + ownerEmail + " does not exist in Policy Server.");
        }

        // Recipient: look up, auto-create (referred by the owner) if not found.
        String[] recipientEntity = resolveOrCreateUser(tenantObj, recipientEmail, ownerEmail);

        // 4. Pre-checks before protecting
        if (tenantObj.isProtectedFile(filePath)) {
            System.out.println("File is already protected.");
            FSHelperLibrary.terminate();
            return;
        }
        if (!tenantObj.isSupportedFile(filePath)) {
            System.out.println("File format not supported.");
            FSHelperLibrary.terminate();
            return;
        }

        // 6. Build Independent Rights XML using entity IDs from Policy Server
        String rights = "1";  // Rights value from Policy Server configuration
        String protectionXML =
            "<protection-details>" +
            "  <classification><id>1</id></classification>" +
            "  <file-access-right-mappings>" +
            "    <file-access-right-mapping>" +
            "      <action>1</action>" +
            "      <access-right>" +
            "        <entity>" +
            "          <id>" + recipientEntity[0] + "</id>" +
            "          <rep-code>" + recipientEntity[1] + "</rep-code>" +
            "          <type>" + recipientEntity[2] + "</type>" +
            "        </entity>" +
            "        <primary-access-right>" + rights + "</primary-access-right>" +
            "        <offline>0</offline>" +
            "        <redistribute>0</redistribute>" +
            "        <lock-to-first-machine>0</lock-to-first-machine>" +
            "        <no-of-days-since-protection>-1</no-of-days-since-protection>" +
            "        <no-of-days-since-first-access>-1</no-of-days-since-first-access>" +
            "      </access-right>" +
            "    </file-access-right-mapping>" +
            "  </file-access-right-mappings>" +
            "  <owner>" +
            "    <entity>" +
            "      <id>" + ownerEntity[0] + "</id>" +
            "      <rep-code>" + ownerEntity[1] + "</rep-code>" +
            "      <type>" + ownerEntity[2] + "</type>" +
            "    </entity>" +
            "  </owner>" +
            "</protection-details>";

        // 7. Protect the file
        // psConnection=null → SDK uses a pooled session; output written to same directory as input, appended with .html
        // protectorDetails="" → reserved, always empty string
        String filePath = "C:\\demo\\document.docx";
        ProtectedFile result = tenantObj.protectAndWrap(
            null,
            filePath,
            filePath,
            ProtectionType.PROTECT,
            protectionXML,
            "",
            "Protected with Independent Rights"
        );

        System.out.println("Protected file ID : " + result.getFileId());
        System.out.println("Protected file path: " + result.getFilePath());

        FSHelperLibrary.terminate();
    }

    // Helper: look up a user in Policy Server. sendRequest type 74.
    // Returns null if no match (don't throw — callers decide whether that's fatal).
    private static String[] lookupUser(FSHelper tenantObj, String email) throws Exception {
        String searchXML =
            "<request><request-header/><request-details>" +
            "  <email-id>" + email + "</email-id>" +
            "</request-details></request>";

        // sendRequest() always returns the response XML as a String — never a String[].
        String responseXML = tenantObj.sendRequest(null, 74, searchXML);
        return parseFirstEntity(responseXML);  // [id, repCode, type] or null
    }

    // Helper: look up a user, auto-create (referred by referrerEmail) if not found.
    // sendRequest type 109. referrerEmail MUST already exist in Policy
    // Server — typically the file owner (matches the pattern in Seclore's own Independent
    // Rights sample code: the owner refers each recipient that needs to be created).
    private static String[] resolveOrCreateUser(FSHelper tenantObj, String email, String referrerEmail) throws Exception {
        String[] found = lookupUser(tenantObj, email);
        if (found != null) {
            return found;
        }
        // No <entities> match (or return-value negative, e.g. -220372) — user not found; create.
        // email-id, requestor-comments, and referrer-email-id are all mandatory. Omitting
        // referrer-email-id fails with -210001; an empty/invalid one fails with -220517.
        String createXML =
            "<request><request-header/><request-details>" +
            "  <im-user>" +
            "    <email-id>" + email + "</email-id>" +
            "    <requestor-comments>Auto-created for Independent Rights protection</requestor-comments>" +
            "    <referrer-email-id>" + referrerEmail + "</referrer-email-id>" +
            "  </im-user>" +
            "</request-details></request>";
        String createResponseXML = tenantObj.sendRequest(null, 109, createXML);
        String[] created = parseFirstImUser(createResponseXML);
        if (created == null) {
            throw new RuntimeException("Failed to resolve or create user " + email
                + " — response: " + createResponseXML);
        }
        return created;
    }

    // Parses id/rep-code/type out of a type-109 response's top-level <im-user> block
    // (different shape from type 74's <entities><entity> — there's no <type> tag here,
    // so default to "1" for User, matching what every type-109 response actually creates).
    private static String[] parseFirstImUser(String responseXML) {
        int s = responseXML.indexOf("<im-user>");
        if (s < 0) return null;
        int e = responseXML.indexOf("</im-user>", s);
        String block = responseXML.substring(s, e);
        String id      = between(block, "<id>", "</id>");
        String repCode = between(block, "<rep-code>", "</rep-code>");
        if (id == null || repCode == null) return null;
        return new String[] { id, repCode, "1" };
    }

    // Pulls [id, repCode, type] out of the first <entity> in a type-74-style response,
    // or returns null if there's no entity (not found). Quick-and-dirty substring parsing
    // for sample purposes — use a real XML parser in production code.
    private static String[] parseFirstEntity(String responseXML) {
        int entityStart = responseXML.indexOf("<entity>");
        if (entityStart < 0) return null;
        int entityEnd = responseXML.indexOf("</entity>", entityStart);
        String entity = responseXML.substring(entityStart, entityEnd);
        String id      = between(entity, "<id>", "</id>");
        String repCode = between(entity, "<rep-code>", "</rep-code>");
        String type    = between(entity, "<type>", "</type>");
        if (id == null || repCode == null) return null;
        return new String[] { id, repCode, type };
    }

    private static String between(String xml, String start, String end) {
        int s = xml.indexOf(start);
        if (s < 0) return null;
        s += start.length();
        int e = xml.indexOf(end, s);
        if (e < 0) return null;
        return xml.substring(s, e).trim();
    }
}
```

---

## Code Sample: Protect with External Reference (Policy Federation)

```java
import com.seclore.fs.helper.library.FSHelperLibrary;
import com.seclore.fs.helper.library.FSHelper;
import com.seclore.fs.helper.core.ProtectedFile;
import com.seclore.fs.helper.enums.ProtectionType;

public class SecloreExternalReferenceSample {

    private static final String TENANT_ID = "Tenant-1";

    public static void main(String[] args) throws Exception {

        // 1. App config
        String appConfigXML =
            "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
            "<fs-helper-config>" +
            "  <locale/>" +
            "  <app-path>.</app-path>" +
            "  <initalize-logger>true</initalize-logger>" +
            "</fs-helper-config>";

        FSHelperLibrary.initialize(appConfigXML);

        // 2. Tenant config
        String psUrl     = "https://your-policy-server.example.com";
        int    psPort    = 443;
        String appName   = "YourAppName";
        String eaId = "your-ea-id";
        String passphrase = "your-ea-passphrase";

        String tenantConfigXML =
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

        FSHelperLibrary.initializeHelper(TENANT_ID, "", tenantConfigXML);

        // 3. Per-request: protect a file with external references
        FSHelper tenantObj = FSHelperLibrary.getHelper(TENANT_ID);

        String filePath    = "C:\\demo\\document.docx";
        String comments    = "Protected with External Reference";

        // HF External Reference: identifies the Hot Folder by your app's reference ID
        // (as registered in Policy Server → Hot Folder → External Reference configuration)
        String hfExtRefId   = "HF-REF-001";      // Required
        String hfExtRefName = "My App HF Policy"; // Optional
        String hfExtRefData = "";                  // Optional

        // File External Reference: your application's unique ID for this specific file
        // Policy Server will use this ID when calling back to your app to ask for access rights
        String fileExtRefId   = "DOC-12345";       // Required — your unique file ID
        String fileExtRefName = "Document 12345";  // Optional
        String fileExtRefData = "";                 // Optional

        // Optional pre-checks
        if (tenantObj.isProtectedFile(filePath)) {
            System.out.println("File is already protected.");
            return;
        }
        if (!tenantObj.isSupportedFile(filePath)) {
            System.out.println("File format not supported.");
            return;
        }

        // Build External Reference protection XML
        StringBuilder protectionXML = new StringBuilder();
        protectionXML.append("<hot-folder-extn-reference>");
        protectionXML.append("  <extn-reference>");
        protectionXML.append("    <extn-ref-id>").append(hfExtRefId).append("</extn-ref-id>");
        if (hfExtRefName != null && !hfExtRefName.isEmpty()) {
            protectionXML.append("    <extn-ref-name>").append(hfExtRefName).append("</extn-ref-name>");
        }
        if (hfExtRefData != null && !hfExtRefData.isEmpty()) {
            protectionXML.append("    <extn-ref-data>").append(hfExtRefData).append("</extn-ref-data>");
        }
        protectionXML.append("  </extn-reference>");
        protectionXML.append("</hot-folder-extn-reference>");

        protectionXML.append("<file-extn-reference>");
        protectionXML.append("  <extn-reference>");
        protectionXML.append("    <extn-ref-id>").append(fileExtRefId).append("</extn-ref-id>");
        if (fileExtRefName != null && !fileExtRefName.isEmpty()) {
            protectionXML.append("    <extn-ref-name>").append(fileExtRefName).append("</extn-ref-name>");
        }
        if (fileExtRefData != null && !fileExtRefData.isEmpty()) {
            protectionXML.append("    <extn-ref-data>").append(fileExtRefData).append("</extn-ref-data>");
        }
        protectionXML.append("  </extn-reference>");
        protectionXML.append("</file-extn-reference>");

        // Protect the file
        // psConnection=null → SDK uses a pooled session; output written to same directory as input, appended with .html
        // protectorDetails="" → reserved, always empty string
        ProtectedFile result = tenantObj.protectAndWrap(
            null,
            filePath,
            filePath,
            ProtectionType.PROTECT_WITH_HF_EXT_REF,
            protectionXML.toString(),
            "",
            comments
        );

        System.out.println("Protected file ID : " + result.getFileId());
        System.out.println("Protected file path: " + result.getFilePath());

        FSHelperLibrary.terminate();
    }
}
```

---

## Code Sample: Unprotect — Standard EA

```java
import com.seclore.fs.helper.library.FSHelperLibrary;
import com.seclore.fs.helper.library.FSHelper;
import com.seclore.fs.helper.core.UnprotectedFile;

public class SecloreUnprotectSample {

    private static final String TENANT_ID = "Tenant-1";

    public static void main(String[] args) throws Exception {

        // 1. App config
        String appConfigXML =
            "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
            "<fs-helper-config>" +
            "  <locale/>" +
            "  <app-path>.</app-path>" +
            "  <initalize-logger>true</initalize-logger>" +
            "</fs-helper-config>";

        FSHelperLibrary.initialize(appConfigXML);

        // 2. Tenant config
        String psUrl     = "https://your-policy-server.example.com";
        int    psPort    = 443;
        String appName   = "YourAppName";
        String eaId = "your-ea-id";
        String passphrase = "your-ea-passphrase";

        String tenantConfigXML =
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

        FSHelperLibrary.initializeHelper(TENANT_ID, "", tenantConfigXML);

        // 3. Unprotect a file
        FSHelper tenantObj = FSHelperLibrary.getHelper(TENANT_ID);

        String filePath = "C:\\demo\\document.docx.html";  // Protected .html file
        String comments = "Unprotected by sample app";

        // Pre-check: must be HTML-wrapped before calling unwrapAndUnprotect
        if (!tenantObj.isHTMLWrapped(filePath)) {
            System.out.println("File is not HTML-wrapped.");
            return;
        }

        // Unprotect
        // psConnection=null → SDK uses a pooled session; output written to same directory as input
        UnprotectedFile result = tenantObj.unwrapAndUnprotect(
            null,
            filePath,
            filePath,
            comments
        );

        System.out.println("Unprotected file path: " + result.getFilePath());

        FSHelperLibrary.terminate();
    }
}
```

---

## Code Sample: Unprotect Any File — Advanced EA

```java
import com.seclore.fs.helper.library.FSHelperLibrary;
import com.seclore.fs.helper.library.FSHelper;
import com.seclore.fs.helper.core.UnprotectedFile;
import com.seclore.fs.helper.crypto.DefaultCryptoHandler;

public class SecloreUnprotectAnyFileSample {

    private static final String TENANT_ID = "Tenant-1";

    public static void main(String[] args) throws Exception {

        // 1. App config
        String appConfigXML =
            "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
            "<fs-helper-config>" +
            "  <locale/>" +
            "  <app-path>.</app-path>" +
            "  <initalize-logger>true</initalize-logger>" +
            "</fs-helper-config>";

        FSHelperLibrary.initialize(appConfigXML);

        // 2. Tenant config — allow-advanced-privileges must be true
        String psUrl     = "https://your-policy-server.example.com";
        int    psPort    = 443;
        String appName   = "YourAppName";
        String eaId = "your-ea-id";
        String passphrase = "your-ea-passphrase";

        String tenantConfigXML =
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
            "      <allow-advanced-privileges>true</allow-advanced-privileges>" +
            "    </hotfolder-cabinet>" +
            "  </login-details>" +
            "  <include-inline-attachment-in-mail-body>false</include-inline-attachment-in-mail-body>" +
            "  <session-pool>" +
            "    <max-size>50</max-size>" +
            "    <default-session-timeout>900</default-session-timeout>" +
            "  </session-pool>" +
            "</fs-helper-ps-config>";

        // 3. Build DefaultCryptoHandler with the RSA private key
        // privateKeyXML is the hex-encoded private key generated and saved by the demo.
        // activeKeyId is copied from Policy Server after registering the matching public key.
        String privateKeyXML = "<private-key>...</private-key>"; // Replace with actual key XML
        String activeKeyId   = "your-active-key-id-from-Policy Server";    // Replace with actual key ID

        // Parameters: privateKeyXML, keySize=256, activeKeyId, cipherMode="ECB", padding="PKCS1Padding"
        DefaultCryptoHandler cryptoHandler = new DefaultCryptoHandler(
            privateKeyXML, 256, activeKeyId, "ECB", "PKCS1Padding"
        );

        // 4. Initialize with the CryptoHandler (Advanced EA)
        // Note: Advanced EA privilege is NOT validated here — it is validated on first unprotect call
        FSHelperLibrary.initializeHelper(TENANT_ID, "", tenantConfigXML, cryptoHandler);

        // 5. Unprotect any file on this Policy Server
        FSHelper tenantObj = FSHelperLibrary.getHelper(TENANT_ID);

        String filePath = "C:\\demo\\any-protected-file.docx.html";
        String comments = "Unprotected via Advanced EA";

        if (!tenantObj.isHTMLWrapped(filePath)) {
            System.out.println("File is not HTML-wrapped.");
            return;
        }

        UnprotectedFile result = tenantObj.unwrapAndUnprotect(
            null,
            filePath,
            filePath,
            comments
        );

        System.out.println("Unprotected file path: " + result.getFilePath());

        FSHelperLibrary.terminate();
    }
}
```

---

## Code Sample: Native Protect (protectX — no HTML wrapper)

Use this when you want to protect a file without immediately adding the HTML envelope.
The output is a natively-protected Seclore file. Use `wrap()` in a second step to add the HTML envelope.

```java
import com.seclore.fs.helper.library.FSHelperLibrary;
import com.seclore.fs.helper.library.FSHelper;
import com.seclore.fs.helper.enums.ProtectionType;

public class SecloreNativeProtectSample {

    private static final String TENANT_ID = "Tenant-1";

    public static void main(String[] args) throws Exception {

        // 1. App config — initialize once at application startup
        String appConfigXML =
            "<?xml version=\"1.0\" encoding=\"UTF-16\" ?>" +
            "<fs-helper-config>" +
            "  <locale/>" +
            "  <app-path>.</app-path>" +
            "  <initalize-logger>true</initalize-logger>" +
            "</fs-helper-config>";

        FSHelperLibrary.initialize(appConfigXML);

        // 2. Tenant config — initialize once per tenant
        String psUrl     = "https://your-policy-server.example.com";
        int    psPort    = 443;
        String appName   = "YourAppName";
        String eaId = "your-ea-id";
        String passphrase = "your-ea-passphrase";

        String tenantConfigXML =
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

        FSHelperLibrary.initializeHelper(TENANT_ID, "", tenantConfigXML);

        // 3. Protect natively (no HTML envelope)
        FSHelper tenantObj = FSHelperLibrary.getHelper(TENANT_ID);

        String filePath    = "C:\\demo\\document.docx";
        String hotFolderId = "7";
        String comments    = "Natively protected by sample app";

        if (tenantObj.isProtectedFile(filePath)) {
            System.out.println("File is already protected.");
            return;
        }
        if (!tenantObj.isSupportedFile(filePath)) {
            System.out.println("File format not supported.");
            return;
        }

        String protectionXML = "<hot-folder><id>" + hotFolderId + "</id></hot-folder>";

        // protectX produces a natively-protected file — no HTML envelope
        // Returns String (output file path), not ProtectedFile — there is no File ID
        String nativeFilePath = tenantObj.protectX(
            null,
            filePath,
            filePath,
            ProtectionType.PROTECT_WITH_HF,
            protectionXML,
            "",
            comments
        );

        System.out.println("Natively protected file: " + nativeFilePath);

        FSHelperLibrary.terminate();
    }
}
```

---

## Code Sample: Wrap and Unwrap (HTML envelope operations)

`wrap()` adds an HTML envelope to an existing natively-protected file.
`unwrap()` removes the HTML envelope, leaving the natively-protected file.
Neither method returns a File ID — `getFileId()` is always `null` for both.

```java
import com.seclore.fs.helper.library.FSHelperLibrary;
import com.seclore.fs.helper.library.FSHelper;
import com.seclore.fs.helper.core.ProtectedFile;

public class SecloreWrapUnwrapSample {

    private static final String TENANT_ID = "Tenant-1";

    public static void main(String[] args) throws Exception {

        // (SDK initialization omitted for brevity — see Hot Folder sample above)

        FSHelper tenantObj = FSHelperLibrary.getHelper(TENANT_ID);

        // --- Wrap: add HTML envelope to a natively-protected file ---
        // Input:  natively-protected Seclore file (e.g., produced by protectX)
        // Output: HTML-wrapped file (.html) in the same directory
        // Note:   No activityComments parameter. getFileId() is always null.
        String nativeFilePath = "C:\\demo\\document.docx";
        ProtectedFile wrapResult = tenantObj.wrap(
            null,             // PSConnection — null = use pooled session
            nativeFilePath,   // path to the natively-protected file
            nativeFilePath    // displayFileName — shown in PS audit trail
        );

        System.out.println("Wrapped file path: " + wrapResult.getFilePath());
        // wrapResult.getFileId() is always null — do not use

        // --- Unwrap: strip HTML envelope, returning the natively-protected file ---
        // Input:  HTML-wrapped Seclore file (.html)
        // Output: natively-protected file in the same directory
        // Note:   Only one parameter. getFileId() is always null.
        String htmlFilePath = wrapResult.getFilePath();
        ProtectedFile unwrapResult = tenantObj.unwrap(htmlFilePath);

        System.out.println("Unwrapped file path: " + unwrapResult.getFilePath());
        // unwrapResult.getFileId() is always null — do not use

        FSHelperLibrary.terminate();
    }
}
```

---

## Code Sample: Native Unprotect (unprotectX — natively-protected files)

Use this when the file was protected with `protectX()` (no HTML envelope).
**Do NOT use `unwrapAndUnprotect()` on these files** — it will throw `WSClientException: Invalid file format 'docx' for HTML unwrapping`.

```java
import com.seclore.fs.helper.library.FSHelperLibrary;
import com.seclore.fs.helper.library.FSHelper;

public class SecloreNativeUnprotectSample {

    private static final String TENANT_ID = "Tenant-1";

    public static void main(String[] args) throws Exception {

        // (SDK initialization omitted for brevity — see Hot Folder sample above)

        FSHelper tenantObj = FSHelperLibrary.getHelper(TENANT_ID);

        String filePath = "C:\\demo\\document.docx"; // natively-protected (no .html extension)
        String comments = "Unprotected via native unprotect";

        // Pre-check: confirm this is a natively-protected Seclore file.
        // Use isProtectedFile(), NOT isHTMLWrapped() — this file has no HTML envelope.
        if (!tenantObj.isProtectedFile(filePath)) {
            System.out.println("File is not Seclore-protected.");
            return;
        }

        // unprotectX reverses protectX — do NOT call unwrapAndUnprotect on these files
        String unprotectedFilePath = tenantObj.unprotectX(
            null,
            filePath,
            filePath,
            comments
        );

        System.out.println("Unprotected file path: " + unprotectedFilePath);

        FSHelperLibrary.terminate();
    }
}
```

**Notes:**
- Calling `unwrapAndUnprotect()` on a natively-protected (non-HTML) file throws
  `WSClientException: Invalid file format 'docx' for HTML unwrapping` — always match the
  unprotect method to how the file was originally protected (`protectX` → `unprotectX`;
  `protectAndWrap` → `unwrapAndUnprotect`).
- `unprotectX` returns a `String` (the output file path), like `protectX` — not an
  `UnprotectedFile` object, so there is no `getFileId()` to call.

---

> **NOTE (added during repackaging):** this section was found cut off mid-comment in the
> draft — the method body ended after `// Use isProtectedFile(), NOT isHT` with no
> pre-check, `unprotectX` call, or closing braces. The completion above mirrors the
> equivalent pre-check/call/closing pattern already used in the Native Protect sample
> earlier in this file. Flagging here per your standing instruction to surface gaps rather
> than silently patch them — please confirm this is the intended completion (it was not
> re-derived from any additional verified sample beyond the existing Native Protect code
> in this same document).

---

## Code Sample: Custom Logger — ISecloreSDKLogger

Use this when your application already manages its own logging framework and you want SDK
logs routed through it instead of the SDK writing to its own `WSClient.log`.

**Interface** (package: `com.seclore.fs.ws.client.logger.interfaces`):

```java
public interface ISecloreSDKLogger extends Serializable {
    void logDebug(String pRequestId, String pMessage);
    void logInfo(String pRequestId, String pMessage);
    void logException(String pRequestId, String pMessage, Throwable pThrowable);
}
```

`pRequestId` is unique per SDK operation — use it as a correlation ID to link all log
lines from a single protect/unprotect call.

> **`pThrowable` can be null.** The SDK calls `logException` for both error-with-cause and
> error-without-cause scenarios. Always guard against null before passing to your logging
> framework.

---

### Production pattern — constructor-injected logger name (recommended)

Passing the logger name via the constructor lets different parts of your application
direct SDK logs to separate named loggers (e.g. one per tenant, one per service). This
is the pattern used in Seclore's own engineering reference implementation.

**Log4j2:**

```java
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import com.seclore.fs.ws.client.logger.interfaces.ISecloreSDKLogger;

public class SecloreSDKLogger implements ISecloreSDKLogger {

    private static final long serialVersionUID = 1L; // required: ISecloreSDKLogger extends Serializable

    private final Logger mLogger;

    public SecloreSDKLogger(String pLoggerName) {
        mLogger = LogManager.getLogger(pLoggerName);
    }

    @Override
    public void logDebug(String pRequestId, String pMessage) {
        mLogger.debug("[{}] {}", pRequestId, pMessage);
    }

    @Override
    public void logInfo(String pRequestId, String pMessage) {
        mLogger.info("[{}] {}", pRequestId, pMessage);
    }

    @Override
    public void logException(String pRequestId, String pMessage, Throwable pExp) {
        if (pExp == null) {
            mLogger.error("[{}] {}", pRequestId, pMessage);
        } else {
            mLogger.error("[{}] {}", pRequestId, pMessage, pExp);
        }
    }
}
```

**Wire-up:**
```java
// Named logger — SDK logs appear under "SecloreSDK" in your log config
ISecloreSDKLogger sdkLogger = new SecloreSDKLogger("SecloreSDK");
FSHelperLibrary.initialize(sdkLogger, appConfigXML);
```

---

### Alternative — class-based static logger

Simpler for single-tenant applications where all SDK log output goes to one logger.

**Log4j2:**

```java
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import com.seclore.fs.ws.client.logger.interfaces.ISecloreSDKLogger;

public class SecloreLog4j2Logger implements ISecloreSDKLogger {

    private static final long serialVersionUID = 1L;
    private static final Logger log = LogManager.getLogger(SecloreLog4j2Logger.class);

    @Override
    public void logDebug(String id, String msg) {
        log.debug("[SDK][{}] {}", id, msg);
    }

    @Override
    public void logInfo(String id, String msg) {
        log.info("[SDK][{}] {}", id, msg);
    }

    @Override
    public void logException(String id, String msg, Throwable t) {
        if (t == null) {
            log.error("[SDK][{}] {}", id, msg);
        } else {
            log.error("[SDK][{}] {}", id, msg, t);
        }
    }
}
```

**SLF4J:**

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.seclore.fs.ws.client.logger.interfaces.ISecloreSDKLogger;

public class SecloreSlf4jLogger implements ISecloreSDKLogger {

    private static final long serialVersionUID = 1L;
    private static final Logger log = LoggerFactory.getLogger(SecloreSlf4jLogger.class);

    @Override
    public void logDebug(String id, String msg) {
        log.debug("[SDK][{}] {}", id, msg);
    }

    @Override
    public void logInfo(String id, String msg) {
        log.info("[SDK][{}] {}", id, msg);
    }

    @Override
    public void logException(String id, String msg, Throwable t) {
        if (t == null) {
            log.error("[SDK][{}] {}", id, msg);
        } else {
            log.error("[SDK][{}] {}", id, msg, t);
        }
    }
}
```

**Java Util Logging (JUL):**

```java
import java.util.logging.Level;
import java.util.logging.Logger;
import com.seclore.fs.ws.client.logger.interfaces.ISecloreSDKLogger;

public class SecloreJULLogger implements ISecloreSDKLogger {

    private static final long serialVersionUID = 1L;
    private static final Logger log = Logger.getLogger(SecloreJULLogger.class.getName());

    @Override
    public void logDebug(String id, String msg) {
        log.fine(String.format("[SDK][%s] %s", id, msg));
    }

    @Override
    public void logInfo(String id, String msg) {
        log.info(String.format("[SDK][%s] %s", id, msg));
    }

    @Override
    public void logException(String id, String msg, Throwable t) {
        if (t == null) {
            log.severe(String.format("[SDK][%s] %s", id, msg));
        } else {
            log.log(Level.SEVERE, String.format("[SDK][%s] %s", id, msg), t);
        }
    }
}
```

---

**App Config XML — `<initalize-logger>false</initalize-logger>` is required:**

```xml
<?xml version="1.0" encoding="UTF-16" ?>
<fs-helper-config>
    <locale/>
    <app-path>.</app-path>
    <initalize-logger>false</initalize-logger>
</fs-helper-config>
```

Without `false`, the SDK still initialises its own Log4j2 appender in parallel →
double-logging and potential file lock conflicts.

---

**Key rules:**
- `serialVersionUID` must be declared — `ISecloreSDKLogger` extends `Serializable`
- Always null-check `pThrowable`/`t` in `logException` — the SDK passes null for errors that have no underlying exception
- `<initalize-logger>false</initalize-logger>` must be set when using a custom logger
- Interface package: `com.seclore.fs.ws.client.logger.interfaces`
- `initialize(logger, xml)` (2-arg) is distinct from `initialize(xml)` (1-arg) — they are not interchangeable
- This is a callback: the SDK calls your methods; do not call SDK methods from inside the logger
- All subsequent SDK calls (`initializeHelper`, `getHelper`, protect, unprotect, etc.) are identical regardless of which logger variant is used

---

## Code Sample: Check File Protection Status

Two approaches: with the SDK (requires initialization) and without (byte-level detection,
no SDK dependency).

---

### With SDK

```java
import com.seclore.fs.ws.client.FSHelper;
import com.seclore.fs.ws.client.FSHelperLibrary;

public class ProtectionStatusWithSDK {

    public static void main(String[] args) throws Exception {
        String appConfigXML  = "<path-to-app-config.xml>";
        String tenantId      = "myTenantId";
        String tenantConfig  = "<path-to-tenant-config.xml>";
        String filePath      = "<path-to-file>";

        // Step 1: Initialize SDK
        FSHelperLibrary.initialize(appConfigXML);
        FSHelperLibrary.initializeHelper(tenantId, tenantConfig);

        // Step 2: Get helper and check status
        FSHelper tenantObj = FSHelperLibrary.getHelper(tenantId);

        boolean isNativelyProtected = tenantObj.isProtectedFile(filePath);
        boolean isHTMLWrapped       = tenantObj.isHTMLWrapped(filePath);
        boolean isSupportedFormat   = tenantObj.isSupportedFile(filePath);

        System.out.println("Natively protected : " + isNativelyProtected);
        System.out.println("HTML wrapped       : " + isHTMLWrapped);
        System.out.println("Supported format   : " + isSupportedFormat);

        // Step 3: Terminate
        FSHelperLibrary.terminate();
    }
}
```

---

### Without SDK (byte-level signature detection)

Use when the application cannot or does not want to take an SDK dependency.

```java
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

/**
 * Detects whether a file is Seclore-protected without using the Seclore Server SDK.
 *
 * Detection is based on Seclore's embedded binary signatures:
 *   - Native protection: signature embedded at buffer-boundary byte offsets
 *   - HTML wrapping:     HTML comment signature in the first 1 MB of the file
 *
 * Files smaller than 64 KB are not Seclore-protected or wrapped.
 */
public class SecloreProtectionDetector {

    /** Signature embedded in natively protected (non-HTML) files. */
    private static final String NATIVE_SIGNATURE =
        "FXIMLHDESAACAIDNUIIABMURME.DTDL.ETVPYGSOKTLOOPCNHCLIETEEROLCESNT";

    /** Signature embedded in HTML-wrapped Seclore files. */
    private static final String HTML_SIGNATURE =
        "<!--FXIMLHDESAACAIDNUIIABMURME.DTDL.ETVPYGSOKTLOOPCNHCLIETEEROLCESNT-->";

    private static final long MIN_FILE_SIZE_BYTES = 64L * 1024; // 64 KB

    public enum ProtectionStatus {
        SECLORE_PROTECTED,  // natively protected (non-HTML format)
        SECLORE_WRAPPED,    // HTML-wrapped Seclore file
        NOT_SECLORE         // not protected (or file < 64 KB)
    }

    public static ProtectionStatus detect(File file) throws IOException {
        // Files below 64 KB cannot be Seclore-protected or wrapped
        if (file.length() < MIN_FILE_SIZE_BYTES) {
            return ProtectionStatus.NOT_SECLORE;
        }

        String filename  = file.getName();
        String extension = filename.contains(".")
            ? filename.substring(filename.lastIndexOf('.') + 1).toLowerCase()
            : "";

        // HTML-wrapped files: search first 1 MB for the HTML comment signature
        if ("html".equals(extension)) {
            byte[] buf = readBytes(file, 0, 1024 * 1024);
            return new String(buf, "UTF-8").contains(HTML_SIGNATURE)
                ? ProtectionStatus.SECLORE_WRAPPED
                : ProtectionStatus.NOT_SECLORE;
        }

        // Native protection: walk buffer-boundary offsets looking for the signature.
        // Seclore places its signature at the start of each buffer-header block.
        // Offset progression formula: next = (2 * current) + 4
        // This covers buffers up to 1 MB of original content.
        int offsetKB = 60; // first boundary at 60 KB
        while (offsetKB < 1024) {
            long byteOffset = (long) offsetKB * 1024;
            if (file.length() < byteOffset) {
                break; // file is smaller than this offset slot
            }
            byte[] sig = readBytes(file, byteOffset, 64);
            if (new String(sig, "UTF-8").contains(NATIVE_SIGNATURE)) {
                return ProtectionStatus.SECLORE_PROTECTED;
            }
            // Advance to next buffer boundary: 60 → 124 → 252 → 508 → 1020
            offsetKB = (2 * offsetKB) + 4;
        }

        return ProtectionStatus.NOT_SECLORE;
    }

    /** Read {@code length} bytes from {@code file} starting at {@code offset}. */
    private static byte[] readBytes(File file, long offset, int length) throws IOException {
        byte[] buf = new byte[length];
        try (FileInputStream fis = new FileInputStream(file)) {
            long skipped = fis.skip(offset);
            if (skipped < offset) return buf; // file ended before the offset
            fis.read(buf, 0, length);
        }
        return buf;
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            System.err.println("Usage: SecloreProtectionDetector <file-path>");
            System.exit(1);
        }
        File file = new File(args[0]);
        ProtectionStatus status = detect(file);
        System.out.println(file.getName() + " → " + status);
    }
}
```

**Notes:**
- `SECLORE_PROTECTED` and `SECLORE_WRAPPED` are mutually exclusive — native protection
  applies to non-HTML formats; HTML wrapping applies only to `.html` files.
- At most 1 MB of any file is read, so detection is lightweight even on large files.
- For production use, catch `IOException` and treat it as `NOT_SECLORE` (or re-throw
  depending on your error-handling policy).
- The algorithm covers original content up to 1020 KB. Files with larger original content
  whose signatures land beyond 1 MB will not be detected by this method; use the SDK for
  those cases.

---

## Code Sample: Seclore Endpoint SDK — Invoke from Java

These samples show how to invoke `SecloreActionDispatcher.exe` from a Java application using `ProcessBuilder`. The executable is shipped with Seclore Desktop Client and runs on the same Windows machine.

### SecloreEndpointSDKInvoker — protect, classify, and bulk operations

```java
import java.io.*;
import java.util.*;

/**
 * Utility class for invoking Seclore Endpoint SDK actions from Java.
 *
 * Prerequisites:
 *  - Seclore Desktop Client installed on this machine and user logged in.
 *  - For protect/protectshare/share: Desktop Client 3.12.0.0 (Seclore 3.14.4.0)+
 *  - For classify: Desktop Client 3.19.5.0 (Seclore 3.27.5.0)+
 *
 * SecloreActionDispatcher.exe is shipped with the Desktop Client and available on PATH.
 * If not on PATH, provide the absolute path to the exe.
 */
public class SecloreEndpointSDKInvoker {

    private static final String DISPATCHER = "SecloreActionDispatcher.exe";

    // -----------------------------------------------------------------------
    // Protect — Self type
    // -----------------------------------------------------------------------
    public static int protectSelf(String applicationName, String filePath,
                                   String classificationId) throws IOException, InterruptedException {
        List<String> cmd = new ArrayList<>(Arrays.asList(
            DISPATCHER,
            "-ActionId",        "protect",
            "-ApplicationName", applicationName,
            "-File",            filePath,
            "-Type",            "self",
            "-Classification",  classificationId
        ));
        return run(cmd);
    }

    // -----------------------------------------------------------------------
    // Protect — Policy type (single or multiple Policy IDs, comma-separated)
    // -----------------------------------------------------------------------
    public static int protectWithPolicy(String applicationName, String filePath,
                                         String policyIds, String classificationId)
            throws IOException, InterruptedException {
        List<String> cmd = new ArrayList<>(Arrays.asList(
            DISPATCHER,
            "-ActionId",        "protect",
            "-ApplicationName", applicationName,
            "-File",            filePath,
            "-Type",            "policy",
            "-ListId",          policyIds,      // e.g. "9" or "9,1"
            "-Classification",  classificationId
        ));
        return run(cmd);
    }

    // -----------------------------------------------------------------------
    // Protect with optional IncidentId and UserId (for DLP / system context)
    // -----------------------------------------------------------------------
    public static int protectWithIncident(String applicationName, String filePath,
                                           String policyIds, String classificationId,
                                           String incidentId, String userSid)
            throws IOException, InterruptedException {
        List<String> cmd = new ArrayList<>(Arrays.asList(
            DISPATCHER,
            "-ActionId",        "protect",
            "-ApplicationName", applicationName,
            "-File",            filePath,
            "-Type",            "policy",
            "-ListId",          policyIds,
            "-Classification",  classificationId
        ));
        if (incidentId != null && !incidentId.isEmpty()) {
            cmd.add("-IncidentId"); cmd.add(incidentId);
        }
        if (userSid != null && !userSid.isEmpty()) {
            cmd.add("-UserId"); cmd.add(userSid);
        }
        return run(cmd);
    }

    // -----------------------------------------------------------------------
    // Classify — classify only
    // -----------------------------------------------------------------------
    public static int classify(String applicationName, String filePath, String labelId)
            throws IOException, InterruptedException {
        List<String> cmd = new ArrayList<>(Arrays.asList(
            DISPATCHER,
            "-ActionId",        "classify",
            "-ApplicationName", applicationName,
            "-File",            filePath,
            "-LabelId",         labelId
        ));
        return run(cmd);
    }

    // -----------------------------------------------------------------------
    // Classify and protect (if a Seclore policy is mapped to the label)
    // -----------------------------------------------------------------------
    public static int classifyAndProtect(String applicationName, String filePath, String labelId)
            throws IOException, InterruptedException {
        List<String> cmd = new ArrayList<>(Arrays.asList(
            DISPATCHER,
            "-ActionId",           "classify",
            "-ApplicationName",    applicationName,
            "-File",               filePath,
            "-LabelId",            labelId,
            "-ApplyLabelPolicies", "true"
        ));
        return run(cmd);
    }

    // -----------------------------------------------------------------------
    // Classify / Reclassify (justification is mandatory when reclassifying)
    // -----------------------------------------------------------------------
    public static int reclassify(String applicationName, String filePath, String labelId,
                                  String justification)
            throws IOException, InterruptedException {
        List<String> cmd = new ArrayList<>(Arrays.asList(
            DISPATCHER,
            "-ActionId",        "classify",
            "-ApplicationName", applicationName,
            "-File",            filePath,
            "-LabelId",         labelId,
            "-Reclassify",      "true",
            "-Justification",   justification
        ));
        return run(cmd);
    }

    // -----------------------------------------------------------------------
    // Bulk classify — all files in a folder
    // -----------------------------------------------------------------------
    public static int bulkClassify(String applicationName, String folderPath, String labelId)
            throws IOException, InterruptedException {
        List<String> cmd = new ArrayList<>(Arrays.asList(
            DISPATCHER,
            "-ActionId",        "classify",
            "-ApplicationName", applicationName,
            "-Folder",          folderPath,
            "-LabelId",         labelId
        ));
        return run(cmd);
    }

    // -----------------------------------------------------------------------
    // Run command and return exit code
    // -----------------------------------------------------------------------
    private static int run(List<String> cmd) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.redirectErrorStream(true);
        Process process = pb.start();

        // Drain stdout/stderr to avoid blocking on full pipe buffer
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println("[EndpointSDK] " + line);
            }
        }

        int exitCode = process.waitFor();
        System.out.println("[EndpointSDK] Exit code: " + exitCode + " | Command: " + cmd);
        return exitCode;
    }

    // -----------------------------------------------------------------------
    // Example usage
    // -----------------------------------------------------------------------
    public static void main(String[] args) throws Exception {
        String appName = "MyDLPApp";

        // 1. Self protect
        int rc = protectSelf(appName, "C:\\testdata\\file1.txt", "1");
        System.out.println("Self protect exit code: " + rc);

        // 2. Policy protect with incident ID
        rc = protectWithIncident(appName, "C:\\testdata\\file2.txt", "9", "1",
                                 "DLP-INCIDENT-20240610", null);
        System.out.println("Policy protect exit code: " + rc);

        // 3. Classify and protect
        rc = classifyAndProtect(appName, "C:\\testdata\\report.docx", "10001");
        System.out.println("Classify and protect exit code: " + rc);

        // 4. Bulk classify a folder
        rc = bulkClassify(appName, "C:\\testdata\\reports", "10001");
        System.out.println("Bulk classify exit code: " + rc);
    }
}
```

**Notes:**
- `SecloreActionDispatcher.exe` dispatches the action asynchronously — a zero exit code means
  the action was successfully queued, not that the file has been protected yet. Monitor the
  `ActionExecutor.exe` logs at `C:\ProgramData\Seclore\FileSecure\Desktop Client\Logs` for
  execution results.
- When running in system context (Windows Service, SCCM task), always pass `-UserId` with
  the Windows SID of the target user. Without it, the action dispatches to the last logged-in
  user's queue, which may not be the intended target.
- All parameters are case-sensitive in `SecloreActionDispatcher.exe`.
- For bulk operations, `ProcessBuilder` blocks until `SecloreActionDispatcher.exe` has finished
  queuing the action. Actual file protection/classification happens asynchronously.

---

## Code Sample: Admin Operations — Create/Update EA, Hot Folder, Policy (sendRequest)

These samples cover ten `sendRequest`-based admin operations: Create/Update Enterprise
Application (types 44/47), Update Enterprise Application Passphrase (type 48), Create/Update
Hot Folder (types 49/50), Create/Update Policy — "credential" on the wire — (types 22/24),
List Policies by Owner (type 20, read-only), Get Policy Details (type 21, read-only), and
Map/Unmap Entities to a Policy (type 25). They
follow the call pattern confirmed against Seclore's own Server SDK sample console apps
("Create EA" and "Create Hot Folder" reference projects) and, for the Policy/Hot-Folder
group, against a real verified-working customer deployment — `FSHelper.sendRequest(sessionId, RequestType, requestXML)` with the request body
built as a raw XML string, escaping every field value with an XML-escape helper.

**Real-world workflow order, confirmed by that customer deployment:** Create Policy (22) →
Map Entities to Policy (25) → Create/Update Hot Folder using that Policy (49/50) → Update
Policy (24, via the fetch-then-edit pattern below using type 21). Skipping the type-25
mapping step before attaching a Policy to a Hot Folder fails with: "Unable to create the
Hot Folder '...' as some Policies are not mapped to the Owner." Using the security-admin/
root (Super User) account as a Policy owner fails with: "Super User can not define a
Custom Policy."

Field sets below reflect the request/response XML structures documented in the sendRequest
reference tables (see `sdk-guide.md` Section 9). Where the real sample code and the protocol
docs disagreed (Hot Folder `state` and `protection-details`), the code below follows the
verified working sample.

### Shared helper — XML escaping and response parsing

```java
import com.seclore.fs.helper.library.FSHelper;
import com.seclore.fs.helper.library.FSHelperLibrary;
import com.seclore.fs.ws.client.core.RequestType;
import org.w3c.dom.Node;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.DocumentBuilder;
import org.xml.sax.InputSource;
import java.io.StringReader;

public class SecloreAdminOpsUtil {

    /** Minimal XML escaping for values dropped into a hand-built request string. */
    public static String esc(String value) {
        if (value == null) return "";
        return value.replace("&", "&amp;")
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace("\"", "&quot;")
                    .replace("'", "&apos;");
    }

    /** request-header used by sendRequest calls in this section. */
    public static String requestHeader() {
        return "<request-header/>";
    }

    /** Parses <request-status><return-value> and throws with the display-message on failure. */
    public static Node parseAndCheckStatus(String responseXML, String rootChildName) throws Exception {
        DocumentBuilderFactory bf = DocumentBuilderFactory.newInstance();
        bf.setNamespaceAware(false);
        DocumentBuilder builder = bf.newDocumentBuilder();
        Node root = builder.parse(new InputSource(new StringReader(responseXML))).getDocumentElement();

        Node statusNode = findChild(root, "request-status");
        String returnValue = textOf(findChild(statusNode, "return-value"));
        if (!"1".equals(returnValue)) {
            String displayMessage = textOf(findChild(statusNode, "display-message"));
            String errorMessage = textOf(findChild(statusNode, "error-message"));
            throw new Exception((displayMessage != null && !displayMessage.trim().isEmpty()
                    ? displayMessage : errorMessage) + " (" + returnValue + ")");
        }
        return rootChildName == null ? null : findChild(root, rootChildName);
    }

    private static Node findChild(Node parent, String name) {
        if (parent == null) return null;
        org.w3c.dom.NodeList children = parent.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            Node n = children.item(i);
            if (name.equals(n.getNodeName())) return n;
        }
        return null;
    }

    private static String textOf(Node n) {
        return n == null ? null : n.getTextContent();
    }
}
```

### Create Enterprise Application (type 44 — `RT_ADD_ENTERPRISE_APPLICATION`)

```java
public class SecloreCreateEA {

    public static String createEA(FSHelper helper, String psId, String name, String description,
                                   String type, String machineId, String machineHostName,
                                   String passphrase) throws Exception {

        String requestDetails =
            "<request-details>" +
            "  <ps-id>" + SecloreAdminOpsUtil.esc(psId) + "</ps-id>" +
            "  <file-server>" +
            "    <name>" + SecloreAdminOpsUtil.esc(name) + "</name>" +
            "    <description>" + SecloreAdminOpsUtil.esc(description) + "</description>" +
            "    <type>" + SecloreAdminOpsUtil.esc(type) + "</type>" +              // ALWAYS use 3 (Custom EA). 1=Server EA/2=Desktop EA are physical EAs, not creatable via SDK — caller should hardcode "3", not pass it as a parameter
            "    <machine-id>" + SecloreAdminOpsUtil.esc(machineId) + "</machine-id>" +
            "    <machine-host-name>" + SecloreAdminOpsUtil.esc(machineHostName) + "</machine-host-name>" +
            "    <passphrase>" + SecloreAdminOpsUtil.esc(passphrase) + "</passphrase>" +
            "  </file-server>" +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";

        String responseXML = helper.sendRequest(null, RequestType.RT_ADD_ENTERPRISE_APPLICATION, requestXML);

        Node fileServerNode = SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, "file-server");
        // fileServerNode now holds <id>, <name>, etc. for the newly created EA
        return fileServerNode.getFirstChild() != null ? responseXML : responseXML;
    }
}
```

**Notes:**
- `description` is sent by the working sample even though the protocol doc lists it as
  optional on create — safe to always send it.
- `machine-id` / `machine-host-name` are typically read from a config file in real deployments
  (they identify the host the EA's keys are bound to), not user input — shown here as plain
  parameters for clarity.
- `ar-adaptor-details` (Policy Federation adapter config) is omitted — only needed if
  configuring Policy Federation at EA-creation time. See `policy-federation-api.md`.

### Update Enterprise Application (type 47 — `RT_UPDATE_ENTERPRISE_APPLICATION`)

```java
public class SecloreUpdateEA {

    // eaType/araType/araBaseUrl/araAuthScheme may all be passed as null to omit Policy
    // Federation handling entirely (plain name/description update). If you want to add,
    // change, or keep Policy Federation (ARA) config on this EA, eaType is REQUIRED — see
    // notes below. araUsername/araPassword are only needed when araAuthScheme="1" (Basic
    // Auth) — pass null for araAuthScheme="0" (no auth).
    public static String updateEA(FSHelper helper, String psId, String eaId, String name,
                                   String description, String lmTime,
                                   String eaType, String araType, String araBaseUrl,
                                   String araAuthScheme, String araUsername, String araPassword) throws Exception {

        String authParams = "0".equals(araAuthScheme) ? "" :
            "          <param><name>ARAdaptorUsername</name><value>" + SecloreAdminOpsUtil.esc(araUsername) + "</value></param>" +
            "          <param><name>ARAdaptorPassword</name><value>" + SecloreAdminOpsUtil.esc(araPassword) + "</value></param>";

        String arAdaptorDetails = araType == null ? "" :
            "    <ar-adaptor-details>" +
            "      <type>" + SecloreAdminOpsUtil.esc(araType) + "</type>" +   // 0=None, 1=Partial, 2=Full Policy Federation (always use 2 — Partial is not actively used)
            "      <ar-adaptor-specific-details>" +
            "        <params>" +
            "          <param><name>ARAdaptorBaseURL</name><value>" + SecloreAdminOpsUtil.esc(araBaseUrl) + "</value></param>" +
            "          <param><name>ARAdaptorAuthScheme</name><value>" + SecloreAdminOpsUtil.esc(araAuthScheme) + "</value></param>" +
            authParams +
            "        </params>" +
            "      </ar-adaptor-specific-details>" +
            "    </ar-adaptor-details>";

        String requestDetails =
            "<request-details>" +
            "  <ps-id>" + SecloreAdminOpsUtil.esc(psId) + "</ps-id>" +
            "  <file-server>" +
            "    <id>" + SecloreAdminOpsUtil.esc(eaId) + "</id>" +
            "    <name>" + SecloreAdminOpsUtil.esc(name) + "</name>" +
            "    <description>" + SecloreAdminOpsUtil.esc(description) + "</description>" +
            "    <lm-time>" + SecloreAdminOpsUtil.esc(lmTime) + "</lm-time>" +   // concurrency check
            (eaType != null ? "    <type>" + SecloreAdminOpsUtil.esc(eaType) + "</type>" : "") +
            arAdaptorDetails +
            "  </file-server>" +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        String responseXML = helper.sendRequest(null, RequestType.RT_UPDATE_ENTERPRISE_APPLICATION, requestXML);
        SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, "file-server");
        return responseXML;
    }
}
```

**Notes:**
- **Requires an Advanced Security (elevated) session.** Calling this with a plain/basic
  login (no `DefaultCryptoHandler`) is rejected outright with `-220656 "Elevated session is
  needed for this operation."`, regardless of which EA is calling or which EA is the target.
  Any integration that needs to update EAs must log in with the Advanced Security crypto
  handler.
- **Policy Federation cannot be disabled once enabled.** Sending `ar-adaptor-details` with
  `<type>0</type>` to an EA that already has Full Federation (`2`) configured is rejected
  regardless of payload shape: leftover `ARAdaptorBaseURL`/auth params alongside `type=0`
  gets `-220429 "No configuration found for Access Right Adaptor type : 0"`; a fully empty
  `<params></params>` block gets `-210001 "Missing parameter 'type'."` instead. This matches
  the Policy Server admin console, where the "Access Right Adaptor type" dropdown is greyed
  out and stuck on its current value once Policy Federation has been turned on for an EA.
  Treat Policy Federation as a one-way switch: plan EA configuration with this in mind, since
  there's no supported path (API or console) to turn it back off once enabled.
- `lm-time` must be the exact value last returned by the Policy Server for this EA — stale
  values are rejected as a concurrency conflict (`-220641`). Fetch current details first
  (Type 45) if you don't already have it cached.
- `description` is NOT mandatory but is full-overwrite: omitting it blanks the existing
  value rather than preserving it. Always fetch current details first and resend every
  field you don't want cleared.
- `machine-id`, `machine-host-name`, and `passphrase` are not updatable via this request.
  Passphrase rotation uses a separate request type (48 — see below).
- `type` (the EA's own type — 1=Server, 2=Desktop, 3=Custom) is updatable. Policy Federation
  (`ar-adaptor-details`) can also be added or changed via this Update request, not just at
  create time — but only if `type` is included in the SAME request. Omitting `type` while
  sending `ar-adaptor-details` fails with `-220435` ("Access Right Adaptor cannot be
  configured for Enterprise Application type : -1") because the server can't resolve the
  EA's type for the ARA-eligibility check. Fetch the EA's real type via Type 45 if you don't
  already know it, and always send it alongside `ar-adaptor-details`. This works both for
  enabling ARA on an EA that didn't have it and for changing the `ARAdaptorBaseURL` on an EA
  that already did.
- The `ar-adaptor-specific-details` params use these literal keys (the protocol doc only
  specifies the generic `param/name/value` wrapper, not these names): `ARAdaptorBaseURL`,
  `ARAdaptorAuthScheme`, `ARAdaptorUsername`, `ARAdaptorPassword`. `ARAdaptorAuthScheme=0`
  (no auth) works standalone with no extra params. `ARAdaptorAuthScheme=1` (Basic Auth)
  additionally requires `ARAdaptorUsername` and `ARAdaptorPassword` — omitting the username
  fails with `-2500034 "Basic Authentication user name is missing."`, a fixed/generic message
  that (unlike `-220439`) never names the literal field.
- Whatever you send as the ARA's `<name>` is not echoed back — the server returns a label
  derived from `type` instead (e.g. type=2 → `Full Federation`). Don't rely on it
  round-tripping.

### Update Enterprise Application Passphrase (type 48)

```java
public class SecloreUpdateEAPassphrase {

    // oldPassphrase can be passed as null regardless of reset value — it is not enforced
    // for any EA holding the create/update-other-EA privilege (see notes below). Send it
    // when available anyway since the field is part of the documented contract, but don't
    // rely on it for access control.
    public static String updateEAPassphrase(FSHelper helper, String psId, String eaId,
                                             String newPassphrase, String lmTime,
                                             String reset, String oldPassphrase) throws Exception {

        String requestDetails =
            "<request-details>" +
            "  <ps-id>" + SecloreAdminOpsUtil.esc(psId) + "</ps-id>" +
            "  <file-server>" +
            "    <id>" + SecloreAdminOpsUtil.esc(eaId) + "</id>" +
            "    <passphrase>" + SecloreAdminOpsUtil.esc(newPassphrase) + "</passphrase>" +
            "    <lm-time>" + SecloreAdminOpsUtil.esc(lmTime) + "</lm-time>" +   // concurrency check
            "  </file-server>" +
            "  <reset>" + SecloreAdminOpsUtil.esc(reset) + "</reset>" +
            (oldPassphrase != null ? "  <old-passphrase>" + SecloreAdminOpsUtil.esc(oldPassphrase) + "</old-passphrase>" : "") +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        // Request type 48. This jar's RequestType enum constant for it has not been
        // independently confirmed the way RT_UPDATE_ENTERPRISE_APPLICATION (47) was — pass
        // the literal int 48 if no named constant resolves at compile time.
        String responseXML = helper.sendRequest(null, 48, requestXML);
        SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, "file-server");
        return responseXML;
    }
}
```

**Notes:**
- Unlike Update EA (47), this is **not** a full-overwrite request — only `id`, `passphrase`,
  and `lm-time` inside `file-server` are read; sending other shared-structure fields (name,
  description, etc.) has no effect. Confirmed live: sending a different `name` value
  alongside a valid `id`/`passphrase`/`lm-time` still returns success, but the EA's actual
  name is left completely unchanged — the extra field is silently dropped, not applied and
  not rejected.
- **The real access control here is caller privilege, not `old-passphrase`/`reset`.** Only an
  EA holding the Advanced Privilege to create/update other EAs
  (`app-privileges.manage-other-apps`, configured via Type 100) can call this against another
  EA's id. A caller without that privilege — including a plain/basic login with no Advanced
  Security configured at all — is rejected outright with `-220133 "User is not authenticated
  with the Enterprise Application '<id>'."`, before `old-passphrase` or `reset` is ever
  evaluated. A caller that DOES have Advanced Security configured but sends
  `allow-advanced-privileges=false` gets a different rejection instead:
  `-220656 "Elevated session is needed for this operation."` Only Advanced Security +
  `allow-advanced-privileges=true` + the privilege itself succeeds — same requirement applies
  to Get EA Details (type 45) when targeting another EA's id.
- `old-passphrase` is not enforced for any EA holding that privilege: omitting it succeeds
  under both `reset="0"` and `reset="1"`, even though the documented framing of `reset`
  describes it as the switch controlling whether `old-passphrase` is required. Caller
  privilege is the only access control on this request — don't design access control
  around `old-passphrase`.
- Sending `newPassphrase` identical to the EA's current passphrase succeeds — there is no
  "new passphrase cannot equal old passphrase" enforcement in practice, despite the
  documentation stating otherwise.
- `lm-time` and `passphrase` are both genuinely mandatory — omitting either fails with
  `-240003 "Missing parameter '<field>'."` The new passphrase is never echoed back in the
  response, same as Update EA.

### Configure Advanced Security (type 100)

```java
public class SecloreConfigureAdvSecurity {

    // Use action-mode "1" to add or replace the EA's RSA public key (Configure), or "2"
    // to disable Advanced Security on the EA. pubKeyX509Der and keyLength are only required
    // for action-mode "1" — pass null for both when disabling.
    //
    // clid must always be the literal fixed string "com.seclore.fs.ws" — it is a protocol
    // constant, not a caller-chosen identifier. Any other value fails with -220655.
    //
    // keyId is server-assigned regardless of what the caller sends. Omitting it (null) is
    // safe and preferred; the server generates its own UUID either way. Read the
    // server-assigned value back from the response — that UUID is the Active Key ID to
    // supply to DefaultCryptoHandler at SDK initialization time.
    //
    // lmTime must be the value returned by the most recent successful call on this EA
    // (fetch via Type 45 before calling). A stale value is rejected as a concurrency
    // conflict (-220641).
    public static String configure(FSHelper helper, String psId, String eaId, String lmTime,
                                   String actionMode, String clid, String keyId, String appId,
                                   String pubKeyX509Der, String keyLength) throws Exception {

        String appKeyBlock = "";
        if (!"2".equals(actionMode)) {
            // action-mode=1 (Configure) — build the app-key block
            String keyIdElem = keyId != null
                ? "<key-id>" + SecloreAdminOpsUtil.esc(keyId) + "</key-id>"
                : "";   // omit entirely; server assigns its own UUID
            String appIdElem = appId != null
                ? "<app-id>" + SecloreAdminOpsUtil.esc(appId) + "</app-id>"
                : "";

            appKeyBlock =
                "<app-key>" +
                "  <client-key-meta>" +
                "    <clid>" + SecloreAdminOpsUtil.esc(clid) + "</clid>" +   // must be "com.seclore.fs.ws"
                keyIdElem +
                appIdElem +
                "  </client-key-meta>" +
                "  <pki-key-pair>" +
                "    <pub-key>" +
                "      <key><X509><ver>1</ver><data>" + SecloreAdminOpsUtil.esc(pubKeyX509Der) + "</data></X509></key>" +
                "      <algo>5</algo>" +                           // 5 = RSA
                "      <key-length>" + SecloreAdminOpsUtil.esc(keyLength) + "</key-length>" +   // always "256"
                "      <padding>PKCS1Padding</padding>" +
                "      <chaining-mode>ECB</chaining-mode>" +
                "    </pub-key>" +
                "  </pki-key-pair>" +
                "</app-key>";
        }

        String requestDetails =
            "<request-details>" +
            "  <ps-id>" + SecloreAdminOpsUtil.esc(psId) + "</ps-id>" +
            "  <file-server>" +
            "    <id>" + SecloreAdminOpsUtil.esc(eaId) + "</id>" +
            "    <lm-time>" + SecloreAdminOpsUtil.esc(lmTime) + "</lm-time>" +
            appKeyBlock +
            "  </file-server>" +
            "  <action-mode>" + SecloreAdminOpsUtil.esc(actionMode) + "</action-mode>" +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        // No named RequestType constant confirmed for type 100 — pass the literal integer.
        String responseXML = helper.sendRequest(null, 100, requestXML);
        SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, "file-server");
        return responseXML;
    }
}
```

**Notes:**
- **`clid` must be the literal fixed string `"com.seclore.fs.ws"`.** This is a protocol
  constant — the SDK's own Java package namespace used as a client identifier. Any other
  value fails with `-220655 "Client not supported for this operation."` Omitting `clid`
  entirely causes a server-side null-pointer crash (`-240011`) rather than a clean
  validation error, because the Policy Server calls `.equals()` on the (null) result of
  `getCLId()` without a null-check.
- **`key-id` is server-assigned, not caller-controlled.** Whatever value the caller sends
  (including well-formed UUIDs) is ignored — Policy Server always generates its own UUID
  and returns it in the response. Omitting `key-id` entirely is safe; the server generates
  a value regardless. Read the server-assigned `key-id` from the response's
  `app-key/client-key-meta/key-id` — that is the **Active Key ID** to pass to
  `DefaultCryptoHandler`'s constructor at SDK initialization time.
- **`key-length` is always `"256"` for this request.** This is the SDK's internal key-length
  parameter (matching `DefaultCryptoHandler`'s constructor), not the RSA modulus bit size.
  The policy server portal uses 256 for 2048-bit RSA keys; always send 256 regardless of
  actual key modulus size.
- **Policy Server does not verify key possession at Configure time.** The server accepts and
  stores any syntactically valid Base64 X.509 `pub-key-data` without verifying that the
  caller holds the matching private key. A mismatch will not surface until the first
  authenticated call fails its crypto challenge. Keeping the public/private pair correctly
  matched is entirely the caller's responsibility.
- **`action-mode=2` (Disable) is not idempotent.** Calling Disable on an EA that already
  has Advanced Security disabled fails with `-220616 "FileServer '<id>' is not advanced
  security enabled."` — it does not succeed silently. Check the EA's current Advanced
  Security state via Type 45 before calling Disable if there is any doubt.
- **Response includes `signing-algo` in the pub-key block** (`<signing-algo>SHA256withRSA</signing-algo>`)
  that is not present in the request and not documented in the protocol spec. It is returned
  after `chaining-mode` in the response pub-key. The public key data itself (`X509/data`) is
  NOT echoed back in the response — only the key metadata is returned.
- **`lm-time` is an optimistic-lock check.** Fetch the current value via Type 45 before
  calling. A stale value is rejected with `-220641`. The response's `file-server/lm-time`
  is the new value to use for the next call.
- **`ps-id` format:** the full admin-console label `"<Display Name> (<hex-id>)"` is
  required — same as all other admin-ops request types. Sending the hex-id alone or an
  empty value fails with `-200023 "Invalid Policy Server identifier '<value>'."`.

### Create Hot Folder (type 49 — `RT_CREATE_HOT_FOLDER`)

```java
public class SecloreCreateHotFolder {

    public static String createHotFolder(FSHelper helper, String psId, String name, String description,
                                          String location, String classificationId,
                                          String ownerRepCode, String ownerId, String eaId,
                                          String policyIdToAttach) throws Exception {

        // VERIFIED-BY-SAMPLE: <state>1</state> is sent explicitly on create (Monitoring), even
        // though older protocol docs list it as server-only. <parent-id> and <exts> are omitted
        // entirely for a top-level HF with process-all-supported=1.
        //
        // DISCREPANCY BETWEEN TWO VERIFIED-WORKING SAMPLES: the customer-thread sample
        // ("Create HF (With Policy).xml") instead sends <state>-1</state> and an explicit
        // <parent-id>0</parent-id> for a top-level HF. Both samples are confirmed working,
        // and both samples' responses come back with <state>1</state> regardless of what
        // was sent — suggesting the server may ignore/normalize this field on create. Either
        // value (1 or -1 for state; omitted or 0 for parent-id) appears safe; 1/omitted is
        // used below as the more self-documenting choice. See 49-create-hot-folder.xml for
        // the full discussion. Not yet confirmed via live testing which form is "correct."
        //
        // VERIFIED-BY-SAMPLE (second sample, "Create HF (With Policy).xml", from a customer
        // thread): adds <adv-html-wrap-supported> on the hot-folder, <type>/<is-external> on the
        // owner entity, and an optional <file-credential-mappings> block to attach an existing
        // Policy at creation time. REQUIRED PRE-STEP: that Policy must already be mapped to the
        // owner entity via type 25 (see SecloreMapEntityToPolicy below) — skipping it fails with
        // "Unable to create the Hot Folder '...' as some Policies are not mapped to the Owner."
        // Also, ownerId cannot be the security-admin/root (Super User) account when a Policy is
        // involved — that fails with "Super User can not define a Custom Policy." Pass
        // policyIdToAttach == null to create the Hot Folder with no Policy attached.
        String fileCredentialMappings = policyIdToAttach == null ? "" :
            "      <file-credential-mappings>" +
            "        <file-credential-mapping>" +
            "          <credential><id>" + SecloreAdminOpsUtil.esc(policyIdToAttach) + "</id></credential>" +
            "          <granted-by><type>2</type></granted-by>" +    // 2 = HotFolder
            "          <action>1</action>" +                          // 1 = Add
            "        </file-credential-mapping>" +
            "      </file-credential-mappings>";

        String requestDetails =
            "<request-details>" +
            "  <ps-id>" + SecloreAdminOpsUtil.esc(psId) + "</ps-id>" +
            "  <hot-folder>" +
            "    <name>" + SecloreAdminOpsUtil.esc(name) + "</name>" +
            "    <description>" + SecloreAdminOpsUtil.esc(description) + "</description>" +
            "    <location>" + SecloreAdminOpsUtil.esc(location) + "</location>" +
            "    <adv-html-wrap-supported>0</adv-html-wrap-supported>" +
            "    <inherits>0</inherits>" +
            "    <state>1</state>" +
            "    <recursive>1</recursive>" +
            "    <type>1</type>" +                          // 1=Monitored, 2=Excluded
            "    <process-all-ext>0</process-all-ext>" +
            "    <process-wo-ext>0</process-wo-ext>" +
            "    <process-all-supported>1</process-all-supported>" +
            "    <protection-details>" +
            "      <classification>" +
            "        <id>" + SecloreAdminOpsUtil.esc(classificationId) + "</id>" +
            "      </classification>" +
            fileCredentialMappings +
            "      <owner>" +
            "        <entity>" +
            "          <type>1</type>" +                    // 1=User, 2=Group
            "          <rep-code>" + SecloreAdminOpsUtil.esc(ownerRepCode) + "</rep-code>" +
            "          <id>" + SecloreAdminOpsUtil.esc(ownerId) + "</id>" +
            "          <is-external>0</is-external>" +       // 0=internal repo, 1=external repo
            "        </entity>" +
            "      </owner>" +
            "    </protection-details>" +
            "    <file-server>" +
            "      <id>" + SecloreAdminOpsUtil.esc(eaId) + "</id>" +
            "    </file-server>" +
            "  </hot-folder>" +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        String responseXML = helper.sendRequest(null, RequestType.RT_CREATE_HOT_FOLDER, requestXML);
        Node hfNode = SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, "hot-folder");
        return responseXML;
    }
}
```

**Notes:**
- No Advanced Security session is required, as long as you're creating the Hot Folder for
  the SAME EA you authenticated as (see the file-server bullet below).
- Confirmed mandatory (fail with `-240003 "Missing parameter '<field>'."` if omitted):
  `name`, `location`, `inherits`, `recursive`, `type`. `process-all-supported` is also
  effectively mandatory but fails differently — an omitted/falsy value is treated as "only
  specific extensions," which then requires `<exts>`; omitting both fails with `-220526`
  instead of `-240003`.
- Confirmed optional, with a server-side default when omitted: `description` (defaults to
  empty), `adv-html-wrap-supported`/`process-wo-ext`/`process-all-ext` (default to 0),
  `state` (always normalizes to 1/Monitoring on create regardless of what's sent or whether
  it's sent at all), `classification` (defaults to the tenant's `default-selected=1`
  classification — don't hardcode id `1` as a safe default, see the Create Hot Folder note
  above), `parent-id` (omitting it is equivalent to sending 0 for a top-level HF).
- Use `<exts><ext>EXTENSION</ext></exts>` (repeatable `<ext>`) only when
  `process-all-supported=0`; omit `<exts>` entirely when `process-all-supported=1`.
- To create a *child* Hot Folder under an existing parent, add `<parent-id>PARENT_HF_ID</parent-id>`
  inside `<hot-folder>`; for a top-level HF, omitting it is equivalent to sending 0 — confirmed
  live, the response comes back with `<parent-id>0</parent-id>` either way.
- `description` is optional, not mandatory — omitting it succeeds and the field comes back
  empty.
- `classification` is optional, not mandatory — omitting the whole block succeeds, and the
  server assigns whichever classification has `default-selected=1` for the tenant. Don't
  hardcode classification id `1` as a "safe" default — it maps to different labels per
  tenant (in one tested environment, id `1` was "Top Secret," not "Unclassified").
- `owner` is genuinely mandatory — omitting it fails with `-220156 "Could not create the
  HotFolder '...' as the owner is not provided."` `protector` (not shown in the sample above)
  defaults to the same entity as `owner` when omitted.
- `location` is genuinely mandatory — omitting it fails with `-240003 "Missing parameter
  'location'."` The value isn't validated against a real filesystem path; any string works.
- `file-server > id` is the Enterprise Application this Hot Folder belongs to — and it must
  be the SAME EA you authenticated as. Creating a Hot Folder for a different EA fails with
  `-220133`, even with a full elevated session holding the manage-other-apps privilege (the
  same privilege that DOES allow cross-EA calls on type 48) — this is a structural
  restriction, not a missing privilege.
- An `extn-reference` block (`extn-ref-id`/`extn-ref-name`/`extn-ref-data`/`extn-app-id`,
  matching the Policy Server UI's "External Reference" section) can be sent at creation time
  too, not just on update (type 50) — confirmed live, echoed back unchanged in the response.
- To change `state` (Monitoring/Paused/Deleted) after creation, use type 51
  (`RT_CHANGE_HOT_FOLDER_STATE`), not type 50 (update).
- `file-credential-mappings` is repeatable — one `<file-credential-mapping>` per Policy
  being attached at creation time. Each Policy referenced must already be mapped to the
  owner entity via type 25 first.

### Update Hot Folder (type 50 — `RT_UPDATE_HOT_FOLDER`)

```java
public class SecloreUpdateHotFolder {

    // ownerRepCode/ownerId: pass these (non-null) whenever policyIdToAdd is used. Adding a
    // Policy without also including <owner> in the SAME request doesn't fail cleanly — it
    // crashes the server with an unhandled NPE (-240011). Safe to pass null for both when
    // policyIdToAdd is null (owner is optional otherwise and the existing owner is preserved).
    public static String updateHotFolder(FSHelper helper, String psId, String hfId, String lmTime,
                                          String name, String classificationId,
                                          String policyIdToAdd, String policyIdToDrop,
                                          String ownerRepCode, String ownerId) throws Exception {

        // VERIFIED-BY-SAMPLE ("Update HF (Add and Drop Policy).xml", from a customer
        // thread), confirmed end-to-end: adding a Policy needs only
        // <credential><id>+<action>1</action> (PLUS <owner> elsewhere in the request — see
        // the ownerRepCode/ownerId note above); dropping one needs <credential><id>+empty
        // <lm-time/></credential>, <granted-by><type>2</type></granted-by>, and
        // <action>2</action>. The Policy being added must already be mapped to this Hot
        // Folder's owner via type 25 first, or you'll get -220162 once <owner> is present
        // (or -240011 if it's missing — see above).
        StringBuilder mappings = new StringBuilder();
        if (policyIdToAdd != null || policyIdToDrop != null) {
            mappings.append("<file-credential-mappings>");
            if (policyIdToAdd != null) {
                mappings.append("<file-credential-mapping>")
                        .append("<credential><id>").append(SecloreAdminOpsUtil.esc(policyIdToAdd)).append("</id></credential>")
                        .append("<action>1</action>")                 // 1 = Add
                        .append("</file-credential-mapping>");
            }
            if (policyIdToDrop != null) {
                mappings.append("<file-credential-mapping>")
                        .append("<credential><id>").append(SecloreAdminOpsUtil.esc(policyIdToDrop)).append("</id><lm-time></lm-time></credential>")
                        .append("<granted-by><type>2</type></granted-by>")
                        .append("<action>2</action>")                 // 2 = Drop
                        .append("</file-credential-mapping>");
            }
            mappings.append("</file-credential-mappings>");
        }

        String requestDetails =
            "<request-details>" +
            "  <ps-id>" + SecloreAdminOpsUtil.esc(psId) + "</ps-id>" +
            "  <hot-folder>" +
            "    <id>" + SecloreAdminOpsUtil.esc(hfId) + "</id>" +
            "    <lm-time>" + SecloreAdminOpsUtil.esc(lmTime) + "</lm-time>" +
            "    <name>" + SecloreAdminOpsUtil.esc(name) + "</name>" +
            "    <inherits>0</inherits>" +
            "    <recursive>1</recursive>" +
            "    <process-all-ext>0</process-all-ext>" +
            "    <process-wo-ext>0</process-wo-ext>" +
            "    <process-all-supported>1</process-all-supported>" +
            "    <protection-details>" +
            "      <classification>" +
            "        <id>" + SecloreAdminOpsUtil.esc(classificationId) + "</id>" +
            "      </classification>" +
            mappings.toString() +
            (ownerRepCode != null && ownerId != null ?
                "      <owner><entity><type>1</type>" +
                "<rep-code>" + SecloreAdminOpsUtil.esc(ownerRepCode) + "</rep-code>" +
                "<id>" + SecloreAdminOpsUtil.esc(ownerId) + "</id>" +
                "<is-external>0</is-external></entity></owner>" : "") +
            "    </protection-details>" +
            "  </hot-folder>" +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        String responseXML = helper.sendRequest(null, RequestType.RT_UPDATE_HOT_FOLDER, requestXML);
        SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, "hot-folder");
        return responseXML;
    }
}
```

**Notes:**
- No Advanced Security session is required.
- `parent-id`, `location`, `type`, and `state` are not updatable via this request.
- Confirmed mandatory (`-240003 "Missing parameter '<field>'."` if omitted): `lm-time`,
  `name`, `inherits`, `recursive`. `process-all-supported` is also mandatory but fails
  differently — an omitted/falsy value requires `<exts>`, so omitting both gives `-220525`
  instead of the generic `-240003` (same behavior as create). `process-wo-ext` and
  `process-all-ext` are optional, defaulting to 0.
- The `<protection-details>` block itself is mandatory — omitting it entirely fails with
  `-200016 "Mandatory parameter 'protection-details' is not specified."`
- Unlike Create Hot Folder, `classification` inside `protection-details` IS mandatory on
  update (`-210001 "Missing parameter 'classification'."` if omitted) — don't assume the two
  requests share the same optional/mandatory rules for this field.
- Same `exts` rule as create: omit when `process-all-supported=1`.
- `owner` is optional in the general case — omitting it preserves the existing owner. **But
  when ADDING a Policy via `file-credential-mappings`, `owner` must also be included in the
  same request.** Omitting it in that specific combination doesn't produce a clean
  validation error — it crashes with an unhandled server-side NPE (`-240011`). Re-sending
  with `owner` included surfaces the correct, documented error instead (`-220162`, if the
  type-25 mapping pre-step hasn't been done). Confirmed end-to-end: with the owner mapped to
  the Policy via type 25 and `owner` included in the request, both adding and dropping a
  Policy succeed and are reflected in the response's `file-credential-mappings`.
- An optional `extn-reference` block (Policy Federation use case) can also be sent — omitted
  here for brevity; see the Create Hot Folder sample above for its shape.

### Create Policy (type 22 — `RT_ADD_CRED`) — wire tag is `<credential>`

Owner should be a Container (OU), not an individual user — see the note below the sample for
why a User owner is rejected regardless of privileges.

```java
public class SecloreCreatePolicy {

    // ownerRepCode/ownerContainerId/ownerContainerCode identify the Container (OU) that will
    // own this Policy — e.g. an "Internal Users" repository container. Do NOT pass an
    // individual user's id here; see the note below this sample.
    public static String createPolicy(FSHelper helper, String name, String description,
                                       String ownerRepCode, String ownerContainerId, String ownerContainerCode,
                                       String accessRightEntityRepCode, String accessRightUserId,
                                       String primaryAccessRight) throws Exception {

        String requestDetails =
            "<request-details>" +
            "  <credential>" +
            "    <name>" + SecloreAdminOpsUtil.esc(name) + "</name>" +
            "    <owner>" +
            "      <type>2</type>" +                       // 2=Container — see note below
            "      <container>" +
            "        <rep-code>" + SecloreAdminOpsUtil.esc(ownerRepCode) + "</rep-code>" +
            "        <id>" + SecloreAdminOpsUtil.esc(ownerContainerId) + "</id>" +
            "        <code>" + SecloreAdminOpsUtil.esc(ownerContainerCode) + "</code>" +
            "      </container>" +
            "    </owner>" +
            "    <description>" + SecloreAdminOpsUtil.esc(description) + "</description>" +
            "    <status>1</status>" +                      // 1=Active, 0=Inactive
            "    <default-applicable>0</default-applicable>" +
            "    <details>" +
            "      <access-rights>" +
            "        <access-right>" +
            "          <entity>" +
            "            <rep-code>" + SecloreAdminOpsUtil.esc(accessRightEntityRepCode) + "</rep-code>" +
            "            <id>" + SecloreAdminOpsUtil.esc(accessRightUserId) + "</id>" +
            "            <type>1</type>" +                  // 1=User, 2=Group
            "          </entity>" +
            "          <primary-access-right>" + SecloreAdminOpsUtil.esc(primaryAccessRight) + "</primary-access-right>" +
            "          <offline>0</offline>" +
            "          <redistribute>0</redistribute>" +
            "          <lock-to-first-machine>0</lock-to-first-machine>" +
            "        </access-right>" +
            "      </access-rights>" +
            "    </details>" +
            "  </credential>" +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        String responseXML = helper.sendRequest(null, RequestType.RT_ADD_CRED, requestXML);
        SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, "credential");
        return responseXML;
    }
}
```

**Notes:**
- "Policy" is this skill's term; the wire structure is named `<credential>` (older naming) —
  same thing.
- No Advanced Security session is required for this request — a plain/basic session works.
- `<details><access-rights>` is repeatable — one `<access-right>` block per user/group grant.
- Every field shown is mandatory except `id`, `locked`, `created-by`, `creation-time`, `lm-by`,
  `lm-time` (server-assigned). This includes `<offline>` inside each `<access-right>` —
  omitting it fails with `-240003 Missing parameter 'offline'.`, even though the source
  protocol documentation doesn't call it out as required. `<redistribute>` and
  `<lock-to-first-machine>` should be sent alongside it, as shown above.
- **Custom (User-owned) Policies cannot be created through this request, from any SDK/API
  session, regardless of that session's privilege level.** Setting `owner.type=1` to point at
  an individual user is rejected with `-220402 "Super User can not define custom credential"`
  (display message: `"Super User can not define a Custom Policy."`). This restriction is not
  about which specific user is named as owner — it reflects that Custom Policy creation is
  only permitted from a genuine Super User/administrator session logged into the Policy Server
  UI directly, not from any EA-authenticated SDK session. **For SDK-driven Policy creation,
  always set `owner.type=2` (Container/OU) as shown in the sample above.** This produces a
  Policy that the Policy Server admin UI lists as Type "Predefined" (owned by the container),
  and it works from any authorized EA session, including a plain one with no Advanced Security
  at all.
- Creating the Policy here is not enough to use it in a Hot Folder — you must also call type 25
  (`SecloreMapEntityToPolicy` below) to map the Hot Folder's owner entity to this Policy, or
  Hot Folder creation/update fails with "Unable to create the Hot Folder '...' as some
  Policies are not mapped to the Owner."

### List Policies by Owner (type 20 — `RT_GET_CREDS`, read-only)

```java
public class SecloreListPoliciesByUser {

    /**
     * Workaround for "there's no lookup-Policy-by-name request" — per the customer thread:
     * "getting policy by its name is not possible as the name can be duplicate. ID will
     * always be unique." Lists all Policies owned by a given user/group; match by name
     * client-side, then call SecloreGetPolicyDetails for the full record.
     */
    public static String listPoliciesByUser(FSHelper helper, String entityRepCode, String entityId,
                                             String entityType) throws Exception {

        String requestDetails =
            "<request-details>" +
            "  <entity>" +
            "    <type>" + SecloreAdminOpsUtil.esc(entityType) + "</type>" +   // 1=User, 2=Group
            "    <rep-code>" + SecloreAdminOpsUtil.esc(entityRepCode) + "</rep-code>" +
            "    <id>" + SecloreAdminOpsUtil.esc(entityId) + "</id>" +
            "  </entity>" +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        String responseXML = helper.sendRequest(null, RequestType.RT_GET_CREDS, requestXML);
        SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, null);
        return responseXML;   // a list of <credential> entries, BASIC fields only (no access-rights)
    }
}
```

**Notes:**
- In practice, pass the security-admin/owner account ID that owns the Policies you're
  searching for, not an arbitrary end user.
- `entityId` must be a real, LDAP-resolvable SID/QID — resolve it via Search User (type 74)
  first, don't pass an email address or login id directly. An unresolvable value doesn't
  fail cleanly: the server crashes with an unhandled NPE, `-240011`
  (`FIMLDAPUser.getIsMemberOf()` on a null object), instead of a validation error. Treat any
  `-240011` here as "the id didn't resolve," not as a documented error condition.
- No Advanced Security session is required for this request — a plain/basic session works,
  same as Create Policy (type 22).
- The response can include Policies the queried entity does not literally own — alongside
  Policies where `owner` matches the queried entity directly, it can also return Policies
  owned by a Container the entity belongs to (e.g. a shared default owner used for built-in
  Policies). Don't assume every returned Policy is individually owned by the entity you
  queried.
- For the `type=2` (Group) path, supply a real, independently LDAP-resolvable Group SID —
  the same requirement Type 74 satisfies for User SIDs. This skill has no dedicated "search
  group" request; obtain a Group SID from your directory service or the Policy Server admin
  console directly.
- Returns BASIC fields only (id, name, owner, status, etc.) — no `<details>`/access-rights.
  Follow up with type 21 on a specific Policy ID for the full record.

### Get Policy Details (type 21 — `RT_GET_CRED_DETAILS`, read-only)

```java
public class SecloreGetPolicyDetails {

    /**
     * HARD PREREQUISITE for Update Policy (type 24) — per the Readme shipped with the
     * verified sample: always fetch the full record here first, copy it into the update
     * request, and edit only the access-rights. Never hand-build an update from scratch.
     */
    public static String getPolicyDetails(FSHelper helper, String policyId) throws Exception {

        String requestDetails =
            "<request-details>" +
            "  <credentials>" +
            "    <credential>" +
            "      <id>" + SecloreAdminOpsUtil.esc(policyId) + "</id>" +
            "    </credential>" +
            "  </credentials>" +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        String responseXML = helper.sendRequest(null, RequestType.RT_GET_CRED_DETAILS, requestXML);
        SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, null);
        return responseXML;   // <credentials><credential> with the FULL record incl. access-rights
    }
}
```

**Notes:**
- `<credentials><credential>` is repeatable — you can fetch multiple Policies in one call.
- The returned `<credential>` is the exact block to copy into `SecloreUpdatePolicy` below.

### Map/Unmap Entities to a Policy (type 25 — no named `RequestType` constant in this jar)

```java
public class SecloreMapEntityToPolicy {

    /**
     * VERIFIED-BY-SAMPLE ("Mapping Entities to Policy.xml", from a customer thread).
     * REQUIRED before attaching a Policy to a Hot Folder (see SecloreCreateHotFolder /
     * SecloreUpdateHotFolder above) — map the Hot Folder's intended owner entity to the
     * Policy here first. action: 1 = Map, 0 = Unmap.
     *
     * IMPORTANT: re-verified against this jar's compiled RequestType class — there is NO
     * named constant for 25 (unlike RT_ADD_CRED/RT_UPDATE_CRED for 22/24). Pass the literal
     * integer 25. Confirm against your own SDK version in case a newer build adds one.
     */
    public static String mapEntityToPolicy(FSHelper helper, String policyId, String entityRepCode,
                                            String entityId, String containerRepCode,
                                            String containerId, String containerCode,
                                            int action) throws Exception {

        String requestDetails =
            "<request-details>" +
            "  <credential-entity-mappings>" +
            "    <credential-entity-mapping>" +
            "      <credential><id>" + SecloreAdminOpsUtil.esc(policyId) + "</id></credential>" +
            "      <entity-actions>" +
            "        <entity-action>" +
            "          <entity>" +
            "            <type>1</type>" +                  // 1=User, 2=Group
            "            <rep-code>" + SecloreAdminOpsUtil.esc(entityRepCode) + "</rep-code>" +
            "            <id>" + SecloreAdminOpsUtil.esc(entityId) + "</id>" +
            "            <container>" +                      // optional — AD-sourced entities
            "              <rep-code>" + SecloreAdminOpsUtil.esc(containerRepCode) + "</rep-code>" +
            "              <id>" + SecloreAdminOpsUtil.esc(containerId) + "</id>" +
            "              <code>" + SecloreAdminOpsUtil.esc(containerCode) + "</code>" +
            "            </container>" +
            "          </entity>" +
            "          <action>" + action + "</action>" +     // 1 = Map, 0 = Unmap
            "        </entity-action>" +
            "      </entity-actions>" +
            "    </credential-entity-mapping>" +
            "  </credential-entity-mappings>" +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        String responseXML = helper.sendRequest(null, 25, requestXML);   // literal int — no named constant
        SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, null);
        return responseXML;   // empty success envelope on success, no echoed entity data
    }
}
```

**Notes:**
- No Advanced Security session is required for this request — a plain session works.
- `<entity-actions><entity-action>` is repeatable — map/unmap multiple entities to the same
  Policy in one call.
- `<container>` inside `<entity>` is optional, used for AD-sourced users/groups; omit it for
  plain internal users.
- The response on success is an empty status envelope — there's no echoed entity data to parse
  beyond `return-value`. Mapping and unmapping a real user were both confirmed independently
  in the Policy Server UI's "Policy Entity Mapping" screen.
- `<entity><id>` must be a real, LDAP-resolvable entity SID — the container/OU id used as a
  Policy's `<owner><container><id>` (from Create Policy, type 22) is NOT itself a mappable
  Group entity; sending it as `type=2` fails with `-300016 Could not get entity '...' from
  repository`. Use a real Group SID for the `type=2` path (untested so far — see
  `25-map-entities-to-policy.xml`).

### Update Policy (type 24 — `RT_UPDATE_CRED`) — full-record, fetch-then-edit

```java
public class SecloreUpdatePolicy {

    /**
     * VERIFIED-BY-SAMPLE ("Adding Entities or Updating Permissions of Existing Entities in
     * Policy.xml" + "Readme for Policy Update.txt", from a customer thread). The Readme's
     * own instructions: (1) call Get Policy Details (type 21) first, (2) copy the entire
     * returned <credential> block verbatim, (3) edit only access-rights — for an EXISTING
     * entity, keep its <id>/<creation-time>/<lm-time> and just change the rights fields; for
     * a NEW entity, add a new <access-right> and explicitly omit <id>/<creation-time>/
     * <lm-time> (the server assigns those). Never hand-build this request from scratch.
     *
     * `existingCredentialXmlFromType21` is the raw <credential>...</credential> XML string
     * copied from SecloreGetPolicyDetails's response, with access-rights already edited by
     * the caller per the rules above.
     */
    public static String updatePolicy(FSHelper helper, String existingCredentialXmlFromType21) throws Exception {

        String requestDetails =
            "<request-details>" +
            existingCredentialXmlFromType21 +
            "</request-details>";

        String requestXML = "<request>" + SecloreAdminOpsUtil.requestHeader() + requestDetails + "</request>";
        String responseXML = helper.sendRequest(null, RequestType.RT_UPDATE_CRED, requestXML);
        SecloreAdminOpsUtil.parseAndCheckStatus(responseXML, "credential");
        return responseXML;
    }
}
```

**Notes:**
- No Advanced Security session is required for this request — a plain session works.
- `<status>` cannot be changed via this request, even when sent back as part of the full
  record. Sending a different `<status>` value still returns success (`return-value=1`), but
  the field is silently ignored — a follow-up type-21 fetch shows the original value
  unchanged. Changing a Policy's status is not possible via the SDK at all — type 23
  (`RT_UPDATE_CRED_STATUS`) was tried across a plain session, an Advanced-Security session
  with no Advanced Privileges, and an Advanced-Security session with Advanced Privileges
  enabled, and every attempt failed identically with `-220085 Insufficient privileges to
  perform the operation`. Use the Policy Server admin UI to activate/deactivate a Policy.
- `owner`, `status`, and `default-applicable` are optional on this request — they can be
  omitted from the resubmitted record entirely, and the existing values are preserved rather
  than reset or rejected. A minimal update only needs `id`, `name`, `lm-time`, and `details`.
  Including the full record (as the sample above does) is still the safer default, since it
  guarantees you don't accidentally omit something that turns out to matter for other field
  types, but it is not required for owner/status/default-applicable specifically.
- To drop an entity's access entirely, omit its `<access-right>` when copying the type-21
  response back in — confirmed: the entity's access-right disappears from the next type-21
  fetch.
- `primary-access-right` values may not be echoed back verbatim. Granting a higher-level
  right (e.g. Full Control) causes the server to normalize/expand the stored value to include
  every right it implies — don't assume the value you send is the value you'll read back on
  a subsequent type-21 fetch.

### Common considerations across all ten operations

- **`RequestType` constant names, verified directly from the SDK jar.** All named constants
  and their integer values above were confirmed by inspecting the compiled `RequestType` class
  inside `fs-ws-client.jar` (shipped with the sample code), not guessed from naming conventions.
  Notably, the Policy/credential operations are `RT_ADD_CRED` (22) and `RT_UPDATE_CRED` (24) —
  not `RT_ADD_CREDENTIAL`/`RT_UPDATE_CREDENTIAL` as the "Policy" naming might suggest. The same
  jar confirms `RT_GET_CREDS` = 20 and `RT_GET_CRED_DETAILS` = 21, but has **no named constant
  for type 25** (Map/Unmap Entities to Policy) — pass the literal integer 25 for that one, and
  confirm against your own SDK version in case a newer build adds a constant. This jar also
  confirms `RT_GET_PROTECTION_DETAILS` = 29 and `RT_GET_ACCESS_PERMISSION` = 31, matching this
  skill's existing Type 29/Type 31 documentation in this file.
- **Real-world Policy/Hot-Folder workflow order, confirmed by a live customer deployment.**
  Create Policy (22) → Map Entities to Policy (25) → Create/Update Hot Folder using that Policy
  (49/50) → Update Policy (24, fetch-then-edit via 21). Skipping the type-25 mapping step before
  attaching a Policy to a Hot Folder, or setting an individual User (rather than a Container)
  as the Policy owner, both produce specific, reproducible server errors documented in the
  Create Policy sample above.
- **`<ps-id>`** appears in `request-details` for EA and Hot Folder create/update. It is
  **mandatory**, and the required value is the full Policy Server admin-console label,
  `"<Display Name> (<hex-id>)"` — e.g.
  `"AWS Cloud PoC-50 PolicyServer (d6413e9316c611638cb48706ced92c4a0bc9ba60)"` — not the hex id
  alone (that fails with `-200023 Invalid Policy Server identifier '<hex-id>'.`) and not an
  empty value (fails with `-200023 ... 'null'.`). Confirmed via live testing for Create EA
  (type 44) and Create/Update Hot Folder (types 49/50); the same full-label format is expected
  for Update EA (type 47) too, following the same shared structure.
- **`<request-header/>`** is sent empty/self-closing in this skill's existing sendRequest
  examples (types 29/31). The "Create EA"/"Create Hot Folder" Server SDK samples instead send
  `<request-header><protocol-version>2</protocol-version></request-header>` — that sample uses
  an older SDK build; this discrepancy in the header's `protocol-version` convention has not
  been reconciled against the current SDK and is not reflected in the code above. If your
  SDK version requires a `protocol-version` value, add it back into `requestHeader()`.
- **Response parsing.** Every response follows the same `<response><request-status><return-value>`
  envelope shown in `parseAndCheckStatus()` above — `return-value` of `"1"` means success;
  anything else, surface `display-message` (fall back to `error-message`).
- **Concurrency (`lm-time`).** All four *update* operations require the caller to echo back the
  exact `lm-time` last returned by the server for that object. Fetch current details first if
  you don't already have it cached, or the update will be rejected as a stale write.
