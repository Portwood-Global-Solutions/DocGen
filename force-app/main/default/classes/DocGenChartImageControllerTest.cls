@IsTest
private class DocGenChartImageControllerTest {
    // -------------------------------------------------------------------------
    // tagSignature — must be deterministic and order-independent so the LWC
    // and the merge-side expander hash the same tag to the same key.
    // -------------------------------------------------------------------------

    @IsTest
    static void tagSignature_isDeterministic() {
        Map<String, String> opts = new Map<String, String>{ 'colors' => '#aaa,#bbb', 'width' => '500' };
        String sig1 = DocGenChartImageController.tagSignature('Survey_Responses__r', 'A__c', 'bar', opts);
        String sig2 = DocGenChartImageController.tagSignature('Survey_Responses__r', 'A__c', 'bar', opts);
        System.assertEquals(sig1, sig2, 'Same inputs must hash to same signature.');
        System.assertEquals(16, sig1.length(), 'Signature is 16 hex chars.');
    }

    @IsTest
    static void tagSignature_isOrderIndependent() {
        Map<String, String> a = new Map<String, String>{ 'colors' => '#aaa,#bbb', 'width' => '500' };
        Map<String, String> b = new Map<String, String>{ 'width' => '500', 'colors' => '#aaa,#bbb' };
        System.assertEquals(
            DocGenChartImageController.tagSignature('R__r', 'F__c', 'bar', a),
            DocGenChartImageController.tagSignature('R__r', 'F__c', 'bar', b),
            'Option insertion order must not affect the signature.'
        );
    }

    @IsTest
    static void tagSignature_differentInputs_differentSignatures() {
        Map<String, String> opts = new Map<String, String>();
        String sBar = DocGenChartImageController.tagSignature('R__r', 'F__c', 'bar', opts);
        String sPivot = DocGenChartImageController.tagSignature('R__r', 'F__c', 'pivot', opts);
        System.assertNotEquals(sBar, sPivot, 'Style must affect the signature.');

        String sF1 = DocGenChartImageController.tagSignature('R__r', 'F1__c', 'bar', opts);
        String sF2 = DocGenChartImageController.tagSignature('R__r', 'F2__c', 'bar', opts);
        System.assertNotEquals(sF1, sF2, 'Field must affect the signature.');
    }

    @IsTest
    static void tagSignature_nullOptions_handled() {
        // Defensive: a malformed call should not NPE — the controller's
        // own parseOptions never returns null but Apex callers might.
        String sig = DocGenChartImageController.tagSignature('R__r', 'F__c', 'bar', null);
        System.assertNotEquals(null, sig);
        System.assertEquals(16, sig.length());
    }

    // -------------------------------------------------------------------------
    // uploadChartImage / deleteChartImages — happy-path round trip.
    // -------------------------------------------------------------------------

