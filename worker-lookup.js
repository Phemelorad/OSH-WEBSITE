// ============================================================
// WORKER LOOKUP UTILITY
// Shared by form.html, accident-report.html, injury-disease-report.html
//
// Usage: call attachWorkerLookup(config) after DOM is ready.
// The config tells this library which field IDs to fill.
// ============================================================

(function () {

  // ── Inject shared styles once ────────────────────────────
  if (!document.getElementById('wl-styles')) {
    const s = document.createElement('style');
    s.id = 'wl-styles';
    s.textContent = `
      .wl-wrapper {
        position: relative;
      }
      .wl-input-row {
        display: flex; gap: 8px; align-items: stretch;
      }
      .wl-input-row input {
        flex: 1;
      }
      .wl-lookup-btn {
        padding: 10px 18px; background: #333; color: white;
        border: none; border-radius: 8px; cursor: pointer;
        font-size: 13px; font-weight: 600; white-space: nowrap;
        transition: background 0.2s; font-family: inherit;
        flex-shrink: 0;
      }
      .wl-lookup-btn:hover { background: #111; }
      .wl-lookup-btn:disabled { opacity: 0.5; cursor: not-allowed; }
      .wl-status {
        margin-top: 6px; font-size: 12px; min-height: 18px;
        display: flex; align-items: center; gap: 6px;
      }
      .wl-status.found   { color: #155724; }
      .wl-status.notfound { color: #856404; }
      .wl-status.error   { color: #721c24; }
      .wl-status.loading { color: #888; }
      .wl-profile-banner {
        margin-top: 10px; padding: 12px 16px;
        background: #d4edda; border: 1px solid #c3e6cb;
        border-radius: 8px; font-size: 13px; color: #155724;
        display: none;
      }
      .wl-profile-banner.show { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
      .wl-profile-banner .wl-name { font-weight: 700; font-size: 14px; }
      .wl-profile-banner .wl-chips { display: flex; gap: 6px; flex-wrap: wrap; }
      .wl-chip {
        background: rgba(0,0,0,0.08); padding: 2px 10px;
        border-radius: 10px; font-size: 11px; font-weight: 600;
      }
      .wl-save-note {
        margin-top: 6px; font-size: 11px; color: #888; font-style: italic;
      }
      .wl-type-toggle {
        display: flex; gap: 0; margin-bottom: 8px;
        border: 2px solid #e0e0e0; border-radius: 8px; overflow: hidden;
      }
      .wl-type-btn {
        flex: 1; padding: 8px; border: none; background: white;
        font-size: 12px; font-weight: 600; color: #666; cursor: pointer;
        font-family: inherit; transition: all 0.2s;
      }
      .wl-type-btn.active { background: #333; color: white; }
    `;
    document.head.appendChild(s);
  }

  // ── Supabase client (reuse existing) ─────────────────────
  function getSB() {
    return window.supabaseClient || window.supabase?.createClient(
      'https://qblogmmknnacaaircrlt.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibG9nbW1rbm5hY2FhaXJjcmx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzODM5MzcsImV4cCI6MjA5NTk1OTkzN30.qQB1DhoAn-W1wqSMyJpwQ3cqX0JWhw54kb_XOb5fU5s'
    );
  }

  // ── Main function ─────────────────────────────────────────
  // config: {
  //   containerId: 'wl-container',   ← the div where we inject the lookup widget
  //   fields: {                       ← map registry column → target field id
  //     full_name:   'nameOfClaimant',
  //     sex:         'gender',
  //     nationality: 'nationality',
  //     occupation:  'occupation',
  //     address:     'location',
  //     id_number:   'claimantIdInput',   ← the ID input on the form itself
  //   },
  //   onFound: (worker) => {},   ← optional callback after autofill
  //   saveNewWorker: true        ← auto-save unknown workers to registry
  // }
  window.attachWorkerLookup = function (config) {
    const container = document.getElementById(config.containerId);
    if (!container) { console.warn('worker-lookup: container not found:', config.containerId); return; }

    // Inject widget HTML
    container.innerHTML = `
      <div class="wl-type-toggle">
        <button type="button" class="wl-type-btn active" id="wl-btn-omang"
                onclick="wlSetType('Omang')">🪪 Omang (National ID)</button>
        <button type="button" class="wl-type-btn" id="wl-btn-passport"
                onclick="wlSetType('Passport')">📘 Passport</button>
      </div>
      <div class="wl-input-row">
        <input type="text" id="wl-id-input" placeholder="Enter Omang number…"
               oninput="wlOnInput()" onkeydown="if(event.key==='Enter'){event.preventDefault();wlLookup()}"
               autocomplete="off">
        <button type="button" class="wl-lookup-btn" id="wl-btn" onclick="wlLookup()">
          🔍 Look Up
        </button>
      </div>
      <div class="wl-status" id="wl-status"></div>
      <div class="wl-profile-banner" id="wl-banner">
        <span>✅</span>
        <div>
          <div class="wl-name" id="wl-banner-name"></div>
          <div class="wl-chips" id="wl-banner-chips"></div>
        </div>
      </div>
      <div class="wl-save-note" id="wl-save-note" style="display:none"></div>`;

    let currentIdType = 'Omang';
    let lastFoundWorker = null;

    window.wlSetType = function (type) {
      currentIdType = type;
      document.getElementById('wl-btn-omang').classList.toggle('active', type === 'Omang');
      document.getElementById('wl-btn-passport').classList.toggle('active', type === 'Passport');
      document.getElementById('wl-id-input').placeholder =
        type === 'Omang' ? 'Enter Omang number…' : 'Enter Passport number…';
      wlClear();
    };

    window.wlOnInput = function () {
      const val = document.getElementById('wl-id-input').value.trim();
      if (!val) wlClear();
    };

    window.wlLookup = async function () {
      const idVal = document.getElementById('wl-id-input').value.trim().toUpperCase();
      if (!idVal) {
        setStatus('Enter an ID number first.', 'error'); return;
      }

      const btn = document.getElementById('wl-btn');
      btn.disabled = true;
      setStatus('Looking up…', 'loading');
      hideBanner();

      const { data, error } = await getSB()
        .from('workers_registry')
        .select('*')
        .eq('id_number', idVal)
        .maybeSingle();

      btn.disabled = false;

      if (error) { setStatus('Lookup error: ' + error.message, 'error'); return; }

      if (data) {
        lastFoundWorker = data;
        autofill(data, config.fields);
        showBanner(data);
        setStatus('✅ Worker found — fields auto-filled.', 'found');
        document.getElementById('wl-save-note').style.display = 'none';
        if (config.onFound) config.onFound(data);
      } else {
        lastFoundWorker = null;
        setStatus(`⚠ No record found for ${idVal}. Fill in the details and they will be saved automatically.`, 'notfound');
        // Pre-fill the id_number field if mapped
        const idFieldId = config.fields.id_number;
        if (idFieldId) {
          const el = document.getElementById(idFieldId);
          if (el) el.value = idVal;
        }
        if (config.saveNewWorker !== false) {
          document.getElementById('wl-save-note').style.display = 'block';
          document.getElementById('wl-save-note').textContent =
            'New worker — their details will be saved to the registry when you submit this form.';
          // Store pending ID for the form to pick up
          window._pendingWorkerId    = idVal;
          window._pendingWorkerIdType = currentIdType;
        }
      }
    };

    // ── Autofill helper ──────────────────────────────────────
    function autofill(worker, fields) {
      // fields is a map like { full_name: 'nameOfClaimant', sex: 'gender', ... }
      Object.entries(fields).forEach(([registryCol, formFieldId]) => {
        if (registryCol === 'id_number') {
          // Fill the form's ID field with the looked-up value
          const el = document.getElementById(formFieldId);
          if (el && worker.id_number) el.value = worker.id_number;
          return;
        }
        if (registryCol === 'worker_registry_id') {
          // Hidden field to store the registry FK
          const el = document.getElementById(formFieldId);
          if (el) el.value = worker.id;
          return;
        }
        const val = worker[registryCol];
        if (val == null) return;
        const el = document.getElementById(formFieldId);
        if (!el) return;
        if (el.tagName === 'SELECT') {
          // Try to match option value or text
          const opts = [...el.options];
          const match = opts.find(o =>
            o.value.toLowerCase() === String(val).toLowerCase() ||
            o.text.toLowerCase()  === String(val).toLowerCase()
          );
          if (match) el.value = match.value;
        } else {
          el.value = val;
        }
        // Flash green to indicate autofill
        el.style.transition = 'background 0.3s';
        el.style.background = '#d4edda';
        setTimeout(() => { el.style.background = ''; }, 1800);
      });
      // Store registry ID on form for submission
      window._resolvedWorkerId = worker.id;
    }

    function showBanner(worker) {
      const banner = document.getElementById('wl-banner');
      document.getElementById('wl-banner-name').textContent = worker.full_name;
      const chips = [
        worker.sex, worker.nationality, worker.occupation, worker.employer_name
      ].filter(Boolean).map(c => `<span class="wl-chip">${c}</span>`).join('');
      document.getElementById('wl-banner-chips').innerHTML = chips;
      banner.classList.add('show');
    }

    function hideBanner() {
      document.getElementById('wl-banner').classList.remove('show');
    }

    function setStatus(msg, cls) {
      const el = document.getElementById('wl-status');
      el.textContent = msg;
      el.className = 'wl-status ' + cls;
    }

    function wlClear() {
      setStatus('', '');
      hideBanner();
      document.getElementById('wl-save-note').style.display = 'none';
      window._pendingWorkerId     = null;
      window._pendingWorkerIdType = null;
      window._resolvedWorkerId    = null;
    }
  };

  // ── Save new worker to registry (called on form submit) ───
  // Pass the collected form data and the field mapping.
  window.saveWorkerIfNew = async function (formData, fieldMap) {
    if (!window._pendingWorkerId) return null;   // already exists or not attempted

    const worker = {
      id_number:  window._pendingWorkerId,
      id_type:    window._pendingWorkerIdType || 'Omang',
      full_name:  formData[fieldMap.full_name]  || '',
      sex:        formData[fieldMap.sex]         || null,
      nationality:formData[fieldMap.nationality] || null,
      occupation: formData[fieldMap.occupation]  || null,
      address:    formData[fieldMap.address]     || null,
    };

    if (!worker.full_name) return null;   // can't save without a name

    const sb = getSB();
    const { data, error } = await sb
      .from('workers_registry')
      .upsert([worker], { onConflict: 'id_number' })
      .select('id')
      .maybeSingle();

    if (error) { console.warn('Could not save worker to registry:', error.message); return null; }

    // Clear pending flags
    window._pendingWorkerId     = null;
    window._pendingWorkerIdType = null;
    window._resolvedWorkerId    = data?.id || null;
    return data?.id || null;
  };

  console.log('worker-lookup.js loaded');
})();
