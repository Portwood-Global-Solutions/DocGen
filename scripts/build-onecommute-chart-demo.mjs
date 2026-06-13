#!/usr/bin/env node
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

const run = promisify(execFile);

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const source = path.join(root, "docs", "OneCommuteExampleReportSource.pptx");
const out = path.join(root, "docs", "OneCommuteChartDemoTemplate.pptx");

const charts = [
  {
    slide: "ppt/slides/slide7.xml",
    id: 901,
    name: "DocGen Live Mode Split Chart",
    x: 6758940,
    y: 1778507,
    cx: 5231892,
    cy: 2842895,
    tag:
      "{Chart:Survey_Responses__r:Commute_Mode__c:bar:title=Commute Mode Split&width=550&height=300&colors=#8FD3EA,#40B9D2,#14566D,#8BC53F,#F6B800}",
    label: "Live DocGen chart: commute mode split",
  },
  {
    slide: "ppt/slides/slide9.xml",
    id: 902,
    name: "DocGen Live Shuttle Interest Chart",
    x: 6880000,
    y: 930000,
    cx: 5010000,
    cy: 2320000,
    tag:
      "{Chart:Survey_Responses__r:Shuttle_Interest__c:bar:title=Shuttle Interest&width=525&height=245&colors=#8FD3EA,#40B9D2,#14566D,#8BC53F,#F6B800}",
    label: "Live DocGen chart: shuttle interest",
  },
  {
    slide: "ppt/slides/slide11.xml",
    id: 903,
    name: "DocGen Live Resource Interest Chart",
    x: 3860000,
    y: 1080000,
    cx: 7640000,
    cy: 4380000,
    tag:
      "{Chart:Survey_Responses__r:Resource_Interests__c:bar:split=;&title=Requested Resources and Benefits&width=802&height=460&colors=#8FD3EA,#40B9D2,#14566D,#8BC53F,#F6B800}",
    label: "Live DocGen chart: commuter resources requested",
  },
];

const directTextReplacements = [
  ["OneCommute", "{Client_Name__c}"],
  ["925 NorthPoint Parkway", "{Address__c}"],
  ["925 Northpoint Parkway", "{Address__c}"],
  ["925 Northpoint Parkway, Alpharetta, GA  30005", "{Address__c}, {City__c}, {State__c} {Postal_Code__c}"],
  ["2025", "{Reporting_Year__c}"],
  ["November", "{Report_Month__c}"],
  ["958", "{Total_Employees__c:number}"],
  ["48.6%,", "{Alt_Mode_Rate__c}%, "],
  ["48.6%.", "{Alt_Mode_Rate__c}%."],
  ["48.6%", "{Alt_Mode_Rate__c}%"],
  ["35% ", "{Alt_Mode_Target__c}% "],
  ["35", "{Alt_Mode_Target__c}"],
];

