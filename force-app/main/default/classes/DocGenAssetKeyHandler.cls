/**
 * Trigger handler for DocGen_Asset__c — stamps the immutable, human-readable
 * Asset_Key__c on insert. The key backs the {%asset:<key>} merge tag and the
 * field's unique external-id index, so it must be stable and unique.
 *
 * Keys are meant to be meaningful (e.g. "footer", "primary-logo") so a template
 * author can tell what a tag does at a glance. When the caller supplies a key we
 * canonicalize it (lowercase URL-safe slug); when it's blank we derive a slug
 * from the asset Name, falling back to a short random hex slug only if the name
 * yields no usable characters. Collisions are de-duped with a numeric suffix
 * (footer, footer-2, footer-3, ...) before the DML hits the unique index.
 *
 * normalizeKey is the single source of truth for the slug grammar — reused by
 * DocGenController.createAsset/checkAssetKey so the UI, Apex, and trigger all
 * agree on what a key looks like.
 */
public with sharing class DocGenAssetKeyHandler {
    // Max stored key length. The field allows 64; we cap slugs shorter so the
    // resulting merge tag stays comfortably typable.
    private static final Integer MAX_KEY_LENGTH = 40;

    // Length of the random hex fallback slug (only used when a name yields no
    // usable characters). 12 hex chars = 48 bits of entropy.
    private static final Integer FALLBACK_LENGTH = 12;

    /**
     * Canonicalizes a raw key (or any text) into a URL-safe slug: lowercased,
     * with every run of non-alphanumeric characters collapsed to a single
     * hyphen, leading/trailing hyphens stripped, capped at MAX_KEY_LENGTH.
     * Returns '' if nothing usable remains. This is the grammar the {%asset:<key>}
     * tag must match, so the resolver lowercases the tag key the same way.
     */
    public static String normalizeKey(String raw) {
        if (String.isBlank(raw)) {
            return '';
        }
        String slug = raw.trim().toLowerCase();
        // Collapse any run of chars that aren't a-z/0-9 into a single hyphen.
        slug = slug.replaceAll('[^a-z0-9]+', '-');
        // Strip leading/trailing hyphens.
        slug = slug.replaceAll('^-+', '').replaceAll('-+$', '');
        if (slug.length() > MAX_KEY_LENGTH) {
            slug = slug.substring(0, MAX_KEY_LENGTH).replaceAll('-+$', '');
        }
        return slug;
    }

    /**
     * Stamps Asset_Key__c on every record on insert. Called from the before-insert
     * trigger; public static so DocGenAssetTest can exercise generation/uniqueness
     * without DML round-trips.
     */
    public static void assignKeys(List<DocGen_Asset__c> assets) {
        if (assets == null || assets.isEmpty()) {
            return;
        }

        // Reserve keys already taken by existing records + earlier rows in this
        // batch so a derived/duplicate key gets a numeric suffix instead of
        // failing the unique index. The asset catalog is small (per-org config),
        // so reading existing keys here is cheap.
        Set<String> taken = new Set<String>();
        for (DocGen_Asset__c existing : [SELECT Asset_Key__c FROM DocGen_Asset__c]) {
            if (String.isNotBlank(existing.Asset_Key__c)) {
                taken.add(existing.Asset_Key__c.toLowerCase());
            }
        }

        for (DocGen_Asset__c asset : assets) {
            String supplied = normalizeKey(asset.Asset_Key__c);
            if (String.isNotBlank(supplied)) {
                // Caller chose a key (createAsset already enforced uniqueness for
                // the UI path); canonicalize it and only suffix on a genuine batch/
                // catalog collision so two inserts can't share a key.
                asset.Asset_Key__c = uniquify(supplied, taken);
            } else {
                // Blank (or unusable) key: derive a slug from the name, falling back
                // to random hex if the name has no alphanumerics.
                String base = normalizeKey(asset.Name);
                if (String.isBlank(base)) {
                    base = randomSlug();
                }
                asset.Asset_Key__c = uniquify(base, taken);
            }
            taken.add(asset.Asset_Key__c.toLowerCase());
        }
    }

    /**
     * Returns base if free, else base-2, base-3, ... — the first variant not in
     * the reserved set.
     */
    private static String uniquify(String base, Set<String> taken) {
        if (!taken.contains(base)) {
            return base;
        }
        Integer suffix = 2;
        String candidate = base + '-' + suffix;
        while (taken.contains(candidate)) {
            suffix++;
            candidate = base + '-' + suffix;
        }
        return candidate;
    }

    /**
     * Short, URL-safe random slug (0-9a-f) — fallback only, when a name yields no
     * usable characters to slugify.
     */
    private static String randomSlug() {
        Blob randomBytes = Crypto.generateAesKey(256);
        Blob hash = Crypto.generateDigest('SHA-256', randomBytes);
        return EncodingUtil.convertToHex(hash).substring(0, FALLBACK_LENGTH);
    }
}
