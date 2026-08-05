/**
 * The Canvas scene graph, and the only place that knows how it becomes HTML.
 *
 * WHY A MODEL AND NOT THE DOM
 * ---------------------------
 * The existing designer treats the rendered DOM as the document: it reads the canvas
 * back with innerHTML and re-parses it. Under Lightning Web Security's per-namespace
 * sandbox that has repeatedly bitten us — `ChildNode.replaceWith` missing on proxied
 * nodes, `cloneNode(true)` silently dropping browser-inserted nodes — because the
 * browser is allowed to restructure contenteditable output and LWS distorts what you
 * read back.
 *
 * Here the model is the truth. Boxes are plain objects with inch coordinates; the DOM
 * is a projection of them that is thrown away and re-rendered. Nothing is ever parsed
 * back out of the live tree, so there is no tree to be distorted. contenteditable
 * survives only INSIDE a single text box, where the browser's restructuring can't
 * escape the box it belongs to.
 *
 * UNITS
 * -----
 * The model stores INCHES because that is what the PDF is measured in and what the
 * author is really choosing. Pixels appear only at render time (inches x 96 x zoom),
 * so changing zoom can never drift the document — a class of bug the old caret/marker
 * code had to divide the zoom back out of by hand at every site.
 */

/** CSS reference pixels per inch. Fixed by the CSS spec, not by the display. */
export const PX_PER_IN = 96;

/** Page geometry in inches, content area only (page size minus 0.5in margins). */
const PAGE_GEOMETRY = {
    'Letter|portrait': { css: 'Letter portrait', w: 7.5, h: 10 },
    'Letter|landscape': { css: 'Letter landscape', w: 10, h: 7.5 },
    'A4|portrait': { css: 'A4 portrait', w: 7.27, h: 10.69 },
    'A4|landscape': { css: 'A4 landscape', w: 10.69, h: 7.27 },
    'Legal|portrait': { css: 'Legal portrait', w: 7.5, h: 13 },
    'Legal|landscape': { css: 'Legal landscape', w: 13, h: 7.5 }
};

export function pageGeometry(pageSize, orientation) {
    const key = (pageSize || 'Letter') + '|' + (orientation || 'Portrait').toLowerCase();
    return PAGE_GEOMETRY[key] || PAGE_GEOMETRY['Letter|portrait'];
}

let seq = 0;
/** Ids are per-session only — they never reach the serialized document. */
function nextId(prefix) {
    seq += 1;
    return prefix + '_' + seq;
}

export function newTextBox(xIn, yIn, wIn, hIn) {
    return {
        id: nextId('box'),
        kind: 'text',
        // `pinned` boxes are position:absolute and land exactly where dropped.
        // `flow` boxes sit in normal flow so their content can paginate — that is
        // how a {#Loop} of 60 rows spills onto the next page instead of being
        // clipped at the artboard edge.
        mode: 'pinned',
        x: round3(xIn),
        y: round3(yIn),
        w: round3(wIn),
        h: round3(hIn),
        html: 'Text'
    };
}

export function newArtboard() {
    return { id: nextId('board'), boxes: [] };
}

export function blankDocument() {
    return { artboards: [newArtboard()] };
}

function round3(n) {
    return Math.round(n * 1000) / 1000;
}

export function inToPx(inches, zoom) {
    return inches * PX_PER_IN * (zoom || 1);
}

export function pxToIn(px, zoom) {
    return round3(px / (PX_PER_IN * (zoom || 1)));
}

/**
 * Clamps a box inside its artboard. Width and height are preserved where possible —
 * a box dragged off the right edge slides back in rather than being squashed, which
 * is what every design tool does and what authors expect.
 */
export function clampBox(box, geo) {
    const w = Math.min(box.w, geo.w);
    const h = Math.min(box.h, geo.h);
    return {
        ...box,
        w: round3(w),
        h: round3(h),
        x: round3(Math.max(0, Math.min(box.x, geo.w - w))),
        y: round3(Math.max(0, Math.min(box.y, geo.h - h)))
    };
}

// ---------------------------------------------------------------------------
// Serialization — model -> the CANVAS_CSS contract
// ---------------------------------------------------------------------------

/**
 * Every rule below was measured against a real Blob.toPdf render, not assumed.
 * See scripts/canvas-layout-model-probe.apex and docs/canvas-layout-model-p*.png.
 *
 *   min-height, never height   a pinned height is OVERRUN by growing merge content
 *                              instead of growing with it
 *   page-break-BEFORE          on each artboard after the first. page-break-after on
 *                              the previous one gets swallowed when a flow region
 *                              spills, and the next artboard then paints its pinned
 *                              boxes on top of the overflow
 */
