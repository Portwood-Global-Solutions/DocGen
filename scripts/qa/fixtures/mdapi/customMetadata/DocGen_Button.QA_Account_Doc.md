<?xml version="1.0" encoding="UTF-8"?>
<!--
  QA-only DocGen_Button__mdt configuration.

  docGenButton is data-driven: with no matching DocGen_Button__mdt row it renders
  its "no configuration" error and nothing downstream is exercised. Testing the
  component therefore means shipping a config with it.

  Template_API_Name__c (not Template_Id__c) on purpose — a record Id differs in
  every org, so an Id here would make the fixture org-specific. The API name is
  set on the seeded template by setup-org.apex, which keeps the two ends of this
  reference in files that live next to each other.
-->
<!--
  xmlns:xsd is REQUIRED even though every value below only uses it inside an
  xsi:type attribute. Omit it and the deploy fails with a bare
  "UNKNOWN_EXCEPTION ... include this ErrorId if you contact support" and ZERO
  component failures — no file named, no field named, nothing to search for.
-->
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <label>QA Account Doc</label>
    <protected>false</protected>
    <values>
        <field>Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>Object_API_Name__c</field>
        <value xsi:type="xsd:string">Account</value>
    </values>
    <values>
        <field>Template_API_Name__c</field>
        <value xsi:type="xsd:string">QA_Verify_Designer</value>
    </values>
    <values>
        <field>Document_Title__c</field>
        <value xsi:type="xsd:string">QA Button Document</value>
    </values>
    <values>
        <field>Save_To_Record__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>Sort_Order__c</field>
        <value xsi:type="xsd:double">1</value>
    </values>
</CustomMetadata>
