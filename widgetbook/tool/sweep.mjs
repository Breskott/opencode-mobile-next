#!/usr/bin/env node
// Screenshot sweep: loads every catalog use-case in headless Chromium at
// phone size (Widgetbook's `preview` mode hides the side panels, so the
// screen fills the page) and saves
//
//   <out>/<area>/<component>/<state>.png         full size
//   <out>/<area>/<component>/<state>.thumb.png   small, for the map
//   <out>/report.json                            what worked and what failed
//   <out>/index.html                             a one-screen-per-image gallery
//
//   node tool/sweep.mjs --base http://127.0.0.1:8770 --catalog catalog.json \
//        --out build/site/shots [--jobs 3] [--timeout 90] [--only substring] \
//        [--standard standard_report.json]
//
// With --standard (the screen standard check's report) each screenshot gets a
// badge ("2 issues: cut-off text, 4 text sizes") and shots/issues.html lists
// every use-case with findings, sorted by screen.
//
// A page fails when Chromium exits non-zero or times out, the screenshot is
// blank (almost one colour), or the console logs "Scene failed" (the catalog's
// own fake data threw) or an uncaught error.
import { spawn } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync, existsSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, v, i, all) => {
    if (v.startsWith("--")) acc.push([v.slice(2), all[i + 1] && !all[i + 1].startsWith("--") ? all[i + 1] : "true"]);
    return acc;
  }, []),
);
const base = args.base ?? "http://127.0.0.1:8770";
const outDir = args.out ?? "build/site/shots";
const jobs = Number(args.jobs ?? 3);
const timeoutMs = Number(args.timeout ?? 90) * 1000;
const only = args.only ?? "";
const standardFile = args.standard ?? "";
const chromium = args.chromium ?? "/snap/bin/chromium";
const catalog = JSON.parse(readFileSync(args.catalog ?? "catalog.json", "utf8"));

const cases = [];
for (const c of catalog) {
  for (const u of c.useCases) {
    if (only && !u.path.includes(only)) continue;
    cases.push({ area: c.area, component: c.component, screen: c.screen, ...u });
  }
}

// Snap Chromium moves its processes out of our process group (and out of the
// systemd unit), so a timeout cannot kill them the normal way. Find them by
// the unique screenshot path in their command line (never by a name pattern)
// and kill exactly those trees.
function killTreesWith(marker) {
  const ppid = new Map(), mine = new Set();
  for (const d of readdirSync("/proc")) {
    if (!/^\d+$/.test(d)) continue;
    try {
      const stat = readFileSync(`/proc/${d}/stat`, "utf8");
      ppid.set(Number(d), Number(stat.slice(stat.lastIndexOf(")") + 2).split(" ")[1]));
      if (readFileSync(`/proc/${d}/cmdline`, "utf8").includes(marker)) mine.add(Number(d));
    } catch { /* process ended */ }
  }
  let grew = true;
  while (grew) {
    grew = false;
    for (const [pid, parent] of ppid) if (mine.has(parent) && !mine.has(pid)) { mine.add(pid); grew = true; }
  }
  for (const pid of mine) { try { process.kill(pid, "SIGKILL"); } catch { /* gone */ } }
}

function run(cmd, argv, ms) {
  return new Promise((resolve) => {
    // Own process group, so a timeout kills Chromium's children too.
    const p = spawn(cmd, argv, { stdio: ["ignore", "pipe", "pipe"], detached: true });
    let out = "", err = "";
    p.stdout.on("data", (d) => (out += d));
    p.stderr.on("data", (d) => (err += d));
    const timer = setTimeout(() => { try { process.kill(-p.pid, "SIGKILL"); } catch { p.kill("SIGKILL"); } resolve({ code: -1, out, err, timedOut: true }); }, ms);
    p.on("close", (code) => { clearTimeout(timer); resolve({ code, out, err, timedOut: false }); });
  });
}

