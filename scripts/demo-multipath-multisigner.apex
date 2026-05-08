// Demo: Multi-Document Packet + Multi-Signer signature flow.
//
// Sets up a clean demo state on any org (scratch or subscriber) where
// the v1.85 package is installed. Creates 3 distinct Word templates,
// each with signature placement tags, plus an Account + 2 Contacts.
//
// After running, open the Account record, click the "Send for Signature"
// quick action, pick all 3 templates, add 2 signers (Buyer + Seller),
// and generate. The flow exercises the multipath + multi-signer code
// paths fixed in #61 and #65.
//
// Uses dynamic SObject construction with `portwoodglobal__` prefixes so
// the script works in both subscriber orgs (managed package install) and
// dev scratches (source-pushed namespace).

Integer pass = 0;
Integer fail = 0;

String NS = 'portwoodglobal__'; // set to '' if running in a non-namespaced source-push org
String OBJ_TPL = NS + 'DocGen_Template__c';
String OBJ_VER = NS + 'DocGen_Template_Version__c';
String OBJ_REQ = NS + 'DocGen_Signature_Request__c';

String F_BASE_OBJECT = NS + 'Base_Object_API__c';
String F_TYPE = NS + 'Type__c';
String F_OUTPUT_FORMAT = NS + 'Output_Format__c';
String F_QUERY_CONFIG = NS + 'Query_Config__c';
String F_DESCRIPTION = NS + 'Description__c';
String F_CATEGORY = NS + 'Category__c';
String F_TEMPLATE = NS + 'Template__c';
String F_IS_ACTIVE = NS + 'Is_Active__c';
String F_CV_ID = NS + 'Content_Version_Id__c';

// ── Cleanup prior demo state ────────────────────────────────────────
try {
    String reqQuery = 'SELECT Id FROM ' + OBJ_REQ + ' WHERE ' + F_TEMPLATE + '__r.Name LIKE \'v1.85 Demo %\'';
    List<SObject> reqs = Database.query(reqQuery);
    if (!reqs.isEmpty()) {
        delete reqs;
    }
    String tplQuery = 'SELECT Id FROM ' + OBJ_TPL + ' WHERE Name LIKE \'v1.85 Demo %\'';
    List<SObject> tpls = Database.query(tplQuery);
    if (!tpls.isEmpty()) {
        delete tpls;
    }
    delete [SELECT Id FROM Contact WHERE Email LIKE 'demo+%@portwood.dev' AND Account.Name = 'Acme v1.85 Demo Co'];
    delete [SELECT Id FROM Account WHERE Name = 'Acme v1.85 Demo Co'];
    pass++;
    System.debug('CLEANUP: PASS');
} catch (Exception e) {
    System.debug('CLEANUP: ' + e.getMessage());
}

// ── Account + Contacts ──────────────────────────────────────────────
Id acctId;
List<Account> existingAccts = [SELECT Id FROM Account WHERE Name = 'Acme v1.85 Demo Co' LIMIT 1];
if (!existingAccts.isEmpty()) {
    acctId = existingAccts[0].Id;
} else {
    Account a = new Account(Name = 'Acme v1.85 Demo Co', Industry = 'Technology', Phone = '555-0100');
    Database.DMLOptions opts = new Database.DMLOptions();
    opts.DuplicateRuleHeader.AllowSave = true;
    Database.insert(a, opts);
    acctId = a.Id;
}

Map<String, Contact> existingByEmail = new Map<String, Contact>();
for (Contact c : [
    SELECT Id, Email
    FROM Contact
    WHERE Email IN ('demo+buyer@portwood.dev', 'demo+seller@portwood.dev') AND AccountId = :acctId
]) {
    existingByEmail.put(c.Email, c);
}
List<Contact> toInsert = new List<Contact>();
if (!existingByEmail.containsKey('demo+buyer@portwood.dev')) {
    toInsert.add(
        new Contact(
            AccountId = acctId,
            FirstName = 'Brooke',
            LastName = 'Buyer',
            Email = 'demo+buyer@portwood.dev',
            Title = 'Director'
        )
    );
}
if (!existingByEmail.containsKey('demo+seller@portwood.dev')) {
    toInsert.add(
        new Contact(
            AccountId = acctId,
            FirstName = 'Sasha',
            LastName = 'Seller',
            Email = 'demo+seller@portwood.dev',
            Title = 'VP'
        )
    );
}
if (!toInsert.isEmpty()) {
    Database.DMLOptions cOpts = new Database.DMLOptions();
    cOpts.DuplicateRuleHeader.AllowSave = true;
    Database.insert(toInsert, cOpts);
}
pass++;
System.debug('ACCT+CONTACTS: ' + acctId);

// ── Build a minimal Word DOCX with signature placement tags ─────────
String buildDocXml(String marker, String tags) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ' +
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
        '<w:body>' +
        '<w:p><w:r><w:rPr><w:b/><w:sz w:val="36"/></w:rPr><w:t>' +
        marker +
        '</w:t></w:r></w:p>' +
        '<w:p><w:r><w:t>For: {Name}</w:t></w:r></w:p>' +
        '<w:p><w:r><w:t>Industry: {Industry}</w:t></w:r></w:p>' +
        '<w:p><w:r><w:t>Date: {Today}</w:t></w:r></w:p>' +
        tags +
        '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>' +
        '<w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="360" w:footer="360"/>' +
        '</w:sectPr></w:body></w:document>';
}

