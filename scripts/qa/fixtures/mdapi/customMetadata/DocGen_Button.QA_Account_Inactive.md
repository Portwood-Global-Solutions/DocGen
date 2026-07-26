<?xml version="1.0" encoding="UTF-8"?>
<!--
  QA-only. Exists to be FILTERED OUT, not to run.

  Active__c = false. If the Account record action ever shows a picker, or shows
  this label, the Active__c filter in DocGenButtonController.loadConfigs has
  stopped working — and the failure mode there is a customer's retired button
  configuration coming back to life, which is worse than a button that is
  missing, because the document still generates and looks legitimate.
-->
<!-- xmlns:xsd is required — see QA_Account_Doc.md for what its absence looks like. -->
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <label>QA Account Inactive</label>
    <protected>false</protected>
    <values>
        <field>Active__c</field>
        <value xsi:type="xsd:boolean">false</value>
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
        <value xsi:type="xsd:string">QA Inactive — must never appear</value>
    </values>
    <values>
        <field>Save_To_Record__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>Sort_Order__c</field>
        <value xsi:type="xsd:double">2</value>
    </values>
</CustomMetadata>