async function shoot(c) {
  const file = join(outDir, `${c.shot}.png`);
  mkdirSync(dirname(file), { recursive: true });
  const url = `${base}/#/?path=${c.path}&preview`;
  const r = await run(chromium, [
    "--headless=new", "--no-sandbox", "--password-store=basic", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
    "--hide-scrollbars", "--window-size=412,915", "--enable-logging=stderr", "--v=0",
    "--virtual-time-budget=40000", `--screenshot=${file}`, url,
  ], timeoutMs);
  killTreesWith(`--screenshot=${file}`);
  const result = { ...c, file: `${c.shot}.png`, ok: true, problems: [] };
  if (r.timedOut) result.problems.push("timed out");
  else if (r.code !== 0) result.problems.push(`chromium exit ${r.code}`);
  const logs = r.err.split("\n").filter((l) => l.includes("CONSOLE"));
  for (const l of logs) {
    if (/Scene failed|Fake data failed|Uncaught|Unhandled|Exception/i.test(l) && !/Noto fonts/.test(l)) {
      result.problems.push(l.replace(/^.*CONSOLE:\d+\]\s*/, "").slice(0, 200));
      break;
    }
  }
  if (existsSync(file)) {
    // Blank page: the standard deviation of the grey levels is near zero.
    const s = await run("convert", [file, "-colorspace", "Gray", "-format", "%[fx:standard_deviation]", "info:"], 20000);
    if (Number(s.out) < 0.004) result.problems.push("blank page");
    await run("convert", [file, "-resize", "200x", "-strip", file.replace(/\.png$/, ".thumb.png")], 20000);
  } else {
    result.problems.push("no screenshot");
  }
  result.ok = result.problems.length === 0;
  return result;
}

const results = [];
let next = 0;
async function worker() {
  while (next < cases.length) {
    const c = cases[next++];
    const r = await shoot(c);
    results.push(r);
    console.log(`${r.ok ? "ok  " : "FAIL"} ${c.path}${r.ok ? "" : "  " + r.problems.join("; ")}`);
  }
}
await Promise.all(Array.from({ length: Math.min(jobs, cases.length) }, worker));
results.sort((a, b) => a.path.localeCompare(b.path));

const failures = results.filter((r) => !r.ok);
writeFileSync(
  join(outDir, "report.json"),
  JSON.stringify({ at: new Date().toISOString(), total: results.length, failed: failures.length,
    failures: failures.map((f) => ({ path: f.path, problems: f.problems })),
    results: results.map((r) => ({ path: r.path, ok: r.ok, file: r.file })) }, null, 1) + "\n",
);

