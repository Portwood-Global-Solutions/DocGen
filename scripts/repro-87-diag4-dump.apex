// Dump previewHtml from the latest REPRO87_PD packet attempt for offline analysis.
// Looks for the most recent Signature_Request__c that referenced the PD templates,
// extracts the previewHtml, and writes the first 6000 chars to debug.

List<DocGen_Template__c> tmpls = [SELECT Id FROM DocGen_Template__c WHERE Name LIKE 'REPRO87_PD_%'];
Set<Id> pdIds = new Set<Id>();
for (DocGen_Template__c t : tmpls)
    pdIds.add(t.Id);

// Build a fresh packet to capture the current preview HTML
List<Id> templateIds = new List<Id>{};
for (Id i : pdIds)
    templateIds.add(i);
templateIds.sort();

List<Account> accts = [SELECT Id FROM Account LIMIT 1];
Id recordId = accts.isEmpty() ? null : accts[0].Id;

List<Map<String, Object>> signers = new List<Map<String, Object>>{
    new Map<String, Object>{ 'signerName' => 'Repro87 Dump', 'signerEmail' => 'r@e.invalid', 'roleName' => 'Buyer' }
};

List<DocGenSignatureSenderController.SignerResult> results = DocGenSignatureSenderController.createPacketSignerRequestWithTitle(
    JSON.serialize(templateIds),
    recordId,
    JSON.serialize(signers),
    'Parallel',
    null
);
Id sigId = results[0].signerId;
Id requestId = [SELECT Signature_Request__c FROM DocGen_Signer__c WHERE Id = :sigId LIMIT 1][0].Signature_Request__c;

DocGen_Signature_Request__c req = [
    SELECT Signature_Data__c
    FROM DocGen_Signature_Request__c
    WHERE Id = :requestId
    LIMIT 1
];
Map<String, Object> cached = (Map<String, Object>) JSON.deserializeUntyped(req.Signature_Data__c);
String html = (String) cached.get('previewHtml');

System.debug('LENGTH=' + html.length());
// Print in 3000-char chunks so System.debug doesn't truncate
Integer chunk = 3000;
for (Integer i = 0; i < html.length(); i += chunk) {
    System.debug('HTML[' + i + ']=' + html.substring(i, Math.min(i + chunk, html.length())));
}

// Cleanup so we don't accumulate request rows
delete [SELECT Id FROM DocGen_Signer__c WHERE Signature_Request__c = :requestId];
delete [SELECT Id FROM DocGen_Signature_Request__c WHERE Id = :requestId];
