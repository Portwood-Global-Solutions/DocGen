User stdUser = [
    SELECT Id
    FROM User
    WHERE Username = '1781231252721_test-mndkqizlbyr6@example.com'
    LIMIT 1
];

List<PermissionSet> userPerms = [SELECT Id FROM PermissionSet WHERE Name = 'DocGen_User' LIMIT 1];
if (!userPerms.isEmpty()) {
    List<PermissionSetAssignment> existing = [
        SELECT Id
        FROM PermissionSetAssignment
        WHERE AssigneeId = :stdUser.Id AND PermissionSetId = :userPerms[0].Id
    ];
    if (existing.isEmpty()) {
        insert new PermissionSetAssignment(AssigneeId = stdUser.Id, PermissionSetId = userPerms[0].Id);
    }
}

String proofName = 'Proof Giant Runner ' + Datetime.now().formatGMT('yyyyMMddHHmmss');
Database.DMLOptions allowDuplicateRules = new Database.DMLOptions();
allowDuplicateRules.DuplicateRuleHeader.allowSave = true;
Account acct = new Account(Name = proofName, OwnerId = stdUser.Id);
Database.insert(acct, allowDuplicateRules);

List<Contact> contacts = new List<Contact>();
for (Integer i = 1; i <= 2105; i++) {
    contacts.add(
        new Contact(
            FirstName = 'Proof',
            LastName = 'Contact ' + String.valueOf(i).leftPad(4, '0'),
            Email = 'proof' + i + '@example.test',
            AccountId = acct.Id,
            OwnerId = stdUser.Id
        )
    );
    if (contacts.size() == 200) {
        Database.insert(contacts, allowDuplicateRules);
        contacts.clear();
    }
}
if (!contacts.isEmpty()) {
    Database.insert(contacts, allowDuplicateRules);
}

String queryConfig = JSON.serialize(
    new Map<String, Object>{
        'v' => 3,
        'root' => 'Account',
        'nodes' => new List<Object>{
            new Map<String, Object>{
                'id' => 'n0',
                'object' => 'Account',
                'fields' => new List<String>{ 'Name' },
                'parentFields' => new List<String>(),
                'parentNode' => null,
                'lookupField' => null,
                'relationshipName' => null
            },
            new Map<String, Object>{
                'id' => 'n1',
                'object' => 'Contact',
                'fields' => new List<String>{ 'FirstName', 'LastName', 'Email' },
                'parentFields' => new List<String>(),
                'parentNode' => 'n0',
                'lookupField' => 'AccountId',
                'relationshipName' => 'Contacts'
            }
        }
    }
);

String tinyPngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l8N8WQAAAABJRU5ErkJggg==';

DocGen_Template__c wordTpl = new DocGen_Template__c(
    Name = proofName + ' - Word Giant PDF',
    Base_Object_API__c = 'Account',
    Type__c = 'Word',
    Output_Format__c = 'PDF',
    Query_Config__c = queryConfig,
    Test_Record_Id__c = acct.Id,
    Specific_Record_Ids__c = acct.Id,
    Document_Title_Format__c = 'Proof Word Giant - {Name}'
);
insert wordTpl;

DocGen_Template__c htmlTpl = new DocGen_Template__c(
    Name = proofName + ' - HTML Giant PDF',
    Base_Object_API__c = 'Account',
    Type__c = 'HTML',
    Output_Format__c = 'PDF',
    Query_Config__c = queryConfig,
    Test_Record_Id__c = acct.Id,
    Specific_Record_Ids__c = acct.Id,
    Header_Html__c = 'HTML giant header - {Name}',
    Footer_Html__c = 'HTML giant footer - {PageNumber} of {TotalPages}',
    Document_Title_Format__c = 'Proof HTML Giant - {Name}'
);
insert htmlTpl;

String docXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' +
    '<w:body><w:p><w:r><w:t>WORD_GIANT_CHROME {Name}</w:t></w:r></w:p>' +
    '<w:tbl><w:tblPr/><w:tblGrid><w:gridCol w:w="2200"/><w:gridCol w:w="2600"/><w:gridCol w:w="3600"/></w:tblGrid>' +
    '<w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc><w:p><w:r><w:t>First</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Last</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Email</w:t></w:r></w:p></w:tc></w:tr>' +
    '<w:tr><w:tc><w:p><w:r><w:t>{#Contacts}{FirstName}</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>{LastName}</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>{Email}{/Contacts}</w:t></w:r></w:p></w:tc></w:tr>' +
    '</w:tbl><w:p><w:r><w:t>WORD_GIANT_FOOTER_MARKER</w:t></w:r></w:p></w:body></w:document>';

Compression.ZipWriter zw = new Compression.ZipWriter();
zw.addEntry(
    '[Content_Types].xml',
    Blob.valueOf(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
            '<Default Extension="xml" ContentType="application/xml"/>' +
            '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' +
            '</Types>'
    )
);
zw.addEntry(
    '_rels/.rels',
    Blob.valueOf(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' +
            '</Relationships>'
    )
);
zw.addEntry('word/document.xml', Blob.valueOf(docXml));
ContentVersion docxCv = new ContentVersion(
    Title = proofName + ' Word Source',
    PathOnClient = 'proof-word.docx',
    VersionData = zw.getArchive(),
    FirstPublishLocationId = wordTpl.Id
);
insert docxCv;

