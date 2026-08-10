# SIEM / Activity & Audit Log Integration Guide

Seclore activity and audit log data can reach a customer's SIEM (or any external system) through
**two independent mechanisms**. They don't depend on each other and aren't mutually exclusive —
a customer can use either, or both:

| | Part 1 — Seclore for SIEM (push) | Part 2 — Direct DB View query (pull) |
|---|---|---|
| Mechanism | Seclore pushes logs via Logstash pipelines to a SYSLOG server, HTTP endpoint, or file | Customer's own system queries Seclore's Policy Server database views directly with SQL |
| Requires | The "Seclore for SIEM" add-on tool, deployed on top of Policy Server on explicit request | Nothing extra — the DB views exist on every Policy Server. Requires direct DB network access |
| Works for | On-premises and SaaS (Cloud) deployments | **On-premises only** — a SaaS customer has no direct access to Seclore's cloud database |
| Who sets it up | ISD team (on-prem) or Cloud team (SaaS), only on explicit customer request | The customer's own DBA/integration team, against Seclore's DB |
| Data format | SYSLOG or JSON | Raw SQL result set (whatever the customer's query returns) |

Route a question to Part 1 whenever the customer already has a SIEM tool and wants log data
pushed to it in near-real-time. Route to Part 2 when the customer wants to pull data themselves
(their own script, ETL job, or reporting tool) directly from an on-premises Policy Server, or when
their SIEM is expected to pull rather than have data pushed to it.

---

## Part 1 — Seclore for SIEM (push-based integration)

### What it is

"Seclore for SIEM" is a separate tool deployed on top of Policy Server. It is **not included by
default** — it is deployed only when a customer explicitly requests SIEM integration:
- **On-premises Policy Server:** the ISD team deploys it.
- **SaaS (Cloud) Policy Server:** the Cloud team deploys it.

### Prerequisites

- Policy Server 3.17.7.0 / Seclore 3.31.8.0 or above.
- Seclore for SIEM 1.0.0.0 or above.

### Network and firewall requirements (customer side)

- Open ports for log transmission (TCP/UDP/SSL-TCP, whichever the SYSLOG server uses).
- Inbound traffic allowed from Seclore servers to the SIEM system.
- Network connectivity between Seclore servers and the SIEM system (cloud or on-prem).
- The SIEM URL must be reachable **from the Policy Server** — if it's blocked, the customer needs
  to open access on their side.

### How it works — architecture

```
Policy Server Database  →  Seclore for SIEM (bridge)  →  Logstash Pipelines  →  SIEM system
```

1. **Policy Server Database** holds all activity types.
2. **Seclore for SIEM** is the bridge component that reads from the Policy Server database and
   forwards data to external SIEM systems. Not included by default with Policy Server.
3. **Logstash pipelines** — one each for DRM Activities, DRM Audit Logs, and DAC (classification)
   Activities — push the data onward to the SIEM system.

### What data can be pushed

- **EDRM Activities** (file-level actions — protect, view, edit, print, share, unprotect, etc.)
- **EDRM Audit Logs** (admin/system actions — repository, credential, policy changes, etc.)
- **DAC (classification) Activities** (classify, declassify, upgrade, downgrade, etc.)

The customer decides which of these categories to push — it isn't all-or-nothing.

**Not currently supported:** DAC **Audit** logs (Add/Update Classification Labels, Add/Update
Publishing Policies) are not part of the audit logs pushed to SIEM. Don't confuse these with DAC
*Activity* logs (classification events on files/emails), which are supported.

### Format types

- **SYSLOG** or **JSON** — customer's choice.

### Output mechanisms (3 supported)

| Mechanism | Applies to | What the customer must provide |
|---|---|---|
| **Output to File** | On-premises PS only | Absolute path of the output file. (For SaaS, Seclore can optionally retain output files in Seclore Cloud as backup on request — 6-month retention.) |
| **Send to SYSLOG Server** | SaaS or on-prem | SYSLOG Server URL/IP, port, protocol (UDP, TCP, or SSL-TCP), and CA certificate details if the protocol is SSL-TCP |
| **HTTP** | SaaS or on-prem | SIEM Server URL (e.g. `https://example.siem.com/data`), HTTP method (POST), authorization token if required, CA certificate details if the certificate isn't trusted |

### Frequency of publishing

- Default: **15 minutes**. Minimum configurable: **5 minutes**.
- Going below 5 minutes is not recommended — it impacts performance.

### Historical data

- Policy Server can be configured to retain historical SIEM data for **1–180 days** (default 30).
- The Seclore for SIEM tool **does not support sending historical data older than 30 days**,
  regardless of the retention window configured — don't promise a customer they can backfill
  further than that through this mechanism.

### Priority values (SYSLOG PRI)

Every pushed log message carries a Priority Value combining a **Severity Level** and a
**Facility Code**: `PRI = (Facility × 8) + Severity`.

**Severity levels:**

| Value | Name | Example event |
|---|---|---|
| 0 | Emergency | Kernel panic, total hardware failure |
| 1 | Alert | Database corruption, loss of primary connection |
| 2 | Critical | Hardware failure, out-of-memory |
| 3 | Error | Application crash, authentication failure |
| 4 | Warning | High CPU usage, low disk space |
| 5 | Notice | Service restart, config change |
| 6 | Informational | User login/logout, scheduled backup completed |
| 7 | Debug | Debug traces, function execution logs |

**Facility codes actually used by Seclore:** `1` (user-level messages) for DRM Activities and DAC
Activities; `13` (security/log-audit) for Audit Logs. (The full syslog facility table has 24
entries, 0–23; Seclore only emits under these two.)

**DRM Activity priority values** (Facility 1): Authorized activities are Severity 6
(Informational) → Priority **14**, except Print and Unprotect which are Severity 5 (Notice) →
Priority **13**. Unauthorized activities are uniformly Severity 4 (Warning) → Priority **12**,
across all activity types (View, Edit, Print, Share, Unprotect, Transfer Ownership, Access
Remotely, Accessed on VM, View in Lite Viewer, Creating offline permissions, Close File, Enable
Offline Access).

**Audit Log priority values** (Facility 13): Most administrative activities (Add/Update
Repository, Add/Update Policy, Map/Unmap entity, Transfer Ownership, Admin Login, User Creation,
etc.) are Severity 6 (Informational) → Priority **110**. A smaller set — Assign Admin, Change
Password for System Administrator, Delete Component Configuration — are Severity 5 (Notice) →
Priority **109**. Delete Repository is Severity 2 (Critical) → Priority **106**, the most severe
value Seclore assigns in the audit category.

**DAC Activity priority values** (Facility 1): Classified, Upgraded, and Email auto-upgraded are
Severity 6 (Informational) → Priority **14**. Declassified, Downgraded, Email blocked, and
Ignored-suggestion-and-did-not-classify are Severity 4 (Warning) → Priority **12**.

If asked for the priority value of a specific activity not listed above, don't compute or guess
one — say it isn't in the documented table.

### Logstash pipeline configuration (background — normally handled by ISD/Cloud team)

This is infrastructure work typically done by Seclore's ISD or Cloud team, not by the customer's
developers, but the mechanics are useful for troubleshooting or understanding what "Seclore for
SIEM" is actually doing:

- Three `.conf` pipeline files per customer, copied from `Seclore for SIEM [version]\scripts\templates`
  into `<LOGSTASH_HOME>\config`: `cl-siem-logstash-CUSTOMER_ID.conf` (classification/DAC),
  `irm-siem-logstash-CUSTOMER_ID.conf` (IRM/DRM activities), `audit-siem-logstash-CUSTOMER_ID.conf`
  (audit logs). `CUSTOMER_ID` is replaced with the value from `customer.id` in the Seclore API
  Server's `application.properties`.
- Each pipeline has a matching `_logstash_jdbc_last_run` file recording the UTC timestamp from
  which activities should sync — this is how Logstash tracks "what's already been sent."
- `pipelines.yml` registers all three pipeline IDs with `queue.type: persisted`.
- **SSL quirk:** Logstash's Syslog output plugin requires a client SSL certificate and key pair to
  be configured whenever the protocol is `ssl-tcp`, even if mutual SSL verification isn't
  requested — this is a Logstash plugin requirement, not a Seclore-specific one.
- Sensitive values (credentials, tokens) are entered via a dedicated
  `siem-customer-configurations.bat` script rather than being placed in the `.conf` files directly.
- Windows-integrated auth for MSSQL is supported (remove `jdbc_password`, append
  `integratedSecurity=true` to `jdbc_connection_string`, and place the matching `sqljdbc_auth.dll`
  — x86 or x64 depending on JVM bitness — in `<LOGSTASH_HOME>\bin`).

### Sample logs and known limitations

Sample log payloads are packaged separately per deployment (not included in this skill — they may
contain customer-sensitive data and should never be shared outside the intended audience). If
someone asks to see a sample log format, point them to check with the ISD/Cloud team or the
customer's existing SIEM integration package rather than fabricating one.

### FAQ

**What types of logs does Seclore for SIEM export?** DRM Activity Logs (file-level actions), DAC
Activity Logs (classification events), and EDRM Audit Logs (system/admin actions). DAC Audit logs
are not currently supported.

**How is historical data managed?** Policy Server retains 1–180 days of historical SIEM data
(default 30). Seclore for SIEM itself cannot send data older than 30 days regardless of that
retention setting.

**Are there separate system requirements for Seclore for SIEM?** No — it's configured within the
existing Logstash setup alongside Policy Server; no separate infrastructure is needed.

**Does this work for both on-prem and SaaS?** Yes, both are supported.

**Is it supported on Windows and Linux?** Yes — Windows Server natively, and Linux via Docker.

### Questionnaire

When scoping a new SIEM integration for a customer, gather: which SIEM tool/version they use;
whether it's cloud or on-prem; preferred format (SYSLOG or JSON); whether the customer expects
Seclore to *push* data (SYSLOG/HTTP) or their SIEM to *pull* it (file output); which log
categories they need (EDRM Activities, Classification/DAC Activities, EDRM Audit Logs); and the
required publishing frequency. Use this to determine whether the integration is supported
out-of-the-box or needs custom work — don't assume a customer's requirement is standard without
checking it against what's documented above.

---

## Part 2 — Direct database view query (on-premises only)

### When this applies

This path only works for **on-premises Policy Server deployments** where the customer has direct
network access to Seclore's database (MSSQL or Oracle). A SaaS/Cloud customer cannot query
Seclore's database directly — for SaaS, Part 1 (Seclore for SIEM push) is the only option.

Seclore exposes two read-only database views for this purpose. No additional Seclore tool or
license is required — any client that can run SQL against the Policy Server database can query
these views directly.

### `EXTFILEUSERACTIVITYVIEW` — end-user DRM activity logs

One record per activity performed by an end user on a file (protect, open, print, share,
unprotect, etc.).

| Column | Type (MSSQL / Oracle) | Description |
|---|---|---|
| `ID` | BIGINT / NUMBER | Activity ID — auto-generated sequential number |
| `FILE_ID` | BIGINT / NUMBER | ID of the file |
| `FILE_NAME` | NVARCHAR / VARCHAR2 | Name of the file when it was protected |
| `CURRENT_FILE_NAME` | NVARCHAR / VARCHAR2 | Name of the file when the activity was performed |
| `CLASSIFICATION_ID` | INT / NUMBER | ID of the file's classification |
| `CLASSIFICATION_NAME` | NVARCHAR / VARCHAR2 | Classification name at the time of the activity |
| `CLASSIFICATION_DESC` | NVARCHAR / VARCHAR2 | Classification description |
| `OWNER_QID` | NVARCHAR / VARCHAR2 | QID of the file's owner |
| `OWNER_NAME` | NVARCHAR / VARCHAR2 | Full name of the file's owner |
| `OWNER_EMAIL_ID` | NVARCHAR / VARCHAR2 | Email of the file's owner |
| `PROTECTOR_QID` | NVARCHAR / VARCHAR2 | QID of who protected the file |
| `PROTECTOR_NAME` | NVARCHAR / VARCHAR2 | Full name of the protector |
| `PROTECTOR_EMAIL_ID` | NVARCHAR / VARCHAR2 | Email of the protector |
| `CONTAINER_QID` | NVARCHAR / VARCHAR2 | QID of the owner's OU |
| `CONTAINER_QHCODE` | NVARCHAR / VARCHAR2 | Unique path (QHCode) of the owner's OU |
| `USER_QID` | NVARCHAR / VARCHAR2 | QID of the user performing the activity |
| `USER_NAME` | NVARCHAR / VARCHAR2 | Full name of the user performing the activity |
| `USER_EMAIL_ID` | NVARCHAR / VARCHAR2 | Email of the user performing the activity |
| `PRIMARY_ACCESS_RIGHT` | INT / NUMBER | Usage permission the user had during the activity |
| `OFFLINE_ACCESS_RIGHT` | INT / NUMBER | Offline usage permission the user had |
| `ACTIVITY_DATE` | DATETIME / TIMESTAMP(0) | When the activity occurred, accurate to the second |
| `ACTIVITY` | INT / NUMBER | Activity type code (see table below) |
| `AUTHORIZED` | INT / NUMBER | `1` authorized, `0` unauthorized |
| `ONLINE_MODE` | INT / NUMBER | `1` online, `0` offline |
| `CREATION_TIME` | DATETIME / TIMESTAMP(0) | When this record was created — use this, not `ID`, for sequential extraction (see below) |
| `REQUEST_IP_ADDRESS` | NVARCHAR / VARCHAR2 | IP address the request came from |
| `MACHINE_NAME` | NVARCHAR / VARCHAR2 | Name of the machine where the activity occurred |
| `MACHINE_IP1` | NVARCHAR / VARCHAR2 | Comma-separated list of that machine's IPs |
| `ACTIVITY_COMMENTS` | NVARCHAR / VARCHAR2 | Free-text comments logged, if any |
| `CLID_DESCRIPTION` | NVARCHAR / VARCHAR2 | Client type — Desktop Client / Hot Folder Server / Web Services, etc. |
| `SOURCE_LOCATION` | NVARCHAR / VARCHAR2 | File location at protection time (can be blank) |
| `CURRENT_LOCATION` | NVARCHAR / VARCHAR2 | File location when the activity occurred (can be blank) |
| `FILE_EXT_REF_ID` / `_NAME` / `_DATA` | NVARCHAR / VARCHAR2 | External reference details for the file, from the integrating application (Policy Federation) |
| `FILE_EXT_APP_ID` | NVARCHAR / VARCHAR2 | External application details for the file |
| `HOTFOLDER_ID` | BIGINT / NUMBER | ID of the file's Hot Folder |
| `HOTFOLDER_NAME` | NVARCHAR / VARCHAR2 | Hot Folder name |
| `HOTFOLDER_EXT_REF_ID` / `_NAME` / `_DATA` / `_EXT_APP_ID` | NVARCHAR / VARCHAR2 | External reference details for the Hot Folder |
| `ENTERPRISE_APP_ID` | BIGINT / NUMBER | ID of the Enterprise Application |
| `ENTERPRISE_APP_NAME` | NVARCHAR / VARCHAR2 | Name of the Enterprise Application |
| `IRM_AWARE` | INT / NUMBER | `0` Basic Protection, `1` Advance Protection |

Newer Policy Server versions add `COUNTRY_ISO_CODE` and `COUNTRY_NAME` (country where the
activity was performed) — present in the SIEM export field list; confirm availability against the
customer's specific Policy Server version before relying on them in a query.

**Activity type codes:**

| Code | Activity | Code | Activity |
|---|---|---|---|
| 1 | Protect | 8 | Access Remotely |
| 2 | View | 9 | Accessed on VM |
| 3 | Edit | 13 | View in Lite Viewer |
| 4 | Print | 14 | Creating offline permissions |
| 5 | Share | 16 | Close File* |
| 6 | Unprotect | 17 | Enable Offline Access |
| 7 | Transfer Ownership | | |

\* Close File (16) is only logged if the System Admin has enabled that option in Policy Server
Portal's feature configuration — absence of Close File records doesn't necessarily mean no files
were closed.

**Open activities span two codes** — the Desktop Client logs opens as `2` (View), while all Lite
clients (Android, iOS, Windows FS Lite, Lite Online) log opens as `13` (View in Lite Viewer). A
query for "all opens" must include both: `WHERE ACTIVITY = 2 OR ACTIVITY = 13`.

**QID syntax** (`USER_QID`, `OWNER_QID`, `PROTECTOR_QID`, `CONTAINER_QID`): `<Repository
Code>::<Unique ID within that repository>` — e.g. the user's SID for Active Directory, or the
EntryUUID for FIM/SIM (OpenDJ-backed). `CONTAINER_QHCODE` follows the same repository-code prefix
pattern but carries the OU's hierarchical path instead of an ID. Break the QID on `::` and look up
the remainder in the underlying repository (AD/LDAP query, etc.) to resolve a human-readable name.

**Primary/Offline Access Right bitmask values:**

| Right | Value |
|---|---|
| READ | `0x00000002` (2) |
| LITE_VIEWER | `0x00000006` (6) |
| PRINT | `0x0000000A` (10) |
| EDIT | `0x00000022` (34) |
| FULL_CONTROL | `0x000000AA` (170) |
| OWNER | `0x0000FFFF` (65535) |
| COPY_DATA | `0x00000102` (258) |
| SCREEN_CAPTURE | `0x00000202` (514) |
| MACRO | `0x00000402` (1026) |

Check a specific right with a bitwise AND: `(GivenRights & 0x0000000A) = 0x0000000A` → user has
PRINT. Skip individual checks entirely if the given right is FULL_CONTROL or OWNER — both already
imply every other right.

### `EXTAUDITLOGVIEW` — administrator audit logs

One record per administrative action (System Admin, Security Admin, Global Security Admin).

| Column | Type (MSSQL / Oracle) | Description |
|---|---|---|
| `ID` | NVARCHAR / VARCHAR2 | Unique activity ID |
| `USER_QID` | NVARCHAR / VARCHAR2 | `0::0` for System Admin, otherwise the acting user's QID |
| `ACTIVITY_DATE` | DATETIME / TIMESTAMP(0) | When the activity occurred |
| `CONTAINER_QID` / `CONTAINER_QHCODE` | NVARCHAR / VARCHAR2 | Container (OU) associated with the object acted on — varies by activity type; `0::0` / `0::SYSTEM/` for System Admin |
| `ACTIVITY` | INT / NUMBER | Activity type code (see table below) |
| `ACTIVITY_COMMENTS` | NVARCHAR / VARCHAR2 | Free-text comments, if any |
| `PRIMARY_REF` | NVARCHAR / VARCHAR2 | Reference to the primary object — meaning depends on activity type |
| `SECONDARY_REF` | NVARCHAR / VARCHAR2 | Reference to the secondary object — meaning depends on activity type |
| `DESCRIPTION` | NVARCHAR / VARCHAR2 | Request-specific description |
| `CLID_DESCRIPTION` | NVARCHAR / VARCHAR2 | Client type used |

**Audit activity codes and what `PRIMARY_REF`/`SECONDARY_REF` mean for each:**

| Code | Activity | Primary Ref | Secondary Ref | Container |
|---|---|---|---|---|
| 2 | Successful Authentication as System Administrator | Logged-in user QID | — | Logged-in user's OU |
| 4 | Change login context as Security/Global Security Admin | Logged-in user QID | — | Logged-in OU |
| 7 | Add Repository | Repository Code | Repository Name | Logged-in user's OU |
| 8 | Update Repository | Repository Code | Repository Name | Logged-in user's OU |
| 10 | Update User Protection License | User QID | `LicenseType:LicenseValue` | Logged-in user's OU |
| 11 | Assign Security/Global Security Admin | OU QID | User QID | The requested OU |
| 12 | Add Classification | Classification ID | Classification Name | Logged-in user's OU |
| 13 | Update Classification Status | Classification ID | Classification Name | Logged-in user's OU |
| 14 | Update Classification | Classification ID | Classification Name | Logged-in user's OU |
| 16 | Change System User Password | User QID | — | Logged-in user's OU |
| 22 | Create Predefined Credential (Policy) | Credential ID | Credential Name | Requested credential's OU |
| 23 | Update Credential Status | Credential ID | Credential Name | Requested credential's OU |
| 24 | Update Credential | Credential ID | Credential Name | Requested credential's OU |
| 25 | Map/Unmap Entities to Credential | Credential ID | Credential Name | Requested credential's OU |
| 37 | Transfer File Ownership (legacy) | File ID | New owner's User QID | Requested file's new OU |
| 38 | Change File Status | File ID | File Status | Requested file's OU |
| 41 | Transfer Credential Ownership | Credential ID | New Owner OU | New owner's OU (or User's OU if owner is a user) |
| 42 | Delete Repository | Repository Code | Repository Name | Logged-in user's OU |
| 43 | Add Repository to Repository Mapping | Repository Code | Repository Name | Logged-in user's OU |
| 59 | Set Default Classification | Classification ID | Classification Name | Logged-in user's OU |
| 62 | Reset Lock-To-Machine for an Entity | File ID | — | Requested file's OU |
| 99 | Update Repository Cache | Repository Code | Repository Name | Logged-in user's OU |
| 109 | User Creation by integrating app (EA) | New User QID | File Server (EA) ID | New user's OU |
| 110 | Revoke File Access | User QID whose access is revoked | — | Logged-in user's OU |
| 111 | Replicate User Access | New User QID (recipient) | User QID (source) | Logged-in user's OU |
| 113 | Transfer File Ownership (current) | New owner's User QID | — | Logged-in user's OU |
| 116 | Replace User Access | New User QID (recipient) | User QID (source) | Logged-in user's OU |
| 155 | Add Component Configuration | Component name | — | Logged-in user's OU |
| 156 | Delete Component Configuration | Component name | — | Logged-in user's OU |
| 157 | Update Component Configuration | Component name | — | Logged-in user's OU |

