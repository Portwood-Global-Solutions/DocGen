// Smoke test for DocGenSvgChartSerializer — emit a sample bar SVG, save as CV.
// Open the CV URL in a browser to eyeball the rendered chart.

List<Map<String, Object>> buckets = new List<Map<String, Object>>{
    new Map<String, Object>{
        'key' => 'Very Satisfied',
        'key_label' => 'Very Satisfied',
        'count' => 42,
        'percent' => 80,
        'max_percent' => 80,
        'index' => 0
    },
    new Map<String, Object>{
        'key' => 'Satisfied',
        'key_label' => 'Satisfied',
        'count' => 27,
        'percent' => 52,
        'max_percent' => 80,
        'index' => 1
    },
    new Map<String, Object>{
        'key' => 'Neutral',
        'key_label' => 'Neutral',
        'count' => 11,
        'percent' => 21,
        'max_percent' => 80,
        'index' => 2
    },
    new Map<String, Object>{
        'key' => 'Dissatisfied',
        'key_label' => 'Dissatisfied',
        'count' => 5,
        'percent' => 10,
        'max_percent' => 80,
        'index' => 3
    },
    new Map<String, Object>{
        'key' => 'Very Dissatisfied',
        'key_label' => 'Very Dissatisfied',
        'count' => 2,
        'percent' => 4,
        'max_percent' => 80,
        'index' => 4
    }
};

Map<String, String> options = new Map<String, String>{ 'style' => 'bar', 'title' => 'Customer Satisfaction (n=87)' };

String svg = DocGenSvgChartSerializer.emit(buckets, options);

ContentVersion cv = new ContentVersion(
    Title = 'spike-svg-emitter-smoke-' + System.now().getTime(),
    PathOnClient = 'svg-emitter-smoke.svg',
    VersionData = Blob.valueOf(svg),
    IsMajorVersion = true
);
insert cv;
ContentVersion saved = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

System.debug('=== DocGenSvgChartSerializer smoke ===');
System.debug('SVG bytes: ' + svg.length());
System.debug('SVG CV:    ' + saved.Id);
System.debug(
    'Open SVG:  ' + URL.getOrgDomainURL().toExternalForm() + '/sfc/servlet.shepherd/version/download/' + saved.Id
);
System.debug('--- first 400 chars of SVG ---');
System.debug(svg.substring(0, Math.min(400, svg.length())));
