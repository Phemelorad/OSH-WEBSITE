// Reference-error harness for this static site.
//
//  * Runs each page's inline <script> blocks in a Node VM.
//  * Unknown global identifiers/properties resolve to `undefined` (browser
//    semantics), so a bare call like `window.accidentLookupInit(...)` throws
//    the same TypeError the browser reports.
//  * Invokes the page's load/DOMContentLoaded callback, drains microtasks, and
//    reports the first exception (the thing that silently aborts the rest of
//    the handler).
//  * Then checks every static onclick/onchange/... handler target is actually a
//    global function once the page has finished initialising.
//
// Known/stubbed sources: browser builtins, names exported by the project's
// standalone .js files, and a small seed of window globals those files install.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = process.cwd();
const SKIP_DIRS = new Set(['node_modules', '.git', '_archive', 'scripts']);

function walk(dir, filter, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (SKIP_DIRS.has(e.name)) continue;
      walk(path.join(dir, e.name), filter, out);
    } else if (filter(e.name)) out.push(path.join(dir, e.name));
  }
  return out;
}

const STUB_LABEL = Symbol('stub');
function makeStub() {
  const fn = function () { return stub; };
  const stub = new Proxy(fn, {
    get(t, p) {
      if (p === 'then') return undefined;
      if (p === Symbol.toPrimitive) return () => 0;
      if (p === Symbol.iterator) {
        return function () {
          let n = 0;
          const it = { next: () => (n++ < 8 ? { value: stub, done: false } : { done: true }) };
          it[Symbol.iterator] = function () { return it; };
          return it;
        };
      }
      if (p === 'toString' || p === 'valueOf') return () => '';
      if (p === 'length') return 0;
      if (p === 'name') return String(p);
      return stub;
    },
    apply() { return stub; },
    construct() { return stub; },
    has() { return true; },
    set() { return true; },
    deleteProperty() { return true; },
    getPrototypeOf() { return null; },
    getOwnPropertyDescriptor() { return { configurable: true, enumerable: true, value: stub }; },
  });
  return stub;
}

const BUILTINS = new Set(
  ('window document console Math JSON Object Array String Number Boolean Date RegExp Error ' +
   'Promise Map Set WeakMap WeakSet Symbol parseInt parseFloat isNaN isFinite ' +
   'encodeURIComponent decodeURIComponent encodeURI decodeURI alert confirm prompt fetch URL ' +
   'URLSearchParams Blob File FileReader FormData Headers Request Response AbortController ' +
   'TextEncoder TextDecoder structuredClone btoa atob localStorage sessionStorage navigator ' +
   'location history setTimeout setInterval clearTimeout clearInterval requestAnimationFrame ' +
   'cancelAnimationFrame HTMLElement Event CustomEvent MutationObserver IntersectionObserver ' +
   'ResizeObserver Image Audio Option XMLHttpRequest WebSocket Intl Reflect Proxy Function eval ' +
   'crypto performance getComputedStyle matchMedia scrollTo scrollBy open close postMessage ' +
   'addEventListener removeEventListener dispatchEvent globalThis self top parent screen ' +
   'innerWidth innerHeight devicePixelRatio name frames').split(/\s+/)
);

const KEYWORDS = new Set(('if for while switch return typeof new function await catch else do try void in of instanceof this delete throw case break continue class const let var').split(' '));

// Global names the project's standalone .js files define.
function extractJsGlobals() {
  const names = new Set();
  const files = walk(ROOT, (n) => /\.js$/i.test(n) && !/supabase\.min\.js$/i.test(n));
  for (const f of files) {
    const src = fs.readFileSync(f, 'utf8');
    const res = [
      /(?:^|[\s;}])(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(/gm,
      /(?:^|[\s;}])class\s+([A-Za-z_$][\w$]*)/gm,
      /(?:^|[\s;}])(?:var|let|const)\s+([A-Za-z_$][\w$]*)\b/gm,
      /(?:^|[\s;}])window\.([A-Za-z_$][\w$]*)\s*=/gm,
      /(?:^|[\s;}])globalThis\.([A-Za-z_$][\w$]*)\s*=/gm,
      /(?:^|[\s;}])global\.([A-Za-z_$][\w$]*)\s*=/gm,
      /(?:^|[\s;}])self\.([A-Za-z_$][\w$]*)\s*=/gm,
    ];
    for (const re of res) { let m; while ((m = re.exec(src))) names.add(m[1]); }
  }
  return names;
}
const JS_GLOBALS = extractJsGlobals();

// window.* values installed by the shared scripts (supabase-config.js, etc.).
const SEED = new Set([...JS_GLOBALS, 'supabaseClient', 'supabase', 'OSH_ACTIVE_PAGE', 'SB']);