function xmlEscape(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function tableCell(value, opts = {}) {
  const fill = opts.fill ?? "FFFFFF";
  const color = opts.color ?? "163746";
  const bold = opts.bold ? ' b="1"' : "";
  const size = opts.size ?? "800";
  const align = opts.align ?? "ctr";
  return (
    `<a:tc><a:txBody><a:bodyPr wrap="square" lIns="45720" tIns="25400" rIns="45720" bIns="25400"/><a:lstStyle/>` +
    `<a:p><a:pPr algn="${align}"/><a:r><a:rPr sz="${size}"${bold} dirty="0">` +
    `<a:solidFill><a:srgbClr val="${color}"/></a:solidFill><a:latin typeface="Calibri"/></a:rPr><a:t>${xmlEscape(value)}</a:t></a:r>` +
    `<a:endParaRPr sz="${size}"/></a:p></a:txBody>` +
    `<a:tcPr marL="0" marR="0" marT="0" marB="0"><a:lnL w="6350"><a:solidFill><a:srgbClr val="D8EAF2"/></a:solidFill></a:lnL><a:lnR w="6350"><a:solidFill><a:srgbClr val="D8EAF2"/></a:solidFill></a:lnR><a:lnT w="6350"><a:solidFill><a:srgbClr val="D8EAF2"/></a:solidFill></a:lnT><a:lnB w="6350"><a:solidFill><a:srgbClr val="D8EAF2"/></a:solidFill></a:lnB><a:solidFill><a:srgbClr val="${fill}"/></a:solidFill></a:tcPr></a:tc>`
  );
}

function tableRow(cells, opts = {}) {
  const height = opts.height ?? 230000;
  return `<a:tr h="${height}">${cells.map((cell) => tableCell(cell, opts)).join("")}</a:tr>`;
}

function hiddenLoopRow(tag, columnCount) {
  return tableRow([tag, ...Array(Math.max(0, columnCount - 1)).fill("")], {
    fill: "FFFFFF",
    color: "FFFFFF",
    size: "100",
    height: 1000,
  });
}

function livePowerPointTable(columns, widths, openTag, rowCells, closeTag, footerCells = null) {
  const grid = widths.map((w) => `<a:gridCol w="${w}"/>`).join("");
  return (
    `<a:tbl><a:tblPr firstRow="1" bandRow="1"><a:tableStyleId>{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}</a:tableStyleId></a:tblPr>` +
    `<a:tblGrid>${grid}</a:tblGrid>` +
    tableRow(columns, { fill: "14566D", color: "FFFFFF", bold: true, size: "760", height: 260000 }) +
    hiddenLoopRow(openTag, columns.length) +
    tableRow(rowCells, { fill: "F7FBFD", color: "163746", size: "690", height: 190000 }) +
    hiddenLoopRow(closeTag, columns.length) +
    (footerCells ? tableRow(footerCells, { fill: "D8EAF2", color: "14566D", bold: true, size: "700", height: 210000 }) : "") +
    `</a:tbl>`
  );
}

function employerTable() {
  return livePowerPointTable(
    ["Employer", "# Employees", "Responses", "Response Rate"],
    [3300000, 1150000, 1150000, 1350000],
    "{#Employers__r}",
    ["{Name}", "{Employee_Count__c:number}", "{Response_Count__c:number}", "{Response_Rate__c:percent}"],
    "{/Employers__r}",
    ["Total", "{Total_Employees__c:number}", "", "{Alt_Mode_Rate__c}%"]
  );
}

function bucketTable(id, relationship, field, title, modifier = "") {
  const modifierSuffix = modifier ? `:${modifier}` : "";
  return livePowerPointTable(
    [title, "Percent", "Count"],
    [4550000, 1200000, 1000000],
    `{#ChartBucket:${relationship}:${field}${modifierSuffix}}`,
    ["{key_label}", "{percent}%", "{count}"],
    "{/ChartBucket}"
  );
}

function tripTable() {
  return livePowerPointTable(
    ["Location", "Dir", "Daily", "Midweek", "AM Peak", "PM Peak"],
    [2550000, 750000, 1000000, 1100000, 900000, 900000],
    "{#Trip_Counts__r}",
    [
      "{Location__c}",
      "{Direction__c}",
      "{Daily_Average__c:number}",
      "{Midweek_Average__c:number}",
      "{AM_Peak__c:number}",
      "{PM_Peak__c:number}",
    ],
    "{/Trip_Counts__r}"
  );
}

function placeholderShape(chart) {
  const label = xmlEscape(chart.label);
  const tag = xmlEscape(chart.tag);
  return (
    `<p:sp>` +
    `<p:nvSpPr><p:cNvPr id="${chart.id}" name="${xmlEscape(chart.name)}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>` +
    `<p:spPr><a:xfrm><a:off x="${chart.x}" y="${chart.y}"/><a:ext cx="${chart.cx}" cy="${chart.cy}"/></a:xfrm>` +
    `<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>` +
    `<a:solidFill><a:srgbClr val="F7FBFD"/></a:solidFill>` +
    `<a:ln w="12700"><a:solidFill><a:srgbClr val="40B9D2"/></a:solidFill><a:prstDash val="solid"/></a:ln></p:spPr>` +
    `<p:txBody><a:bodyPr vert="horz" wrap="square" lIns="91440" tIns="91440" rIns="91440" bIns="91440" rtlCol="0"><a:spAutoFit/></a:bodyPr><a:lstStyle/>` +
    `<a:p><a:pPr algn="ctr"><a:spcBef><a:spcPts val="1800"/></a:spcBef></a:pPr><a:r><a:rPr sz="1800" b="1" dirty="0"><a:solidFill><a:srgbClr val="14566D"/></a:solidFill><a:latin typeface="Calibri"/></a:rPr><a:t>${label}</a:t></a:r><a:endParaRPr sz="1800"/></a:p>` +
    `<a:p><a:pPr algn="ctr"/><a:r><a:rPr sz="1050" dirty="0"><a:solidFill><a:srgbClr val="6D7D85"/></a:solidFill><a:latin typeface="Calibri"/></a:rPr><a:t>Generated from live OneCommute Survey Response rows in DocGen Runner.</a:t></a:r><a:endParaRPr sz="1050"/></a:p>` +
    `<a:p><a:pPr algn="ctr"/><a:r><a:rPr sz="800" dirty="0"><a:solidFill><a:srgbClr val="F7FBFD"/></a:solidFill><a:latin typeface="Calibri"/></a:rPr><a:t>${tag}</a:t></a:r><a:endParaRPr sz="800"/></a:p>` +
    `</p:txBody></p:sp>`
  );
}

function replaceTextRuns(xml) {
  let outXml = xml;
  for (const [from, to] of directTextReplacements) {
    outXml = outXml.replaceAll(`<a:t>${xmlEscape(from)}</a:t>`, `<a:t>${xmlEscape(to)}</a:t>`);
  }
  return outXml;
}

function replaceFirstTable(xml, tableXml) {
  return xml.replace(/<a:tbl[\s\S]*?<\/a:tbl>/, tableXml);
}

function replaceAllGraphicTablesWithFirstTable(xml, tableXml) {
  let first = true;
  return xml.replace(/<p:graphicFrame>[\s\S]*?<a:tbl[\s\S]*?<\/a:tbl>[\s\S]*?<\/p:graphicFrame>/g, (frame) => {
    if (!first) {
      return "";
    }
    first = false;
    return frame.replace(/<a:tbl[\s\S]*?<\/a:tbl>/, tableXml);
  });
}

function removeExistingDocGenChartShapes(xml) {
  return xml.replace(/<p:sp>[\s\S]*?\{Chart:[\s\S]*?<\/p:sp>/g, "");
}

async function stripPowerPointRevisionParts(tmp) {
  await fs.rm(path.join(tmp, "ppt", "revisionInfo.xml"), { force: true });
  await fs.rm(path.join(tmp, "ppt", "changesInfos"), { recursive: true, force: true });
  await fs.rm(path.join(tmp, "[trash]"), { recursive: true, force: true });

  const relsPath = path.join(tmp, "ppt", "_rels", "presentation.xml.rels");
  try {
    let rels = await fs.readFile(relsPath, "utf8");
    rels = rels.replace(/<Relationship\s+[^>]*(?:revisionInfo|changesInfo)[^>]*\/>/g, "");
    await fs.writeFile(relsPath, rels, "utf8");
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }

  const contentTypesPath = path.join(tmp, "[Content_Types].xml");
  let contentTypes = await fs.readFile(contentTypesPath, "utf8");
  contentTypes = contentTypes
    .replace(/<Override\s+PartName="\/ppt\/revisionInfo\.xml"[^>]*\/>/g, "")
    .replace(/<Override\s+PartName="\/ppt\/changesInfos\/[^"]+"[^>]*\/>/g, "");
  await fs.writeFile(contentTypesPath, contentTypes, "utf8");
}

function normalizePowerPointSlideXml(xml) {
  return xml
    .replaceAll("<a:t></a:t>", "<a:t> </a:t>")
    .replaceAll("<a:tableStyleId></a:tableStyleId>", "<a:tableStyleId>{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}</a:tableStyleId>");
}

async function listPackageFiles(dir, relative = "") {
  const entries = await fs.readdir(path.join(dir, relative), { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const child = path.join(relative, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listPackageFiles(dir, child)));
    } else {
      files.push(child);
    }
  }
  return files.sort((a, b) => a.localeCompare(b));
}

async function main() {
  await fs.access(source);
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), "onecommute-pptx-"));

  try {
    await run("unzip", ["-q", source, "-d", tmp]);
    await stripPowerPointRevisionParts(tmp);

    const tableBySlide = new Map([
      ["ppt/slides/slide5.xml", employerTable()],
      ["ppt/slides/slide6.xml", bucketTable(806, "Survey_Responses__r", "Commute_Mode__c", "Transportation Mode")],
      ["ppt/slides/slide7.xml", bucketTable(807, "Survey_Responses__r", "Commute_Mode__c", "Commuter Modes")],
      ["ppt/slides/slide8.xml", bucketTable(808, "Survey_Responses__r", "Alternative_Mode__c", "Response Choice")],
      ["ppt/slides/slide9.xml", bucketTable(809, "Survey_Responses__r", "Shuttle_Interest__c", "Response Choice")],
      ["ppt/slides/slide10.xml", bucketTable(810, "Survey_Responses__r", "Resource_Interests__c", "Response Choice", "split=;")],
    ]);

    for (let slideNumber = 1; slideNumber <= 13; slideNumber++) {
      const slideName = `ppt/slides/slide${slideNumber}.xml`;
      const slidePath = path.join(tmp, slideName);
      try {
        let xml = await fs.readFile(slidePath, "utf8");
        xml = removeExistingDocGenChartShapes(xml);
        xml = replaceTextRuns(xml);
        if (tableBySlide.has(slideName)) {
          xml = replaceFirstTable(xml, tableBySlide.get(slideName));
        }
        if (slideName === "ppt/slides/slide13.xml") {
          xml = replaceAllGraphicTablesWithFirstTable(xml, tripTable());
        }
        xml = normalizePowerPointSlideXml(xml);
        await fs.writeFile(slidePath, xml, "utf8");
      } catch (error) {
        if (error.code !== "ENOENT") {
          throw error;
        }
      }
    }

    for (const chart of charts) {
      const slidePath = path.join(tmp, chart.slide);
      let xml = await fs.readFile(slidePath, "utf8");
      if (!xml.includes("</p:spTree>")) {
        throw new Error(`Could not find slide shape tree in ${chart.slide}`);
      }
      xml = xml.replace("</p:spTree>", `${placeholderShape(chart)}</p:spTree>`);
      xml = normalizePowerPointSlideXml(xml);
      await fs.writeFile(slidePath, xml, "utf8");
    }

    await fs.mkdir(path.dirname(out), { recursive: true });
    await fs.rm(out, { force: true });
    const packageFiles = await listPackageFiles(tmp);
    await run("zip", ["-q", "-X", out, ...packageFiles], { cwd: tmp });
  } finally {
    await fs.rm(tmp, { recursive: true, force: true });
  }

  console.log(out);
}

await main();
