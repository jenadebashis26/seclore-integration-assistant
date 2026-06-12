# Seclore Endpoint SDK Integration Guide

## 1. Overview

The Seclore Endpoint SDK is a lightweight command-line tool shipped as part of the Seclore Desktop Client (both Admin and Adminless variants). It allows endpoint applications — DLP tools, data classification systems, data discovery/monitoring applications — to trigger Seclore file protection and classification actions without integrating the Seclore Java Server SDK or any other library.

**Two executables work together:**

| Executable | Role |
|------------|------|
| `SecloreActionDispatcher.exe` (Windows) / `SecloreActionDispatcher` (Mac) | Receives the action request from the integrating application and pushes it to the queue |
| `ActionExecutor.exe` (Windows only) | Picks actions from the queue and calls Seclore Desktop Client APIs to execute them |

**Technical workflow:**
```
Integrating Application
  → SecloreActionDispatcher.exe (queues the action)
    → Queue Manager
      → ActionExecutor.exe (executes via Desktop Client APIs)
        → Seclore Desktop Client
          → Policy Server
```

**Supported actions:**

| Action | Windows | Mac |
|--------|---------|-----|
| `protect` | ✓ | ✓ |
| `protectshare` | ✓ | ✗ |
| `share` | ✓ | ✗ |
| `classify` | ✓ | ✗ |

---

## 2. Prerequisites

### Windows
| Action type | Required Desktop Client version |
|-------------|--------------------------------|
| `protect`, `protectshare`, `share` | 3.12.0.0 (Seclore 3.14.4.0) or above |
| `classify` | 3.19.5.0 (Seclore 3.27.5.0) or above |

- The logged-in Seclore Desktop Client user must have a Seclore License.
- `SecloreActionDispatcher.exe` ships with the Desktop Client and can be invoked directly by name — no additional installation required.

### Mac
- Seclore Lite for Mac 3.4.2.0 (Seclore 3.12.0.0) or above.
- Only the `protect` action is supported on Mac.

---

## 3. Parameters

All parameters are case-sensitive. Parameters can be passed as individual switches or as a JSON string via `-ActionParams`.

| Switch | Value | Mandatory/Optional |
|--------|-------|-------------------|
| `-ActionId` | `protect` / `protectshare` / `share` / `classify` | Mandatory |
| `-ApplicationName` | Name of the integrating application (used for activity logging) | Mandatory |
| `-file` | Absolute path to the file | Mandatory (either `-file` or `-folder`) |
| `-folder` | Absolute path to the folder (bulk actions) | Mandatory (either `-file` or `-folder`) |
| `-type` | `self` or `policy` | Mandatory for `protect` and `protectshare` |
| `-listId` | Policy ID(s) on Policy Server. Comma-separated for multiple. Required when `-type` is `policy` | Conditional |
| `-classification` | Seclore Classification ID (legacy; required with protect/protectshare/share) | Mandatory for protect/protectshare/share |
| `-LabelId` | Classification label ID in Policy Server | Mandatory for `classify` |
| `-IncidentId` | Correlation ID for troubleshooting. If not passed, a random number is generated | Optional |
| `-UserId` | Windows SID of the target user. Dispatches to that user's queue. If omitted and running in system context, dispatches to last logged-in user's queue | Optional |
| `-ExpiryTime` | Action expiry time in seconds | Optional |
| `-DisplayResult` | `none` (default for `protect`) / `slidenotification` (default for `protectshare` and `share`) | Optional |
| `-Metadata` | File metadata to store in Seclore's HTML wrapper (e.g. classification metadata from DLP) | Optional |
| `-ComponentName` | Name of the specific component invoking the SDK | Optional |
| `-Output` | Path to output folder for results and bulk reports | Optional |
| `-CreateBulkReport` | `true` (default) / `false`. When `true`, Seclore creates a CSV report at the output path (or `~/Desktop/SecloreReports` if not specified) | Optional |
| `-ApplyLabelPolicies` | `true` / `false` (default: `false`). When `true`, protection policies mapped to the label are applied automatically | Optional |
| `-Reclassify` | `true` / `false` (default: `false`). When `true`, already-classified files are reclassified | Optional |
| `-Justification` | Justification text for reclassification. Required when `-Reclassify` is `true` | Conditional |

---

## 4. Protection Types

### Self
The logged-in Seclore Desktop Client user becomes the file owner. No other user gets permissions initially. When a Self-protected file is shared via Outlook, Seclore Smart-Sharing (Outlook Plugin) automatically grants access to email recipients.

Best for: recipients are not known in advance; Outlook is the primary sharing method.

### Policy
File is protected with a predefined Policy ID. The policy defines who can access the file, what rights they have, when, and from where. The logged-in user becomes the file owner. Multiple policies can be applied simultaneously (comma-separated list of Policy IDs).

