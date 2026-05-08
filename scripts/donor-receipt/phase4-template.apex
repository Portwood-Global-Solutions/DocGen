// Phase 4: Create Donation Receipt template + DOCX + Version

Account testAcc = [SELECT Id, Name FROM Account WHERE Website = 'DONOR_BATCH' ORDER BY CreatedDate LIMIT 1];

String v3Config = '{"v":3,"root":"Account","nodes":['
    + '{"id":"n0","object":"Account","fields":["Name","BillingStreet","BillingCity","BillingState","BillingPostalCode","Phone"],"parentFields":[],"parentNode":null,"lookupField":null,"relationshipName":null},'
    + '{"id":"n1","object":"Contact","fields":["FirstName","LastName","Email","Title"],"parentFields":[],"parentNode":"n0","lookupField":"AccountId","relationshipName":"Contacts"},'
    + '{"id":"n2","object":"Opportunity","fields":["Name","Amount","CloseDate","StageName"],"parentFields":[],"parentNode":"n0","lookupField":"AccountId","relationshipName":"Opportunities"}'
    + ']}';

DocGen_Template__c tmpl = new DocGen_Template__c(
    Name = 'Donation Receipt',
    Base_Object_API__c = 'Account',
    Type__c = 'Word',
    Output_Format__c = 'PDF',
    Query_Config__c = v3Config,
    Test_Record_Id__c = testAcc.Id
);
insert tmpl;

