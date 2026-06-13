# Security Policy

## Supported Versions

| Version | Supported           |
| ------- | ------------------- |
| 1.1.x   | Yes                 |
| 1.0.x   | Security fixes only |
| < 1.0   | No                  |

## Reporting a Vulnerability

If you discover a security vulnerability in Portwood DocGen, **please do not open a public issue.**

Instead, report it privately:

1. **Email:** security@portwood.dev
2. **Subject:** `[SECURITY] <brief description>`
3. **Include:** Steps to reproduce, affected versions, and potential impact

You will receive an acknowledgment within 48 hours. We will work with you to understand the issue and coordinate a fix before any public disclosure.

## Security Design

DocGen is designed with Salesforce security best practices:

- **No external callouts.** All processing happens within the Salesforce platform. No data leaves the org.
- **CRUD/FLS enforcement.** All user-facing queries use `WITH USER_MODE` or `Security.stripInaccessible()`.
- **No session ID exposure.** The package never accesses or transmits `UserInfo.getSessionId()`.
- **Token-gated guest signing.** The optional e-signature flow exposes public Visualforce endpoints to Salesforce Site guest users. Guests have **no DocGen object CRUD** by design; every guest entry point validates a 64-char hex capability token (`DocGen_Signer__c.Secure_Token__c`), resolves the record by token equality, enforces a documented per-field allowlist (`DocGenFlsGuard.guestAssert*` + `DocGenSignatureGuestSecurity`), and runs SOQL/DML `WITH SYSTEM_MODE`. The token IS the access credential — see `DocGenSignatureGuestSecurity.cls` for the model.
- **Signer form fields & record writeback.** Admins may configure signer-filled form fields on a template; the guest persists ONLY the collected values as a validated JSON blob on the guest-writable field `DocGen_Signer__c.Field_Data_Json__c` (required enforced, types coerced, unknown keys dropped against the template config before write). The guest **never** performs DML on the base record. A platform event (`DocGen_Field_Writeback__e`), published by the signature finalizer only after the signed PDF is saved, is consumed by a trigger running as the Automated Process user; `DocGenFieldWritebackService.performWriteback` rebuilds the writable-field allowlist **server-side from the template config** (never from the guest JSON keys), re-checks `isUpdateable()` per field, and writes with `Database.update(..., allOrNone=false, AccessLevel.USER_MODE)` so the automation user's FLS + validation rules apply. Writeback failures are logged to `DocGen_Signature_Audit__c` and never re-thrown into the signing flow. Note: a signer cannot choose _which_ field is written (the target set is admin-configured and server-derived), but where an admin maps writeback onto a reference/lookup field (e.g. an owner or relationship field), the signer-supplied value influences that reference on the related record — treat such mappings as an admin-trust decision.
- **Permission-gated access.** All admin/user functionality requires the DocGen Admin or DocGen User permission set; guest signing requires the DocGen Guest Signature permission set assigned to the Site guest user.
- **Code Analyzer clean.** Scanned with `sf code-analyzer run --rule-selector "recommended"` — 0 Critical, 0 High violations.

## Responsible Disclosure

We follow responsible disclosure practices. If you report a vulnerability:

- We will not take legal action against you for the report
- We will work with you to understand and resolve the issue
- We will credit you in the release notes (unless you prefer to remain anonymous)
