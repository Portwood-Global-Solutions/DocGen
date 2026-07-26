<?xml version="1.0" encoding="UTF-8"?>
<!--
  QA-only. Also exists to be filtered out — but by a different rule.

  Object_API_Name__c = Contact. On an Account record this must not appear, which
  proves the object filter in DocGenButtonController.getButtons independently of
  the Active__c filter that QA_Account_Inactive covers. Two rules, two fixtures,
  so a report can say WHICH filter broke rather than that "the button is wrong".

  Together with QA_Account_Doc this also leaves exactly one visible config on an
  Account, which is what puts the component down its run-immediately branch.
-->
<!-- xmlns:xsd is required — see QA_Account_Doc.md for what its absence looks like. -->
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <label>QA Contact Doc</label>
    <protected>false</protected>
    <values>
        <field>Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>Object_API_Name__c</field>
        <value xsi:type="xsd:string">Contact</value>
    </values>
    <values>
        <field>Template_API_Name__c</field>
        <value xsi:type="xsd:string">QA_Verify_Designer</value>
    </values>
    <values>
        <field>Document_Title__c</field>
        <value xsi:type="xsd:string">QA Contact — must never appear on an Account</value>
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