    @IsTest
    static void uploadAndDelete_roundTrip() {
        Account acc = new Account(Name = 'Chart Pipeline Test');
        insert acc;

        // Tiny base64-encoded 1x1 PNG (transparent).
        String tinyPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkAAIAAAoAAv/lxKUAAAAASUVORK5CYII=';
        String sig = 'abcdef1234567890';

        Test.startTest();
        Id cvId = DocGenChartImageController.uploadChartImage(acc.Id, sig, tinyPng);
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'Upload should return a CV Id.');
        ContentVersion cv = [
            SELECT Id, Title, PathOnClient, FirstPublishLocationId, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cvId
        ];
        System.assert(cv.Title.startsWith('docgen_chart_'), 'Title must use the reaper-friendly prefix.');
        System.assert(cv.Title.endsWith('_' + sig), 'Title must end with the signature.');
        System.assertEquals('chart.png', cv.PathOnClient);
        // FirstPublishLocationId defaults to the running user's Id when not set,
        // which is fine — what matters is the source record getting no
        // ContentDocumentLink, so the chart PNG never appears on the record's
        // Files related list.
        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :cv.ContentDocumentId AND LinkedEntityId = :acc.Id
        ];
        System.assertEquals(0, links.size(), 'Chart CV must not be linked to the source record Files tab.');

        DocGenChartImageController.deleteChartImages(new List<Id>{ cvId });

        List<ContentVersion> after = [SELECT Id FROM ContentVersion WHERE Id = :cvId];
        System.assertEquals(0, after.size(), 'CV should be deleted after cleanup.');
    }

    @IsTest
    static void uploadChartImage_validatesInputs() {
        Account acc = new Account(Name = 'Chart Pipeline Test');
        insert acc;

        Boolean caught = false;
        try {
            DocGenChartImageController.uploadChartImage(null, 'abc', 'data');
        } catch (AuraHandledException e) {
            caught = true;
        }
        System.assert(caught, 'Null recordId must throw.');

        caught = false;
        try {
            DocGenChartImageController.uploadChartImage(acc.Id, '', 'data');
        } catch (AuraHandledException e) {
            caught = true;
        }
        System.assert(caught, 'Blank signature must throw.');

        caught = false;
        try {
            DocGenChartImageController.uploadChartImage(acc.Id, 'abc', '');
        } catch (AuraHandledException e) {
            caught = true;
        }
        System.assert(caught, 'Blank PNG data must throw.');
    }

    @IsTest
    static void uploadChartImage_rejectsNonAlphanumericSignature() {
        // Defense in depth: the signature is concatenated into the CV title
        // (used by the cleanup reaper's LIKE query), so we reject anything
        // that could smuggle a LIKE pattern in.
        Account acc = new Account(Name = 'Chart Pipeline Test');
        insert acc;
        String tinyPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkAAIAAAoAAv/lxKUAAAAASUVORK5CYII=';

        Boolean caught = false;
        try {
            DocGenChartImageController.uploadChartImage(acc.Id, 'abc%def_ghi', tinyPng);
        } catch (AuraHandledException e) {
            caught = true;
        }
        System.assert(caught, 'Signature with non-alphanumeric chars must be rejected.');
    }

    @IsTest
    static void deleteChartImages_isIdempotent() {
        // Empty list and null list should return without throwing — the LWC's
        // `try/finally` cleanup must never surface errors.
        DocGenChartImageController.deleteChartImages(null);
        DocGenChartImageController.deleteChartImages(new List<Id>());
        // No assertion — the contract is "no exception thrown."
    }

    // -------------------------------------------------------------------------
    // prepareChartImages — only the boundary cases that don't require a real
    // pre-decomposed Word template. End-to-end happy path is exercised by the
    // e2e-07 syntax scripts.
    // -------------------------------------------------------------------------

    @IsTest
    static void prepareChartImages_nullArgs_throws() {
        Boolean caught = false;
        try {
            DocGenChartImageController.prepareChartImages(null, null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        System.assert(caught, 'Null inputs must throw.');
    }

    @IsTest
    static void prepareChartImages_wordTemplateWithChartTag_emitsRequest() {
        // Stand up the minimum surface area prepareChartImages reads:
        // - A Word template the running user can see.
        // - An active template version.
        // - A pre-decomposed `docgen_tmpl_xml_<verId>_word__document.xml` CV
        //   whose body contains a {Chart:...} tag.
        // The chart relationship doesn't resolve (no preloaded data), so the
        // SVG emitter falls through to its empty-state placeholder — that's
        // fine; the assertion is that the *scan+parse* path runs and returns
        // a ChartImageRequest with a signature + SVG. End-to-end pixel-check
        // is the manual checklist's job.
        Account acc = new Account(Name = 'Chart Pipeline Word Test');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline Word Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);
        String docXml =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' +
            '<w:body>' +
            '<w:p><w:r><w:t>{Chart:Survey_Responses__r:A__c:bar:title=Demo}</w:t></w:r></w:p>' +
            '</w:body></w:document>';
        ContentVersion xmlCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + ver.Id + '_word__document.xml',
            PathOnClient = 'document.xml',
            VersionData = Blob.valueOf(docXml)
        );
        insert xmlCv;

        Test.startTest();
        List<DocGenChartImageController.ChartImageRequest> reqs = DocGenChartImageController.prepareChartImages(
            tpl.Id,
            acc.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, reqs);
        System.assertEquals(1, reqs.size(), 'Single top-level chart tag should produce one request.');
        DocGenChartImageController.ChartImageRequest r = reqs[0];
        System.assertEquals(16, r.signature.length(), 'Signature is 16 hex chars.');
        System.assert(String.isNotBlank(r.svgString), 'SVG should be non-empty.');
        System.assert(r.svgString.contains('<svg'), 'SVG should be well-formed.');
        System.assert(r.width > 0, 'Width should be positive.');
        System.assert(r.height > 0, 'Height should be positive.');
    }

    @IsTest
    static void prepareChartImages_powerPointTemplateWithChartTag_emitsRequest() {
        // PPTX charts (#116 follow-up): prepareChartImages must scan PowerPoint
        // slide XML, not just word/document.xml. Two slides are pre-decomposed;
        // the chart tag lives on slide 2, so this also proves loadActivePptxBody
        // concatenates ALL slide parts (a single-slide test wouldn't).
        Account acc = new Account(Name = 'Chart Pipeline PPTX Test');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline PPTX Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'PowerPoint',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);

        String slide1 =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"' +
            ' xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">' +
            '<p:cSld><p:spTree><a:p><a:r><a:t>Title slide, no chart</a:t></a:r></a:p></p:spTree></p:cSld></p:sld>';
        String slide2 =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"' +
            ' xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">' +
            '<p:cSld><p:spTree><a:p><a:r>' +
            '<a:t>{Chart:Survey_Responses__r:A__c:bar:title=Demo}</a:t>' +
            '</a:r></a:p></p:spTree></p:cSld></p:sld>';
        insert new List<ContentVersion>{
            new ContentVersion(
                Title = 'docgen_tmpl_xml_' + ver.Id + '_ppt__slides__slide1.xml',
                PathOnClient = 'slide1.xml',
                VersionData = Blob.valueOf(slide1)
            ),
            new ContentVersion(
                Title = 'docgen_tmpl_xml_' + ver.Id + '_ppt__slides__slide2.xml',
                PathOnClient = 'slide2.xml',
                VersionData = Blob.valueOf(slide2)
            )
        };

        Test.startTest();
        List<DocGenChartImageController.ChartImageRequest> reqs = DocGenChartImageController.prepareChartImages(
            tpl.Id,
            acc.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, reqs);
        System.assertEquals(1, reqs.size(), 'Chart tag on slide 2 should produce one request.');
        DocGenChartImageController.ChartImageRequest r = reqs[0];
        System.assertEquals(16, r.signature.length(), 'Signature is 16 hex chars.');
        System.assert(String.isNotBlank(r.svgString) && r.svgString.contains('<svg'), 'SVG should be well-formed.');
        System.assert(r.width > 0 && r.height > 0, 'Dimensions should be positive.');
    }

    @IsTest
    static void powerPointImageReplacement_usesPlaceholderSize() {
        // PowerPoint authors position charts by drawing a placeholder shape. The
        // chart PNG may be rasterized at a larger logical size for readability,
        // but the inserted <p:pic> must stay inside the placeholder box so it
        // does not overlap tables or callout panels on the slide.
        String slideXml =
            '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"' +
            ' xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"' +
            ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
            '<p:cSld><p:spTree>' +
            '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Chart Placeholder"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>' +
            '<p:spPr><a:xfrm><a:off x="457200" y="914400"/><a:ext cx="1828800" cy="914400"/></a:xfrm>' +
            '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>' +
            '<p:txBody><a:bodyPr/><a:p><a:r><a:t><!--DGPIC|rId5|8572500|3429000|1--></a:t></a:r></a:p></p:txBody>' +
            '</p:sp>' +
            '</p:spTree></p:cSld></p:sld>';

        String out = DocGenService.convertDgPicMarkersInSlide(slideXml, new List<Map<String, Object>>());

        System.assert(out.contains('<p:pic>'), 'Placeholder shape should be replaced by a picture.');
        System.assert(
            out.contains('<a:off x="457200" y="914400"/>'),
            'Picture should preserve the placeholder position.'
        );
        System.assert(
            out.contains('<a:ext cx="1828800" cy="914400"/>'),
            'Picture should preserve the placeholder size, not the larger rasterized chart size.'
        );
        System.assert(!out.contains('8572500'), 'Rasterized width must not leak into the slide geometry.');
        System.assert(!out.contains('3429000'), 'Rasterized height must not leak into the slide geometry.');
    }

    @IsTest
    static void powerPointImageReplacement_addsMissingPictureNamespaces() {
        // Some client-authored/rewritten slides use synthetic ns0/ns1 prefixes
        // and omit p/a/r declarations. The inserted picture uses p:/a:/r:, so
        // the slide root must carry those namespace bindings or PowerPoint will
        // repair the generated deck.
        String slideXml =
            '<ns0:sld xmlns:ns0="http://schemas.openxmlformats.org/presentationml/2006/main"' +
            ' xmlns:ns1="http://schemas.openxmlformats.org/drawingml/2006/main">' +
            '<ns0:cSld><ns0:spTree>' +
            '<ns0:sp><ns0:nvSpPr><ns0:cNvPr id="2" name="Chart Placeholder"/><ns0:cNvSpPr/><ns0:nvPr/></ns0:nvSpPr>' +
            '<ns0:spPr><ns1:xfrm><ns1:off x="457200" y="914400"/><ns1:ext cx="1828800" cy="914400"/></ns1:xfrm></ns0:spPr>' +
            '<ns0:txBody><ns1:bodyPr/><ns1:p><ns1:r><ns1:t><!--DGPIC|rId5|8572500|3429000|1--></ns1:t></ns1:r></ns1:p></ns0:txBody>' +
            '</ns0:sp>' +
            '</ns0:spTree></ns0:cSld></ns0:sld>';

        String out = DocGenService.convertDgPicMarkersInSlide(slideXml, new List<Map<String, Object>>());

        System.assert(out.contains('<p:pic>'), 'Picture insertion should still use the standard PPTX prefixes.');
        System.assert(
            out.contains('<p:cNvPr id="3" name="DocGenPicture3"/>'),
            'Picture id should be allocated after existing cNvPr ids, regardless of namespace prefix.'
        );
        System.assert(!out.contains('name="Chart Placeholder"'), 'The original placeholder shape should be replaced.');
        System.assert(
            out.contains('<a:off x="457200" y="914400"/>') && out.contains('<a:ext cx="1828800" cy="914400"/>'),
            'The ns0/ns1 placeholder position and size should be preserved.'
        );
        System.assert(out.contains('xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'));
        System.assert(out.contains('xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"'));
        System.assert(out.contains('xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'));
    }

    @IsTest
    static void prepareChartImages_wordTemplate_chartInLoopBodySkipped() {
        // Charts inside loop bodies are intentionally skipped — their bucket
        // data depends on the loop iteration item, which isn't in scope at
        // the controller's pre-flight pass. Verifies the depth-tracking
        // scan in `findTopLevelChartTags` works.
        Account acc = new Account(Name = 'Chart Pipeline Loop Skip');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline Word Loop',
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);
        String docXml =
            '<w:document>' +
            '<w:body>' +
            '<w:p>{#Surveys__r}{Chart:Responses__r:A__c:bar}{/Surveys__r}</w:p>' +
            '<w:p>{Chart:TopLevel__r:A__c:bar}</w:p>' +
            '</w:body></w:document>';
        ContentVersion xmlCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + ver.Id + '_word__document.xml',
            PathOnClient = 'document.xml',
            VersionData = Blob.valueOf(docXml)
        );
        insert xmlCv;

        List<DocGenChartImageController.ChartImageRequest> reqs = DocGenChartImageController.prepareChartImages(
            tpl.Id,
            acc.Id
        );
        System.assertEquals(
            1,
            reqs.size(),
            'Only the top-level chart should produce a request (loop-body chart skipped).'
        );
    }

    @IsTest
    static void prepareChartImages_wordTemplate_noActiveVersion_returnsEmpty() {
        // Word template exists but no active version → loadActiveWordBody
        // returns null → prepareChartImages returns empty (does not throw).
        Account acc = new Account(Name = 'Chart Pipeline No Version');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline No-Version Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        List<DocGenChartImageController.ChartImageRequest> reqs = DocGenChartImageController.prepareChartImages(
            tpl.Id,
            acc.Id
        );
        System.assertNotEquals(null, reqs);
        System.assertEquals(0, reqs.size(), 'No active version → empty result, not an exception.');
    }

    @IsTest
    static void prepareChartImages_wordTemplate_bodyHasNoChartTags_returnsEmpty() {
        // Body has no {Chart:...} → cheap early return (no SOQL on
        // DocGenDataRetriever). Covers the contains() guard at line ~72.
        Account acc = new Account(Name = 'Chart Pipeline No Tags');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline No-Tags Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);
        ContentVersion xmlCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + ver.Id + '_word__document.xml',
            PathOnClient = 'document.xml',
            VersionData = Blob.valueOf('<w:document><w:body><w:p>Just text</w:p></w:body></w:document>')
        );
        insert xmlCv;

        List<DocGenChartImageController.ChartImageRequest> reqs = DocGenChartImageController.prepareChartImages(
            tpl.Id,
            acc.Id
        );
        System.assertEquals(0, reqs.size());
    }

    @IsTest
    static void prepareChartImages_malformedChartTag_skippedSilently() {
        // {Chart:...} with no field is malformed — parseChartTag returns null
        // and the scanner skips it. The controller does NOT surface an error
        // here because the main merge engine has authoritative error reporting
        // for chart tags (which the author will see in the final document).
        Account acc = new Account(Name = 'Chart Pipeline Bad Tag');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline Bad-Tag Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);
        ContentVersion xmlCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + ver.Id + '_word__document.xml',
            PathOnClient = 'document.xml',
            VersionData = Blob.valueOf('<w:document><w:body><w:p>{Chart:OnlyRel}</w:p></w:body></w:document>')
        );
        insert xmlCv;

        List<DocGenChartImageController.ChartImageRequest> reqs = DocGenChartImageController.prepareChartImages(
            tpl.Id,
            acc.Id
        );
        System.assertEquals(0, reqs.size(), 'Malformed tag should be skipped, not throw.');
    }

    @IsTest
    static void prepareChartImages_widthOverride_honored() {
        // The width=N option is parsed by the controller and surfaced as
        // ChartImageRequest.width so the LWC canvas matches the SVG's
        // declared viewBox. Covers safeInt + the width branch of
        // renderChartAsRequest.
        Account acc = new Account(Name = 'Chart Pipeline Width');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline Width Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);
        ContentVersion xmlCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + ver.Id + '_word__document.xml',
            PathOnClient = 'document.xml',
            VersionData = Blob.valueOf(
                '<w:document><w:body><w:p>{Chart:R__r:F__c:bar:width=720&height=200}</w:p></w:body></w:document>'
            )
        );
        insert xmlCv;

        List<DocGenChartImageController.ChartImageRequest> reqs = DocGenChartImageController.prepareChartImages(
            tpl.Id,
            acc.Id
        );
        System.assertEquals(1, reqs.size());
        System.assertEquals(720, reqs[0].width, 'Width modifier should override default.');
        System.assertEquals(200, reqs[0].height, 'Height modifier should override default.');
    }

    // -------------------------------------------------------------------------
    // prepareChartImagesServerSide — pure-Apex PNG-via-CV variant. Same scan
    // and parse as prepareChartImages, but rasterizes via DocGenChartRasterizer
    // and uploads transient CVs instead of returning SVG strings. End-to-end
    // happy path against a real bucket-bearing record is exercised by the
    // manual checklist / e2e scripts; this asserts the scaffold + map shape.
    // -------------------------------------------------------------------------

    @IsTest
    static void prepareChartImagesServerSide_nullArgs_throws() {
        Boolean caught = false;
        try {
            DocGenChartImageController.prepareChartImagesServerSide(null, null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        System.assert(caught, 'Null inputs must throw.');
    }

    @IsTest
    static void prepareChartImagesServerSide_nonWordTemplate_returnsEmpty() {
        Account acc = new Account(Name = 'Chart Pipeline SS HTML');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline SS HTML Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'HTML'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        Map<String, String> out = DocGenChartImageController.prepareChartImagesServerSide(tpl.Id, acc.Id);
        System.assertNotEquals(null, out, 'Should return empty map, not null.');
        System.assertEquals(0, out.size(), 'HTML templates produce no chart CVs.');
    }

    @IsTest
    static void prepareChartImagesServerSide_noActiveVersion_returnsEmpty() {
        Account acc = new Account(Name = 'Chart Pipeline SS NoVer');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline SS NoVer Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        Map<String, String> out = DocGenChartImageController.prepareChartImagesServerSide(tpl.Id, acc.Id);
        System.assertEquals(0, out.size());
    }

    @IsTest
    static void prepareChartImagesServerSide_wordTemplateWithChartTag_emitsCvMap() {
        // Same skeleton as prepareChartImages_wordTemplateWithChartTag_emitsRequest
        // but exercises the server-side path: bucket resolution → rasterizer →
        // transient CV upload → map of signature -> "cvId|WxH". Buckets resolve
        // to empty (no preloaded child data) so the rasterizer emits its empty
        // placeholder; the assertion is that the wiring runs end-to-end.
        Account acc = new Account(Name = 'Chart Pipeline SS Word');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline SS Word Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);
        String docXml =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' +
            '<w:body>' +
            '<w:p><w:r><w:t>{Chart:Survey_Responses__r:A__c:bar:title=SS}</w:t></w:r></w:p>' +
            '</w:body></w:document>';
        ContentVersion xmlCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + ver.Id + '_word__document.xml',
            PathOnClient = 'document.xml',
            VersionData = Blob.valueOf(docXml)
        );
        insert xmlCv;

        Test.startTest();
        Map<String, String> out = DocGenChartImageController.prepareChartImagesServerSide(tpl.Id, acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, out);
        System.assertEquals(1, out.size(), 'One top-level chart tag → one CV map entry.');
        String sig = new List<String>(out.keySet())[0];
        System.assertEquals(16, sig.length(), 'Signature key is 16 hex chars.');
        String value = out.get(sig);
        System.assert(value.contains('|'), 'Map value must be in "cvId|WxH" format.');
        List<String> parts = value.split('\\|');
        System.assertEquals(2, parts.size(), 'Value should split into cvId and WxH.');
        System.assert(parts[1].contains('x'), 'Dimensions must be in WxH form.');
        Id cvId = parts[0];
        // Verify the uploaded CV exists and looks like a chart CV.
        List<ContentVersion> cvs = [SELECT Id, Title, VersionData FROM ContentVersion WHERE Id = :cvId];
        System.assertEquals(1, cvs.size(), 'CV must be created.');
        System.assert(cvs[0].Title.startsWith('docgen_chart_'), 'CV title must use the reaper-friendly prefix.');
        // PNG signature: 89 50 4E 47 0D 0A 1A 0A
        Blob png = cvs[0].VersionData;
        System.assertNotEquals(null, png, 'CV must have VersionData.');
        String hexHeader = EncodingUtil.convertToHex(png).substring(0, 16).toLowerCase();
        System.assertEquals('89504e470d0a1a0a', hexHeader, 'VersionData must be a real PNG.');
    }

    @IsTest
    static void prepareChartImagesServerSide_chartInLoopBodySkipped() {
        // Mirrors the LWC-path test: top-level only — loop-body charts are
        // skipped because their bucket data is loop-iteration-scoped.
        Account acc = new Account(Name = 'Chart Pipeline SS Loop');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline SS Loop Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);
        String docXml =
            '<w:document>' +
            '<w:body>' +
            '<w:p>{#Surveys__r}{Chart:Responses__r:A__c:bar}{/Surveys__r}</w:p>' +
            '<w:p>{Chart:TopLevel__r:A__c:bar}</w:p>' +
            '</w:body></w:document>';
        ContentVersion xmlCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + ver.Id + '_word__document.xml',
            PathOnClient = 'document.xml',
            VersionData = Blob.valueOf(docXml)
        );
        insert xmlCv;

        Map<String, String> out = DocGenChartImageController.prepareChartImagesServerSide(tpl.Id, acc.Id);
        System.assertEquals(1, out.size(), 'Only the top-level chart should produce a CV (loop-body chart skipped).');
    }

    @IsTest
    static void prepareChartImagesServerSide_widthOverride_inLogicalDims() {
        // width=720 + height=200 from the tag modifiers should flow through
        // emitWithMeta into the "|WxH" suffix of the CV map value.
        Account acc = new Account(Name = 'Chart Pipeline SS Width');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline SS Width Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);
        ContentVersion xmlCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + ver.Id + '_word__document.xml',
            PathOnClient = 'document.xml',
            VersionData = Blob.valueOf(
                '<w:document><w:body><w:p>{Chart:R__r:F__c:bar:width=720&height=200}</w:p></w:body></w:document>'
            )
        );
        insert xmlCv;

        Map<String, String> out = DocGenChartImageController.prepareChartImagesServerSide(tpl.Id, acc.Id);
        System.assertEquals(1, out.size());
        String value = out.values()[0];
        System.assert(value.endsWith('|720x200'), 'CV map value should encode the overridden logical dims: ' + value);
    }

    @IsTest
    static void prepareChartImagesServerSide_returnedCvIsValidPng() {
        // Already asserted in _emitsCvMap, but as a dedicated test to keep the
        // "CV bytes are a real PNG" guarantee searchable in the suite.
        Account acc = new Account(Name = 'Chart Pipeline SS PNG');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline SS PNG Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Query_Config__c = 'Name'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true);
        Database.insert(ver, AccessLevel.SYSTEM_MODE);
        ContentVersion xmlCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + ver.Id + '_word__document.xml',
            PathOnClient = 'document.xml',
            VersionData = Blob.valueOf('<w:document><w:body><w:p>{Chart:R__r:F__c:column}</w:p></w:body></w:document>')
        );
        insert xmlCv;

        Map<String, String> out = DocGenChartImageController.prepareChartImagesServerSide(tpl.Id, acc.Id);
        System.assertEquals(1, out.size());
        Id cvId = out.values()[0].split('\\|')[0];
        ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE Id = :cvId LIMIT 1];
        String hex = EncodingUtil.convertToHex(cv.VersionData).substring(0, 16).toLowerCase();
        System.assertEquals('89504e470d0a1a0a', hex, 'Column-style CV must also be a valid PNG.');
    }

    @IsTest
    static void prepareChartImages_nonWordTemplate_returnsEmpty() {
        // Insert a minimal HTML template and verify the controller returns
        // an empty list (HTML stays on the existing CSS-bar path, so no PNG
        // prep is needed). End-to-end resolution against a real Word template
        // is exercised by the e2e-07 syntax scripts and the manual checklist.
        Account acc = new Account(Name = 'Chart Pipeline Test');
        insert acc;
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Chart Pipeline HTML Tpl',
            Base_Object_API__c = 'Account',
            Type__c = 'HTML'
        );
        Database.insert(tpl, AccessLevel.SYSTEM_MODE);
        List<DocGenChartImageController.ChartImageRequest> reqs = DocGenChartImageController.prepareChartImages(
            tpl.Id,
            acc.Id
        );
        System.assertNotEquals(null, reqs, 'Should return empty list, not null.');
        System.assertEquals(0, reqs.size(), 'HTML templates should return empty list.');
    }
}
