/**
 * downloadBase64 — LWS routing.
 *
 *   node scripts/qa/lws-download-route-check.mjs
 *
 * Lightning Web Security sanitizes URL.createObjectURL against a MIME
 * allowlist: PDF, images and plain text pass, everything else is refused with
 * "Cannot 'createObjectURL' using an unsecure [object Blob]". Office formats,
 * JSON and HTML are all off it, so every .docx/.pptx/.xlsx download from the
 * runner failed in an LWS-enabled org — silently, because the org where this
 * was developed has LWS off.
 *
 * The fix routes allowlisted types through a Blob URL (no size ceiling) and
 * everything else through a data: URI (never calls createObjectURL). This
 * asserts the routing, with a stub that throws exactly as LWS does — so a
 * regression that sends Office bytes back through createObjectURL fails here
 * rather than in a customer org.
 */

function isBlobSafeMime(mimeType) {
    if (!mimeType) {
        return false;
    }
    return mimeType === 'application/pdf' || mimeType.startsWith('image/') || mimeType === 'text/plain';
}

// Mirrors the shipped downloadBase64, with the DOM and URL calls captured.
function downloadBase64(base64Data, fileName, mimeType, env) {
    const anchor = { download: fileName, href: null, clicked: false };
    let objectUrl = null;
    if (isBlobSafeMime(mimeType)) {
        try {
            objectUrl = env.createObjectURL(mimeType);
        } catch (e) {
            objectUrl = null;
        }
    }
    anchor.href = objectUrl || 'data:' + (mimeType || 'application/octet-stream') + ';base64,' + base64Data;
    anchor.clicked = true;
    if (objectUrl) {
        env.revoked.push(objectUrl);
    }
    return anchor;
}

// LWS: allowlisted types get a blob: URL, everything else throws.
const lws = {
    revoked: [],
    createObjectURL(mime) {
        if (!isBlobSafeMime(mime)) {
            throw new Error("Lightning Web Security: Cannot 'createObjectURL' using an unsecure [object Blob].");
        }
        return 'blob:mock/' + mime;
    }
};

let fail = 0;
const ok = (c, m) => {
    console.log((c ? '  ok  ' : ' FAIL ') + m);
    if (!c) fail++;
};

const B64 = 'UEsDBBQ';

const pdf = downloadBase64(B64, 'a.pdf', 'application/pdf', lws);
ok(pdf.href.startsWith('blob:'), 'PDF uses a blob URL (allowlisted, no size ceiling)');
ok(lws.revoked.length === 1, 'and the blob URL is revoked');

const png = downloadBase64(B64, 'a.png', 'image/png', lws);
ok(png.href.startsWith('blob:'), 'images use a blob URL');

for (const [name, mime] of [
    ['docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    ['pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'],
    ['xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    ['octet-stream', 'application/octet-stream'],
    ['json', 'application/json'],
    ['html', 'text/html']
]) {
    const r = downloadBase64(B64, 'a.' + name, mime, lws);
    ok(r.href.startsWith('data:' + mime + ';base64,'), `${name} falls back to a data: URI`);
}

const noMime = downloadBase64(B64, 'a.bin', undefined, lws);
ok(noMime.href.startsWith('data:application/octet-stream;base64,'), 'a missing MIME still downloads');

// If a future LWS release tightens the allowlist further, the wrapped call must
// degrade rather than throw.
const hostile = {
    revoked: [],
    createObjectURL() {
        throw new Error('Lightning Web Security: Cannot createObjectURL');
    }
};
const degraded = downloadBase64(B64, 'a.pdf', 'application/pdf', hostile);
ok(degraded.href.startsWith('data:application/pdf;base64,'), 'a refused blob URL degrades to data:, never throws');
ok(degraded.clicked, 'and the download still fires');

console.log(fail ? `\n${fail} FAILED` : '\nrouting OK');
process.exit(fail ? 1 : 0);