**License Type:** `0` No License, `1` Classification, `2` Protection.
**License Value:** `0` No License, `1` Classification, `2` Protect with Predefined Credential, `3`
Protect with Any Credential.
**File Status:** `0` Inactive, `1` Active.

### Sample queries (MSSQL syntax — equivalent Oracle syntax applies)

```sql
-- All open activities on EXTFILEUSERACTIVITYVIEW
SELECT * FROM EXTFILEUSERACTIVITYVIEW WHERE ACTIVITY = 2 OR ACTIVITY = 13;

-- All unauthorized end-user activities since a given date
SELECT * FROM EXTFILEUSERACTIVITYVIEW WHERE AUTHORIZED = 0 AND ACTIVITY_DATE > '1 Mar 2014';

-- File open activities within a date range
SELECT * FROM EXTFILEUSERACTIVITYVIEW
WHERE (ACTIVITY = 2 OR ACTIVITY = 13) AND ACTIVITY_DATE BETWEEN '10 Feb 2014' AND '15 Feb 2014';

-- Unauthorized activities for a specific classification
SELECT * FROM EXTFILEUSERACTIVITYVIEW WHERE AUTHORIZED = 0 AND CLASSIFICATION_ID = 1;

-- All activities for a Policy-Federation-protected file, by external reference ID
SELECT * FROM EXTFILEUSERACTIVITYVIEW WHERE FILE_EXT_REF_ID = N'4C0E0055-E1D4-4963-A24A-4505DEF839BB';

-- Audit log: all Credential create/update activity from a given date
SELECT * FROM EXTAUDITLOGVIEW WHERE (ACTIVITY = 22 OR ACTIVITY = 24) AND ACTIVITY_DATE >= '1 FEB 2014';

-- Audit log: all activity on a specific Repository
SELECT * FROM EXTAUDITLOGVIEW WHERE (ACTIVITY = 7 OR ACTIVITY = 8 OR ACTIVITY = 43) AND PRIMARY_REF = N'1';
```

