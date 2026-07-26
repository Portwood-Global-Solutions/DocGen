#!/usr/bin/env node
// ============================================================================
// Portwood DocGen DEMO — Template installer
//   1. Reads install/manifest.json
//   2. Uploads each template body file as a ContentVersion (REST)
//   3. Creates namespaced DocGen_Template__c + active DocGen_Template_Version__c
//      (DML insert — works in a subscriber org; no global save method needed)
//
// Usage: node scripts/demo/install/install.mjs <orgAlias> [--only=key1,key2]
//
// This tooling lives under scripts/demo/ (internal), while the template BODIES
// it uploads live under "DEMO TEMPLATES/" (the shareable example library). The
// manifest's `file` paths are relative to that library — "html/financial/...",
// "docx/out/..." — so the two roots are resolved separately below.
// ============================================================================
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

const run = promisify(execFile);
const HERE = path.dirname(fileURLToPath(import.meta.url)); // scripts/demo/install
const REPO_ROOT = path.resolve(HERE, "..", "..", "..");
// Template bodies, NOT the tooling. Kept apart on purpose: the library is
// published, this installer is not.
const DEMO_ROOT = path.join(REPO_ROOT, "DEMO TEMPLATES");
const ORG = process.argv[2] && !process.argv[2].startsWith("--") ? process.argv[2] : null;
const onlyArg = process.argv.find((a) => a.startsWith("--only="));
const ONLY = onlyArg ? onlyArg.split("=")[1].split(",") : null;

const MIME = {
  ".html": "text/html",
  ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
};

async function orgInfo(alias) {
  const { stdout } = await run("sf", ["org", "display", "--target-org", alias, "--json"], { maxBuffer: 1e8 });
  const r = JSON.parse(stdout).result;
  // namespace is null in a --no-namespace scratch org, where the objects are
  // source-deployed under bare API names. See the note on `ns` in main().
  return { token: r.accessToken, url: r.instanceUrl, namespace: r.namespace || "" };
}

async function uploadCv(org, filePath, title) {
  const ext = path.extname(filePath).toLowerCase();
  const meta = JSON.stringify({ Title: title, PathOnClient: path.basename(filePath) });
  const { stdout } = await run(
    "curl",
    [
      "-sS", "--fail-with-body",
      `${org.url}/services/data/v60.0/sobjects/ContentVersion`,
      "-H", `Authorization: Bearer ${org.token}`,
      "-F", `entity_content=${meta};type=application/json`,
      "-F", `VersionData=@${filePath};type=${MIME[ext] || "application/octet-stream"}`,
    ],
    { maxBuffer: 1e8 }
  );
  const id = JSON.parse(stdout).id;
  if (!id) throw new Error("No CV id returned: " + stdout.slice(0, 300));
  return id;
}

function apexLiteral(s) {
  // Embed a JSON string inside an Apex single-quoted string literal.
  return s.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
}

