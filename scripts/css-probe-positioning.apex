// Does Flying Saucer (Blob.toPdf) honour absolute positioning?
//
// This decides whether a Canva-style pixel-exact canvas can render at all. Each
// box declares a KNOWN offset. If positioning works the boxes land apart at the
// declared coordinates; if it is ignored they stack in document order at the top
// left, which is visually unmistakable.

String html =
    '<!DOCTYPE html><html><head><meta charset="utf-8"/><style>' +
    '@page { size: Letter portrait; margin: 0.5in; }' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 10pt; color: #111; }' +
    '.stage { position: relative; width: 7.5in; height: 4in; border: 1pt solid #333; }' +
    '.abs { position: absolute; background: #ffd400; border: 1pt solid #000; padding: 4pt; }' +
    '.a1 { left: 0.25in; top: 0.25in; width: 1.6in; }' +
    '.a2 { left: 3.00in; top: 1.30in; width: 1.6in; }' +
    '.a3 { left: 5.40in; top: 2.60in; width: 1.6in; }' +
    '.rel { position: relative; left: 2in; background: #9fd7ff; border: 1pt solid #000; padding: 4pt; width: 2in; }' +
    '.fix { position: fixed; left: 1in; top: 9in; background: #ffb3b3; border: 1pt solid #000; padding: 4pt; }' +
    '.flt { float: right; width: 1.8in; background: #c8f7c5; border: 1pt solid #000; padding: 4pt; }' +
    '</style></head><body>' +
    '<p><b>PROBE 1 — position:absolute inside position:relative</b></p>' +
    '<div class="stage">' +
    '<div class="abs a1">ABS A &mdash; L0.25 T0.25</div>' +
    '<div class="abs a2">ABS B &mdash; L3.00 T1.30</div>' +
    '<div class="abs a3">ABS C &mdash; L5.40 T2.60</div>' +
    '</div>' +
    '<p><b>PROBE 2 — position:relative offset</b></p>' +
    '<div class="rel">REL &mdash; shifted left:2in</div>' +
    '<p><b>PROBE 3 — float:right</b></p>' +
    '<div><div class="flt">FLOAT RIGHT</div>Body text beside the float.</div>' +
    '<div class="fix">FIXED &mdash; L1 T9</div>' +
    '</body></html>';

Blob pdf = Blob.toPdf(html);
ContentVersion cv = new ContentVersion(
    Title = 'probe_position_' + Datetime.now().getTime(),
    PathOnClient = 'probe-position.pdf',
    VersionData = pdf
);
insert cv;
System.debug('OUTCV ' + [SELECT Id FROM ContentVersion WHERE Id = :cv.Id].Id + ' size=' + pdf.size());
