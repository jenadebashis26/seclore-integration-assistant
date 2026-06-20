# Identity Federation Guide

This guide covers how Seclore authenticates and authorizes users — generic identity protocols
as Seclore implements them, Seclore-specific identity concepts (repositories, repository
adaptors, User Search), and the Custom Repository Adaptor (CRA) used for identity systems
Seclore does not support out of the box.

---

## 1. The two-tier model

**Tier 1 — Native, out-of-the-box repositories.** No custom development required. Configured
directly in Seclore Admin under Configuration > Repositories.

| Repository type | Mechanism |
|---|---|
| Active Directory (on-premises) | LDAP/LDAPS |
| Azure AD | Native support — SAML 2.0, OAuth 2.0, or OpenID Connect |
| Known SAML IdPs (Okta, PingFederate, ADFS, Google) | SAML 2.0 |
| Seclore Identity Manager (SIM) | Seclore's own proprietary repository (OpenDJ-backed), for external users when the customer has no system of their own |

**Tier 2 — Custom Repository Adaptor (CRA).** Required when the customer's identity system is
not in Tier 1 — for example Oracle IAM, or a fully custom user database. A CRA requires custom
development on the Policy Server side and only appears in the repository dropdown after it is
deployed. The CRA is an umbrella term, not a single protocol — which underlying mechanism it
uses depends on what the customer's system supports:

| CRA flavor | Use when the customer's system supports |
|---|---|
| SAML 2.0-based CRA | SAML 2.0, but isn't one of the pre-integrated IdPs |
| OAuth 2.0-based CRA | OAuth 2.0 |
| OpenID Connect-based CRA | OIDC |
| Pure API-based CRA | None of the above — only a callable HTTP endpoint |

In other words: when a customer asks "can you integrate with my identity system," the answer is
always yes — the only question is which of these four mechanisms fits what they already expose.

---

## 2. SAML 2.0 — protocol detail

Policy Server acts as the SAML **Service Provider (SP)**; the customer's system is the
**Identity Provider (IdP)**.

**Fixed SP identifiers** (used in the metadata exchanged with the customer):
- EntityId: `SeclorePolicyServer` (or the Policy Server URL, depending on integration)
- Assertion Consumer Service (ACS) URL: `<Policy Server URL>/SAMLPostLogin.do` (example)

**From the customer's IdP metadata, Policy Server needs:**
- EntityId
- Single Sign-On Service POST binding URL
- Signature verification X.509 certificate (from `<KeyDescriptor use="signing">`)

**Flow:**
1. User opens a Seclore-protected file; the request reaches Policy Server.
2. Policy Server determines the user should authenticate via this IdP and issues an HTTP POST
   redirect to the IdP's SSO URL, passing the issuer identifier and the ACS URL as the
   PostLoginURL. A random token is passed in `RelayState` for replay/CSRF protection.
3. The IdP authenticates the user using its own method (password, MFA, smart card — opaque to
   Seclore) and POSTs a SAML response back to the ACS URL.
4. Policy Server validates the `RelayState` token, validates the assertion signature against the
   IdP's X.509 certificate, and extracts the required assertion attributes.
5. Policy Server creates an authenticated session and opens the file per the user's permissions.

**Required assertion attributes (case-sensitive):** NameID (the unique user identifier — e.g.
`userPrincipalName` for AD, `emailAddress` for Azure AD, depending on the integration),
First Name, Last Name, Email Id.

**Security constraints:**
- Only the assertion is signed — not the entire SAML response — and it is never encrypted.
- Signature algorithm: SHA-256.
- The SAML message is deflated, Base64-encoded, and URL-encoded.
- Single Logout is not supported by the Custom Repository Adaptor.

This information (NameID + names + email) is stored in the Seclore database. Whether that's
sufficient on its own, or whether a separate User Search call is also needed, depends on the
authorization model — see Section 6.

---

## 3. OAuth 2.0 — protocol detail

Standard authorization-code flow.

1. Policy Server redirects to the IdP's **Authorization Endpoint** with `client_id`,
   `response_type=code`, `state`, `redirect_url`.
2. The IdP authenticates the user (its own method — username/password, MFA, SSO) and redirects
   back to `redirect_url` with an authorization `code` and the original `state`.