### Extracting records sequentially (polling pattern)

**Don't poll on `ID`.** In Seclore's High-Availability architecture, multiple Tomcat instances sit
behind a load balancer, so `ID` values are not guaranteed to be assigned in strict chronological
order across instances. Use `CREATION_TIME` instead:

```sql
SELECT * FROM EXTFILEUSERACTIVITYVIEW
WHERE CREATION_TIME > 'DD-MM-YY HH:MI:SS AM/PM'
ORDER BY CREATION_TIME;
```

After each run, record the `CREATION_TIME` of the last row returned and use that value as the
lower bound on the next run. This is the same pattern an external polling system should use for
building its own incremental sync against these views.

### Determining how long a document was open

Supported for Seclore Lite for Windows (Office 2010/2013/2016, Seclore PDF Viewer), Seclore Lite
Online, and Seclore Lite for Mac (Office 2016 64-bit, Seclore PDF Viewer) — specific file formats:
doc/docx/docm/xls/xlsx/xlsm/xlsb/ppt/pptx/pptm/rtf/csv/pdf (exact list varies slightly by
platform).

Pair each open (`ACTIVITY IN (2,13)`) with the next matching Close (`ACTIVITY = 16`) for the same
file and user, ordered by `ACTIVITY_DATE`. MSSQL example:

