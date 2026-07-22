// ============================================================
// BL FORM LOOKUP — shared by all BL 43-xx forms
// Searches workers_registry + companies by ID, passport or name.
// Pulls both injured/worker data AND company/employer data.
//
// Usage (call after DOM ready):
//   BLLookup.init({
//     workerFields: {                // optional — omit fields you don't have
//       id_number:    'worker_id_number',
//       full_name:    'worker_name',
//       address:      'worker_address',
//       occupation:   'occupation',
//       sex:          'worker_sex',
//       date_of_birth:'worker_dob',
//       nationality:  'worker_nationality',
//       age_years:    'worker_age',
//     },
//     employerFields: {              // optional
//       employer_name:      'employer_name',
//       employer_address:   'employer_address',
//       employer_telephone: 'employer_telephone',
//     },
//     onWorkerFound:   function(worker) {},  // optional callback
//     onEmployerFound: function(company) {}, // optional callback
//   });
// ============================================================

(function(global) {
  'use strict';

  // ── CSS ───────────────────────────────────────────────────
  function injectStyles() {
    if (document.getElementById('bl-lookup-styles')) return;
    const s = document.createElement('style');
    s.id = 'bl-lookup-styles';
    s.textContent = `
      .bl-lookup-panel {
        background: #f0f4f8;
        border: 1px solid #d0dbe8;
        border-radius: 10px;
        padding: 18px 20px;
        margin-bottom: 22px;
      }
      .bl-lookup-panel h4 {
        font-size: 13px;
        font-weight: 700;
        color: #2c3e50;
        margin: 0 0 12px;
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .bl-lookup-tabs {
        display: flex;
        gap: 0;
        margin-bottom: 12px;
        border-radius: 6px;
        overflow: hidden;
        border: 1px solid #c8d6e5;
      }
      .bl-lookup-tab {
        flex: 1;
        padding: 8px;
        font-size: 12px;
        font-weight: 600;
        border: none;
        cursor: pointer;
        background: white;
        color: #555;
        transition: all 0.15s;
        font-family: inherit;
      }
      .bl-lookup-tab.active {
        background: #2c3e50;
        color: white;
      }
      .bl-lookup-row {
        display: flex;
        gap: 8px;
        align-items: center;
      }
      .bl-lookup-row input {
        flex: 1;
        padding: 9px 12px;
        border: 1px solid #c8d6e5;
        border-radius: 6px;
        font-size: 13px;
        font-family: inherit;
        transition: border-color 0.2s;
      }
      .bl-lookup-row input:focus {
        outline: none;
        border-color: #2c3e50;
        box-shadow: 0 0 0 3px rgba(44,62,80,0.1);
      }
      .bl-lookup-btn {
        padding: 9px 18px;
        background: #2c3e50;
        color: white;
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        cursor: pointer;
        white-space: nowrap;
        font-family: inherit;
        transition: background 0.15s;
      }
      .bl-lookup-btn:hover { background: #34495e; }
      .bl-lookup-btn:disabled { opacity: 0.5; cursor: not-allowed; }
      .bl-lookup-status {
        font-size: 12px;
        margin-top: 8px;
        min-height: 18px;
        display: flex;
        align-items: center;
        gap: 6px;
      }
      .bl-lookup-status.found   { color: #27ae60; }
      .bl-lookup-status.notfound { color: #e67e22; }
      .bl-lookup-status.error   { color: #e74c3c; }
      .bl-lookup-status.loading { color: #7f8c8d; }
      .bl-result-card {
        display: none;
        margin-top: 12px;
        background: white;
        border: 1px solid #d4edda;
        border-radius: 8px;
        padding: 12px 14px;
      }
      .bl-result-card.show { display: block; }
      .bl-result-card .bl-rc-title {
        font-size: 12px;
        font-weight: 700;
        color: #155724;
        margin-bottom: 8px;
        display: flex;
        align-items: center;
        gap: 6px;
      }
      .bl-result-card .bl-rc-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 4px 16px;
        font-size: 12px;
      }
      .bl-result-card .bl-rc-item {
        display: flex;
        flex-direction: column;
      }
      .bl-result-card .bl-rc-label { color: #888; font-size: 11px; }
      .bl-result-card .bl-rc-value { color: #222; font-weight: 600; }
      /* Suggestions dropdown */
      .bl-suggestions {
        position: absolute;
        top: 100%;
        left: 0;
        right: 0;
        background: white;
        border: 1px solid #c8d6e5;
        border-top: none;
        border-radius: 0 0 6px 6px;
        box-shadow: 0 6px 16px rgba(0,0,0,0.1);
        z-index: 1000;
        max-height: 220px;
        overflow-y: auto;
        display: none;
      }
      .bl-suggestion-item {
        padding: 9px 14px;
        cursor: pointer;
        font-size: 13px;
        border-bottom: 1px solid #f5f5f5;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      .bl-suggestion-item:hover { background: #f0f4f8; }
      .bl-suggestion-item .bs-name { font-weight: 600; color: #2c3e50; }
      .bl-suggestion-item .bs-meta { font-size: 11px; color: #888; }
      .bl-input-wrap { position: relative; flex: 1; }
    `;
    document.head.appendChild(s);
  }

  // ── Supabase client ───────────────────────────────────────
  function getSB() {
    return window.supabaseClient || (window.supabase && window.supabase.createClient ?
      window.supabase.createClient(
        'https://qblogmmknnacaaircrlt.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibG9nbW1rbm5hY2FhaXJjcmx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzODM5MzcsImV4cCI6MjA5NTk1OTkzN30.qQB1DhoAn-W1wqSMyJpwQ3cqX0JWhw54kb_XOb5fU5s'
      ) : null);
  }

  // ── Autofill helper ───────────────────────────────────────
  function fillFields(fieldMap, data) {
    if (!fieldMap || !data) return;
    Object.entries(fieldMap).forEach(([dataKey, fieldId]) => {
      if (!fieldId) return;
      const val = data[dataKey];
      if (val == null || val === '') return;
      const el = document.getElementById(fieldId) ||
                 document.querySelector(`[name="${fieldId}"]`);
      if (!el) return;
      if (el.tagName === 'SELECT') {
        const opt = [...el.options].find(o =>
          o.value.toLowerCase() === String(val).toLowerCase() ||
          o.text.toLowerCase()  === String(val).toLowerCase()
        );
        if (opt) el.value = opt.value;
      } else {
        el.value = val;
      }
      // Flash green
      el.style.transition = 'background 0.3s';
      el.style.background = '#d4edda';
      setTimeout(() => { el.style.background = ''; }, 2000);
    });
  }

  // ── Build result card HTML ────────────────────────────────
  function buildResultCard(data, type) {
    const isWorker = type === 'worker';
    const icon = isWorker ? '👤' : '🏢';
    const title = isWorker ? 'Worker found in registry' : 'Company found in register';
    const items = isWorker ? [
      ['Name', data.full_name],
      ['ID / Passport', data.id_number],
      ['Occupation', data.occupation || data.usual_occupation],
      ['Employer', data.employer_name],
      ['Sex', data.sex],
      ['Nationality', data.nationality],
      ['Address', data.address],
      ['Telephone', data.employer_telephone],
    ] : [
      ['Company', data.company_name],
      ['Industry', data.industry],
      ['Location', data.location],
      ['Physical Address', data.physical_address],
      ['Telephone', data.telephone],
      ['Owner', data.owner_name],
    ];

    const rows = items
      .filter(([, v]) => v)
      .map(([l, v]) => `<div class="bl-rc-item">
        <span class="bl-rc-label">${l}</span>
        <span class="bl-rc-value">${v}</span>
      </div>`).join('');

    return `<div class="bl-rc-title">${icon} ${title}</div>
            <div class="bl-rc-grid">${rows}</div>`;
  }

  // ── Main init ─────────────────────────────────────────────
  function init(config) {
    injectStyles();
    config = config || {};

    const wFields = config.workerFields   || null;
    const eFields = config.employerFields || null;

    // Find or create container
    let container = document.getElementById('bl-lookup-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'bl-lookup-container';
      // Insert before first section-title or at top of form
      const form = document.querySelector('form');
      const firstSection = form && form.querySelector('h3');
      if (firstSection) {
        firstSection.parentNode.insertBefore(container, firstSection);
      } else if (form) {
        form.prepend(container);
      } else {
        document.body.prepend(container);
      }
    }

    container.innerHTML = `
      <div class="bl-lookup-panel">
        <h4>🔍 Look Up Worker / Employer</h4>
        <div class="bl-lookup-tabs">
          <button type="button" class="bl-lookup-tab active" data-mode="id">🪪 By Omang / Passport ID</button>
          <button type="button" class="bl-lookup-tab" data-mode="name">👤 By Name</button>
          <button type="button" class="bl-lookup-tab" data-mode="company">🏢 By Company</button>
        </div>
        <div class="bl-lookup-row">
          <div class="bl-input-wrap">
            <input type="text" id="bl-search-input"
              placeholder="Enter Omang / Passport number…"
              autocomplete="off">
            <div class="bl-suggestions" id="bl-suggestions"></div>
          </div>
          <button type="button" class="bl-lookup-btn" id="bl-search-btn">Search</button>
        </div>
        <div class="bl-lookup-status" id="bl-status"></div>
        <div class="bl-result-card" id="bl-worker-card"></div>
        <div class="bl-result-card" id="bl-company-card"></div>
      </div>`;

    const input       = document.getElementById('bl-search-input');
    const searchBtn   = document.getElementById('bl-search-btn');
    const statusEl    = document.getElementById('bl-status');
    const workerCard  = document.getElementById('bl-worker-card');
    const companyCard = document.getElementById('bl-company-card');
    const suggestBox  = document.getElementById('bl-suggestions');
    const tabs        = container.querySelectorAll('.bl-lookup-tab');

    let mode = 'id';   // 'id' | 'name' | 'company'
    let suggestTimer  = null;

    // ── Tab switch
    tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        mode = tab.dataset.mode;
        input.value = '';
        suggestBox.style.display = 'none';
        clearStatus();
        workerCard.classList.remove('show');
        companyCard.classList.remove('show');
        const placeholders = {
          id:      'Enter Omang or Passport number…',
          name:    'Enter worker name (min 2 chars)…',
          company: 'Enter company or employer name…',
        };
        input.placeholder = placeholders[mode];
      });
    });

    // ── Suggestions on typing
    input.addEventListener('input', () => {
      clearTimeout(suggestTimer);
      const q = input.value.trim();
      if (q.length < 2) { suggestBox.style.display = 'none'; return; }
      suggestTimer = setTimeout(() => fetchSuggestions(q), 280);
    });

    input.addEventListener('keydown', e => {
      if (e.key === 'Enter') { e.preventDefault(); doSearch(); }
    });

    searchBtn.addEventListener('click', doSearch);

    // Close on outside click
    document.addEventListener('click', e => {
      if (!e.target.closest('#bl-lookup-container')) {
        suggestBox.style.display = 'none';
      }
    });

    // ── Fetch suggestions
    async function fetchSuggestions(q) {
      const sb = getSB();
      if (!sb) return;

      let results = [];
      if (mode === 'id') {
        const { data } = await sb.from('workers_registry')
          .select('id, id_number, full_name, occupation, employer_name')
          .ilike('id_number', `%${q}%`).limit(8);
        results = (data || []).map(r => ({
          label: r.full_name,
          meta:  r.id_number,
          sub:   r.employer_name || r.occupation || '',
          value: r.id_number,
          raw:   r, type: 'worker'
        }));
      } else if (mode === 'name') {
        const { data } = await sb.from('workers_registry')
          .select('id, id_number, full_name, occupation, employer_name')
          .ilike('full_name', `%${q}%`).limit(8);
        results = (data || []).map(r => ({
          label: r.full_name,
          meta:  r.id_number,
          sub:   r.employer_name || r.occupation || '',
          value: r.full_name,
          raw:   r, type: 'worker'
        }));
      } else {
        const { data } = await sb.from('companies')
          .select('id, company_name, industry, location, telephone')
          .ilike('company_name', `%${q}%`).limit(8);
        results = (data || []).map(r => ({
          label: r.company_name,
          meta:  r.industry || '',
          sub:   r.location || '',
          value: r.company_name,
          raw:   r, type: 'company'
        }));
      }

      if (!results.length) { suggestBox.style.display = 'none'; return; }

      suggestBox.innerHTML = results.map((r, i) => `
        <div class="bl-suggestion-item" data-idx="${i}">
          <div>
            <span class="bs-name">${r.label}</span>
            ${r.meta ? `<span class="bs-meta" style="margin-left:8px">${r.meta}</span>` : ''}
          </div>
          <span class="bs-meta">${r.sub}</span>
        </div>`).join('');

      suggestBox.querySelectorAll('.bl-suggestion-item').forEach((el, i) => {
        el.addEventListener('click', () => {
          suggestBox.style.display = 'none';
          input.value = results[i].value;
          applyResult(results[i].raw, results[i].type);
        });
      });

      suggestBox.style.display = 'block';
    }

    // ── Execute search
    async function doSearch() {
      const q = input.value.trim();
      if (!q) { setStatus('Enter a search term.', 'error'); return; }
      const sb = getSB();
      if (!sb) { setStatus('Database not available.', 'error'); return; }

      setStatus('Searching…', 'loading');
      suggestBox.style.display = 'none';
      searchBtn.disabled = true;
      workerCard.classList.remove('show');
      companyCard.classList.remove('show');

      try {
        if (mode === 'company') {
          const { data, error } = await sb.from('companies')
            .select('*').ilike('company_name', `%${q}%`).limit(1).maybeSingle();
          if (error) throw error;
          if (data) {
            applyResult(data, 'company');
          } else {
            setStatus('⚠ No company found. Check the spelling or register the company first.', 'notfound');
          }
        } else {
          // Try exact Omang/Passport match first, then name
          let data = null;
          if (mode === 'id') {
            const res = await sb.from('workers_registry')
              .select('*').eq('id_number', q.toUpperCase()).maybeSingle();
            if (!res.error) data = res.data;
            // Fallback: partial match
            if (!data) {
              const res2 = await sb.from('workers_registry')
                .select('*').ilike('id_number', `%${q}%`).limit(1).maybeSingle();
              if (!res2.error) data = res2.data;
            }
          } else {
            const res = await sb.from('workers_registry')
              .select('*').ilike('full_name', `%${q}%`).limit(1).maybeSingle();
            if (!res.error) data = res.data;
          }

          if (data) {
            applyResult(data, 'worker');
            // Also try to fetch matching company for employer fields
            if (data.employer_name && eFields) {
              const compRes = await sb.from('companies')
                .select('*').ilike('company_name', data.employer_name).maybeSingle();
              if (!compRes.error && compRes.data) {
                fillFields(eFields, {
                  employer_name:      compRes.data.company_name,
                  employer_address:   compRes.data.physical_address || compRes.data.location,
                  employer_telephone: compRes.data.telephone,
                });
              }
            }
          } else {
            setStatus('⚠ No worker found. You can fill the details manually.', 'notfound');
          }
        }
      } catch (err) {
        setStatus('Error: ' + err.message, 'error');
      } finally {
        searchBtn.disabled = false;
      }
    }

    // ── Apply found record
    function applyResult(data, type) {
      if (type === 'worker') {
        fillFields(wFields, {
          id_number:    data.id_number,
          full_name:    data.full_name,
          address:      data.address,
          occupation:   data.occupation || data.usual_occupation,
          sex:          data.sex,
          date_of_birth:data.date_of_birth,
          nationality:  data.nationality,
          age_years:    data.age_years,
          employer_name:data.employer_name,
          employer_telephone: data.employer_telephone,
          employer_address:   data.employer_address,
        });
        // Also fill employer fields if mapped
        fillFields(eFields, {
          employer_name:      data.employer_name,
          employer_telephone: data.employer_telephone,
          employer_address:   data.employer_address,
        });
        workerCard.innerHTML = buildResultCard(data, 'worker');
        workerCard.classList.add('show');
        setStatus('✅ Worker found — fields auto-filled.', 'found');
        if (config.onWorkerFound) config.onWorkerFound(data);
      } else {
        fillFields(eFields, {
          employer_name:      data.company_name,
          employer_address:   data.physical_address || data.location,
          employer_telephone: data.telephone,
        });
        companyCard.innerHTML = buildResultCard(data, 'company');
        companyCard.classList.add('show');
        setStatus('✅ Company found — employer fields auto-filled.', 'found');
        if (config.onEmployerFound) config.onEmployerFound(data);
      }
    }

    // ── Status helpers
    function setStatus(msg, cls) {
      statusEl.textContent = msg;
      statusEl.className = 'bl-lookup-status ' + (cls || '');
    }
    function clearStatus() {
      statusEl.textContent = '';
      statusEl.className = 'bl-lookup-status';
    }
  }

  global.BLLookup = { init };

})(window);
