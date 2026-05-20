/**
 * DocGenChartImageController
 *
 * Bridge between the runner LWC and the chart pipeline (#117). The LWC calls
 * `prepareChartImages` to get a list of SVG strings (one per top-level
 * {Chart:...} tag in the active Word template body) plus a stable signature
 * per chart. The LWC rasterizes each SVG to PNG via a hidden <canvas>, then
 * calls `uploadChartImage` to land each PNG as a ContentVersion. The
 * resulting `Map<signature, ContentVersionId>` is passed back into the merge
 * pipeline so DocGenChartTagExpander can substitute the chart tag with the
 * format-specific image markup. After generate completes, the LWC calls
 * `deleteChartImages` to reap the transient CVs.
 *
 * Scope (PR 1, DOCX + PDF):
 *   - Word template type only. HTML templates keep the existing CSS-bar
 *     path; PPT/Excel deferred to follow-up PRs.
 *   - Top-level {Chart:...} tags only — charts inside {#Loop}...{/Loop}
 *     bodies stay HTML-only because their bucket data depends on the loop
 *     iteration item, which isn't available pre-merge.
 *
 * Bucket cost: `prepareChartImages` issues a GROUP BY SOQL per chart that
 * falls into the SOQL-fallback path (>2000 child rows, `where=`, or
 * `groupBy=`). The subsequent generate transaction re-computes the same
 * buckets when DocGenService.processXml runs ChartBucket preprocessing.
 * Tolerable for v1 — chart SOQL is the bottleneck the existing 50-budget
 * already governs. A future PR can cache by signature to avoid the double.
 */