let standard = {};
if (standardFile && existsSync(standardFile)) {
  standard = JSON.parse(readFileSync(standardFile, "utf8")).results ?? {};
}
const ruleText = (rule, detail) => {
  const n = (detail.match(/^(\d+)/) ?? [])[1];
  return ({
    overflow: "overflow",
    cutoff: "cut-off text",
    red: "red used",
    "text-sizes": `${n} text sizes`,
    "main-actions": `${n} main actions`,
    "first-view-items": `${n} items in first view`,
  })[rule] ?? rule;
};
// One entry per rule (the worst pass keeps its detail), in a fixed order.
const issuesOf = (path) => {
  const found = new Map();
  for (const f of standard[path]?.findings ?? []) {
    if (!found.has(f.rule)) found.set(f.rule, f);
  }
  return [...found.values()];
};
const badge = (path) => {
  const list = issuesOf(path);
  if (!standardFile || !(path in standard)) return "";
  if (list.length === 0) return `<span class="ok">no issues</span>`;
  return `<span class="bad">${list.length} issue${list.length > 1 ? "s" : ""}: ${list.map((f) => esc(ruleText(f.rule, f.detail))).join(", ")}</span>`;
};
const esc = (s) => String(s).replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[ch]);
const areas = new Map();
for (const r of results) { if (!areas.has(r.area)) areas.set(r.area, []); areas.get(r.area).push(r); }
const body = [...areas.entries()].map(([area, list]) =>
  `<section><h2>${esc(area)}</h2>${list.map((r) => `<figure>
<a href="../#/?path=${esc(r.path)}"><img loading="lazy" src="${esc(r.file)}" width="412" alt="${esc(r.component)}: ${esc(r.name)}"></a>
<figcaption><b>${esc(r.component)}</b>: ${esc(r.name)} ${badge(r.path)}${r.ok ? "" : ` <span class="bad">${esc(r.problems.join("; "))}</span>`}</figcaption></figure>`).join("")}</section>`).join("\n");
writeFileSync(join(outDir, "index.html"), `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Screenshots</title>
<style>
:root{--bg:#f3f3f1;--ink:#1b1c1b;--ink2:#5d605d;--line:#d5d7d3;--bad:#b3261e}
@media (prefers-color-scheme:dark){:root{--bg:#121312;--ink:#ecedec;--ink2:#a3a7a3;--line:#343734;--bad:#ff8a80}}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.4 system-ui,sans-serif;padding:0 16px 48px}
header{padding:16px 0;display:flex;gap:16px;align-items:baseline;flex-wrap:wrap}
h1{font-size:20px;margin:0}h2{font-size:18px;margin:32px 0 8px;border-bottom:1px solid var(--line);padding-bottom:6px}
a{color:inherit}figure{margin:16px 0}img{max-width:100%;height:auto;display:block;border:1px solid var(--line);border-radius:12px}
figcaption{margin-top:6px;color:var(--ink2)}.bad{color:var(--bad)}.ok{color:var(--ink2)}
</style></head><body>
<header><h1>Every screen, every state</h1><a href="../">Catalog</a><a href="../map/">Map</a><a href="issues.html">Issues</a>
<span>${results.length} screenshots, ${failures.length} failed</span></header>
${body}
</body></html>
`);
// issues.html: every use-case with findings, sorted by screen.
const withIssues = results.filter((r) => issuesOf(r.path).length > 0)
  .sort((a, b) => (a.component + a.name).localeCompare(b.component + b.name));
const amberOf = (path) => Object.values(standard[path]?.amberUsed ?? {}).flat();
writeFileSync(join(outDir, "issues.html"), `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Standard issues</title>
<style>
:root{--bg:#f3f3f1;--ink:#1b1c1b;--ink2:#5d605d;--line:#d5d7d3;--bad:#b3261e}
@media (prefers-color-scheme:dark){:root{--bg:#121312;--ink:#ecedec;--ink2:#a3a7a3;--line:#343734;--bad:#ff8a80}}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.4 system-ui,sans-serif;padding:0 16px 48px}
header{padding:16px 0}h1{font-size:20px;margin:0 0 4px}a{color:inherit}
article{display:flex;gap:12px;border-top:1px solid var(--line);padding:12px 0}
img{width:96px;height:auto;border:1px solid var(--line);border-radius:8px;align-self:flex-start}
ul{margin:4px 0;padding-left:18px}.k{color:var(--ink2);font-size:13px}.bad{color:var(--bad)}
</style></head><body>
<header><h1>Screen standard: ${withIssues.length} of ${results.length} use-cases have issues</h1>
<span class="k">docs/ux-system/screen-standard.md. <a href="index.html">Screenshots</a> <a href="../">Catalog</a> <a href="../map/">Map</a></span></header>
${standardFile ? withIssues.map((r) => `<article><a href="../#/?path=${esc(r.path)}"><img loading="lazy" src="${esc(r.shot)}.thumb.png" alt=""></a><div>
<b>${esc(r.component)}</b>: ${esc(r.name)}<ul>${issuesOf(r.path).map((f) => `<li><span class="bad">${esc(ruleText(f.rule, f.detail))}</span> <span class="k">(${esc(f.pass)}) ${esc(f.detail)}</span></li>`).join("")}</ul>
${amberOf(r.path).length ? `<div class="k">amber used: ${esc([...new Set(amberOf(r.path))].slice(0, 4).join("; "))}</div>` : ""}</div></article>`).join("\n") : "<p>The standard check did not run.</p>"}
</body></html>
`);
console.log(`swept ${results.length}, failed ${failures.length}`);
process.exit(0);
