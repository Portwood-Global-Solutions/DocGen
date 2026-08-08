/**
 * Writes a CSV of Contacts for the chart-scale fixture, for Bulk API load.
 *
 *   node scripts/qa/seed-chart-scale-bulk.mjs <accountId> [count] > /tmp/contacts.csv
 *   sf data import bulk --file /tmp/contacts.csv --sobject Contact \
 *       --target-org <org> --line-ending CRLF --wait 30
 *
 * WHY NOT ANONYMOUS APEX
 * ----------------------
 * The obvious approach — a loop inserting Contacts — does not survive this
 * volume. Ten thousand sObjects built in a loop exceeds the 10s synchronous CPU
 * limit long before the 10,000-row DML cap bites, and splitting into smaller
 * batches just moves the failure. Bulk API 2.0 loads 30,000 in under two
 * minutes with no governor in the way.
 *
 * Line endings matter: csv writers commonly emit CRLF, and Bulk API rejects the
 * job outright if --line-ending disagrees with the file. This writes CRLF.
 *
 * The mix is exact rather than random. A 100-slot picking table walked by
 * i * 7 mod 100 (7 and 100 are coprime) reproduces the intended distribution
 * every whole 100 rows, so a chart reading 34% can be checked against 34%
 * instead of "roughly a third".
 */
const [, , accountId, countArg] = process.argv;
if (!accountId) {
    console.error('usage: node seed-chart-scale-bulk.mjs <accountId> [count]');
    process.exit(1);
}
const count = Number(countArg || 30000);

const modes = ['Drove Alone', 'Transit', 'Telework', 'Carpool', 'Bike', 'Day Off'];
const weights = [34, 24, 18, 12, 8, 4]; // sums to 100
const departments = ['Engineering', 'Sales', 'Operations', 'Finance'];

const pick = [];
modes.forEach((m, i) => {
    for (let n = 0; n < weights[i]; n++) pick.push(m);
});

const rows = ['FirstName,LastName,AccountId,Description,Department,LeadSource'];
for (let i = 0; i < count; i++) {
    rows.push(
        [
            'Rider',
            'Bulk-' + String(i).padStart(6, '0'),
            accountId,
            pick[(i * 7) % 100],
            departments[i % departments.length],
            i % 3 === 0 ? 'Web' : 'Referral'
        ].join(',')
    );
}
process.stdout.write(rows.join('\r\n') + '\r\n');
