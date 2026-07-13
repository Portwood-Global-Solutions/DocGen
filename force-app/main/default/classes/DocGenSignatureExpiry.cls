/**
 * Single source of truth for signature-link expiration.
 *
 * Requests stamp Expires_At__c at send/resend time (org default from
 * DocGen_Settings__c.Signature_Expiration_Days__c, or a per-send override).
 * Enforcement everywhere goes through isExpired(). Requests created before the
 * field existed have a null Expires_At__c and keep the legacy 48-hour lifetime
 * from CreatedDate — deliberately NOT the new setting, so upgrading the package
 * never silently shortens or lengthens in-flight links.
 */
public with sharing class DocGenSignatureExpiry {
    /** Pre-Expires_At__c requests live this long from CreatedDate. Do not change. */
    @TestVisible
    private static final Integer LEGACY_EXPIRATION_HOURS = 48;

    private static final Integer DEFAULT_DAYS = 2;
    private static final Integer MAX_DAYS = 365;

    /** Org default from settings, clamped to 1–365; 2 days when unset. */
    public static Integer defaultDays() {
        DocGen_Settings__c s = DocGen_Settings__c.getOrgDefaults();
        Decimal configured = s != null ? s.Signature_Expiration_Days__c : null;
        if (configured == null || configured < 1 || configured > MAX_DAYS) {
            return DEFAULT_DAYS;
        }
        return configured.intValue();
    }

    public static Integer defaultHours() {
        return defaultDays() * 24;
    }

    /**
     * Expiry timestamp for a request being sent now. overrideDays (per-send /
     * Flow input) wins when valid; otherwise the org default applies.
     */
    public static Datetime computeExpiry(Integer overrideDays) {
        Integer days = (overrideDays != null &&
            overrideDays >= 1 &&
            overrideDays <= MAX_DAYS)
            ? overrideDays
            : defaultDays();
        return System.now().addHours(days * 24);
    }

    /**
     * The one expiration check. Pass the request's stamped Expires_At__c and the
     * record's CreatedDate (request or signer — signers are created with their
     * request, so either works for the legacy fallback).
     */
    public static Boolean isExpired(Datetime expiresAt, Datetime createdDate) {
        if (expiresAt != null) {
            return expiresAt < System.now();
        }
        return createdDate != null && createdDate.addHours(LEGACY_EXPIRATION_HOURS) < System.now();
    }

    /**
     * Whole-hours lifetime for the {ExpirationHours} email token: hours from now
     * until expiresAt (minimum 1 so a nearly-expired link never says "0 hours"),
     * or the legacy 48 when no stamp exists.
     */
    public static Integer effectiveHours(Datetime expiresAt) {
        if (expiresAt == null) {
            return LEGACY_EXPIRATION_HOURS;
        }
        Long msLeft = expiresAt.getTime() - System.now().getTime();
        Integer hours = (Integer) (msLeft / (1000 * 60 * 60));
        return hours < 1 ? 1 : hours;
    }
}