Best for: granular/restrictive permissions; unknown sharing channel; time-based or IP-based controls needed.

---

## 5. protect Action

Protects individual files or all files in a folder.

**Mandatory parameters:** `-ActionId`, `-ApplicationName`, `-file` (or `-folder`), `-type`, `-classification`
If `-type` is `policy`, also `-listId`.

**Examples:**

```bat
:: Self protect
SecloreActionDispatcher.exe -ActionId "protect" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\3.txt" -Type "self" -Classification "1"

:: Policy protect — single policy
SecloreActionDispatcher.exe -ActionId "protect" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\2.txt" -Type "policy" -ListId "9" -Classification "1"

:: Policy protect — multiple policies
SecloreActionDispatcher.exe -ActionId "protect" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\2.txt" -Type "policy" -ListId "9,1" -Classification "1"

:: Bulk protect — all files in a folder
SecloreActionDispatcher.exe -ActionId "protect" -ApplicationName "MyAppName" ^
  -Folder "C:\Users\admin1\Desktop" -Type "self" -Classification "1"

:: With IncidentId and UserId
SecloreActionDispatcher.exe -ActionId "protect" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\2.txt" -Type "policy" -ListId "9" -Classification "1" ^
  -UserId "S-1-5-21-1898936974-2135547054-2131954801-30115" -IncidentId "kQtuwheeri87Y"

:: With custom metadata (classification label metadata)
SecloreActionDispatcher.exe -ActionId "protect" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\3.txt" -Type "policy" -ListId "9,1" -Classification "1" ^
  -Metadata "^<?xml version=\"1.0\" encoding=\"us-ascii\"?^>^<sisl ...^>" ^
  -ComponentName "File_Classifier"

:: Show Windows notification on completion
SecloreActionDispatcher.exe -ActionId "protect" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\3.txt" -Type "self" -Classification "1" ^
  -DisplayResult "slidenotification"
```

---

## 6. protectshare Action

Protects an unprotected file and displays a Windows notification to the end user so they can immediately add recipients and set permissions.

**Default behavior:** `-DisplayResult` defaults to `slidenotification` (shows the sharing dialog).

**Mandatory parameters:** Same as `protect`.

**Examples:**

```bat
:: ProtectShare with self type (using switches — recommended)
SecloreActionDispatcher.exe -ActionId "protectshare" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\3.txt" -Type "self" -Classification "1" -ExpiryTime "10"

:: ProtectShare with self type (using JSON ActionParams)
SecloreActionDispatcher.exe -ActionId "protectshare" -ApplicationName "MyAppName" ^
  -ActionParams "{\"file\":\"C:\\Users\\admin1\\Desktop\\3.txt\",\"type\":\"self\",\"classification\":\"1\",\"expirytime\":\"10\"}"
```

---

## 7. share Action

Shows the sharing notification to the end user for an already-protected file. Used when a file is already Seclore-protected and the user needs to add or update recipients.

**Mandatory parameters:** `-ActionId`, `-ApplicationName`, `-file`

**Default behavior:** `-DisplayResult` defaults to `slidenotification`.

**Examples:**

```bat
:: Share an HTML-wrapped protected file (using switches — recommended)
SecloreActionDispatcher.exe -ActionId "share" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\3.txt.html"

:: Share a natively protected file (using JSON ActionParams)
SecloreActionDispatcher.exe -ActionId "share" -ApplicationName "MyAppName" ^
  -ActionParams "{\"file\":\"C:\\Users\\admin1\\Desktop\\3.txt\"}"
```

---

## 8. classify Action

Classifies individual files or all files in a folder. Can optionally apply protection if a policy is mapped to the label, and can reclassify already-classified files.

**Mandatory parameters:** `-ActionId`, `-ApplicationName`, `-file` (or `-folder`), `-LabelId`

**classify sub-actions:**

| Scenario | Required additional parameters |
|----------|-------------------------------|
| Classify only | None (beyond mandatory) |
| Classify + protect | `-ApplyLabelPolicies "true"` |
| Classify/reclassify | `-Reclassify "true"` `-Justification "text"` |
| Classify/reclassify + protect | `-Reclassify "true"` `-Justification "text"` `-ApplyLabelPolicies "true"` |

**Examples:**