```sql
WITH t AS (
  SELECT * FROM EXTFILEUSERACTIVITYVIEW
  WHERE ACTIVITY IN (2,13,16) AND AUTHORIZED = 1
    AND FILE_EXT_REF_ID = '$FILEEXTREFID$' AND USER_QID = '$USERQID$'
)
SELECT a.FILE_EXT_REF_ID, a.FILE_ID,
       a.ID AS OPEN_ACTIVITY_ID, a.ACTIVITY_DATE AS OPEN_TIMESTAMP,
       b.ID AS CLOSE_ACTIVITY_ID, b.ACTIVITY_DATE AS CLOSE_TIMESTAMP,
       DATEDIFF(minute, a.ACTIVITY_DATE, b.ACTIVITY_DATE) AS OPEN_TIME
FROM (SELECT * FROM t WHERE ACTIVITY IN (2,13) AND ACTIVITY_DATE >=
        (SELECT MAX(ACTIVITY_DATE) FROM t WHERE ACTIVITY IN (2,13)
         AND ACTIVITY_DATE < (SELECT MIN(ACTIVITY_DATE) FROM t WHERE ACTIVITY = 16))
     ) a,
     (SELECT * FROM t WHERE ACTIVITY = 16) b
WHERE b.ACTIVITY_DATE = (SELECT MIN(ACTIVITY_DATE) FROM t
                          WHERE ACTIVITY = 16 AND ACTIVITY_DATE > a.ACTIVITY_DATE);
```