DocGen_Template_Version__c wordVer = new DocGen_Template_Version__c(
    Template__c = wordTpl.Id,
    Is_Active__c = true,
    Content_Version_Id__c = docxCv.Id,
    Query_Config__c = queryConfig,
    Type__c = 'Word',
    Base_Object_API__c = 'Account',
    Output_Format__c = 'PDF'
);
insert wordVer;

ContentVersion wordLogoCv = new ContentVersion(
    Title = 'docgen_tmpl_img_' + wordVer.Id + '_rIdLogo',
    PathOnClient = 'proof-word-logo.png',
    VersionData = EncodingUtil.base64Decode(tinyPngB64),
    FirstPublishLocationId = wordVer.Id
);
insert wordLogoCv;
wordLogoCv = [SELECT Id FROM ContentVersion WHERE Id = :wordLogoCv.Id];
String wordLogoUrl = '/sfc/servlet.shepherd/version/download/' + wordLogoCv.Id;

insert new ContentVersion(
    Title = 'docgen_tmpl_xml_' + wordVer.Id + '_word__document.xml',
    PathOnClient = 'word__document.xml',
    VersionData = Blob.valueOf(docXml),
    FirstPublishLocationId = wordVer.Id
);

String wordSnapshot =
    '<html><head><style>@page{size:letter;margin:.5in;} body{font-family:Arial;font-size:9pt;} table{width:100%;border-collapse:collapse;-fs-table-paginate:paginate;} thead{display:table-header-group;} th,td{border:1px solid #777;padding:3px;} th{background:#e7f0ff;}</style></head><body>' +
    '<div><img src="' +
    wordLogoUrl +
    '" style="width:18px;height:18px;" /> WORD_GIANT_CHROME {Name}</div>' +
    '<table><thead><tr><th>First</th><th>Last</th><th>Email</th></tr></thead><tbody><tr><td>{#Contacts}{FirstName}</td><td>{LastName}</td><td>{Email}{/Contacts}</td></tr></tbody></table>' +
    '<div>WORD_GIANT_FOOTER_MARKER</div></body></html>';
insert new ContentVersion(
    Title = 'docgen_tmpl_html_' + wordVer.Id,
    PathOnClient = 'word-snapshot.html',
    VersionData = Blob.valueOf(wordSnapshot),
    FirstPublishLocationId = wordVer.Id
);

ContentVersion htmlLogoCv = new ContentVersion(
    Title = 'docgen_html_img_' + htmlTpl.Id + '_proof-logo',
    PathOnClient = 'proof-html-logo.png',
    VersionData = EncodingUtil.base64Decode(tinyPngB64),
    FirstPublishLocationId = htmlTpl.Id
);
insert htmlLogoCv;
htmlLogoCv = [SELECT Id FROM ContentVersion WHERE Id = :htmlLogoCv.Id];
String htmlLogoUrl = '/sfc/servlet.shepherd/version/download/' + htmlLogoCv.Id;

String htmlBody =
    '<html><head><style>@page{size:letter;margin:.5in;} body{font-family:Arial;font-size:9pt;} table{width:100%;border-collapse:collapse;-fs-table-paginate:paginate;} thead{display:table-header-group;} th,td{border:1px solid #555;padding:3px;} th{background:#e8ffe8;}</style></head><body>' +
    '<div><img src="' +
    htmlLogoUrl +
    '" style="width:18px;height:18px;" /> HTML_GIANT_CHROME {Name}</div>' +
    '<table><thead><tr><th>First</th><th>Last</th><th>Email</th></tr></thead><tbody><tr><td>{#Contacts}{FirstName}</td><td>{LastName}</td><td>{Email}{/Contacts}</td></tr></tbody></table>' +
    '<div>HTML_GIANT_FOOTER_MARKER</div></body></html>';
ContentVersion htmlCv = new ContentVersion(
    Title = proofName + ' HTML Source',
    PathOnClient = 'proof-html.html',
    VersionData = Blob.valueOf(htmlBody),
    FirstPublishLocationId = htmlTpl.Id
);
insert htmlCv;

DocGen_Template_Version__c htmlVer = new DocGen_Template_Version__c(
    Template__c = htmlTpl.Id,
    Is_Active__c = true,
    Content_Version_Id__c = htmlCv.Id,
    Query_Config__c = queryConfig,
    Type__c = 'HTML',
    Base_Object_API__c = 'Account',
    Output_Format__c = 'PDF',
    Header_Html__c = htmlTpl.Header_Html__c,
    Footer_Html__c = htmlTpl.Footer_Html__c
);
insert htmlVer;

Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
if (gd.containsKey('DocGen_Template__Share')) {
    List<SObject> shares = new List<SObject>();
    for (Id tplId : new List<Id>{ wordTpl.Id, htmlTpl.Id }) {
        SObject shareRow = gd.get('DocGen_Template__Share').newSObject();
        shareRow.put('ParentId', tplId);
        shareRow.put('UserOrGroupId', stdUser.Id);
        shareRow.put('AccessLevel', 'Read');
        shareRow.put('RowCause', 'Manual');
        shares.add(shareRow);
    }
    Database.insert(shares, false);
}

System.debug('PROOF_ACCOUNT_ID=' + acct.Id);
System.debug('PROOF_ADMIN_USER=' + UserInfo.getUserName());
System.debug('PROOF_STANDARD_USER=1781231252721_test-mndkqizlbyr6@example.com');
System.debug('PROOF_WORD_TEMPLATE_ID=' + wordTpl.Id);
System.debug('PROOF_HTML_TEMPLATE_ID=' + htmlTpl.Id);