export function buildCanvasCss(geo) {
    return (
        '@page { size: ' +
        geo.css +
        '; margin: 0.5in; }\n' +
        'body { font-family: Helvetica, Arial, sans-serif; font-size: 11pt; color: #1a1a1a; margin: 0; }\n' +
        '.dg-artboard { position: relative; width: ' +
        geo.w +
        'in; min-height: ' +
        geo.h +
        'in; }\n' +
        '.dg-artboard_break { page-break-before: always; }\n' +
        '.dg-pin { position: absolute; }\n' +
        '.dg-flow { position: relative; }\n' +
        'table { border-collapse: collapse; width: 100%; -fs-table-paginate: paginate; }\n' +
        'thead { display: table-header-group; }\n' +
        'td, th { border: 0.5pt solid #999; padding: 2pt 4pt; }\n'
    );
}

function boxToHtml(box) {
    if (box.mode === 'flow') {
        // No top/left: a flow box is placed by the normal flow, and its margin-left
        // is what keeps it visually where the author put it horizontally.
        return (
            '<div class="dg-flow" style="margin: ' +
            box.y +
            'in 0 0 ' +
            box.x +
            'in; width: ' +
            box.w +
            'in;">' +
            box.html +
            '</div>'
        );
    }
    // Height is deliberately NOT emitted for a pinned box. Declaring it would cap the
    // box and let merged content overflow past its own background and border; leaving
    // it off lets the box grow to whatever the merge produces. The model still tracks
    // h so the editor can show a real rectangle to drag.
    return (
        '<div class="dg-pin" style="left: ' +
        box.x +
        'in; top: ' +
        box.y +
        'in; width: ' +
        box.w +
        'in;">' +
        box.html +
        '</div>'
    );
}

export function serialize(doc, geo) {
    const boards = doc.artboards
        .map((b, i) => {
            const cls = i === 0 ? 'dg-artboard' : 'dg-artboard dg-artboard_break';
            const inner = b.boxes.map(boxToHtml).join('\n  ');
            return '<div class="' + cls + '" data-dg-artboard="' + (i + 1) + '">\n  ' + inner + '\n</div>';
        })
        .join('\n');
    return (
        '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8" />\n<style>\n' +
        buildCanvasCss(geo) +
        '</style>\n</head>\n<body>\n' +
        boards +
        '\n</body>\n</html>\n'
    );
}

// ---------------------------------------------------------------------------
// Deserialization — the CANVAS_CSS contract -> model
// ---------------------------------------------------------------------------

function readInches(style, prop) {
    const m = new RegExp(prop + '\\s*:\\s*(-?[0-9.]+)in').exec(style || '');
    return m ? parseFloat(m[1]) : null;
}

/**
 * Reads a stored Canvas body back into the model.
 *
 * Parses from a detached <template> rather than by touching the live canvas — the
 * same discipline the upload path already uses, and the reason LWS node distortion
 * cannot reach this.
 *
 * Returns null when the body is not canvas-shaped, so the caller can tell "empty new
 * template" from "someone pointed this at an HTML template" instead of silently
 * showing a blank artboard over content that is really still there.
 */
export function deserialize(html) {
    if (!html || html.indexOf('dg-artboard') === -1) {
        return null;
    }
    const tpl = document.createElement('template');
    tpl.innerHTML = html;
    const boards = [...tpl.content.querySelectorAll('.dg-artboard')];
    if (!boards.length) {
        return null;
    }
    return {
        artboards: boards.map((boardEl) => {
            const board = newArtboard();
            board.boxes = [...boardEl.querySelectorAll('.dg-pin, .dg-flow')].map((el) => {
                const style = el.getAttribute('style') || '';
                const isFlow = el.classList.contains('dg-flow');
                const box = newTextBox(0, 0, 2, 0.5);
                box.mode = isFlow ? 'flow' : 'pinned';
                box.w = readInches(style, 'width') || 2;
                if (isFlow) {
                    // margin: <top>in 0 0 <left>in
                    const m = /margin:\s*(-?[0-9.]+)in\s+0\s+0\s+(-?[0-9.]+)in/.exec(style);
                    box.y = m ? parseFloat(m[1]) : 0;
                    box.x = m ? parseFloat(m[2]) : 0;
                } else {
                    box.x = readInches(style, 'left') || 0;
                    box.y = readInches(style, 'top') || 0;
                }
                // Height is never serialized (see boxToHtml) — recover a sensible
                // editing rectangle instead of collapsing the box to nothing.
                box.h = readInches(style, 'height') || 0.5;
                box.html = el.innerHTML;
                return box;
            });
            return board;
        })
    };
}