The Oracle equivalent uses the same CTE structure with `ROUND((b.ACTIVITY_DATE -
a.ACTIVITY_DATE) * 24 * 60)` in place of `DATEDIFF`.

### Operational notes — always give these when someone is about to query directly

1. **Create a separate, read-only DB user** for this purpose — grant SELECT only, never write
   access, against Seclore's database.
2. **Never modify Seclore's database.** It's owned and managed by Seclore; direct writes can cause
   unexpected behavior.
3. **These views aren't optimized for heavy external querying.** Recommend the customer pull data
   into their own database for analysis rather than running complex/analytical queries directly
   against Seclore's database — that can add significant load.
4. If query volume is expected to be significant, the customer may need to size up the Seclore
   database server's hardware accordingly.

---

## Quick reference — which part answers a given question

| Question | Part |
|---|---|
| "Can Seclore push logs to Splunk/QRadar/our SIEM?" | Part 1 |
| "What format does Seclore send SIEM data in?" | Part 1 |
| "How often does Seclore send data to our SIEM?" | Part 1 |
| "Can our own script pull activity logs directly from the database?" | Part 2 |
| "What columns are in the activity log?" | Part 2 (or Part 1's priority-value section if the question is really about what gets pushed) |
| "How do we track how long a file was open?" | Part 2 |
| "We're on Seclore SaaS/Cloud — can we query the database ourselves?" | Neither — SaaS customers cannot access the DB directly; redirect to Part 1 |
| "What does activity code 7 / audit code 24 mean?" | Part 2 (activity/audit code tables) — same numeric codes are also used in Part 1's priority-value tables |