async function main() {
  // No default org. The old default was one specific sandbox, so running this
  // with no argument silently targeted somebody else's org.
  if (!ORG) {
    console.error("usage: node scripts/demo/install/install.mjs <orgAlias> [--only=key1,key2]");
    process.exit(1);
  }
  const manifest = JSON.parse(await fs.readFile(path.join(HERE, "manifest.json"), "utf8"));
  let templates = manifest.templates;
  if (ONLY) templates = templates.filter((t) => ONLY.includes(t.key));

  const org = await orgInfo(ORG);
  // DETECTED, not read from the manifest. The manifest hardcodes
  // "portwoodglobal__" because it was written for a sandbox with the managed
  // package installed. Pointed at a --no-namespace scratch org — where the
  // objects are source-deployed under BARE names — every generated Apex
  // statement then references portwoodglobal__DocGen_Template__c, which does
  // not exist there. The installer reported "Creating template records ..." and
  // created ZERO, with the per-template errors scrolling past in a log nobody
  // reads. The org itself is the authority on its own namespace.
  const ns = process.env.DOCGEN_DEMO_NS !== undefined
    ? process.env.DOCGEN_DEMO_NS
    : (org.namespace ? org.namespace + "__" : "");
  console.log(`Installing ${templates.length} template(s) into ${ORG} (ns=${ns || "<none>"})`);

  // Upload bodies, collect specs with cvId
  const specs = [];
  for (const t of templates) {
    const fp = path.join(DEMO_ROOT, t.file);
    process.stdout.write(`  uploading ${t.key} (${path.basename(t.file)}) ... `);
    const cvId = await uploadCv(org, fp, `DEMO ${t.name} body`);
    console.log(cvId);
    specs.push({
      key: t.key, name: t.name, type: t.type, output: t.output || (t.type === "HTML" ? "PDF" : "Native"),
      baseObject: t.baseObject, category: t.category || "DocGen Demo",
      titleFormat: t.titleFormat || (t.name + " - {Name}"),
      description: t.description || "", pageSize: t.pageSize || "Letter",
      orientation: t.orientation || "Portrait", headerHtml: t.headerHtml || "",
      footerHtml: t.footerHtml || "", customMargins: t.customMargins || "",
      testRecordSoql: t.testRecordSoql || "",
      queryConfig: typeof t.queryConfig === "string" ? t.queryConfig : JSON.stringify(t.queryConfig || ""),
      cvId,
    });
  }

  // Anonymous Apex has a 20,000-char limit, so create templates in small batches.
  const BATCH = 4;
  let totalCreated = 0;
  console.log("Creating template records via Apex (batched) ...");
  for (let i = 0; i < specs.length; i += BATCH) {
    const chunk = specs.slice(i, i + BATCH);
    const specsB64 = Buffer.from(JSON.stringify(chunk), "utf8").toString("base64");
    const apex = buildApex(ns, specsB64);
    const tmp = path.join(os.tmpdir(), `docgen-demo-install-${Date.now()}-${i}.apex`);
    await fs.writeFile(tmp, apex);
    const { stdout } = await run("sf", ["apex", "run", "--target-org", ORG, "-f", tmp], { maxBuffer: 1e8 });
    // USER_DEBUG required. Without it the CLI's echo of the Apex SOURCE — which
    // contains the literal System.debug('DEMO-INSTALL CREATED ...') — is counted
    // as a result, and the installer reports "Created 39/31".
    stdout.split("\n").filter((l) => /USER_DEBUG/.test(l) && /DEMO-INSTALL (CREATED|ERROR)/.test(l)).forEach((l) => {
      const m = l.replace(/.*USER_DEBUG\|\[\d+\]\|DEBUG\|/, "");
      if (/CREATED/.test(m)) totalCreated++;
      console.log("   " + m);
    });
    await fs.unlink(tmp).catch(() => {});
  }
  console.log(`Done. Created ${totalCreated}/${specs.length} templates.`);
  // Exit non-zero when nothing landed. "Done. Created 0/31." followed by exit 0
  // is how a demo org came out with a full data set and no templates at all,
  // and the calling script cheerfully printed "ready to demo".
  if (totalCreated === 0 && specs.length > 0) {
    console.error(
      `\nERROR: no templates were created. The most likely cause is a namespace ` +
        `mismatch — this org reports namespace "${org.namespace || "<none>"}", so the ` +
        `generated Apex used prefix "${ns || "<none>"}". Override with DOCGEN_DEMO_NS.`
    );
    process.exit(1);
  }
}

