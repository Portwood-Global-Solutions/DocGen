/**
 * Deprecated as of v1.98.0 — the Experience Cloud guest render path was
 * removed. Empty handler retained for 2GP packaging compatibility (triggers
 * are subject to the same Remove Metadata Components restriction as classes
 * for managed packages). No publishers exist for DocGen_Guest_Render__e, so
 * this trigger never fires at runtime.
 */
trigger DocGenGuestRenderTrigger on DocGen_Guest_Render__e(after insert) {
    // No-op — see trigger comment.
}
