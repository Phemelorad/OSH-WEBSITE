// Static error audit for every page + shared script in the project.
//   node scripts/audit-pages.mjs        (run from the project root)
// Read-only: it parses files and shells out to `node --check` for syntax.
// It never touches the network or the database. Exit code 1 = findings.
import fs from 'fs';
import os from 'os';
import path from 'path';
import { execFileSync } from 'child_process';

const ROOT = process.cwd();
const htmlFiles = fs.readdirSync(ROOT).filter(f => f.endsWith('.html')).sort();
const jsFiles = fs.readdirSync(ROOT).filter(f => f.endsWith('.js') && f !== 'supabase.min.js').sort();
const read = f => fs.readFileSync(path.join(ROOT, f), 'utf8');
const lineOf = (t, i) => t.slice(0, i).split('\n').length;

// ── schema ────────────────────────────────────────────────
const sql = read('database_schema.sql');
const SCHEMA = new Map(), FKS = new Map();
const addFk = (a, b) => { if (!FKS.has(a)) FKS.set(a, new Set()); FKS.get(a).add(b); if (!FKS.has(b)) FKS.set(b, new Set()); FKS.get(b).add(a); };
for (const m of sql.matchAll(/CREATE TABLE public\.([a-z0-9_]+)\s*\(([\s\S]*?)\n\);/g)) {
  const name = m[1], body = m[2], cols = new Set();
  for (const part of body.split(/,\n/)) {
    const t = part.trim().replace(/\s+/g, ' ');
    if (!t || /^(CONSTRAINT|PRIMARY KEY|FOREIGN KEY|UNIQUE|CHECK|REFERENCES|ON DELETE)/i.test(t)) continue;
    const cm = t.match(/^"?([a-z0-9_]+)"?\s+[A-Za-z]/i);
    if (cm) cols.add(cm[1].toLowerCase());
  }
  SCHEMA.set(name, cols);
  for (const fk of body.matchAll(/REFERENCES public\.([a-z0-9_]+)/g)) addFk(name, fk[1]);
}
const NOT_NULL = new Map();
for (const m of sql.matchAll(/CREATE TABLE public\.([a-z0-9_]+)\s*\(([\s\S]*?)\n\);/g)) {
  const req = new Set();
  for (const part of m[2].split(/,\n/)) {
    const t = part.trim().replace(/\s+/g, ' ');
    if (!t || /^(CONSTRAINT|PRIMARY KEY|FOREIGN KEY|UNIQUE|CHECK)/i.test(t)) continue;
    const cm = t.match(/^"?([a-z0-9_]+)"?\s+[A-Za-z].*?NOT NULL/i);
    if (cm && !/DEFAULT/i.test(t)) req.add(cm[1].toLowerCase());
  }
  NOT_NULL.set(m[1], req);
}
const VIEWS = new Set(['company_register_view','accident_report_view','injury_disease_report_view','injury_claims_view','incident_chain_view','user_roles_view','inspections_by_month','active_users_summary','recent_login_activity','accident_statistics','injury_disease_statistics','inspection_report_view','inspection_monthly_summary','inspection_inspector_summary','contravention_frequency','inspections_pending_followup','functions_without_search_path','accident_report_persons_view','dangerous_occurrence_full_view']);
const CLIENT_TABLES = new Set(['companies','company_branches','inspection_bookings','notifications','user_profiles','ohs_form_19','accident_reports','accident_injured_persons','accident_report_persons','dangerous_occurrence_reports','dangerous_occurrence_persons','injury_disease_reports','injury_claims','workers_registry','workplace_inspections','medical_examination_reports','permanent_impairment_reports','practitioner_clients','claim_documents','medical_attendance_notifications','certificate_of_insurance','bl_form_43_02_wages','bl_form_43_04_incapacity']);

