/**
 * Trigger handler for DocGen_Asset__c — mints the immutable, URL-safe
 * Asset_Key__c on insert when the admin didn't supply one. The key backs the
 * {%asset:<key>} merge tag and the field's unique external-id index, so it must
 * be stable and collision-resistant.
 *
 * Key generation mirrors the signature-token pattern in
 * DocGenSignatureSenderController (Crypto.generateAesKey(256) + SHA-256 digest,
 * hex-encoded) but truncates the hex to a short slug so the resulting merge tag
 * stays human-typable. Within a single insert batch we also de-dupe defensively
 * before the DML hits the unique index.
 */
public with sharing class DocGenAssetKeyHandler {
    // Length of the generated key slug (hex chars). 12 hex chars = 48 bits of
    // entropy — ample for a per-org asset catalog, short enough to type into a
    // template tag. The field allows up to 64 chars for admin-supplied keys.
    private static final Integer KEY_LENGTH = 12;

    /**
     * Stamps Asset_Key__c on every record whose key is blank. Called from the
     * before-insert trigger; package-private static so DocGenAssetTest can
     * exercise generation/uniqueness without DML round-trips.
     */
    public static void assignKeys(List<DocGen_Asset__c> assets) {
        if (assets == null || assets.isEmpty()) {
            return;
        }
        // Track keys minted in this batch so two blank-key inserts in the same
        // transaction can't collide before the unique index sees them.
        Set<String> usedInBatch = new Set<String>();
        for (DocGen_Asset__c asset : assets) {
            if (String.isNotBlank(asset.Asset_Key__c)) {
                continue;
            }
            String key = generateAssetKey();
            while (usedInBatch.contains(key)) {
                key = generateAssetKey();
            }
            usedInBatch.add(key);
            asset.Asset_Key__c = key;
        }
    }

    /**
     * Mints one short, URL-safe key: a 256-bit CSPRNG block (Crypto.generateAesKey)
     * SHA-256 digested and hex-encoded, then truncated to KEY_LENGTH. Hex is
     * inherently URL-safe (0-9a-f) so no further escaping is needed.
     */
    private static String generateAssetKey() {
        Blob randomBytes = Crypto.generateAesKey(256);
        Blob hash = Crypto.generateDigest('SHA-256', randomBytes);
        return EncodingUtil.convertToHex(hash).substring(0, KEY_LENGTH);
    }
}
