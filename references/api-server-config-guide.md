# DRM API Server — Prerequisites & Getting Started

Sourced from the DRM API Server 3.5.0.0 offline deployment package (installation guide, Admin
Console usage guide, Swagger testing guide, and the bundled configuration properties/sanity-test
tool) — not the public developer portal. This is not a deployment guide — it doesn't cover
installing or standing up the server. It covers what needs to be configured, on the Policy Server
side and the DRM API Server side, before a developer can start calling the API, plus how to get
and test an API key. See `references/api-server-guide.md` for the full API reference.

If you're deploying or upgrading the server itself, that's outside this skill's scope — see
Section 4, "Who to contact."

---

## 1. What needs to exist before you can call the API

Three things, usually set up by someone else on your team:

1. **A running DRM API Server**, with its base URL/FQDN. Confirm it's actually reachable:
   `curl -k https://<FQDN>/seclore/drm/health` (or `/healthcheck` for a check that doesn't
   depend on Policy Server reachability — see `references/api-server-guide.md` Section 13 for
   the difference between the three health endpoints).
2. **An Enterprise Application (EA) configured on the Policy Server**, with an EA ID and
   passphrase (and an RSA key pair if the EA uses Advanced Security). This is Policy Server
   administration, not something the DRM API Server exposes — if you don't have this, ask your
   Policy Server admin or Seclore PoC.
3. **An Application + API key created in the DRM API Server's Admin Console**, mapped to that
   EA. See Section 2 below — you'll likely need someone with Admin Console access to do this,
   unless that's you.

Once you have the API key, everything else in `references/api-server-guide.md` — upload,
protect, download, classification, etc. — just needs `Authorization: Bearer <api-key>` on each
call. No login step.

Two other things affect what you can do with the API, but are configured server-side by whoever
runs the deployment — you don't set these yourself, just be aware they exist:

- **Which file types can be classified** — controlled by `SUPPORTED_FILE_TYPES` on the server.
  If a classify/reclassify call behaves unexpectedly for a given file type, this is worth
  checking with whoever administers the server.
- **Which file-storage backend is in use** (disk/NAS, AWS S3, or database) — this determines the
  third component's key name in health-check responses (`diskFileStorage`, `s3FileStorage`, or
  `databaseFileStorage`) — don't hardcode one name when parsing health responses.

---

## 2. Getting an API key (Admin Console walkthrough)

The Admin Console is a separate, browser-based UI from the REST API — it's where applications
and API keys are managed. **There is no REST endpoint for API key creation or deletion** — it's
Admin Console only.

1. Navigate to `https://<FQDN_OF_DRM_API_SERVER>/seclore/drm/admin` and log in (default admin
   username is `drmadmin`).
2. On the Applications list, either pick an existing Application or click **+ Add application**.
   Creating one needs:
   - **Application name** (letters/numbers/spaces/hyphens/underscores, 1–200 characters)
   - **Enterprise application ID** — the numeric EA ID from the Policy Server
   - **Enterprise application passphrase** — the EA's passphrase (required on create, can't be
     viewed again afterward — use "Reset passphrase" to change it later)
   - **Policy Server URL** — full URL including scheme/host/port/context path
   - If the EA uses Advanced Security: check "Use Advanced security" and supply the RSA private
     key (XML format, from Seclore's RSA key generator tool), Key ID, key length, padding, and
     chaining mode
   - **Allow Advanced Privileges** (only shown when Advanced Security is checked): enables
     elevated operations for this Application, including **Unprotect Any File** via the same
     `/unprotect` API — the corresponding privilege must *also* be enabled on the EA in the
     Policy Server, same two-sided requirement as the SDK's Advanced Privileges model. See
     `references/api-server-guide.md` Section 9.
   - Note: **classification isn't a separate toggle** — it works automatically whenever
     Advanced Security is enabled, and won't work if it isn't
3. On that Application's row, click **API Keys**, then **+ Add application** → enter a Label
   (e.g. `ERP Integration`, `CI Pipeline - Production`) → **Create API key**.
4. **Copy the key immediately.** It's shown once, in a read-only field with a Copy button, and
   cannot be retrieved again after you close the dialog. Store it in a secrets manager.
5. If you lose it: you can't recover it. Delete the key and create a new one, then update your
   integration.

Applications marked "Managed via Environment" were configured via server-side environment
properties rather than the Admin Console database — they're read-only in the UI and don't
support API key creation from the console; ask whoever manages that environment configuration.

---

## 3. Testing your setup

### 3.1 Sanity test tool (bundled in the offline package)

`tools/sanity-test/drm_sanity_test.sh` walks Upload → Protect (Independent Rights) → Delete →
Unprotect → Download end to end against a real deployment. Requires an Application and API key
already created (Section 2). Prompts for: DRM API Server URL, API key, file to test (defaults to
a bundled sample.pdf), owner email, recipient email, access right(s) (defaults to `read`). Logs
and downloaded files land in `./output` next to the script — useful for sending to Seclore
support if something fails, since every request/response is captured there.

### 3.2 Swagger UI

If the deployment has `springdoc_swagger_ui_enabled=true` set, browse to
`https://<FQDN>/seclore/drm/swagger-ui/index.html`. Click **Authorize**, paste in an API key
(the field also still accepts a legacy JWT access token — the server auto-detects which type
it is), then use "Try it out" on any endpoint. This is the single best way to confirm the exact
live request/response shape for your specific deployed version, since it's generated directly
from the running server rather than from any static document (including this one). If Swagger
isn't enabled on your deployment, ask whoever administers the server to turn it on for testing —
it shouldn't stay on in production.

---

## 4. Who to contact

Straight from the package's own FAQs — these aren't things you can self-serve from the Admin
Console or REST API:

| Situation | Who / what to do |
|---|---|
| Deploying, upgrading, or reconfiguring the DRM API Server itself | Your Seclore implementation team — this skill doesn't cover deployment |
| Forgot the Admin Console password | Ask your Seclore PoC to help reset it |
| Want the Admin Console session timeout changed | Ask your Seclore PoC — it's a server-side config value |
| Need an Enterprise Application (EA) set up or its ID/passphrase | Your Policy Server admin |
| Need an Application + API key created in the DRM API Server itself | Whoever has Admin Console access for your deployment — this is self-service via the console once the server is up, not something Seclore support does for you |
| API behavior seems inconsistent with what's documented (e.g. classification not working for a file type, unexpected storage errors) | Whoever administers the server — it may be a server-side configuration choice (supported file types, storage backend) rather than an API bug |

---

## 5. See also

- `references/api-server-guide.md` — full REST API reference (endpoints, request/response
  schemas, auth model, error codes)
- `references/sdk-guide.md` — for the Java SDK alternative to the API Server
- `references/policy-federation-api.md` — for implementing the ARA callback service the
  External Reference protection type depends on
