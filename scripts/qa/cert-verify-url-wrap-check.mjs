/**
 * Certificate of Completion — verify-URL wrapping.
 *
 *   node scripts/qa/cert-verify-url-wrap-check.mjs
 *
 * The certificate page is drawn with pdf-lib, not HTML, so none of the renderer's
 * word-wrap CSS reaches it — drawText puts everything on one line at a fixed x
 * and runs straight off the sheet. The verify URL overflows every time rather
 * than occasionally: it carries an unguessable token and has no spaces to break
 * at.
 *
 * This mirrors drawWrappedText from DocGenSignaturePdf.page against a width
 * model, so the algorithm is covered without a browser. What matters is that it
 * terminates, never exceeds the line, loses no characters — a dropped character
 * makes the URL silently wrong rather than visibly broken — and reports the y it
 * finished on, so the sentence below moves down instead of landing on top of it.
 */

// Rough Helvetica advance ratio. Exactness is irrelevant: the logic under test
// is the line-breaking, not the metrics, and the real font object supplies those.
const AVG = 0.5;
const font = { widthOfTextAtSize: (s, size) => s.length * size * AVG };

function drawWrappedText(sink, text, opts) {
    const { font: f, size, maxWidth, lineHeight } = opts;
    let y = opts.y;
    let line = '';
    const words = String(text).split(' ');
    const flush = () => {
        if (line !== '') {
            sink.push(line);
            y -= lineHeight;
            line = '';
        }
    };
    for (let w = 0; w < words.length; w++) {
        const candidate = line === '' ? words[w] : line + ' ' + words[w];
        if (f.widthOfTextAtSize(candidate, size) <= maxWidth) {
            line = candidate;
            continue;
        }
        flush();
        const token = words[w];
        if (f.widthOfTextAtSize(token, size) <= maxWidth) {
            line = token;
            continue;
        }
        let chunk = '';
        for (let c = 0; c < token.length; c++) {
            if (f.widthOfTextAtSize(chunk + token[c], size) > maxWidth) {
                sink.push(chunk);
                y -= lineHeight;
                chunk = '';
            }
            chunk += token[c];
        }
        line = chunk;
    }
    flush();
    return y;
}

let fail = 0;
const ok = (c, m) => {
    console.log((c ? '  ok  ' : ' FAIL ') + m);
    if (!c) fail++;
};

const MAX = 504; // 612pt Letter width less two 54pt margins
const SIZE = 7.5;
const LH = 10;

const url =
    'https://portwood-demo.my.site.com/apex/portwoodglobal__DocGenVerify?token=5aafdea1ab3c8433b527b7bf21cd94e80f515d541d05209c7102ad9f1e2b3c4d5';
let lines = [];
let endY = drawWrappedText(lines, url, { font, size: SIZE, maxWidth: MAX, lineHeight: LH, y: 300 });
ok(lines.length > 1, `long URL wraps (${lines.length} lines)`);
ok(lines.join('') === url, 'no characters lost or duplicated');
ok(
    lines.every((l) => font.widthOfTextAtSize(l, SIZE) <= MAX),
    'every line fits the 504pt line width'
);
ok(endY === 300 - lines.length * LH, `y advanced by exactly ${lines.length} lines (${endY})`);

lines = [];
endY = drawWrappedText(lines, 'https://short.example.com/v?t=1', {
    font,
    size: SIZE,
    maxWidth: MAX,
    lineHeight: LH,
    y: 300
});
ok(lines.length === 1, 'a short URL stays on one line');
ok(endY === 290, 'and still advances y once');

lines = [];
drawWrappedText(lines, '', { font, size: SIZE, maxWidth: MAX, lineHeight: LH, y: 300 });
ok(lines.length === 0, 'empty string draws nothing');

console.log(fail ? `\n${fail} FAILED` : '\nwrap OK');
process.exit(fail ? 1 : 0);
