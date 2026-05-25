#!/usr/bin/env node
/*
 * docgen-template-lint — preflight check for Portwood DocGen Word templates.
 *
 * Usage:
 *   node docgen-template-lint.js path/to/template.docx
 *   node docgen-template-lint.js path/to/template.docx --json   (machine-readable output)
 *
 * What it checks (all are common causes of broken merges, all are fixable
 * before upload):
 *
 *   1. Fragmented merge tags    A {Field} that's been split across multiple
 *                               <w:r> runs because of mid-tag editing in Word.
 *                               The merge engine's mergeRunsInTags() handles
 *                               most cases, but tags that mix run boundaries
 *                               with non-tag text in between (e.g. a number
 *                               inside an image tag) still break. Cleanest fix:
 *                               retype the tag in one continuous burst.
 *
 *   2. Loop tag pairing         Every {#Rel} must have a matching {/Rel}, and
 *                               every {/Rel} must have a matching {#Rel}.
 *                               For {#IF expr}…{/IF}, the engine balances by
 *                               the bare key "IF" (DocGenService line ~2002),
 *                               so this linter does the same.
 *                               Duplicates and orphans are flagged.
 *
 *   3. Closing-tag containment  For each {#Rel} … {/Rel} pair, the engine
 *                               picks the nearest <w:tr> that fully encloses
 *                               BOTH tags. If no such row exists, the engine
 *                               either falls back to a paragraph container or
 *                               degrades to inner-XML repeat — neither of
 *                               which is what most authors intend.
 *
 *   4. Closing tag placement    A {/Rel} that appears in the document body
 *                               outside any structural container (i.e. not
 *                               in a <w:tr> or numbered <w:p>) is almost
 *                               always a sign that the closing tag escaped
 *                               its intended cell during editing.
 *
 *   5. Nested loops on same     Two loops with the same relationship name
 *      relationship             nested inside each other will produce
 *                               unexpected output. Almost always a typo.
 *
 *   6. Empty / whitespace-only  A {#Rel} immediately followed by {/Rel} with
 *      loops                    no content. Usually leftover from a deleted
 *                               cell.
 *
 *   7. Row-binding collision    A nested {#}/{#IF} that ends up bound to the
 *                               SAME <w:tr> as its parent loop. Both fight
 *                               for the same container, producing broken
 *                               output. Fix: wrap the inner one in a
 *                               borderless single-cell mini-table so it
 *                               binds to the wrapper's row, leaving the
 *                               outer row intact for the parent loop.
 *
 *   8. Entity-encoded IF       In package versions BEFORE v1.69,
 *      operators                evaluateIfExpression() did not HTML-decode
 *                               the expression before parsing operators.
 *                               Word stores `>` / `<` in OOXML as `&gt;` /
 *                               `&lt;`, so {#IF Field > 0} arrived as
 *                               "Field &gt; 0" and the parser matched the
 *                               `=` inside `&gt;` — producing a mangled
 *                               expression that always evaluated false.
 *                               Fixed in v1.69. The check is left in place
 *                               so templates remain portable to customers
 *                               still on older versions.
 *
 *   9. Nested IF blocks         findBalancedEnd matches loop closers by
 *                               exact-string comparison; for {#IF expr}
 *                               blocks the balance key is just 'IF', so
 *                               the depth tracker doesn't recognize nested
 *                               {#IF expr} as a depth-increment. The outer
 *                               IF's search for {/IF} finds the first inner
 *                               {/IF} it sees and pairs them wrong, leading
 *                               to a confusing 'missing closing "" for ""'
 *                               error at runtime. Fixed in v1.72. The check
 *                               is left in place so templates remain
 *                               portable to customers still on older versions.
 *                               Workaround for older versions: don't nest
 *                               IFs — restructure to siblings, or use a
 *                               {^Rel}…{/Rel} inverse-loop wrapper (the
 *                               relationship name is the closer, not bare
 *                               'IF', so no collision).
 *
 * Exit codes: 0 = clean, 1 = errors found, 2 = invalid input
 *
 * No external dependencies. Tested on Node 18+. Uses only zlib and fs from
 * the Node standard library.
 */

'use strict';

const fs = require('fs');
const zlib = require('zlib');
const path = require('path');