function buildApex(ns, specsB64) {
  return `// AUTO-GENERATED by install.mjs — do not edit.
String specsJson = EncodingUtil.base64Decode('${specsB64}').toString();
List<Object> specs = (List<Object>) JSON.deserializeUntyped(specsJson);
Integer created = 0, skipped = 0;
for (Object o : specs) {
  try {
    Map<String, Object> s = (Map<String, Object>) o;
    String key = (String) s.get('key');
    String name = (String) s.get('name');
    System.debug('DEMO-INSTALL ROW ' + key + ' type=[' + s.get('type') + '] output=[' + s.get('output') + '] size=[' + s.get('pageSize') + '] orient=[' + s.get('orientation') + ']');
    Id testId = null;
    String soql = (String) s.get('testRecordSoql');
    if (soql != null && soql.trim() != '') {
        try {
            List<SObject> recs = Database.query(soql);
            if (!recs.isEmpty()) testId = recs[0].Id;
        } catch (Exception e) {
            System.debug('DEMO-INSTALL WARN ' + key + ' test-record query failed: ' + e.getMessage());
        }
    }
    // Replace existing demo template with same name (idempotent re-install)
    List<${ns}DocGen_Template__c> existing = [SELECT Id FROM ${ns}DocGen_Template__c WHERE Name = :name];
    if (!existing.isEmpty()) {
        List<${ns}DocGen_Template_Version__c> oldVers = [SELECT Id, ${ns}Content_Version_Id__c FROM ${ns}DocGen_Template_Version__c WHERE ${ns}Template__c IN :existing];
        Set<Id> oldCvIds = new Set<Id>();
        for (${ns}DocGen_Template_Version__c v : oldVers) { if (v.${ns}Content_Version_Id__c != null) oldCvIds.add((Id) v.${ns}Content_Version_Id__c); }
        if (!oldCvIds.isEmpty()) {
            Set<Id> oldDocIds = new Set<Id>();
            for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :oldCvIds]) oldDocIds.add(cv.ContentDocumentId);
            if (!oldDocIds.isEmpty()) { try { delete [SELECT Id FROM ContentDocument WHERE Id IN :oldDocIds]; } catch (Exception ig) {} }
        }
        if (!oldVers.isEmpty()) delete oldVers;
        delete existing;
    }
    ${ns}DocGen_Template__c tpl = new ${ns}DocGen_Template__c(
        Name = name,
        ${ns}Type__c = (String) s.get('type'),
        ${ns}Output_Format__c = (String) s.get('output'),
        ${ns}Base_Object_API__c = (String) s.get('baseObject'),
        ${ns}Query_Config__c = (String) s.get('queryConfig'),
        ${ns}Document_Title_Format__c = (String) s.get('titleFormat'),
        ${ns}Description__c = (String) s.get('description'),
        ${ns}Category__c = (String) s.get('category'),
        ${ns}Page_Size__c = (String) s.get('pageSize'),
        ${ns}Page_Orientation__c = (String) s.get('orientation'),
        ${ns}Is_Active__c = true
    );
    if (testId != null) tpl.${ns}Test_Record_Id__c = String.valueOf(testId);
    String hh = (String) s.get('headerHtml');
    String fh = (String) s.get('footerHtml');
    if (hh != null && hh != '') tpl.${ns}Header_Html__c = hh;
    if (fh != null && fh != '') tpl.${ns}Footer_Html__c = fh;
    String cm = (String) s.get('customMargins');
    if (cm != null && cm != '') tpl.${ns}Custom_Margins__c = cm;
    insert tpl;

    ${ns}DocGen_Template_Version__c ver = new ${ns}DocGen_Template_Version__c(
        ${ns}Template__c = tpl.Id,
        ${ns}Is_Active__c = true,
        ${ns}Content_Version_Id__c = (String) s.get('cvId'),
        ${ns}Query_Config__c = (String) s.get('queryConfig'),
        ${ns}Output_Format__c = (String) s.get('output'),
        ${ns}Base_Object_API__c = (String) s.get('baseObject'),
        ${ns}Document_Title_Format__c = (String) s.get('titleFormat'),
        ${ns}Description__c = (String) s.get('description'),
        ${ns}Category__c = (String) s.get('category'),
        ${ns}Page_Size__c = (String) s.get('pageSize'),
        ${ns}Page_Orientation__c = (String) s.get('orientation')
    );
    if (hh != null && hh != '') ver.${ns}Header_Html__c = hh;
    if (fh != null && fh != '') ver.${ns}Footer_Html__c = fh;
    if (cm != null && cm != '') ver.${ns}Custom_Margins__c = cm;
    // ALWAYS set the version type, INCLUDING HTML.
    //
    // This previously said "restricted picklist (Word / PowerPoint only); leave
    // blank for HTML" and skipped it. Both halves were wrong. The picklist does
    // have an HTML value, and — the part that actually bit — Word is marked
    // default=true on the field, so leaving it blank does not leave it blank:
    // the platform stamps Word.
    //
    // DocGenController then does template.Type__c = version.Type__c, so every
    // HTML template in the demo org was typed as Word. It still GENERATED
    // correctly (generation reads the template's own type), which is why this
    // survived a check that only looked at output — but the editor reads the
    // VERSION type, tried to open an HTML body as a DOCX archive, and showed
    // nothing. Every HTML demo template opened blank.
    String tp = (String) s.get('type');
    if (tp != null && tp != '') ver.${ns}Type__c = tp;
    insert ver;
    created++;
    System.debug('DEMO-INSTALL CREATED ' + key + ' -> tpl=' + tpl.Id + ' ver=' + ver.Id + ' test=' + testId);
  } catch (Exception e) {
    skipped++;
    System.debug('DEMO-INSTALL ERROR ' + e.getMessage());
  }
}
System.debug('DEMO-INSTALL DONE created=' + created + ' skipped=' + skipped);
`;
}

main().catch((e) => { console.error(e); process.exit(1); });
