#!/usr/bin/env node
// Generate a document from every demo template against its Test_Record_Id and
// report PASS/FAIL + size. Usage: node validate.mjs <org> [--skip=key1,key2]
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
const run = promisify(execFile);
const ORG = process.argv[2] && !process.argv[2].startsWith("--") ? process.argv[2] : "dave@portwood.dev.demo";
const skipArg = process.argv.find((a) => a.startsWith("--skip="));
const SKIP = skipArg ? skipArg.split("=")[1].split(",") : [];

const NS = "portwoodglobal__";
// Pull templates (Name + Id + test id + type) as JSON via apex
const listApex = `
List<${NS}DocGen_Template__c> ts = [SELECT Id, Name, ${NS}Type__c, ${NS}Test_Record_Id__c, ${NS}Category__c FROM ${NS}DocGen_Template__c WHERE ${NS}Category__c IN ('Financial Services','Professional Services','Manufacturing & Retail','Real Estate & Legal','Events','Nonprofit','Certificates','Education','Transcripts') ORDER BY ${NS}Category__c, Name];
List<Map<String,Object>> out = new List<Map<String,Object>>();
for (${NS}DocGen_Template__c t : ts) out.add(new Map<String,Object>{'id'=>t.Id,'name'=>t.Name,'type'=>t.get('${NS}Type__c'),'rec'=>t.get('${NS}Test_Record_Id__c')});
System.debug('TLIST=' + JSON.serialize(out));
`;
async function apex(src) {
  const tmp = path.join(os.tmpdir(), `dg-val-${Date.now()}-${Math.floor(performance.now())}.apex`);
  await fs.writeFile(tmp, src);
  const { stdout } = await run("sf", ["apex", "run", "--target-org", ORG, "-f", tmp], { maxBuffer: 1e8 });
  await fs.unlink(tmp).catch(() => {});
  return stdout;
}
function dbg(out, marker) {
  const line = out.split("\n").find((l) => l.includes("USER_DEBUG") && l.includes(marker));
  return line ? line.slice(line.indexOf(marker)) : null;
}

const listOut = await apex(listApex);
const raw = dbg(listOut, "TLIST=");
const templates = JSON.parse(raw.slice("TLIST=".length));
console.log(`Validating ${templates.length} templates against ${ORG}\n`);

let pass = 0, fail = 0;
for (const t of templates) {
  const key = t.name;
  if (!t.rec) { console.log(`  SKIP   ${key} (no test record)`); continue; }
  if (SKIP.some((s) => key.toLowerCase().includes(s.toLowerCase()))) { console.log(`  SKIP   ${key}`); continue; }
  const gen = `
try {
  Id doc = portwoodglobal.DocGenService.generateDocument('${t.id}', '${t.rec}');
  ContentVersion cv = [SELECT Id, FileExtension, ContentSize FROM ContentVersion WHERE ContentDocumentId=:doc ORDER BY VersionNumber DESC LIMIT 1];
  System.debug('VAL_OK ext=' + cv.FileExtension + ' bytes=' + cv.ContentSize + ' cv=' + cv.Id);
} catch (Exception e) { System.debug('VAL_ERR ' + e.getMessage()); }
`;
  try {
    const out = await apex(gen);
    const ok = dbg(out, "VAL_OK");
    const err = dbg(out, "VAL_ERR");
    if (ok) { pass++; console.log(`  PASS   ${key.padEnd(48)} ${ok.replace("VAL_OK ", "")}`); }
    else { fail++; console.log(`  FAIL   ${key.padEnd(48)} ${err || "(no result)"}`); }
  } catch (e) {
    fail++; console.log(`  FAIL   ${key.padEnd(48)} ${String(e.message).split("\n")[0].slice(0, 100)}`);
  }
}
console.log(`\n=== PASS: ${pass}  FAIL: ${fail} ===`);
