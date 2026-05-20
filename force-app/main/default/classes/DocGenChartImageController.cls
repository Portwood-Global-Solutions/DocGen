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

    // Styles both DocGenSvgChartSerializer AND DocGenChartRasterizer can emit.
    // Any tag whose style is in this set keeps its style end-to-end through
    // both the browser-canvas and the pure-Apex raster paths. Styles outside
    // this set (e.g. `pivot`, future `scatter`) degrade to plain `bar` so a
    // render still produces something visible rather than crashing.
    private static final Set<String> SVG_STYLES = new Set<String>{
        'bar',
        'column',
        'pie',
        'donut',
        'stacked',
        'clustered',
        'line',
        'area'
    };

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

        // Template-metadata lookup in SYSTEM_MODE matches the rest of
        // DocGenController (managed-package metadata; the FLS gate on the
        // chart's TARGET object data lives downstream in
        // DocGenDataRetriever.getRecordData and the bucket-resolver SOQL).
        /* code-analyzer-suppress ApexFlsViolation */
        List<DocGen_Template__c> templates = [
            SELECT Id, Type__c, Base_Object_API__c, Query_Config__c
            FROM DocGen_Template__c
            WHERE Id = :templateId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (templates.isEmpty()) {
            throw DocGenService.ahe('Template not found or access denied.');
        }
        DocGen_Template__c template = templates[0];

        if (template.Type__c != 'Word' && template.Type__c != 'HTML') {
            return new List<ChartImageRequest>();
        }

        String body = template.Type__c == 'HTML' ? loadActiveHtmlBody(templateId) : loadActiveWordBody(templateId);
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
     * Server-side equivalent of `prepareChartImages` — rasterizes each
     * top-level {Chart:...} tag in the active Word body to a PNG entirely in
     * Apex (no browser, no canvas, no callouts), uploads each PNG as a
     * transient `docgen_chart_*` ContentVersion, and returns the chartCvMap
     * the merge pipeline already understands: `signature -> "cvId|WxH"`.
     *
     * Same map shape the LWC currently produces after rasterizing SVGs in a
     * hidden <canvas>; lets Flow actions, batch jobs, Queueables, and bulk
     * runners produce Word/PDF charts without a DOM. Pairs with
     * `DocGenChartRasterizer.emitWithMeta` (PNG + logical dimensions).
     *
     * Cleanup contract: the CALLER owns the returned CV ids. They get the
     * full map back and decide when to call `deleteChartImages` (typically
     * in a try/finally around `processAndReturnDocument`). The
     * `docgen_chart_*` title prefix also lets the orphan-reaper schedulable
     * clean up if the caller dies mid-flow.
     *
     * Returns an empty map for non-Word templates and for templates whose
     * active body has no {Chart:...} tags — same early-exit semantics as
     * `prepareChartImages`.
     */
    @AuraEnabled
    public static Map<String, String> prepareChartImagesServerSide(Id templateId, Id recordId) {
        if (templateId == null || recordId == null) {
            throw DocGenService.ahe('Template and record IDs are required.');
        }

        // SYSTEM_MODE template-metadata lookup — matches prepareChartImages
        // and the rest of DocGenController. The actual FLS gate on the
        // chart's TARGET-object data lives downstream in
        // DocGenDataRetriever.getRecordData and the bucket-resolver SOQL.
        /* code-analyzer-suppress ApexFlsViolation */
        List<DocGen_Template__c> templates = [
            SELECT Id, Type__c, Base_Object_API__c, Query_Config__c
            FROM DocGen_Template__c
            WHERE Id = :templateId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (templates.isEmpty()) {
            throw DocGenService.ahe('Template not found or access denied.');
        }
        DocGen_Template__c template = templates[0];

        Map<String, String> chartCvMap = new Map<String, String>();
        // Word AND HTML templates both flow through the PNG-via-CV pipeline.
        // PowerPoint/Excel use their own embedding helpers in DocGenService;
        // they're routed via Apex callers that pass templateType explicitly,
        // not through this LWC entry point.
        if (template.Type__c != 'Word' && template.Type__c != 'HTML') {
            return chartCvMap;
        }

        String body = template.Type__c == 'HTML' ? loadActiveHtmlBody(templateId) : loadActiveWordBody(templateId);
        if (String.isBlank(body) || !body.contains(CHART_OPEN_PREFIX)) {
            return chartCvMap;
        }

        Map<String, Object> recordData = DocGenDataRetriever.getRecordData(
            recordId,
            template.Base_Object_API__c,
            template.Query_Config__c
        );

        for (ParsedChartTag tag : findTopLevelChartTags(body)) {
            // Mirror renderChartAsRequest's style normalization so cross-tab
            // styles still produce a Word-embeddable PNG (degrades to `bar`
            // for now; pivot/clustered/stacked PNG emitters land in a
            // follow-up).
            List<Map<String, Object>> buckets = DocGenChartBucketResolver.resolveBucketsForTag(
                recordData,
                tag.relName,
                tag.fieldApi,
                tag.modifiersRaw
            );
            Map<String, String> rasterOpts = new Map<String, String>();
            for (String k : tag.options.keySet()) {
                rasterOpts.put(k, tag.options.get(k));
            }
            String rasterStyle = (tag.style != null && SVG_STYLES.contains(tag.style)) ? tag.style : 'bar';
            rasterOpts.put('style', rasterStyle);
            // Default scale=1 for the server-side path. The rasterizer's
            // bar/column emitters default to 2x supersampling which is great
            // for one-off browser-canvas rasterization but blows the 10s sync
            // CPU budget when stacking multiple charts in one Apex
            // transaction (single 6-bucket bar at scale=2 measured ~11s on
            // staging). The author can still opt back in per-tag via
            // `:scale=2` for higher quality when chart count is low.
            if (!rasterOpts.containsKey('scale')) {
                rasterOpts.put('scale', '1');
            }

            Map<String, Object> meta = DocGenChartRasterizer.emitWithMeta(buckets, rasterOpts);
            Blob png = (Blob) meta.get('png');
            Integer logicalW = (Integer) meta.get('logicalWidth');
            Integer logicalH = (Integer) meta.get('logicalHeight');
            if (png == null) {
                continue;
            }

            String signature = tagSignature(tag.relName, tag.fieldApi, tag.style, tag.options);
            String base64Png = EncodingUtil.base64Encode(png);
            Id cvId = uploadChartImage(recordId, signature, base64Png);
            chartCvMap.put(signature, String.valueOf(cvId) + '|' + logicalW + 'x' + logicalH);
        }
        return chartCvMap;
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
        /* code-analyzer-suppress ApexFlsViolation */
        List<DocGen_Template_Version__c> vs = [
            SELECT Id
            FROM DocGen_Template_Version__c
            WHERE Template__c = :templateId AND Is_Active__c = TRUE
            WITH SYSTEM_MODE
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
     * HTML template body loader — pulls the raw template HTML from the CV
     * referenced by the active version's Content_Version_Id__c. Mirrors the
     * load path DocGenService uses (see line 7300+) so chart-tag scanning
     * sees the same body text the merge engine processes.
     */
    private static String loadActiveHtmlBody(Id templateId) {
        /* code-analyzer-suppress ApexFlsViolation */
        List<DocGen_Template_Version__c> vs = [
            SELECT Id, Content_Version_Id__c
            FROM DocGen_Template_Version__c
            WHERE Template__c = :templateId AND Is_Active__c = TRUE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (vs.isEmpty() || String.isBlank(vs[0].Content_Version_Id__c)) {
            return null;
        }
        Id sourceCvId = (Id) vs[0].Content_Version_Id__c;
        /* code-analyzer-suppress ApexFlsViolation */
        List<ContentVersion> cvs = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Id = :sourceCvId
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
        // Parse the actual emitted dimensions out of the <svg ...> root so
        // the LWC rasterizes at the right size AND the Word substitution gets
        // accurate WxH for {%FieldName:WxH} sizing. Each style auto-computes
        // its own height (bar grows by bucket count, pie/donut by legend
        // length, etc.), so the SVG itself is the source of truth.
        Integer parsedW = parseSvgDimension(svg, 'width');
        Integer parsedH = parseSvgDimension(svg, 'height');
        req.width = parsedW > 0 ? parsedW : 500;
        req.height = parsedH > 0 ? parsedH : 200;
        return req;
    }

    /**
     * Pulls `width="N"` or `height="N"` out of the SVG root element. The
     * emitter always sets these as the first attributes, so a simple
     * substring search is enough — no XML parsing needed.
     */
    private static Integer parseSvgDimension(String svg, String attr) {
        if (svg == null) {
            return 0;
        }
        String needle = attr + '="';
        Integer at = svg.indexOf(needle);
        if (at == -1 || at > 100) {
            return 0;
        }
        Integer start = at + needle.length();
        Integer endAt = svg.indexOf('"', start);
        if (endAt == -1) {
            return 0;
        }
        try {
            return Integer.valueOf(svg.substring(start, endAt));
        } catch (Exception e) {
            return 0;
        }
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