// ─── Minimal DOCX (ZIP) reader, no deps ──────────────────────────────────────
// A .docx is a ZIP archive. We only need to read one file from it
// (word/document.xml), so we implement just enough of the ZIP format to do that.
// Spec: APPNOTE.TXT (PKWARE) — End of Central Directory + Central Directory.
function readDocxEntry(zipBuffer, entryName) {
  const sig = 0x06054b50;
  // Find End of Central Directory record (search backward; max comment = 65535)
  let eocdOffset = -1;
  const minOffset = Math.max(0, zipBuffer.length - 65535 - 22);
  for (let i = zipBuffer.length - 22; i >= minOffset; i--) {
    if (zipBuffer.readUInt32LE(i) === sig) { eocdOffset = i; break; }
  }
  if (eocdOffset === -1) throw new Error('Not a valid DOCX (no EOCD)');

  const cdSize = zipBuffer.readUInt32LE(eocdOffset + 12);
  const cdOffset = zipBuffer.readUInt32LE(eocdOffset + 16);

  // Walk central directory entries to find our file
  let p = cdOffset;
  const cdEnd = cdOffset + cdSize;
  while (p < cdEnd) {
    if (zipBuffer.readUInt32LE(p) !== 0x02014b50) break;
    const compMethod   = zipBuffer.readUInt16LE(p + 10);
    const compSize     = zipBuffer.readUInt32LE(p + 20);
    const fnLen        = zipBuffer.readUInt16LE(p + 28);
    const extraLen     = zipBuffer.readUInt16LE(p + 30);
    const commentLen   = zipBuffer.readUInt16LE(p + 32);
    const localOffset  = zipBuffer.readUInt32LE(p + 42);
    const filename     = zipBuffer.toString('utf8', p + 46, p + 46 + fnLen);

    if (filename === entryName) {
      // Read local file header to find data offset
      const lh = localOffset;
      if (zipBuffer.readUInt32LE(lh) !== 0x04034b50) throw new Error('Bad local header');
      const lhFnLen    = zipBuffer.readUInt16LE(lh + 26);
      const lhExtraLen = zipBuffer.readUInt16LE(lh + 28);
      const dataStart  = lh + 30 + lhFnLen + lhExtraLen;
      const compressed = zipBuffer.slice(dataStart, dataStart + compSize);
      if (compMethod === 0) return compressed;                       // stored
      if (compMethod === 8) return zlib.inflateRawSync(compressed);  // deflate
      throw new Error(`Unsupported compression method ${compMethod}`);
    }
    p += 46 + fnLen + extraLen + commentLen;
  }
  throw new Error(`Entry "${entryName}" not found in DOCX`);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
function buildVisibleTextWithMapping(xml) {
  // Concatenate all <w:t>…</w:t> contents into one string, building a
  // parallel array that maps each character back to its byte offset in xml.
  // This lets us search for merge tags in clean text and then translate
  // hits back to XML positions for structural analysis.
  let visible = '';
  const mapping = [];
  const re = /<w:t(?:\s[^>]*)?>([^<]*)<\/w:t>/g;
  let m;
  while ((m = re.exec(xml)) !== null) {
    const text = m[1];
    const start = m.index + m[0].indexOf('>', 0) + 1;  // first char of text
    for (let i = 0; i < text.length; i++) {
      visible += text[i];
      mapping.push(start + i);
    }
  }
  return { visible, mapping };
}

function findAllRawTags(xml) {
  // Find every {…} including ones with embedded XML (fragmented). The
  // non-greedy pattern stops at the first '}' but allows '<' '>' inside.
  const out = [];
  const re = /\{[^{}]*?\}/g;
  let m;
  while ((m = re.exec(xml)) !== null) {
    out.push({ raw: m[0], xmlStart: m.index, xmlEnd: m.index + m[0].length });
  }
  // We didn't catch fragmented tags above (the regex stops at '}' which can
  // appear in attributes). Use a second pass: find '{' positions and walk
  // forward through XML looking for an unescaped '}' as visible text.
  // For practical templates the first pass is enough; we trust that '}' is
  // rare in attributes. If we see contradictions later we can enhance this.
  return out;
}

function tagsFromVisibleText(visible, mapping) {
  // Find all {…} in the visible-text stream. These are the "logical" tags
  // — the ones the merge engine sees AFTER mergeRunsInTags() does its work.
  const tags = [];
  const re = /\{[^{}]+\}/g;
  let m;
  while ((m = re.exec(visible)) !== null) {
    tags.push({
      tag: m[0],
      visStart: m.index,
      visEnd: m.index + m[0].length,
      xmlStart: mapping[m.index],
      xmlEnd: mapping[m.index + m[0].length - 1] + 1,
    });
  }
  return tags;
}

function findFragmentedTags(xml) {
  // A merge tag is "fragmented" when its raw form in the XML byte stream
  // contains XML markup (<…>) that would have to be stripped for the engine
  // to see a clean tag. Simplest detection: scan for '{' followed (within
  // a reasonable window) by '}' where the slice between them contains '<'.
  const fragmented = [];
  let i = 0;
  while (i < xml.length) {
    const open = xml.indexOf('{', i);
    if (open === -1) break;
    // Only care if this '{' is within a <w:t> text run — otherwise it's
    // part of XML markup like {worksheet} or attribute syntax.
    // Simple heuristic: look at the 8 chars before '{'; if we see "<w:t"
    // somewhere recently without an intervening "</w:t>", we're inside text.
    const recent = xml.slice(Math.max(0, open - 200), open);
    const lastOpen = recent.lastIndexOf('<w:t');
    const lastClose = recent.lastIndexOf('</w:t>');
    if (lastOpen === -1 || lastOpen < lastClose) { i = open + 1; continue; }

    // Find the next '}' anywhere (could be far if fragmented)
    const close = xml.indexOf('}', open);
    if (close === -1) break;

    const between = xml.slice(open + 1, close);
    if (between.includes('<') || between.includes('>')) {
      // Reconstruct the visible text inside this span (strip XML tags)
      const visible = between.replace(/<[^>]+>/g, '');
      fragmented.push({
        xmlStart: open,
        xmlEnd: close + 1,
        rawSnippet: xml.slice(open, close + 1).slice(0, 120),
        reconstructed: '{' + visible + '}',
      });
    }
    i = close + 1;
  }
  return fragmented;
}

function findMatchingPairs(tags) {
  // Given the array of clean tags, build a list of {#Rel}/{/Rel} pairs.
  // Use a stack: push opens, pop on matching close. Anything left on the
  // stack at the end is an unmatched open; closes that don't match the
  // stack top are reported as unmatched closes (with a hint about possible
  // duplicate).
  //
  // SPECIAL CASE: {#IF expr} … {/IF}
  // The merge engine treats the expression-bearing IF opener as having the
  // closing key "IF" (DocGenService.cls line ~2002 — `balanceKey = 'IF'`
  // when key starts with "IF "). Replicate that here so we don't false-
  // positive on `{/IF}` not matching `{#IF Foo > 0}`.
  function balanceKey(rel) {
    const trimmed = rel.trim();
    if (trimmed === 'IF' || /^IF\s/i.test(trimmed)) return 'IF';
    return rel;
  }

  const opens = [];
  const pairs = [];
  const unmatchedCloses = [];

  for (const t of tags) {
    if (t.tag.startsWith('{#') || t.tag.startsWith('{^')) {
      // Both {#X} and {^X} are openers from the engine's perspective —
      // findBalancedEnd in DocGenService treats `content.equals('#' + key)`
      // and `content.equals('^' + key)` as equivalent depth-up cases.
      // We track the opener variant so we can label pairs as inverse.
      const rel = t.tag.slice(2, -1);
      const variant = t.tag[1];   // '#' or '^'
      opens.push({ rel, key: balanceKey(rel), variant, ...t });
    } else if (t.tag.startsWith('{/')) {
      const rel = t.tag.slice(2, -1);
      const key = balanceKey(rel);
      // Find the most recent open with matching balance key
      let found = -1;
      for (let j = opens.length - 1; j >= 0; j--) {
        if (opens[j].key === key) { found = j; break; }
      }
      if (found >= 0) {
        pairs.push({ rel: opens[found].rel, open: opens[found], close: t });
        opens.splice(found, 1);
      } else {
        unmatchedCloses.push({ rel, ...t });
      }
    }
    // Other tags (field, image, barcode, conditional, etc.) ignored here
  }

  return { pairs, unmatchedOpens: opens, unmatchedCloses };
}

function findEnclosingRow(xml, openXmlOffset, closeXmlEnd) {
  // Replicate the engine's logic from extractLoopBody / processXml:
  // walk backward from openXmlOffset to find the nearest <w:tr> opening
  // such that:
  //   - </w:tr> for that opening is at offset >= closeXmlEnd (fully
  //     encloses both tags), AND
  //   - no </w:tr> appears between the chosen <w:tr> and openXmlOffset
  //     (i.e. the open tag isn't already past the row's close).
  //
  // We use a depth-tracking forward walk to build a list of (start, end)
  // <w:tr> ranges, then pick the smallest range that contains both tags.
  const ranges = [];
  const stack = [];
  const re = /<(\/?)w:tr(?=[\s>])/g;
  let m;
  while ((m = re.exec(xml)) !== null) {
    if (m[1] === '') stack.push(m.index);
    else if (stack.length > 0) {
      const start = stack.pop();
      const end = m.index + 7; // </w:tr> length
      ranges.push([start, end]);
    }
  }
  // Find smallest range that encloses both
  let best = null;
  for (const [s, e] of ranges) {
    if (s < openXmlOffset && e >= closeXmlEnd) {
      if (best === null || (e - s) < (best[1] - best[0])) best = [s, e];
    }
  }
  return best; // null if no enclosing row
}

function isInsideAnyContainer(xml, offset) {
  // Returns the kind of container the offset is inside, or null.
  // We check (in priority order) <w:tc>, <w:tr>, <w:p> with <w:numPr>.
  // We use a simple counting approach: count opens vs closes of each tag
  // before offset; if more opens than closes, the offset is inside.
  function countOpenMinusClose(tag) {
    const re = new RegExp(`<${tag}(?=[\\s>])`, 'g');
    const closeRe = new RegExp(`</${tag}>`, 'g');
    const before = xml.slice(0, offset);
    return (before.match(re) || []).length - (before.match(closeRe) || []).length;
  }
  if (countOpenMinusClose('w:tc') > 0) return 'w:tc';
  if (countOpenMinusClose('w:tr') > 0) return 'w:tr';
  if (countOpenMinusClose('w:p') > 0) {
    // Crude check: is there a <w:numPr> in the current paragraph?
    const lastP = xml.lastIndexOf('<w:p>', offset);
    const lastPClosed = xml.lastIndexOf('</w:p>', offset);
    if (lastP > lastPClosed) {
      const pSnippet = xml.slice(lastP, offset);
      if (pSnippet.includes('<w:numPr')) return 'w:p (list)';
    }
    return 'w:p';
  }
  return null;
}

// ─── Main lint function ─────────────────────────────────────────────────────
function lintTemplate(docxPath) {
  const issues = [];
  const info = [];

  if (!fs.existsSync(docxPath)) {
    return { ok: false, issues: [{ severity: 'error', code: 'FILE_NOT_FOUND', message: `File not found: ${docxPath}` }], info: [] };
  }

  let xml;
  try {
    const buf = fs.readFileSync(docxPath);
    xml = readDocxEntry(buf, 'word/document.xml').toString('utf8');
  } catch (err) {
    return { ok: false, issues: [{ severity: 'error', code: 'DOCX_READ_FAILED', message: err.message }], info: [] };
  }

  // --- Check 1: fragmented tags --------------------------------------------
  const fragmented = findFragmentedTags(xml);
  if (fragmented.length > 0) {
    for (const f of fragmented) {
      issues.push({
        severity: 'error',
        code: 'FRAGMENTED_TAG',
        message: `Merge tag is split across multiple Word runs: ${f.reconstructed}`,
        hint: 'Delete the entire tag in Word and retype it in one continuous burst, without backspacing or formatting changes mid-tag.',
        xmlOffset: f.xmlStart,
      });
    }
  }

  // Build text-only stream for clean tag analysis
  const { visible, mapping } = buildVisibleTextWithMapping(xml);
  const tags = tagsFromVisibleText(visible, mapping);

  info.push({ code: 'TAG_COUNT', message: `${tags.length} clean merge tags found` });

  // --- Check 2: loop pairing ------------------------------------------------
  const { pairs, unmatchedOpens, unmatchedCloses } = findMatchingPairs(tags);

  for (const o of unmatchedOpens) {
    issues.push({
      severity: 'error',
      code: 'UNMATCHED_OPEN',
      message: `Loop opener {#${o.rel}} has no matching closing tag {/${o.rel}}`,
      hint: 'Add the closing tag, or delete the opener if it was leftover.',
      xmlOffset: o.xmlStart,
    });
  }

  // Detect duplicate closes by looking at the unmatched closes
  for (const c of unmatchedCloses) {
    issues.push({
      severity: 'error',
      code: 'UNMATCHED_CLOSE',
      message: `Loop closer {/${c.rel}} has no matching opener {#${c.rel}} (possible duplicate)`,
      hint: 'You probably have a stray {/' + c.rel + '} from a copy/paste. Delete the duplicate.',
      xmlOffset: c.xmlStart,
    });
  }

  info.push({ code: 'PAIR_COUNT', message: `${pairs.length} matched loop pair(s)` });

  // --- Check 3 + 4: structural placement of pairs ---------------------------
  for (const pair of pairs) {
    const enclosingRow = findEnclosingRow(xml, pair.open.xmlStart, pair.close.xmlEnd);
    const closeContainer = isInsideAnyContainer(xml, pair.close.xmlStart);

    if (!enclosingRow) {
      // No <w:tr> encloses both. Check if both are in some other container.
      if (closeContainer === null) {
        issues.push({
          severity: 'error',
          code: 'CLOSE_TAG_FLOATING',
          message: `Closing tag {/${pair.rel}} is not inside any structural container (table row, cell, or paragraph)`,
          hint: 'The closing tag has escaped its intended cell. Cut it and paste it back inside the same cell as the opening tag, or inside the cell that contains the related sub-table.',
          xmlOffset: pair.close.xmlStart,
        });
      } else {
        issues.push({
          severity: 'warning',
          code: 'NO_ENCLOSING_ROW',
          message: `No <w:tr> encloses both {#${pair.rel}} and {/${pair.rel}}`,
          hint: 'The merge engine will fall back to paragraph-level repeat. This is usually fine for non-table loops but unexpected for table-based templates. If you want a table row to repeat, both loop tags must live inside cells of the same row (or inside a single cell that contains the entire repeat block).',
          xmlOffset: pair.open.xmlStart,
        });
      }
    } else {
      // Enclosing row found. Inform about the chosen row size.
      const [s, e] = enclosingRow;
      info.push({
        code: 'LOOP_BOUND',
        message: `{${pair.open.variant || '#'}${pair.rel}} … {/${pair.rel}} → bound to <w:tr> spanning ${e - s} chars (offset ${s}–${e})`,
      });
    }
  }

  // --- Check 5: nested same-rel loops --------------------------------------
  // Two pairs over the same relationship nested inside each other is usually
  // a typo. The exception is the inverse-loop conditional pattern:
  //
  //   {^Rel}{:else} ... {#Rel}…{/Rel} ... {/Rel}
  //
  // where the outer is an inverse opener {^Rel} (used as a "render once when
  // non-empty" wrapper via the {:else} branch) and the inner is the actual
  // forward loop {#Rel}. This is the canonical workaround for the totalSize
  // null-vs-zero bug, so we allow it. We still flag two forward {#Rel} loops
  // nested into each other (the original typo case) and two inverse {^Rel}
  // loops nested into each other (would also be a typo).
  for (let i = 0; i < pairs.length; i++) {
    for (let j = 0; j < pairs.length; j++) {
      if (i === j) continue;
      if (pairs[i].rel !== pairs[j].rel) continue;
      const a = pairs[i], b = pairs[j];
      if (a.open.xmlStart < b.open.xmlStart && a.close.xmlEnd > b.close.xmlEnd) {
        // a contains b. Allow {^Rel}…{#Rel}…{/Rel}…{/Rel}.
        if (a.open.variant === '^' && b.open.variant === '#') continue;
        issues.push({
          severity: 'error',
          code: 'NESTED_SAME_REL',
          message: `Two loops over "${a.rel}" are nested inside each other`,
          hint: 'This is almost always a typo. Did you mean to nest a different relationship inside? (Exception: the canonical inverse-loop conditional pattern {^Rel}{:else}…{#Rel}…{/Rel}…{/Rel} is allowed.)',
          xmlOffset: b.open.xmlStart,
        });
      }
    }
  }

  // --- Check 7: row-binding collision --------------------------------------
  // When two loops/conditionals are nested AND bind to the same <w:tr>, the
  // engine processes them as competing repeats over the same container,
  // which produces broken output. The fix is to wrap the inner one in its
  // own borderless single-cell mini-table so it binds to the wrapper's row
  // instead of the outer row.
  const pairsWithRows = pairs.map(pair => ({
    pair,
    row: findEnclosingRow(xml, pair.open.xmlStart, pair.close.xmlEnd),
  })).filter(x => x.row !== null);

  for (let i = 0; i < pairsWithRows.length; i++) {
    for (let j = 0; j < pairsWithRows.length; j++) {
      if (i === j) continue;
      const outer = pairsWithRows[i];
      const inner = pairsWithRows[j];
      // Is inner nested inside outer's content?
      if (outer.pair.open.xmlStart < inner.pair.open.xmlStart &&
          outer.pair.close.xmlEnd > inner.pair.close.xmlEnd) {
        // Same row binding?
        if (outer.row[0] === inner.row[0] && outer.row[1] === inner.row[1]) {
          issues.push({
            severity: 'error',
            code: 'ROW_BINDING_COLLISION',
            message: `{#${inner.pair.rel}} is nested inside {#${outer.pair.rel}} but both bind to the same <w:tr> (offset ${outer.row[0]}–${outer.row[1]})`,
            hint: 'Wrap the inner conditional/loop and its content in a borderless single-cell mini-table so the inner tag binds to the mini-table row instead of fighting the outer loop for the same container.',
            xmlOffset: inner.pair.open.xmlStart,
          });
        }
      }
    }
  }

  // --- Check 6: empty loops -------------------------------------------------
  for (const pair of pairs) {
    const innerVis = visible.slice(pair.open.visEnd, pair.close.visStart).trim();
    if (innerVis.length === 0) {
      issues.push({
        severity: 'warning',
        code: 'EMPTY_LOOP',
        message: `Loop {#${pair.rel}} … {/${pair.rel}} has no content between the tags`,
        hint: 'The loop will iterate but produce no output. Probably leftover from a deleted cell.',
        xmlOffset: pair.open.xmlStart,
      });
    }
  }

  // --- Check 8: entity-encoded IF operators --------------------------------
  // The package's evaluateIfExpression() does not HTML-decode its expression
  // before parsing operators. Word stores `>` and `<` in OOXML as `&gt;` and
  // `&lt;` (since they're reserved XML characters), so an IF written as
  // `{#IF Field > 0}` arrives at the parser as `Field &gt; 0` and the parser
  // matches the `=` inside `&gt;` as the operator. Result: a mangled
  // expression that always evaluates false.
  //
  // To detect this, we scan the RAW XML (not the visible text stream) for
  // `{#IF ... &gt; ...}` or `{#IF ... &lt; ...}` patterns. The `=` and `!=`
  // operators are unaffected since they don't contain `>` or `<`.
  const entityIfPattern = /\{#[Ii][Ff]\s+[^}]*?(&gt;|&lt;)[^}]*?\}/g;
  let entityMatch;
  while ((entityMatch = entityIfPattern.exec(xml)) !== null) {
    const fullTag = entityMatch[0];
    const entity = entityMatch[1];
    const decoded = entity === '&gt;' ? '>' : '<';
    issues.push({
      severity: 'error',
      code: 'IF_ENTITY_ENCODED_OPERATOR',
      message: `IF expression uses '${decoded}' which is HTML-encoded as '${entity}' in OOXML — the package's IF parser does not decode entities before parsing operators, so this expression will always evaluate false: ${fullTag}`,
      hint: `Rewrite the condition using '!=' or '=' (which don't get HTML-encoded). Example: instead of {#IF Field > 0}, use {#IF Field != 0}. Both are equivalent for non-negative count fields. This bug is in evaluateIfExpression() and would be fixed by adding entity-decode before operator parsing.`,
      xmlOffset: entityMatch.index,
    });
  }

  // --- Check 9: nested IF blocks ------------------------------------------
  // findBalancedEnd in DocGenService matches loop closers via exact-string
  // comparison: content.equals('#' + key) where key is normalized to 'IF'
  // for IF expressions. That means the depth tracker treats every
  // {#IF expr} as 'not equal to #IF', so it does NOT increment depth for
  // nested IFs. The outer {#IF}'s search for {/IF} finds the FIRST {/IF}
  // it sees — which belongs to the innermost nested IF — and pairs them
  // incorrectly. The parser then runs from a corrupted state and
  // ultimately throws an "empty quotes" error: missing closing "" for "".
  // Fixed in v1.72; this check stays in place for back-compat with older
  // installs.
  const ifPairs = pairs.filter(p => /^IF(\s|$)/i.test(p.rel));
  for (let i = 0; i < ifPairs.length; i++) {
    for (let j = 0; j < ifPairs.length; j++) {
      if (i === j) continue;
      const outer = ifPairs[i];
      const inner = ifPairs[j];
      if (outer.open.xmlStart < inner.open.xmlStart &&
          outer.close.xmlEnd > inner.close.xmlEnd) {
        issues.push({
          severity: 'error',
          code: 'NESTED_IF_BLOCKS',
          message: `IF block {#${inner.rel}} is nested inside IF block {#${outer.rel}} — package versions before v1.72 cannot disambiguate nested IFs and will incorrectly pair the inner {/IF} with the outer {#IF}, corrupting the parser state. Upgrade to v1.72+ to use nested IFs natively.`,
          hint: `On v1.72+ this works natively. For older installs: restructure to avoid nested IFs. Options: (a) remove the outer IF and accept that the section renders unconditionally; (b) replace one IF with a direct {#Rel}…{/Rel} loop where the relationship name closes with itself instead of bare {/IF}; (c) use {^Rel} inverse loops which also close with the relationship name.`,
          xmlOffset: inner.open.xmlStart,
        });
      }
    }
  }

  return {
    ok: issues.filter(i => i.severity === 'error').length === 0,
    issues,
    info,
  };
}

// ─── CLI ─────────────────────────────────────────────────────────────────────
function colorize(text, color) {
  if (!process.stdout.isTTY) return text;
  const codes = { red: 31, yellow: 33, green: 32, gray: 90, bold: 1 };
  return `\x1b[${codes[color] || 0}m${text}\x1b[0m`;
}

function formatHuman(result, docxPath) {
  const lines = [];
  lines.push(colorize(`docgen-template-lint  ${docxPath}`, 'bold'));
  lines.push('');

  for (const inf of result.info) {
    lines.push(colorize(`  ℹ  ${inf.message}`, 'gray'));
  }

  if (result.issues.length === 0) {
    lines.push('');
    lines.push(colorize('  ✓ No issues found. Template structure looks clean.', 'green'));
    return lines.join('\n');
  }

  lines.push('');
  for (const issue of result.issues) {
    const color = issue.severity === 'error' ? 'red' : 'yellow';
    const sym = issue.severity === 'error' ? '✗' : '⚠';
    lines.push(colorize(`  ${sym}  [${issue.code}] ${issue.message}`, color));
    if (issue.hint) lines.push(colorize(`       ${issue.hint}`, 'gray'));
    if (issue.xmlOffset !== undefined) lines.push(colorize(`       (XML offset ${issue.xmlOffset})`, 'gray'));
    lines.push('');
  }

  const errs = result.issues.filter(i => i.severity === 'error').length;
  const warns = result.issues.filter(i => i.severity === 'warning').length;
  lines.push(colorize(`  Summary: ${errs} error(s), ${warns} warning(s)`, errs > 0 ? 'red' : 'yellow'));
  return lines.join('\n');
}

function main() {
  const args = process.argv.slice(2);
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log('Usage: node docgen-template-lint.js <template.docx> [--json]');
    console.log('');
    console.log('Pre-flight check for Portwood DocGen Word templates.');
    console.log('Detects fragmented merge tags, loop tag pairing issues,');
    console.log('and structural placement problems before you upload.');
    process.exit(args.length === 0 ? 2 : 0);
  }

  const jsonMode = args.includes('--json');
  const docxPath = args.find(a => !a.startsWith('--'));

  if (!docxPath) { console.error('No template path given'); process.exit(2); }

  const result = lintTemplate(docxPath);

  if (jsonMode) {
    console.log(JSON.stringify({ file: docxPath, ...result }, null, 2));
  } else {
    console.log(formatHuman(result, docxPath));
  }
  process.exit(result.ok ? 0 : 1);
}

if (require.main === module) main();

module.exports = { lintTemplate };
