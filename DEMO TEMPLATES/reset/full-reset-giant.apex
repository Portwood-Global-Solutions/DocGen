// ============================================================================
// Portwood DocGen DEMO — FULL RESET (giant catalog chunk)
//   Removes the 2,200-line giant catalog in CPU-safe chunks. Run REPEATEDLY
//   until it prints "GIANT-REMAINING 0" (reset.sh loops this automatically).
//
//   Standard PricebookEntries cannot be deleted directly (platform throws
//   UNKNOWN_EXCEPTION), so we delete the custom mega entries explicitly and let
//   Product2 deletion CASCADE the standard entries.
// ============================================================================
List<PricebookEntry> mega = [
    SELECT Id FROM PricebookEntry
    WHERE Product2.ProductCode LIKE 'GIANT-%' AND Pricebook2.IsStandard = false
    LIMIT 2000];
if (!mega.isEmpty()) {
    delete mega;
} else {
    List<Product2> prods = [SELECT Id FROM Product2 WHERE ProductCode LIKE 'GIANT-%' LIMIT 1000];
    if (!prods.isEmpty()) {
        delete prods;                      // cascades the standard PricebookEntries
    } else {
        delete [SELECT Id FROM Pricebook2 WHERE Name = 'Portwood Mega Catalog (Giant Demo)'];
    }
}
Integer remaining =
    [SELECT COUNT() FROM Product2 WHERE ProductCode LIKE 'GIANT-%'] +
    [SELECT COUNT() FROM PricebookEntry WHERE Product2.ProductCode LIKE 'GIANT-%' AND Pricebook2.IsStandard = false] +
    [SELECT COUNT() FROM Pricebook2 WHERE Name = 'Portwood Mega Catalog (Giant Demo)'];
System.debug('GIANT-REMAINING ' + remaining);