3. Policy Server calls the IdP's **Token Endpoint** server-side: `client_id`,
   `grant_type=authorization_code`, `redirect_url`, `code`, `client_secret`.
4. The IdP responds with an access token.
5. Policy Server calls a **user-details API** using the access token and receives: User's
   Unique ID, First Name, Last Name, Email Address.
6. Policy Server stores these details and creates a session.

**Information required from the customer's IdP, per environment** (these can differ across
US PROD / EU PROD / staging, etc.):
- Client ID and Secret
- Authorization Endpoint URL (GET, returns `authorization_code` + `state`)
- Token Endpoint URL (POST/GET, `application/x-www-form-urlencoded`, returns JSON with the
  access token)
- User Details API URL (returns JSON with unique ID, first/last name, email)

**Infrastructure requirement:** Policy Server must be able to reach the Token Endpoint URL and
the User Details API URL directly (server-to-server).

---

## 4. OpenID Connect — protocol detail

Seclore's OIDC adaptor supports **authorization-code flow only** — no implicit flow, no client
credentials flow, and no `request` parameter.

**Discovery:** the OpenID Provider (OP) exposes a well-known discovery URL
(e.g. `https://accounts.google.com/.well-known/openid-configuration`).

**Authorization request** (Policy Server → OP authorization endpoint):
`client_id`, `redirect_uri=<PS_URL>/postoauth`, `scope=openid email profile`,
`response_type=code`, `login_hint=<user's email>`, `state`.

**Token request** (Policy Server → OP token endpoint, after receiving the code):
`client_id`, `redirect_uri`, `client_secret`, `code`, `grant_type=authorization_code`.

**Token response:** `access_token`, `expires_in`, `token_type`, and `id_token` as a **signed
JWT** — encrypted `id_token` is not supported. Required claims in the `id_token`: `sub`
(unique user ID), `aud` (client_id), `name`, `given_name`, `family_name`, `email`.

**Not supported:** OP-initiated logout (logging out of the OP does not log the user out of
Seclore) and RP-initiated logout (logging out of Seclore does not log the user out of the OP).
If the user's credentials or MFA change at the OP, Seclore will not re-challenge until the
existing Seclore session expires.

---

## 5. Pure API-based CRA — protocol detail

Use this flavor when the customer's identity system supports none of SAML/OAuth/OIDC — only a
callable HTTP endpoint. This is the most heavily hardened of the four flavors because, unlike
the standards-based options, there's no protocol-level security model to lean on — Seclore and
the customer define and secure the handshake themselves.

**Two-leg flow:**

**Leg 1 — Policy Server redirects to the customer's authentication endpoint.**
1. User's browser sends a login request to Policy Server.
2. Policy Server determines the user's domain routes to this CRA.
3. Policy Server generates a `psp_ref_token` and stores it server-side with a short TTL.
4. Policy Server issues an HTTP POST to the customer's configured authentication endpoint with:

| Parameter | Required | Description |
|---|---|---|
| `psp_ref_token` | Yes | Reference token; the customer's system must echo it back unchanged in the `AuthResponse`. Policy Server uses it to validate that a callback corresponds to a legitimate, in-progress request. |
| `psp_redirect_url` | Yes | The Policy Server callback URL the customer's system must POST the `AuthResponse` to. Configured in the CRA adaptor. |
| `psp_email_id` | No | The email address Policy Server already has for the user, so the customer's login page can pre-fill it and avoid duplicate entry. |

**Leg 2 — the customer's system authenticates the user and posts back.**
5. The customer's system authenticates the user by whatever means it likes (password, MFA,
   smart card) — Seclore has no dependency on or visibility into this.
6. On success, it builds an `<auth-response>` payload:

```xml
<auth-response>
  <ref-token>{psp_ref_token value, echoed exactly}</ref-token>
  <user-unique-id>{authenticated user's unique identifier — typically email}</user-unique-id>
</auth-response>
```

7. This payload is RSA-encrypted with Policy Server's public key, Base64-encoded, and POSTed to
   `psp_redirect_url` as the `AuthResponse` parameter.
