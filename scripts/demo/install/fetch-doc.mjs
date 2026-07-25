#!/usr/bin/env node
// Download a ContentVersion's binary by Id.
// Usage: node fetch-doc.mjs <org> <contentVersionId> <outPath>
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs/promises";
const run = promisify(execFile);
const [org, cvId, out] = process.argv.slice(2);
const { stdout } = await run("sf", ["org", "display", "--target-org", org, "--json"], { maxBuffer: 1e8 });
const r = JSON.parse(stdout).result;
const res = await run("curl", ["-sS",
  `${r.instanceUrl}/services/data/v60.0/sobjects/ContentVersion/${cvId}/VersionData`,
  "-H", `Authorization: Bearer ${r.accessToken}`, "--output", out], { maxBuffer: 1e8 });
const st = await fs.stat(out);
console.log(`saved ${out} (${st.size} bytes)`);