function extractInlineScripts(html) {
  const blocks = [];
  const re = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = re.exec(html))) {
    if (/\bsrc\s*=/i.test(m[1])) continue;
    blocks.push({ body: m[2], start: m.index, end: re.lastIndex });
  }
  return blocks;
}

function handlerAttrs(html, scriptRanges) {
  const hits = [];
  const re = /\b(on(?:click|input|change|submit|blur|focus|mouseover|mouseout|keyup|keydown))\s*=\s*"([^"]*)"/gi;
  let m;
  while ((m = re.exec(html))) {
    if (scriptRanges.some((r) => m.index >= r.start && m.index <= r.end)) continue;
    const line = html.slice(0, m.index).split('\n').length;
    const cre = /(?:^|[^.\w$])([A-Za-z_$][\w$]*)\s*\(/g;
    let cm;
    while ((cm = cre.exec(m[2]))) hits.push({ line, attr: m[1], value: m[2].trim(), name: cm[1] });
  }
  return hits;
}

(async () => {
  const files = walk(ROOT, (n) => /\.(html|htm)$/i.test(n));
  const report = [];
  let problems = 0;
  const probeFile = process.argv[2];

  for (const f of files) {
    const html = fs.readFileSync(f, 'utf8');
    const rel = path.relative(ROOT, f);
    const scripts = extractInlineScripts(html);
    if (!scripts.length) continue;

    const handlers = handlerAttrs(html, scripts.map((s) => ({ start: s.start, end: s.end })));
    const store = Object.create(null);
    const loadCallbacks = [];
    let loadErr = null;
    const stubCache = new Map();
    const stubFor = (p) => {
      if (!stubCache.has(p)) stubCache.set(p, makeStub());
      return stubCache.get(p);
    };

    const sandbox = new Proxy(store, {
      has(t, p) { return p in t || BUILTINS.has(p) || SEED.has(p); },
      get(t, p) {
        if (typeof p === 'symbol') return t[p];
        if (p === 'window' || p === 'globalThis' || p === 'self' || p === 'top' || p === 'parent' || p === 'frames') return sandbox;
        if (p in t) return t[p];
        if (p === 'addEventListener') {
          return (type, cb) => { if (type === 'load' || type === 'DOMContentLoaded') loadCallbacks.push(cb); };
        }
        if (p === 'setTimeout') return (fn) => { if (typeof fn === 'function') setImmediate(fn); return 1; };
        if (p === 'setInterval') return () => 2;
        if (p === 'clearTimeout' || p === 'clearInterval') return () => {};
        if (p === 'requestAnimationFrame') return (fn) => { if (typeof fn === 'function') setImmediate(() => fn(0)); return 1; };
        if (p === 'getOwnPropertyDescriptor') return undefined;
        if (BUILTINS.has(p) || SEED.has(p)) return stubFor(p);
        return undefined;               // <- browser semantics for unknown globals
      },
      set(t, p, v) { t[p] = v; return true; },
      deleteProperty(t, p) { delete t[p]; return true; },
      getOwnPropertyDescriptor(t, p) {
        if (p in t) return { configurable: true, enumerable: true, writable: true, value: t[p] };
        return undefined;
      },
    });

    const context = vm.createContext(sandbox, { name: rel });
    for (const s of scripts) {
      try {
        vm.runInContext(s.body, context, { filename: rel, timeout: 5000 });
      } catch (e) {
        report.push(`THROW   ${rel}: inline script aborted -> ${e.name}: ${e.message}`);
        problems++;
        break;
      }
    }

    for (const cb of loadCallbacks) {
      try {
        await cb();
        for (let i = 0; i < 40; i++) await new Promise((r) => setImmediate(r));
      } catch (e) {
        loadErr = e;
        report.push(`LOADERR ${rel}: load callback threw -> ${e.name}: ${e.message}`);
        problems++;
        break;                          // first abort is the one that matters
      }
    }

    if (!loadErr) {
      const missing = new Map();
      for (const h of handlers) {
        if (BUILTINS.has(h.name) || KEYWORDS.has(h.name) || SEED.has(h.name)) continue;
        if (typeof store[h.name] === 'function' || store[h.name] !== undefined) continue;
        if (!missing.has(h.name)) missing.set(h.name, h.line);
      }
      for (const [name, line] of missing) {
        report.push(`HANDLER ${rel}:${line} -> '${name}' is not a global function when the page onclick fires`);
        problems++;
      }
    }

    if (probeFile && rel === probeFile) {
      for (const n of process.argv.slice(3)) report.push(`PROBE   ${rel}: ${n} -> ${typeof store[n]}`);
    }
  }

  console.log(report.join('\n'));
  console.log(`\n--- ${problems} problem(s) across ${files.length} html files ---`);
})();