```bat
:: Classify
SecloreActionDispatcher.exe -ActionId "classify" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\file1.docx" -LabelId "10001"

:: Classify and protect (protection policy mapped to label)
SecloreActionDispatcher.exe -ActionId "classify" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\file1.docx" -LabelId "10001" -ApplyLabelPolicies "true"

:: Classify/Reclassify
SecloreActionDispatcher.exe -ActionId "classify" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\file1.docx" -LabelId "10001" ^
  -Reclassify "true" -Justification "ProvideJustification"

:: Classify/Reclassify and protect
SecloreActionDispatcher.exe -ActionId "classify" -ApplicationName "MyAppName" ^
  -File "C:\Users\admin1\Desktop\file1.docx" -LabelId "10001" ^
  -Reclassify "true" -Justification "ProvideJustification" -ApplyLabelPolicies "true"

:: Bulk classify — all files in folder
SecloreActionDispatcher.exe -ActionId "classify" -ApplicationName "MyAppName" ^
  -Folder "C:\Users\admin1\Desktop" -LabelId "10001"

:: Bulk classify with custom output folder
SecloreActionDispatcher.exe -ActionId "classify" -ApplicationName "MyAppName" ^
  -Folder "C:\Users\admin1\Desktop" -LabelId "10001" -Output "C:\Users\admin1\Desktop"

:: Bulk classify without generating a report
SecloreActionDispatcher.exe -ActionId "classify" -ApplicationName "MyAppName" ^
  -Folder "C:\Users\admin1\Desktop" -LabelId "10001" -CreateBulkReport "false"
```

---

## 9. BulkClassifier.exe

`BulkClassifier.exe` is a separate wrapper exe that simplifies bulk classification with pre-defined parameters. It is an alternative to using `SecloreActionDispatcher.exe -ActionId classify -Folder ...` directly.

All Seclore Digital Asset Classification (DAC) prerequisites and supported format requirements apply to bulk classification.

**Parameters:** `-Folder`, `-LabelId`, `-ApplyLabelPolicies`, `-Reclassify`, `-Justification`, `-UserId`, `-IncidentId`

**Examples:**

```bat
:: Bulk classify
BulkClassifier.exe -Folder "C:\Users\admin1\Desktop" -LabelId "10001"

:: Bulk classify and protect
BulkClassifier.exe -Folder "C:\Users\admin1\Desktop" -LabelId "10001" -ApplyLabelPolicies "true"

:: Bulk classify/reclassify
BulkClassifier.exe -Folder "C:\Users\admin1\Desktop" -LabelId "10001" ^
  -Reclassify "true" -Justification "ProvideJustification"

:: Bulk classify/reclassify and protect
BulkClassifier.exe -Folder "C:\Users\admin1\Desktop" -LabelId "10001" ^
  -Reclassify "true" -Justification "ProvideJustification" -ApplyLabelPolicies "true"
```

`BulkClassifier.exe` can also be executed via enterprise tools like Microsoft SCCM (System Center Configuration Manager) or Active Directory group policies for organization-wide rollout.

---

## 10. Mac — Seclore Lite

`SecloreActionDispatcher` (no `.exe` extension) ships with Seclore Lite for Mac.

**Supported:** `protect` action only. `classify`, `protectshare`, and `share` are not supported on Mac.

**Known issue:** If two instances of `SecloreActionDispatcher` attempt to protect the same file simultaneously, the file may be double-protected (protected twice in sequence). Prevent this at the integrating application level by serializing protect calls for the same file.

**Log location (Mac):** `/private/var/root/Library/Application Support/Seclore/Seclore Lite/Logs`

**Mac protect example:**

```bash
./SecloreActionDispatcher -ActionId "protect" -ApplicationName "MyAppName" \
  -file "/Users/admin/Desktop/file1.txt" -type "self" -classification "1"
```

---

## 11. Troubleshooting

### Log locations

| Component | Log location (Windows) |
|-----------|----------------------|
| `SecloreActionDispatcher.exe` | `C:\ProgramData\Seclore\FileSecure\Desktop Client\Logs` |
| `ActionExecutor.exe` | `C:\ProgramData\Seclore\FileSecure\Desktop Client\Logs` |

### Log filename formats

| Component | Format |
|-----------|--------|
| SecloreActionDispatcher.exe | `<timestamp>(userid)_processid(secloreactiondispatcher.exe)_actiondispatcher-activitylog.log` |
| ActionExecutor.exe | `<timestamp>(userid)_processid(actionexecutor.exe)_action_executor-activitylog.log` |

### Common issues

**Action dispatched but file not protected:** The action was queued by `SecloreActionDispatcher.exe` but `ActionExecutor.exe` has not picked it up. Check the ActionExecutor log. The Desktop Client must be running and the logged-in user must have a Seclore License.

**UserId dispatches to wrong user:** When running in system context (e.g., as a Windows Service or SCCM task), `-UserId` must be passed explicitly. Without it, the action dispatches to the last logged-in user's queue, which may not be the intended target.

**Reclassify fails with missing justification:** `-Justification` is required whenever `-Reclassify "true"` is passed.

**Mac double-protect race condition:** Two concurrent `SecloreActionDispatcher` calls on the same file result in the file being protected twice. Serialize calls for the same file in the integrating application.

**File skipped in bulk classify:** `BulkClassifier.exe` applies Seclore DAC file format requirements. Files in unsupported formats are skipped and logged in the bulk report.
