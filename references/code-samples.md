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
<search-user>
  <email>user@example.com</email>
</search-user>
```

Returns `String[] { id, repCode, type }` on success, or `-220372` if not found.

---

### sendRequest XML — Create IM User (type 109)

```xml
<create-user>
  <email>user@example.com</email>
  <first-name>FirstName</first-name>
  <last-name>User</last-name>
</create-user>
```

Returns `String[] { id, repCode, "1" }`.

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

        // Look up owner (sendRequest type 74)
        // Returns String[] { id, repCode, type } on success, or integer -220372 if not found
        String[] ownerEntity     = resolveUser(tenantObj, ownerEmail);
        String[] recipientEntity = resolveUser(tenantObj, recipientEmail);

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

    // Helper: look up a user in Policy Server, auto-create if not found
    // sendRequest type 74 = search user; type 109 = create IM user
    private static String[] resolveUser(FSHelper tenantObj, String email) throws Exception {
        String searchXML =
            "<search-user>" +
            "  <email>" + email + "</email>" +
            "</search-user>";

        Object searchResult = tenantObj.sendRequest(null, 74, searchXML);
        if (searchResult instanceof String[]) {
            return (String[]) searchResult;  // [id, repCode, type]
        }
        // -220372 = user not found; create the user
        String createXML =
            "<create-user>" +
            "  <email>" + email + "</email>" +
            "  <first-name>" + email.split("@")[0] + "</first-name>" +
            "  <last-name>User</last-name>" +
            "</create-user>";
        return (String[]) tenantObj.sendRequest(null, 109, createXML);  // [id, repCode, "1"]
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
        // Use isProtectedFile(), NOT isHT


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
