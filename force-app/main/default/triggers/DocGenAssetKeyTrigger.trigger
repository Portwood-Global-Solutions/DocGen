/**
 * Stamps an immutable, URL-safe system key onto a DocGen_Asset__c on insert when
 * the admin didn't supply one. The key is what the {%asset:<key>} merge tag
 * references, so it must be stable for the life of the asset — generate it once,
 * here, and never recompute it on update.
 *
 * Generation mirrors the signature-token pattern (Crypto.generateAesKey(256) +
 * SHA-256 digest, hex-encoded) but truncates to a short slug so the resulting
 * merge tag stays human-typable. Uniqueness is backed by the field's unique
 * index; the handler also de-dupes within the same insert batch.
 */
trigger DocGenAssetKeyTrigger on DocGen_Asset__c(before insert) {
    DocGenAssetKeyHandler.assignKeys(Trigger.new);
}