String docxB64 = ''
    + 'UEsDBBQAAAAAALyud1zXeYTquAEAALgBAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbDw/eG1sIHZlcnNpb249IjEuMCIgZW5jb2Rpbmc9IlVURi04IiBzdGFuZGFsb25lPSJ5ZXMiPz4KPFR5cGVzIHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5v'
    + 'cmcvcGFja2FnZS8yMDA2L2NvbnRlbnQtdHlwZXMiPgogIDxEZWZhdWx0IEV4dGVuc2lvbj0icmVscyIgQ29udGVudFR5cGU9ImFwcGxpY2F0aW9uL3ZuZC5vcGVueG1sZm9ybWF0cy1wYWNrYWdlLnJlbGF0aW9uc2hpcHMreG1sIi8+CiAgPERlZmF1bHQgRXh0ZW5z'
    + 'aW9uPSJ4bWwiIENvbnRlbnRUeXBlPSJhcHBsaWNhdGlvbi94bWwiLz4KICA8T3ZlcnJpZGUgUGFydE5hbWU9Ii93b3JkL2RvY3VtZW50LnhtbCIgQ29udGVudFR5cGU9ImFwcGxpY2F0aW9uL3ZuZC5vcGVueG1sZm9ybWF0cy1vZmZpY2Vkb2N1bWVudC53b3JkcHJv'
    + 'Y2Vzc2luZ21sLmRvY3VtZW50Lm1haW4reG1sIi8+CjwvVHlwZXM+UEsDBBQAAAAAALyud1wgG4bqLgEAAC4BAAALAAAAX3JlbHMvLnJlbHM8P3htbCB2ZXJzaW9uPSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+CjxSZWxhdGlvbnNoaXBz'
    + 'IHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5vcmcvcGFja2FnZS8yMDA2L3JlbGF0aW9uc2hpcHMiPgogIDxSZWxhdGlvbnNoaXAgSWQ9InJJZDEiIFR5cGU9Imh0dHA6Ly9zY2hlbWFzLm9wZW54bWxmb3JtYXRzLm9yZy9vZmZpY2VEb2N1bWVu'
    + 'dC8yMDA2L3JlbGF0aW9uc2hpcHMvb2ZmaWNlRG9jdW1lbnQiIFRhcmdldD0id29yZC9kb2N1bWVudC54bWwiLz4KPC9SZWxhdGlvbnNoaXBzPlBLAwQUAAAAAAC8rndcjA6F0J0AAACdAAAAHAAAAHdvcmQvX3JlbHMvZG9jdW1lbnQueG1sLnJlbHM8P3htbCB2ZXJz'
    + 'aW9uPSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+CjxSZWxhdGlvbnNoaXBzIHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5vcmcvcGFja2FnZS8yMDA2L3JlbGF0aW9uc2hpcHMiPgo8L1JlbGF0aW9uc2hpcHM+UEsD'
    + 'BBQAAAAAALyud1zUFLewQQ4AAEEOAAARAAAAd29yZC9kb2N1bWVudC54bWw8P3htbCB2ZXJzaW9uPSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+Cjx3OmRvY3VtZW50IHhtbG5zOndwYz0iaHR0cDovL3NjaGVtYXMubWljcm9zb2Z0LmNv'
    + 'bS9vZmZpY2Uvd29yZC8yMDEwL3dvcmRwcm9jZXNzaW5nQ2FudmFzIgogICAgICAgICAgICB4bWxuczptYz0iaHR0cDovL3NjaGVtYXMub3BlbnhtbGZvcm1hdHMub3JnL21hcmt1cC1jb21wYXRpYmlsaXR5LzIwMDYiCiAgICAgICAgICAgIHhtbG5zOm89InVybjpz'
    + 'Y2hlbWFzLW1pY3Jvc29mdC1jb206b2ZmaWNlOm9mZmljZSIKICAgICAgICAgICAgeG1sbnM6cj0iaHR0cDovL3NjaGVtYXMub3BlbnhtbGZvcm1hdHMub3JnL29mZmljZURvY3VtZW50LzIwMDYvcmVsYXRpb25zaGlwcyIKICAgICAgICAgICAgeG1sbnM6bT0iaHR0'
    + 'cDovL3NjaGVtYXMub3BlbnhtbGZvcm1hdHMub3JnL29mZmljZURvY3VtZW50LzIwMDYvbWF0aCIKICAgICAgICAgICAgeG1sbnM6dj0idXJuOnNjaGVtYXMtbWljcm9zb2Z0LWNvbTp2bWwiCiAgICAgICAgICAgIHhtbG5zOndwPSJodHRwOi8vc2NoZW1hcy5vcGVu'
    + 'eG1sZm9ybWF0cy5vcmcvZHJhd2luZ21sLzIwMDYvd29yZHByb2Nlc3NpbmdEcmF3aW5nIgogICAgICAgICAgICB4bWxuczp3MTA9InVybjpzY2hlbWFzLW1pY3Jvc29mdC1jb206b2ZmaWNlOndvcmQiCiAgICAgICAgICAgIHhtbG5zOnc9Imh0dHA6Ly9zY2hlbWFz'
    + 'Lm9wZW54bWxmb3JtYXRzLm9yZy93b3JkcHJvY2Vzc2luZ21sLzIwMDYvbWFpbiIKICAgICAgICAgICAgeG1sbnM6d25lPSJodHRwOi8vc2NoZW1hcy5taWNyb3NvZnQuY29tL29mZmljZS93b3JkLzIwMDYvd29yZG1sIgogICAgICAgICAgICBtYzpJZ25vcmFibGU9'
    + 'IncxNCB3cDE0Ij4KICA8dzpib2R5PgogICAgPHc6cD48dzpwUHI+PHc6amMgdzp2YWw9ImNlbnRlciIvPjwvdzpwUHI+PHc6cj48dzpyUHI+PHc6Yi8+PHc6c3ogdzp2YWw9IjUyIi8+PHc6c3pDcyB3OnZhbD0iNTIiLz48L3c6clByPjx3OnQ+RE9OQVRJT04gUkVD'
    + 'RUlQVDwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpwUHI+PHc6cEJkcj48dzpib3R0b20gdzp2YWw9InNpbmdsZSIgdzpzej0iNiIgdzpzcGFjZT0iMSIgdzpjb2xvcj0iMzMzMzMzIi8+PC93OnBCZHI+PC93OnBQcj48L3c6cD4KICAgIDx3OnAvPgogICAg'
    + 'PHc6cD48dzpyPjx3OnJQcj48dzpiLz48dzpzeiB3OnZhbD0iMjgiLz48dzpzekNzIHc6dmFsPSIyOCIvPjwvdzpyUHI+PHc6dD57TmFtZX08L3c6dD48L3c6cj48L3c6cD4KICAgIDx3OnA+PHc6cj48dzp0PntCaWxsaW5nU3RyZWV0fTwvdzp0PjwvdzpyPjwvdzpw'
    + 'PgogICAgPHc6cD48dzpyPjx3OnQgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+e0JpbGxpbmdDaXR5fSwge0JpbGxpbmdTdGF0ZX0ge0JpbGxpbmdQb3N0YWxDb2RlfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnQ+e1Bob25lfTwvdzp0PjwvdzpyPjwv'
    + 'dzpwPgogICAgPHc6cC8+CiAgICA8dzpwPjx3OnBQcj48dzpwQmRyPjx3OmJvdHRvbSB3OnZhbD0ic2luZ2xlIiB3OnN6PSI0IiB3OnNwYWNlPSIxIiB3OmNvbG9yPSI5OTk5OTkiLz48L3c6cEJkcj48L3c6cFByPjx3OnI+PHc6clByPjx3OmIvPjx3OnN6IHc6dmFs'
    + 'PSIyNCIvPjx3OnN6Q3Mgdzp2YWw9IjI0Ii8+PC93OnJQcj48dzp0PkRPTk9SIElORk9STUFUSU9OPC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwPjx3OnI+PHc6dD57I0NvbnRhY3RzfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnJQcj48dzpi'
    + 'Lz48L3c6clByPjx3OnQgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+e0ZpcnN0TmFtZX0ge0xhc3ROYW1lfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnQ+e0VtYWlsfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnQ+eyVUaXRsZX08'
    + 'L3c6dD48L3c6cj48L3c6cD4KICAgIDx3OnA+PHc6cj48dzp0PnsvQ29udGFjdHN9PC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwLz4KICAgIDx3OnA+PHc6cFByPjx3OnBCZHI+PHc6Ym90dG9tIHc6dmFsPSJzaW5nbGUiIHc6c3o9IjQiIHc6c3BhY2U9IjEiIHc6'
    + 'Y29sb3I9Ijk5OTk5OSIvPjwvdzpwQmRyPjwvdzpwUHI+PHc6cj48dzpyUHI+PHc6Yi8+PHc6c3ogdzp2YWw9IjI0Ii8+PHc6c3pDcyB3OnZhbD0iMjQiLz48L3c6clByPjx3OnQ+RE9OQVRJT04gREVUQUlMUzwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpy'
    + 'Pjx3OnQ+eyNPcHBvcnR1bml0aWVzfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnJQcj48dzpiLz48L3c6clByPjx3OnQgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+RGVzY3JpcHRpb246IDwvdzp0PjwvdzpyPjx3OnI+PHc6dD57TmFtZX08L3c6dD48'
    + 'L3c6cj48L3c6cD4KICAgIDx3OnA+PHc6cj48dzpyUHI+PHc6Yi8+PC93OnJQcj48dzp0IHhtbDpzcGFjZT0icHJlc2VydmUiPkFtb3VudDogPC93OnQ+PC93OnI+PHc6cj48dzp0PntBbW91bnR9PC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwPjx3OnI+PHc6clBy'
    + 'Pjx3OmIvPjwvdzpyUHI+PHc6dCB4bWw6c3BhY2U9InByZXNlcnZlIj5EYXRlOiA8L3c6dD48L3c6cj48dzpyPjx3OnQ+e0Nsb3NlRGF0ZX08L3c6dD48L3c6cj48L3c6cD4KICAgIDx3OnA+PHc6cj48dzpyUHI+PHc6Yi8+PC93OnJQcj48dzp0IHhtbDpzcGFjZT0i'
    + 'cHJlc2VydmUiPlN0YXR1czogPC93OnQ+PC93OnI+PHc6cj48dzp0PntTdGFnZU5hbWV9PC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwPjx3OnI+PHc6dD57L09wcG9ydHVuaXRpZXN9PC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwLz4KICAgIDx3OnA+PHc6cFBy'
    + 'Pjx3OnBCZHI+PHc6dG9wIHc6dmFsPSJkb3VibGUiIHc6c3o9IjYiIHc6c3BhY2U9IjEiIHc6Y29sb3I9IjMzMzMzMyIvPjwvdzpwQmRyPjwvdzpwUHI+PHc6cj48dzpyUHI+PHc6Yi8+PHc6c3ogdzp2YWw9IjI4Ii8+PHc6c3pDcyB3OnZhbD0iMjgiLz48L3c6clBy'
    + 'Pjx3OnQgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+VG90YWwgRG9uYXRlZDoge1NVTTpPcHBvcnR1bml0aWVzLkFtb3VudDpjdXJyZW5jeX08L3c6dD48L3c6cj48L3c6cD4KICAgIDx3OnAvPgogICAgPHc6cD48dzpwUHI+PHc6amMgdzp2YWw9ImNlbnRlciIvPjwvdzpw'
    + 'UHI+PHc6cj48dzpyUHI+PHc6aS8+PHc6c3ogdzp2YWw9IjI0Ii8+PHc6c3pDcyB3OnZhbD0iMjQiLz48L3c6clByPjx3OnQ+VGhhbmsgeW91IGZvciB5b3VyIGdlbmVyb3VzIGRvbmF0aW9uITwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpwUHI+PHc6amMg'
    + 'dzp2YWw9ImNlbnRlciIvPjwvdzpwUHI+PHc6cj48dzpyUHI+PHc6aS8+PHc6c3ogdzp2YWw9IjE4Ii8+PHc6c3pDcyB3OnZhbD0iMTgiLz48L3c6clByPjx3OnQ+VGhpcyByZWNlaXB0IGlzIGZvciB5b3VyIHRheCByZWNvcmRzLiBQbGVhc2UgcmV0YWluIGZvciB5'
    + 'b3VyIGZpbGVzLjwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6c2VjdFByPgogICAgICA8dzpwZ1N6IHc6dz0iMTIyNDAiIHc6aD0iMTU4NDAiLz4KICAgICAgPHc6cGdNYXIgdzp0b3A9IjE0NDAiIHc6cmlnaHQ9IjE0NDAiIHc6Ym90dG9tPSIxNDQwIiB3OmxlZnQ9'
    + 'IjE0NDAiIHc6aGVhZGVyPSI3MjAiIHc6Zm9vdGVyPSI3MjAiIHc6Z3V0dGVyPSIwIi8+CiAgICA8L3c6c2VjdFByPgogIDwvdzpib2R5Pgo8L3c6ZG9jdW1lbnQ+UEsBAhQDFAAAAAAAvK53XNd5hOq4AQAAuAEAABMAAAAAAAAAAAAAAIABAAAAAFtDb250ZW50X1R5'
    + 'cGVzXS54bWxQSwECFAMUAAAAAAC8rndcIBuG6i4BAAAuAQAACwAAAAAAAAAAAAAAgAHpAQAAX3JlbHMvLnJlbHNQSwECFAMUAAAAAAC8rndcjA6F0J0AAACdAAAAHAAAAAAAAAAAAAAAgAFAAwAAd29yZC9fcmVscy9kb2N1bWVudC54bWwucmVsc1BLAQIUAxQAAAAA'
    + 'ALyud1zUFLewQQ4AAEEOAAARAAAAAAAAAAAAAACAARcEAAB3b3JkL2RvY3VtZW50LnhtbFBLBQYAAAAABAAEAAMBAACHEgAAAAA=';

ContentVersion docxCv = new ContentVersion(
    Title = 'Donation Receipt Template',
    PathOnClient = 'donation_receipt.docx',
    VersionData = EncodingUtil.base64Decode(docxB64),
    IsMajorVersion = true,
    FirstPublishLocationId = tmpl.Id
);
insert docxCv;
docxCv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :docxCv.Id];

DocGen_Template_Version__c ver = new DocGen_Template_Version__c(
    Template__c = tmpl.Id,
    Content_Version_Id__c = docxCv.Id,
    Is_Active__c = true
);
insert ver;

System.debug('');
System.debug('==========================================================');
System.debug('  DONOR RECEIPT SETUP COMPLETE');
System.debug('==========================================================');
System.debug('  Template: ' + tmpl.Name + ' (' + tmpl.Id + ')');
System.debug('  DOCX CV:  ' + docxCv.Id);
System.debug('  Test Acc: ' + testAcc.Name + ' (' + testAcc.Id + ')');
System.debug('==========================================================');