String makeDocxBase64(String marker, String tags) {
    String docXml = buildDocXml(marker, tags);
    String contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
        '<Default Extension="xml" ContentType="application/xml"/>' +
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' +
        '</Types>';
    String relsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' +
        '</Relationships>';
    String wordRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>';

    Compression.ZipWriter zw = new Compression.ZipWriter();
    zw.addEntry('[Content_Types].xml', Blob.valueOf(contentTypes));
    zw.addEntry('_rels/.rels', Blob.valueOf(relsXml));
    zw.addEntry('word/_rels/document.xml.rels', Blob.valueOf(wordRels));
    zw.addEntry('word/document.xml', Blob.valueOf(docXml));
    return EncodingUtil.base64Encode(zw.getArchive());
}

// ── Three templates with different signature configurations ─────────
List<Map<String, String>> templateSpecs = new List<Map<String, String>>{
    new Map<String, String>{
        'name' => 'v1.85 Demo NDA',
        'marker' => 'NON-DISCLOSURE AGREEMENT',
        'tags' => '<w:p><w:r><w:t>Buyer Signature: {@Signature_Buyer}</w:t></w:r></w:p>' +
        '<w:p><w:r><w:t>Date Signed: {@Signature_Buyer:1:Date}</w:t></w:r></w:p>'
    },
    new Map<String, String>{
        'name' => 'v1.85 Demo MSA',
        'marker' => 'MASTER SERVICES AGREEMENT',
        'tags' => '<w:p><w:r><w:t>Buyer: {@Signature_Buyer}  Initials: {@Signature_Buyer:1:Initials}</w:t></w:r></w:p>' +
        '<w:p><w:r><w:t>Seller: {@Signature_Seller}  Initials: {@Signature_Seller:1:Initials}</w:t></w:r></w:p>'
    },
    new Map<String, String>{
        'name' => 'v1.85 Demo Quote',
        'marker' => 'SALES QUOTE',
        'tags' => '<w:p><w:r><w:t>Authorized Buyer: {@Signature_Buyer}</w:t></w:r></w:p>' +
        '<w:p><w:r><w:t>Effective: {@Signature_Buyer:1:DatePick}</w:t></w:r></w:p>'
    }
};

Schema.SObjectType tplType = Schema.getGlobalDescribe().get(OBJ_TPL);
Schema.SObjectType verType = Schema.getGlobalDescribe().get(OBJ_VER);

for (Map<String, String> spec : templateSpecs) {
    try {
        String b64 = makeDocxBase64(spec.get('marker'), spec.get('tags'));

        SObject t = tplType.newSObject();
        t.put('Name', spec.get('name'));
        t.put(F_BASE_OBJECT, 'Account');
        t.put(F_TYPE, 'Word');
        t.put(F_OUTPUT_FORMAT, 'PDF');
        t.put(F_QUERY_CONFIG, 'Name, Industry');
        t.put(F_DESCRIPTION, 'v1.85 multipath + multi-signer demo');
        t.put(F_CATEGORY, 'Demo');
        insert t;

        SObject v = verType.newSObject();
        v.put(F_TEMPLATE, t.Id);
        v.put(F_IS_ACTIVE, true);
        v.put(F_TYPE, 'Word');
        v.put(F_BASE_OBJECT, 'Account');
        v.put(F_CATEGORY, 'Demo');
        v.put(F_DESCRIPTION, spec.get('name') + ' v1');
        v.put(F_QUERY_CONFIG, 'Name, Industry');
        insert v;

        ContentVersion cv = new ContentVersion(
            Title = spec.get('name'),
            PathOnClient = spec.get('name').replace(' ', '_').toLowerCase() + '.docx',
            VersionData = EncodingUtil.base64Decode(b64),
            FirstPublishLocationId = t.Id
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];
        v.put(F_CV_ID, cv.Id);
        update v;

        // Pre-decomposition: the placement parser (extractTemplatePlainText) reads
        // from a ContentVersion titled `docgen_tmpl_xml_<versionId>_word__document.xml`.
        // Normally the LWC upload flow enqueues a queueable that splits the DOCX into
        // these per-part CVs, but enqueueTemplateImageExtraction is `public` (not
        // `global`) so we can't call it from subscriber-context anonymous Apex. We
        // only need word/document.xml for placement detection and merge-tag preview,
        // so write that one CV directly. Pre_Decomposition_Status__c is set so
        // anything that checks it sees Complete.
        String partDocXml = buildDocXml(spec.get('marker'), spec.get('tags'));
        ContentVersion partCv = new ContentVersion(
            Title = 'docgen_tmpl_xml_' + v.Id + '_word__document.xml',
            PathOnClient = 'word__document.xml',
            VersionData = Blob.valueOf(partDocXml)
        );
        insert partCv;
        v.put(NS + 'Pre_Decomposition_Status__c', 'Complete');
        update v;

        pass++;
        System.debug('TEMPLATE ' + spec.get('name') + ': ' + t.Id);
    } catch (Exception e) {
        fail++;
        System.debug('TEMPLATE ' + spec.get('name') + ': FAIL — ' + e.getMessage());
    }
}

System.debug('────────────────────────────────────');
System.debug('DEMO SEED — PASS: ' + pass + '  FAIL: ' + fail);
System.debug('Account: ' + acctId + '  → /lightning/r/Account/' + acctId + '/view');
System.debug('Templates: 3 created (NDA, MSA, Quote). Each has signature tags.');
System.debug('Contacts: Brooke Buyer + Sasha Seller (both at Acme v1.85 Demo Co).');
System.debug('NEXT: open the Account, click Send for Signature, pick all 3, add Buyer + Seller, Generate.');