// ── define / include maps ─────────────────────────────────
const DEF_RE = [
  /function\s+([A-Za-z0-9_$]+)\s*\(/g,
  /(?:window|globalThis)\.([A-Za-z0-9_$]+)\s*=\s*(?:async\s*)?(?:function|\()/g,
  /(?:const|let|var)\s+([A-Za-z0-9_$]+)\s*=\s*(?:async\s*)?(?:function\s*\(|\([^)]*\)\s*=>)/g,
];
const defsOf = (text) => {
  const s = new Set();
  for (const re of DEF_RE) { re.lastIndex = 0; let m; while ((m = re.exec(text))) s.add(m[1]); }
  return s;
};
const JS = new Map();   // file -> {text, defs}
for (const f of jsFiles) { const text = read(f); JS.set(f, { text, defs: defsOf(text) }); }

const inlineScriptsOf = (html) => {
  const out = [];
  for (const m of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
    if (/\bsrc\s*=/i.test(m[1] || '')) continue;
    if (/type\s*=\s*["']?(application\/json|text\/template)/i.test(m[1] || '')) continue;
    out.push({ code: m[2], line: lineOf(html, m.index), index: m.index });
  }
  return out;
};
const includedFilesOf = (html) => [...html.matchAll(/<script[^>]+src\s*=\s*["']([^"']+)["']/gi)].map(m => m[1].split('/').pop());
const htmlWithoutScripts = (html) => html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, m => '\n'.repeat((m.match(/\n/g) || []).length));

const findings = [];
const add = (kind, file, line, msg) => findings.push({ kind, file, line, msg });
const BUILTINS = new Set(['alert','confirm','prompt','print','open','close','focus','blur','submit','reset','return','if','void','eval','typeof','fetch','setTimeout','setInterval','clearTimeout','clearInterval','parseInt','parseFloat','encodeURIComponent','decodeURIComponent','isNaN','Number','String','Boolean','Object','Array','JSON','Math','Date','RegExp','Promise','Set','Map','URL','URLSearchParams','scrollTo','stopPropagation','preventDefault','reload','assign','replace']);

// ── per page ──────────────────────────────────────────────
for (const f of htmlFiles) {
  const html = read(f);
  const scripts = inlineScriptsOf(html);
  const inlineDefs = new Set();
  for (const s of scripts) for (const d of defsOf(s.code)) inlineDefs.add(d);
  const included = includedFilesOf(html);
  const availableDefs = new Set(inlineDefs);
  for (const inc of included) if (JS.has(inc)) for (const d of JS.get(inc).defs) availableDefs.add(d);

  // A. undefined functions invoked from inline handlers
  const handlerAttrs = /\son(?:click|change|input|submit|blur|focus|keyup|keydown|keypress|load|error|mouseover|mouseout|dblclick|paste|invalid)\s*=\s*["']([^"']*)["']/gi;
  const flagged = new Set();
  for (const m of html.matchAll(handlerAttrs)) {
    for (const c of m[1].matchAll(/(^|[^.A-Za-z0-9_$])([A-Za-z_$][A-Za-z0-9_$]*)\s*\(/g)) {
      const name = c[2];
      if (availableDefs.has(name) || BUILTINS.has(name) || flagged.has(name)) continue;
      flagged.add(name);
      add('UNDEFINED FUNCTION', f, lineOf(html, m.index), `inline handler calls ${name}() — not defined in this page nor in any included script (${included.filter(i => i.endsWith('.js')).join(', ') || 'no shared scripts'})`);
    }
  }

  // B. element ids -> only ids in real markup
  const markup = htmlWithoutScripts(html);
  const ids = {};
  for (const m of markup.matchAll(/\bid\s*=\s*["']([^"']+)["']/g)) {
    if (m[1].includes('${') || m[1].includes('{{')) continue;
    (ids[m[1]] = ids[m[1]] || []).push(lineOf(html, m.index));
  }
  for (const [id, lines] of Object.entries(ids))
    if (lines.length > 1) add('DUPLICATE ID', f, lines[1], `id="${id}" appears ${lines.length}× in the markup (lines ${lines.join(', ')}) — getElementById/querySelector only ever reach the first`);

  const jsProvidedIds = new Set();
  for (const inc of included) if (JS.has(inc)) for (const m of JS.get(inc).text.matchAll(/\bid\s*=\s*["']([^"']+)["']/g)) jsProvidedIds.add(m[1]);
  const inlineIdStrings = new Set();
  for (const s of scripts) for (const m of s.code.matchAll(/id\s*=\s*\\?["']([^"'\\]+)/g)) inlineIdStrings.add(m[1]);

  // ids generated at runtime by the page itself, e.g. id="stat-${id}"
  const dynPrefixes = [];
  for (const s of scripts) for (const mm of s.code.matchAll(/id\s*=\s*[`"']([^`"'$]*)\$\{/g)) dynPrefixes.push(mm[1]);
  for (const mm of markup.matchAll(/id\s*=\s*"([^"$]*)\$\{/g)) dynPrefixes.push(mm[1]);
  const seen = new Set();
  for (const m of html.matchAll(/getElementById\(\s*["'`]([^"'`]+)["'`]\s*(\+)?/g)) {
    const id = m[1], dyn = !!m[2];
    if (seen.has(id + dyn)) continue; seen.add(id + dyn);
    if (ids[id] || dyn) continue;
    if (dynPrefixes.some(p => p && id.startsWith(p))) continue;
    if (jsProvidedIds.has(id)) continue;
    if (inlineIdStrings.has(id)) continue;
    add('MISSING ELEMENT', f, lineOf(html, m.index), `getElementById("${id}") — no such id in this page's markup nor in any included script`);
  }
  for (const m of html.matchAll(/document\.getElementById\(\s*["'`]([^"'`]+)["'`]\s*\)\s*\.\s*[A-Za-z_$]/g)) {
    const id = m[1];
    if (ids[id] || id.includes('$') || jsProvidedIds.has(id) || inlineIdStrings.has(id)) continue;
    if (dynPrefixes.some(p => p && id.startsWith(p))) continue;   // id is generated at runtime by this page
    add('UNGUARDED NULL', f, lineOf(html, m.index), `getElementById("${id}").… accessed with no null check — throws TypeError`);
  }

  // C. asset / link targets
  const seenU = new Set();
  for (const m of html.matchAll(/(?:src|href)\s*=\s*["']([^"']+)["']/gi)) {
    const u = m[1].trim();
    if (!u || seenU.has(u)) continue; seenU.add(u);
    if (/^(https?:|mailto:|tel:|data:|javascript:|#|\/\/)/i.test(u)) continue;
    if (u.includes('${') || u.includes('{{')) continue;
    const clean = u.split('#')[0].split('?')[0];
    if (clean && !fs.existsSync(path.join(ROOT, clean))) add('MISSING FILE', f, lineOf(html, m.index), `points at "${clean}" which does not exist`);
  }

  // D. calls into shared files that are not included
  for (const [js, meta] of JS) {
    if (included.includes(js)) continue;
    for (const fn of meta.defs) {
      if (availableDefs.has(fn)) continue;
      if (!new RegExp(`\\b${fn}\\s*\\(`).test(html)) continue;
      add('MISSING SCRIPT', f, 1, `calls ${fn}() — defined in ${js}, which this page does not include`);
      break;
    }
  }

  // E. supabase client present?
  if (/\bSB\s*\.|\bsupabaseClient\s*\.|createClient/.test(html) && !included.includes('supabase-config.js'))
    add('MISSING SCRIPT', f, 1, 'uses SB / supabaseClient but does not include supabase-config.js');
  const inc2 = included;
  if (inc2.includes('supabase-config.js') && inc2.includes('supabase.min.js') && inc2.indexOf('supabase.min.js') > inc2.indexOf('supabase-config.js'))
    add('SCRIPT ORDER', f, 1, 'supabase-config.js is loaded before supabase.min.js (createClient undefined)');
  // F. CSP
  const csp = html.match(/http-equiv=["']Content-Security-Policy["'][^>]*content=(["'])([\s\S]*?)\1/i);
  if (/\bSB\s*\.|supabaseClient/.test(html)) {
    if (!csp) add('NO CSP', f, 1, 'no Content-Security-Policy meta tag on a page that talks to Supabase');
    else if (!/connect-src[^;]*supabase\.co|connect-src\s+\*/.test(csp[2])) add('CSP BLOCKS API', f, 1, 'CSP connect-src does not allow the Supabase host — queries will be blocked by the browser');
  }
}

// ── shared js syntax ──────────────────────────────────────
for (const f of jsFiles) {
  const tmp = path.join(os.tmpdir(), `_s_${f.replace(/[^A-Za-z0-9]/g, '_')}.js`);
  fs.writeFileSync(tmp, read(f));
  try { execFileSync('node', ['--check', tmp], { stdio: 'pipe' }); }
  catch (e) { add('JS SYNTAX', f, 1, (String(e.stderr || '').split('\n').find(l => /SyntaxError|Unexpected/.test(l)) || '').trim()); }
}
for (const f of htmlFiles) {
  const html = read(f);
  inlineScriptsOf(html).forEach((s, i) => {
    const base = `/tmp/_i_${f.replace(/[^A-Za-z0-9]/g, '_')}_${i}`;
    fs.writeFileSync(base + '.mjs', s.code); fs.writeFileSync(base + '.js', s.code);
    try { execFileSync('node', ['--check', base + '.mjs'], { stdio: 'pipe' }); return; } catch (e) {}
    try { execFileSync('node', ['--check', base + '.js'], { stdio: 'pipe' }); return; } catch (e) {}
    add('JS SYNTAX', f, s.line, `inline script #${i + 1} does not parse`);
  });
}

// ── supabase queries vs live schema ───────────────────────
const splitTop = (s) => { const out = []; let d = 0, cur = '', q = null;
  for (let i = 0; i < s.length; i++) { const ch = s[i];
    if (q) { if (ch === '\\') i++; else if (ch === q) q = null; cur += ch; continue; }
    if (ch === '"' || ch === "'" || ch === '`') { q = ch; cur += ch; continue; }
    if ('([{'.includes(ch)) d++; if (')]}'.includes(ch)) d--;
    if (ch === ',' && d === 0) { out.push(cur); cur = ''; } else cur += ch; }
  out.push(cur); return out; };
const topKeys = (lit) => splitTop(lit.slice(1, -1)).map(k => { const t = k.trim(); if (t.startsWith('...')) return null; const m = t.match(/^['"]?([A-Za-z0-9_]+)['"]?\s*:/); return m ? m[1].toLowerCase() : null; }).filter(Boolean);
const bal = (t, i, o = '{', c = '}') => { let d = 0; for (let k = i; k < t.length; k++) { if (t[k] === o) d++; else if (t[k] === c) { d--; if (d === 0) return k; } } return -1; };

for (const f of [...htmlFiles, ...jsFiles]) {
  const text = read(f);
  for (const m of text.matchAll(/\.from\(\s*["'`]([a-z0-9_]+)["'`]\s*\)/g)) {
    const table = m[1], line = lineOf(text, m.index);
    if (!SCHEMA.has(table) && !VIEWS.has(table)) { add('TABLE MISSING LIVE', f, line, `queries "${table}" — no such table in the database (PGRST205 → 404)`); continue; }
    const cols = SCHEMA.get(table);
    let i = m.index + m[0].length;
    for (let hop = 0; hop < 12 && i < text.length; hop++) {
      const chain = text.slice(i, i + 500).match(/^\s*\n?\s*\.([a-z_]+)\s*\(/);
      if (!chain) break;
      const method = chain[1], op = i + chain[0].length - 1, cp = bal(text, op, '(', ')');
      if (cp < 0) break;
      const args = text.slice(op + 1, cp);
      const check = (col, what) => { if (!cols || VIEWS.has(table)) return; col = col.toLowerCase();
        if (!cols.has(col)) add('COLUMN MISSING LIVE', f, lineOf(text, op), `${table}: ${what} uses "${col}" — column does not exist (42703) → request fails`); };
      if (method === 'select') {
        const str = args.trim().match(/^["'`]([\s\S]*?)["'`]/);
        if (str) {
          for (let p of splitTop(str[1])) {
            p = p.trim(); if (!p || p === '*' || p.includes('(')) continue;
            if (p.includes(':')) p = p.split(':').pop().trim();
            if (p.includes('.') || p.includes('->') || p.includes('!')) continue;
            check(p, 'select()');
          }
          for (const emb of str[1].matchAll(/([a-z0-9_]+)(?::[a-z0-9_]+)?!?(?:inner|left)?\s*\(/g)) {
            const t = emb[1];
            if (!SCHEMA.has(t)) { add('EMBED NEEDS FK', f, lineOf(text, op), `${table}: embeds "${t}" — not a table`); continue; }
            const rel = FKS.get(table);
            if (!rel || !rel.has(t)) add('EMBED NEEDS FK', f, lineOf(text, op), `${table}: embeds "${t}" but no foreign key exists between them (PostgREST PGRST200 → 400)`);
          }
        }
      }
      if (['eq','neq','gt','gte','lt','lte','like','ilike','is','in','contains','containedby','overlaps','filter','order','textSearch'].includes(method)) {
        const a = args.trim().match(/^["'`]([^"'`]+)["'`]/);
        if (a && !a[1].includes('.') && !a[1].includes('!')) check(a[1], method + '()');
      }
      if (['insert','upsert','update'].includes(method)) {
        let first = splitTop(args)[0].trim();
        if (first.startsWith('[')) first = first.slice(1).trim();
        if (first.startsWith('{')) { const e = bal(first, 0); if (e > 0) for (const k of topKeys(first.slice(0, e + 1))) check(k, method + '() payload'); }
      }
      i = cp + 1;
    }
  }
  // payload mutated then inserted — pick the CLOSEST insert target
  const targets = [...text.matchAll(/\.from\(\s*["'`]([a-z0-9_]+)["'`]\s*\)[\s\S]{0,120}?\.(insert|upsert|update)\(/g)].map(mm => ({ table: mm[1], line: lineOf(text, mm.index) }));
  if (targets.length) {
    const vars = new Set();
    for (const mm of text.matchAll(/\.(?:insert|upsert|update)\(\s*\[?\s*([A-Za-z_$][A-Za-z0-9_$]*)/g)) vars.add(mm[1]);
    for (const v of vars) {
      const esc = v.replace(/\$/g, '\\$');
      for (const mm of text.matchAll(new RegExp(`\\b${esc}(?:\\.([A-Za-z0-9_]+)|\\[\\s*["'\`]([A-Za-z0-9_]+)["'\`]\\s*\\])\\s*=(?!=)`, 'g'))) {
        const key = (mm[1] || mm[2]).toLowerCase(), line = lineOf(text, mm.index);
        let best = null, bestD = Infinity;
        for (const t of targets) { const d = Math.abs(t.line - line); if (d < bestD) { bestD = d; best = t; } }
        if (!best || bestD > 400 || VIEWS.has(best.table)) continue;
        const cols = SCHEMA.get(best.table);
        if (cols && !cols.has(key)) add('COLUMN MISSING LIVE', f, line, `${best.table}: payload field "${key}" (set on ${v}) — column does not exist (PGRST204) → insert rejected`);
      }
    }
  }
}

console.log('=== summary ===');
const byKind = {};
for (const x of findings) (byKind[x.kind] = byKind[x.kind] || []).push(x);
for (const k of Object.keys(byKind).sort()) console.log(`${String(byKind[k].length).padStart(4)}  ${k}`);
console.log(`total: ${findings.length}`);
for (const k of Object.keys(byKind).sort()) {
  console.log(`\n=== ${k} ===`);
  const bf = {};
  for (const x of byKind[k]) (bf[x.file] = bf[x.file] || []).push(x);
  for (const [file, list] of Object.entries(bf)) { console.log(`  ${file}`); for (const x of list) console.log(`    L${x.line}: ${x.msg}`); }
}
fs.writeFileSync(path.join(os.tmpdir(), 'audit-pages-findings.json'), JSON.stringify(findings, null, 1));

process.exitCode = findings.length ? 1 : 0;