public with sharing class DocGenChartImageController {
    private static final String CHART_OPEN_PREFIX = '{Chart:';
    private static final String CV_TITLE_PREFIX = 'docgen_chart_';

    // Styles the SVG serializer can emit natively. Cross-tab styles
    // (pivot/clustered/stacked) currently flow through the HTML CSS-bar path
    // for HTML output and degrade to plain `bar` SVG for Word until their
    // PNG-via-CV emitters land in a follow-up commit.
    private static final Set<String> SVG_STYLES = new Set<String>{ 'bar', 'column', 'pie', 'donut' };

    /**
     * Discovers top-level chart tags in the active Word template body, resolves
     * each tag's buckets against the source record, and emits an SVG fragment
     * per chart. The LWC rasterizes the SVGs to PNGs and uploads them via
     * `uploadChartImage`.
     *
     * Returns an empty list for non-Word templates (HTML keeps CSS bars; PPT
     * and Excel are not yet wired to the PNG pipeline).
     */
    @AuraEnabled
    public static List<ChartImageRequest> prepareChartImages(Id templateId, Id recordId) {
        if (templateId == null || recordId == null) {
            throw DocGenService.ahe('Template and record IDs are required.');
        }

        // USER_MODE access check — caller must be able to see the template;
        // the catch converts the QueryException Salesforce throws on FLS
        // denial into a clean AuraHandledException for the LWC error banner.
        DocGen_Template__c template;
        try {
            List<DocGen_Template__c> templates = [
                SELECT Id, Type__c, Base_Object_API__c, Query_Config__c
                FROM DocGen_Template__c
                WHERE Id = :templateId
                WITH USER_MODE
                LIMIT 1
            ];
            if (templates.isEmpty()) {
                throw DocGenService.ahe('Template not found or access denied.');
            }
            template = templates[0];
        } catch (QueryException qe) {
            throw DocGenService.ahe('Template not found or access denied.');
        }

        if (template.Type__c != 'Word') {
            return new List<ChartImageRequest>();
        }

        String body = loadActiveWordBody(templateId);
        if (String.isBlank(body) || !body.contains(CHART_OPEN_PREFIX)) {
            return new List<ChartImageRequest>();
        }

        Map<String, Object> recordData = DocGenDataRetriever.getRecordData(
            recordId,
            template.Base_Object_API__c,
            template.Query_Config__c
        );

        List<ChartImageRequest> out = new List<ChartImageRequest>();
        for (ParsedChartTag tag : findTopLevelChartTags(body)) {
            ChartImageRequest req = renderChartAsRequest(tag, recordData);
            if (req != null) {
                out.add(req);
            }
        }
        return out;
    }

    /**
     * Saves a base64-encoded PNG as a ContentVersion linked to the source
     * record. Returns the CV Id for the LWC to pass back into the generate
     * call (and later into `deleteChartImages` for cleanup).
     *
     * Title shape: `docgen_chart_<recordId-15>_<signature-16>`. This lets the
     * cleanup schedulable reap orphans (browser-closed-mid-flow) with one
     * LIKE query without scanning the whole ContentVersion table.
     * FirstPublishLocationId is intentionally NULL so the chart PNG does not
     * show up in the source record's Files related list during the brief
     * window it exists.
     */
    @AuraEnabled
    public static Id uploadChartImage(Id recordId, String signature, String base64Png) {
        if (recordId == null || String.isBlank(signature) || String.isBlank(base64Png)) {
            throw DocGenService.ahe('Record ID, signature, and PNG data are required.');
        }
        if (signature.length() > 24 || !signature.replaceAll('[^A-Za-z0-9]', '').equalsIgnoreCase(signature)) {
            // Defense in depth: signature is concatenated into the CV title, so
            // restrict it to alphanumerics to prevent SOQL LIKE pattern abuse
            // from a tampered LWC payload. Real signatures are 16 hex chars.
            throw DocGenService.ahe('Invalid chart signature.');
        }
        String recordKey = String.valueOf(recordId).substring(0, 15);
        ContentVersion cv = new ContentVersion(
            Title = CV_TITLE_PREFIX + recordKey + '_' + signature,
            PathOnClient = 'chart.png',
            VersionData = EncodingUtil.base64Decode(base64Png)
        );
        // Package-internal transient chart CV; visibility is controlled by
        // standard ContentVersion sharing. Without this suppression, the
        // analyzer flags CRUD/FLS checks that don't apply to ContentVersion
        // (a standard object users always have insert access to).
        /* code-analyzer-suppress ApexFlsViolation */
        insert cv; // NOPMD ApexCRUDViolation
        return cv.Id;
    }

    /**
     * Reaps the transient chart CVs after the merge finishes. Idempotent —
     * silently skips IDs already deleted by the cleanup schedulable or by a
     * concurrent re-render.
     */
    @AuraEnabled
    public static void deleteChartImages(List<Id> cvIds) {
        if (cvIds == null || cvIds.isEmpty()) {
            return;
        }
        List<ContentVersion> existing;
        try {
            existing = [
                SELECT Id, ContentDocumentId, Title
                FROM ContentVersion
                WHERE Id IN :cvIds AND Title LIKE :(CV_TITLE_PREFIX + '%')
                WITH USER_MODE
            ];
        } catch (QueryException qe) {
            // Caller lacks access — treat as already-deleted, do not surface
            // a deletion error to the user-facing LWC.
            return;
        }
        if (existing.isEmpty()) {
            return;
        }
        Set<Id> docIds = new Set<Id>();
        for (ContentVersion cv : existing) {
            if (cv.ContentDocumentId != null) {
                docIds.add(cv.ContentDocumentId);
            }
        }
        if (!docIds.isEmpty()) {
            List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id IN :docIds WITH USER_MODE];
            if (!docs.isEmpty()) {
                // Cleanup of transient chart CVs the same caller just created
                // — the USER_MODE query above already enforces visibility; the
                // analyzer can't see that as a CRUD check.
                /* code-analyzer-suppress ApexFlsViolation */
                delete docs; // NOPMD ApexCRUDViolation
            }
        }
    }

    /**
     * Stable 16-hex-char signature for a chart tag. Same relationship/field/
     * style/options produces the same signature regardless of option order in
     * the source template — necessary because the LWC and the merge engine
     * each compute the signature independently from their own parse of the
     * tag, and both sides must agree on which CV maps to which tag.
     */
    public static String tagSignature(String relName, String fieldApi, String style, Map<String, String> options) {
        List<String> sortedKeys = new List<String>(options == null ? new Set<String>() : options.keySet());
        sortedKeys.sort();
        List<String> kvs = new List<String>();
        for (String k : sortedKeys) {
            kvs.add(k.toLowerCase() + '=' + options.get(k));
        }
        String basis =
            (relName == null ? '' : relName.toLowerCase()) +
            ':' +
            (fieldApi == null ? '' : fieldApi.toLowerCase()) +
            ':' +
            (style == null ? 'bar' : style.toLowerCase()) +
            ':' +
            String.join(kvs, '&');
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(basis));
        return EncodingUtil.convertToHex(digest).substring(0, 16);
    }

    // =====================================================================
    // Internals
    // =====================================================================

    private static String loadActiveWordBody(Id templateId) {
        List<DocGen_Template_Version__c> vs = [
            SELECT Id
            FROM DocGen_Template_Version__c
            WHERE Template__c = :templateId AND Is_Active__c = TRUE
            WITH USER_MODE
            LIMIT 1
        ];
        if (vs.isEmpty()) {
            return null;
        }
        String xmlTitle = 'docgen_tmpl_xml_' + vs[0].Id + '_word__document.xml';
        // SYSTEM_MODE on the pre-decomposed XML CV mirrors DocGenService:1306-1311:
        // it's a package-internal artifact, and the user-mode template access
        // check above is the gate that matters.
        /* code-analyzer-suppress ApexFlsViolation */
        List<ContentVersion> cvs = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Title = :xmlTitle AND IsLatest = TRUE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (cvs.isEmpty() || cvs[0].VersionData == null) {
            return null;
        }
        return cvs[0].VersionData.toString();
    }

    /**
     * Scans `body` for {Chart:...} tags at brace-depth 0 — i.e. not inside any
     * {#section}...{/section} block. Charts inside loop bodies are skipped
     * intentionally; their bucket data is loop-iteration-scoped and only
     * resolvable during processXml recursion. Returns the parsed pieces of
     * each top-level chart, in document order.
     */
    private static List<ParsedChartTag> findTopLevelChartTags(String body) {
        List<ParsedChartTag> out = new List<ParsedChartTag>();
        Integer len = body.length();
        Integer cursor = 0;
        Integer depth = 0;
        while (cursor < len) {
            Integer nextBrace = body.indexOf('{', cursor);
            if (nextBrace == -1) {
                break;
            }
            cursor = nextBrace;
            Integer tagClose = body.indexOf('}', cursor);
            if (tagClose == -1) {
                break;
            }
            String tagFull = body.substring(cursor, tagClose + 1);
            // Section opener / closer — track depth, skip everything inside.
            if (cursor + 2 <= len && body.substring(cursor, cursor + 2) == '{#') {
                depth++;
            } else if (cursor + 2 <= len && body.substring(cursor, cursor + 2) == '{/') {
                if (depth > 0) {
                    depth--;
                }
            } else if (depth == 0 && tagFull.startsWith(CHART_OPEN_PREFIX)) {
                ParsedChartTag parsed = parseChartTag(tagFull);
                if (parsed != null) {
                    out.add(parsed);
                }
            }
            cursor = tagClose + 1;
        }
        return out;
    }

    /**
     * Parses one {Chart:rel:field[:style[:opts]]} tag. Returns null when the
     * tag is malformed — prepareChartImages skips bad tags silently and lets
     * the main merge engine surface the same error during processXml (which
     * already has authoritative error reporting for chart tags).
     */
    private static ParsedChartTag parseChartTag(String fullTag) {
        // Strip leading "{Chart:" and trailing "}". `inner` is an Apex reserved
        // identifier; `tagInner` is the local name.
        String tagInner = fullTag.substring(CHART_OPEN_PREFIX.length(), fullTag.length() - 1);
        tagInner = decodeEntities(tagInner);
        List<String> parts = splitLimit(tagInner, ':', 4);
        if (parts.size() < 2) {
            return null;
        }
        ParsedChartTag t = new ParsedChartTag();
        t.relName = parts[0].trim();
        t.fieldApi = parts[1].trim();
        t.style = (parts.size() >= 3 && String.isNotBlank(parts[2])) ? parts[2].trim().toLowerCase() : 'bar';
        t.modifiersRaw = parts.size() >= 4 ? parts[3] : '';
        if (String.isBlank(t.relName) || String.isBlank(t.fieldApi)) {
            return null;
        }
        t.options = parseOptions(t.modifiersRaw);
        return t;
    }

    /**
     * Resolves buckets for one parsed chart tag and emits the SVG. Returns
     * null when the bucket resolution comes back empty AND there's no
     * `{:else}` fallback expected from the SVG emitter — the SVG emitter
     * still produces an "empty state" placeholder so the chart never silently
     * disappears, but at this layer a null guard would be safer if we ever
     * needed to filter zero-data charts from the LWC pipeline. For PR 1 we
     * always emit (and ship the placeholder) so authors see a clear "No data"
     * box rather than wondering why the chart is gone.
     */
    private static ChartImageRequest renderChartAsRequest(ParsedChartTag tag, Map<String, Object> recordData) {
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.resolveBucketsForTag(
            recordData,
            tag.relName,
            tag.fieldApi,
            tag.modifiersRaw
        );
        // The SVG serializer expects the style to be in the options map so its
        // dispatch can route by it. Styles known to the emitter ship per
        // follow-up commit; styles still served by the HTML+CSS path
        // (pivot/clustered/stacked cross-tabs) fall back to `bar` here so a
        // Word render still produces something visible rather than crashing.
        Map<String, String> svgOptions = new Map<String, String>();
        for (String k : tag.options.keySet()) {
            svgOptions.put(k, tag.options.get(k));
        }
        String svgStyle = (tag.style != null && SVG_STYLES.contains(tag.style)) ? tag.style : 'bar';
        svgOptions.put('style', svgStyle);
        String svg = DocGenSvgChartSerializer.emit(buckets, svgOptions);

        ChartImageRequest req = new ChartImageRequest();
        req.signature = tagSignature(tag.relName, tag.fieldApi, tag.style, tag.options);
        req.svgString = svg;
        req.width = svgOptions.containsKey('width') ? safeInt(svgOptions.get('width'), 500) : 500;
        // Match DocGenSvgChartSerializer.emitBar's height formula for non-titled,
        // non-overridden charts: title(0) + (n * 24) + 6.
        req.height = svgOptions.containsKey('height')
            ? safeInt(svgOptions.get('height'), 280)
            : Math.max(80, 6 + buckets.size() * 24);
        return req;
    }

    private static Integer safeInt(String raw, Integer fallback) {
        try {
            return Integer.valueOf(raw);
        } catch (Exception e) {
            return fallback;
        }
    }

    /**
     * Parses "k=v&k=v" into a Map. Mirrors DocGenChartTagExpander.parseOptions;
     * kept private here to avoid widening the expander's surface for one
     * internal helper.
     */
    private static Map<String, String> parseOptions(String raw) {
        Map<String, String> out = new Map<String, String>();
        if (String.isBlank(raw)) {
            return out;
        }
        for (String chunk : raw.split('&')) {
            Integer eq = chunk.indexOf('=');
            if (eq <= 0) {
                continue;
            }
            String k = chunk.substring(0, eq).trim();
            String v = chunk.substring(eq + 1).trim();
            if (String.isNotBlank(k)) {
                out.put(k, v);
            }
        }
        return out;
    }

    /**
     * Decode the same entity set DocGenChartTagExpander handles, so a Google-
     * Docs-exported template ({Chart:Rel:Field:bar:colors=#aaa&amp;width=400})
     * round-trips correctly through the pre-flight scan.
     */
    private static String decodeEntities(String s) {
        if (s == null || s.indexOf('&') == -1) {
            return s;
        }
        return s.replace('&amp;', '&')
            .replace('&lt;', '<')
            .replace('&gt;', '>')
            .replace('&quot;', '"')
            .replace('&apos;', '\'')
            .replace('&#39;', '\'')
            .replace('&#34;', '"')
            .replace('&#38;', '&');
    }

    private static List<String> splitLimit(String s, String delim, Integer maxParts) {
        List<String> out = new List<String>();
        if (s == null) {
            return out;
        }
        Integer cursor = 0;
        Integer len = s.length();
        while (out.size() < maxParts - 1) {
            Integer at = s.indexOf(delim, cursor);
            if (at == -1) {
                break;
            }
            out.add(s.substring(cursor, at));
            cursor = at + delim.length();
        }
        out.add(s.substring(cursor, len));
        return out;
    }

    /**
     * Payload returned to the LWC per chart tag found in the template body.
     */
    public class ChartImageRequest {
        @AuraEnabled
        public String signature;
        @AuraEnabled
        public String svgString;
        @AuraEnabled
        public Integer width;
        @AuraEnabled
        public Integer height;
    }

    private class ParsedChartTag {
        String relName;
        String fieldApi;
        String style;
        String modifiersRaw;
        Map<String, String> options;
    }
}
