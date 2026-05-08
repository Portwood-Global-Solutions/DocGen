// Test what value actually reaches the QR generator for a URL
String testUrl = 'https://power-data-4330-dev-ed.scratch.lightning.force.com/lightning/r/DocGen_Job__c/a00C3000003test/view';
String escaped = testUrl.escapeXml();
System.debug('ORIGINAL: ' + testUrl);
System.debug('ESCAPED:  ' + escaped);

// Simulate the marker creation (DocGenService line 1152)
String marker = '##BARCODE:qr::' + escaped + '##';
System.debug('MARKER: ' + marker);

// Simulate the renderer parsing (DocGenHtmlRenderer line 1128)
String markerContent = marker.substring(10, marker.length() - 2);
List<String> parts = markerContent.split(':', 3);
System.debug('PARTS[0] type: ' + parts[0]);
System.debug('PARTS[1] size: ' + parts[1]);
System.debug('PARTS[2] value: ' + parts[2]);

// Simulate unescape
String val = parts[2].replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>');
System.debug('FINAL VALUE: ' + val);
System.debug('MATCH: ' + (val == testUrl));