8. Policy Server: validates the session-binding cookie (CSRF check) → RSA-decrypts using its
   private key → matches `ref-token` to an active, unexpired, not-yet-used token → invalidates
   the token (single-use) → looks up or provisions the user from `user-unique-id` → creates an
   authenticated session → redirects to the originally requested resource.

**Security requirements:**

| Control | Specification |
|---|---|
| `psp_ref_token` entropy | Minimum 128 bits, CSPRNG-generated. Never sequential, timestamp-derived, or UUID v4. |
| `psp_ref_token` lifecycle | Single-use — invalidated on receipt of any callback, success or failure. TTL 90–120 seconds max. Held server-side; the token in the URL is a lookup key only, carrying no claims. Transmitted over HTTPS only; never logged in full. |
| CSRF / session binding | At Leg 1, Policy Server sets a short-lived `HttpOnly; Secure; SameSite=Strict` cookie bound to the `psp_ref_token`. At Leg 2, the cookie must be present and match the expected binding for the presented token, or the callback is rejected and logged as a security anomaly. (Conceptually equivalent to the OAuth 2.0 `state` parameter.) |
| `AuthResponse` encryption | Must be RSA-encrypted with Policy Server's public key and Base64-encoded before transmission; Policy Server decrypts with its private key. |
| Rate limiting | Recommended: max 10 requests per source IP per minute on the customer's authentication endpoint, with exponential backoff on repeated failures — the endpoint is effectively unauthenticated from the network's perspective until a valid token arrives. |

This flow is functionally equivalent to the older XML-based `custom-sso-request`/
`custom-repo-request-auth` protocol used in some legacy CRA integrations, but is the current,
hardened approach for new pure-API CRA engagements.

---

## 6. User Search — what it's for, and why it's optional

**What it does:** Policy Server calls a REST/XML web service exposed by the customer's
application to resolve a user or group on demand — by user ID or email — independent of
whether that user has ever authenticated with Seclore before.

**Why it matters for authorization, not just authentication:** authentication establishes who
just logged in. User Search lets Seclore look up *any* user or group at any time, which is what
makes it possible to:
- Add a named user to a policy's access list before that user has ever opened a file
- Assign a Hot Folder owner who hasn't yet logged in
- Resolve group membership for group-based permissions

**It is optional.** If the customer cannot or will not expose a User Search API, Seclore can
still function using only the user details captured during authentication (unique ID, name,
email) — stored on the Seclore side once the user first logs in. This is sufficient when the
customer's use case is **Policy Federation only**: access decisions are made by the
application's ARA callback at file-open time using whatever identity Seclore already has for
that session, so there's no need to pre-resolve a user before they show up.

**The gap without User Search:** you cannot reference a user in any Seclore-side construct
*before* they've authenticated at least once — because there's nothing to search. Concretely:
- Creating a policy and trying to add `jane@customer.com` to its access list fails if Jane has
  never logged into Seclore — there's no record to find.
- Same for assigning a Hot Folder owner.

**Decision rule:** if the integration only ever needs Policy Federation (access decisions made
dynamically by the application at open-time), User Search can be skipped. If the integration
needs **policy-based protection** — an admin proactively granting a named user or group access
ahead of time — User Search is required, regardless of which authentication mechanism (SAML,
OAuth, OIDC, or CRA) is in use.

**Protocol (generic web service / XML form):** request and response are plain XML over
HTTP(S), `application/xml` content-type, UTF-8 encoding, locale via the `Accept-Language`
header.

Request:
```xml
<custom-sso-request-search-user type="1">
  <custom-sso-request-header>
    <protocol-version>1</protocol-version>
    <request-id>{correlation id}</request-id>
  </custom-sso-request-header>
  <custom-sso-request-details-search-user>
    <!-- either user-id or email-id; both cannot be empty -->
    <user-id>testuser@dev.example.com</user-id>
    <email-id>testuser@dev.example.com</email-id>
  </custom-sso-request-details-search-user>
</custom-sso-request-search-user>
```

Response:
```xml
<custom-sso-response-search-user type="1">
  <custom-sso-response-header>
    <request-id>{same as request}</request-id>
    <status>1</status>
  </custom-sso-response-header>
  <custom-sso-response-details-search-user>
    <custom-sso-user-details>
      <name>Test User</name>           <!-- required -->
      <user-id>testuser@dev.example.com</user-id>   <!-- required -->
      <login-id>testuser@dev.example.com</login-id> <!-- required -->
      <email-id>testuser@dev.example.com</email-id> <!-- optional -->
    </custom-sso-user-details>
  </custom-sso-response-details-search-user>
</custom-sso-response-search-user>
```

If email is used as the user identifier, pass the same value in both `<user-id>` and
`<email-id>`.

---

## 7. Generic web-service-based authentication (no SAML/OAuth/OIDC, no redirect)

A simpler pattern than the pure-API CRA in Section 5 — used when Policy Server shows its own
native login form (rather than redirecting to the customer's system) and validates credentials
via a backend web service call.

1. User opens a protected file; Policy Server shows its standard login page (can carry the
   customer's logo).
2. User enters username/password.
3. Policy Server calls the customer's **Authenticate** web service with the credentials.
4. The customer's service verifies the credentials and returns a result.
5. Policy Server creates a session on success.

Two HTTP/XML services are required from the customer side: **Authenticate** and **Search
User** (the same User Search protocol as Section 6). Example endpoint naming, if the base
service URL is `https://dev.example.com/filesecure/services`:
- Authenticate: `.../authuser`
- Search user: `.../searchuserbyemailid`

**Authenticate request:**
```xml
<custom-repo-request-auth type="1">
  <custom-repo-request-header>
    <protocol-version>1</protocol-version>
    <request-id>{correlation id}</request-id>
  </custom-repo-request-header>
  <custom-repo-request-details-auth>
    <login-id>testuser@dev.example.com</login-id>
    <password>encryptedpassword</password>
  </custom-repo-request-details-auth>
</custom-repo-request-auth>
```

**Authenticate success response:**
```xml
<custom-repo-response-auth type="1">
  <custom-repo-response-header>
    <request-id>{same as request}</request-id>
    <status>1</status>
  </custom-repo-response-header>
  <custom-repo-response-details-auth>
    <custom-repo-user-details>
      <name>Test User</name>
      <login-id>testuser@dev.example.com</login-id>
      <email-id>testuser@dev.example.com</email-id>
    </custom-repo-user-details>
  </custom-repo-response-details-auth>
</custom-repo-response-auth>
```

**Authenticate failure response:**
```xml
<custom-repo-response-auth type="1">
  <custom-repo-response-header>
    <request-id>{same as request}</request-id>
    <status>-104</status>
    <error-message>Incorrect login credentials</error-message>
    <display-message>Incorrect login credentials. Please enter valid credentials or contact administrator.</display-message>
  </custom-repo-response-header>
</custom-repo-response-auth>
```

**Security note:** the password in the Authenticate request can be RSA-encrypted with a public
key configured in Policy Server and Base64-encoded.

---

## 8. Seclore-specific concepts — quick reference

**Repository:** the configuration entry in Policy Server that represents a customer's user
store — connection details, type, and credentials. Added by a Seclore Admin (GSA or Root)
under Configuration > Repositories.

**Repository Adaptor:** the component that does the actual work for a configured repository —
connects to the customer's user store, authenticates users, performs user/group search and
group-mapping, supports in-memory caching to reduce load on the customer's infrastructure, and
can enable SSO if the user already has an active domain session.

**Repository types:**

| Type | What it is |
|---|---|
| Active Directory (on-prem) | LDAP/LDAPS |
| Azure AD | Native SAML 2.0 / OAuth 2.0 / OpenID Connect support |
| Seclore Identity Manager (SIM) | Seclore's own external-user repository, OpenDJ-backed; used when the customer has no system of their own for external users; supports OTP, password, or MFA |
| Custom Repository | Any non-standard system, via a Custom Repository Adaptor |

**Authentication vs. Authorization, in Seclore terms:**
- **Authentication** establishes *who the user is* — handled by whichever mechanism the
  repository uses (LDAP bind, SAML assertion, OAuth/OIDC token exchange, or CRA callback).
- **Authorization** determines *what that user can do with a specific file* — handled by
  Seclore's permission framework (independent rights, policy-based control, or Policy
  Federation), which may itself depend on User Search to resolve the user/group being
  authorized.

**Why this distinction matters operationally:** a customer can have working authentication
(users can log in) and still hit a wall on authorization if they need policy-based protection
without a User Search API — see Section 6.

---

## 9. Conversation script — positioning to a customer

When a customer says "we use \<identity system X>, can you integrate with it":

1. Check whether X is a Tier 1 native repository (AD, Azure AD, or a known SAML IdP). If yes,
   no custom development needed.
2. If not, confirm it's a CRA engagement and ask which of SAML 2.0, OAuth 2.0, or OpenID
   Connect their system supports — use the matching CRA flavor.
3. If their system supports none of those — only a callable HTTP endpoint — use the pure
   API-based CRA (Section 5).
4. Separately, ask whether they need policy-based protection (proactive access grants before a
   user's first login) or only Policy Federation (access decided at open-time). If the former,
   a User Search API is required regardless of which option was picked in steps 1–3; if the
   latter, User Search can be skipped.

---

## 10. Frequently asked questions

**Does Seclore support MFA or fingerprint-based authentication?**
Seclore redirects to the customer's own login page for both SAML/OAuth/OIDC and CRA flows, so
authentication mechanism is entirely the customer's choice — password, MFA, biometric, smart
card, whatever they already run. From Seclore's side, everything between the redirect and the
auth response coming back is a black box: Policy Server doesn't participate in or care how the
customer authenticated the user, it only validates the response it gets back.

**How long does it take to build a CRA, and what does it cost?**
Budget roughly 4 weeks for development and testing of a Custom Repository Adaptor. Cost is a
commercial question — point the customer to their Seclore sales or customer success contact
rather than quoting a number yourself.

**Can the customer's IdP initiate the login (IdP-initiated auth)?**
No. Seclore's flows are all SP-initiated: the user opens a Seclore-protected file, and *that*
action triggers the redirect to the IdP. There's no equivalent of a user starting at a common
IdP portal and being pushed into a Seclore session — the trigger is always "a protected document
was opened," not "the IdP decided to start a session."

---

## 11. Worked example — split authentication and authorization sources

A useful pattern to recognize: authentication and authorization don't have to come from the same
system, and a customer may restrict access to one without restricting the other.

**Setup:** the customer ran AD/Azure AD for internal employees and a corporate LDAP for external
users (partners, contractors), with Ping Identity in front of both for SSO. They asked how
Seclore would handle authentication.

**Seclore's proposal:**
- **Authentication (both internal and external users):** integrate with Ping Identity via SAML
  2.0 — one IdP, one protocol, covering both user populations.
- **Authorization (user/group search):** connect directly to the customer's AD/Azure AD for
  internal users, and to the corporate LDAP for external users, so policies could reference
  named users and groups before they'd ever logged in.

**Where it landed:** the customer agreed to the SAML-via-Ping-Identity authentication proposal
for both groups, and agreed to expose AD/Azure AD for internal user/group search. They declined
to expose the corporate LDAP for external-user search, citing compliance — that data store
wasn't going to be queryable by Seclore, full stop.

**Resolution:** this is exactly the authentication/authorization split from Section 8 in
practice — losing the User Search path for external users didn't break authentication, but it
would have blocked policy-based protection for that population (Section 6). The fix kept SAML
via Ping Identity for *authentication* of external users unchanged, and replaced the
*authorization* source for that group:
- Internal users: AD/Azure AD + SAML (Ping Identity) — as originally proposed, unchanged.
- External users: Seclore Identity Manager (SIM) + SAML (Ping Identity). The customer synced
  the relevant subset of their corporate LDAP into Seclore's OpenDJ-backed SIM repository using
  SailPoint, so Seclore could search those users and groups for policy assignment without ever
  being granted direct access to the corporate LDAP itself.

**Why this works as a general pattern:** when a customer restricts access to their authorization
source but not their authentication source, look for a way to mirror just the needed user/group
data into a repository Seclore *is* allowed to query — SIM is the standard landing spot for that,
since it's Seclore-owned and the sync method (SailPoint or otherwise) is the customer's choice
and stays outside Seclore's integration surface.
