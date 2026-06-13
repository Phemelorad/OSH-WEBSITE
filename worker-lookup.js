// ============================================================
// WORKER LOOKUP & REGISTRY — shared across all person-forms
// Normalizes sex + employer; upserts full Tier 1/2 on submit
// ============================================================

(function () {

  const REGISTRY_UPSERT_COLUMNS = [
    'id_type', 'full_name', 'date_of_birth', 'sex', 'nationality', 'address',
    'age_years', 'occupation', 'usual_occupation', 'experience_level',
    'employer_name', 'employer_address', 'employer_telephone', 'employer_fax',
    'email',
  ];

  // ── Inject shared styles once ────────────────────────────
  if (!document.getElementById('wl-styles')) {
    const s = document.createElement('style');
    s.id = 'wl-styles';
    s.textContent = `
      .wl-wrapper { position: relative; }
      .wl-input-row { display: flex; gap: 8px; align-items: stretch; }
      .wl-input-row input { flex: 1; }
      .wl-lookup-btn {
        padding: 10px 18px; background: #333; color: white;
        border: none; border-radius: 8px; cursor: pointer;
        font-size: 13px; font-weight: 600; white-space: nowrap;
        transition: background 0.2s; font-family: inherit; flex-shrink: 0;
      }
      .wl-lookup-btn:hover { background: #111; }
      .wl-lookup-btn:disabled { opacity: 0.5; cursor: not-allowed; }
      .wl-status { margin-top: 6px; font-size: 12px; min-height: 18px; display: flex; align-items: center; gap: 6px; }
      .wl-status.found   { color: #155724; }
      .wl-status.notfound { color: #856404; }
      .wl-status.error   { color: #721c24; }
      .wl-status.loading { color: #888; }
      .wl-profile-banner {
        margin-top: 10px; padding: 12px 16px;
        background: #d4edda; border: 1px solid #c3e6cb;
        border-radius: 8px; font-size: 13px; color: #155724; display: none;
      }
      .wl-profile-banner.show { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
      .wl-profile-banner .wl-name { font-weight: 700; font-size: 14px; }
      .wl-profile-banner .wl-chips { display: flex; gap: 6px; flex-wrap: wrap; }
      .wl-chip {
        background: rgba(0,0,0,0.08); padding: 2px 10px;
        border-radius: 10px; font-size: 11px; font-weight: 600;
      }
      .wl-save-note { margin-top: 6px; font-size: 11px; color: #888; font-style: italic; }
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

  function getSB() {
    // Uses the shared Supabase client from supabase-config.js
    // Must be loaded before this script on every page
    return window.supabaseClient;
  }

  // ── Normalization (single source of truth) ─────────────────
  window.normalizeIdentityId = function (val) {
    if (val == null) return null;
    const t = String(val).trim();
    return t ? t.toUpperCase() : null;
  };

  /** Registry + display: always Male | Female */
  window.normalizeSex = function (val) {
    if (val == null || val === '') return null;
    const v = String(val).trim().toUpperCase();
    if (v === 'M' || v === 'MALE') return 'Male';
    if (v === 'F' || v === 'FEMALE') return 'Female';
    if (val === 'Male' || val === 'Female') return val;
    return null;
  };

  /** Map registry sex → form control value */
  window.sexToFormValue = function (val, formFieldId) {
    const n = window.normalizeSex(val);
    if (!n) return '';
    const el = formFieldId ? document.getElementById(formFieldId) : null;
    if (el?.dataset?.sexFormat === 'mf' || el?.querySelector('option[value="M"]')) {
      return n === 'Male' ? 'M' : 'F';
    }
    return n;
  };

  window.formatSexDisplay = function (val) {
    return window.normalizeSex(val) || '—';
  };

  /** First non-empty employer string (registry > injury employer > accident occupier) */
  window.resolveEmployerName = function (...sources) {
    for (const s of sources.flat()) {
      if (s == null) continue;
      const t = String(s).trim();
      if (t) return t;
    }
    return null;
  };

  window.formatIdTypeDisplay = function (idType) {
    if (!idType) return '—';
    return idType === 'Passport' ? 'Passport' : 'Omang (National ID)';
  };

  /** Preview OHS/COMP/{id}/{seq}/{YY} — requires claim-file-number.sql in Supabase */
  window.previewCompClaimFileNumber = async function (claimantId) {
    const id = window.normalizeIdentityId(claimantId);
    if (!id) return { fileNumber: null, error: null };

    const { data, error } = await getSB().rpc('preview_comp_claim_file_number', {
      p_claimant_id: id,
    });

    if (error) return { fileNumber: null, error: error.message };
    return { fileNumber: data || null, error: null };
  };

  function readFormField(fieldId, column) {
    const el = document.getElementById(fieldId);
    if (!el) return null;
    let val = (el.value != null ? String(el.value) : '').trim();
    if (val === '') return null;
    if (column === 'sex') return window.normalizeSex(val);
    if (column === 'age_years') {
      const n = parseInt(val, 10);
      return Number.isFinite(n) ? n : null;
    }
    return val;
  }

  function mergeRegistryRow(existing, patch) {
    const out = { ...(existing || {}) };
    REGISTRY_UPSERT_COLUMNS.forEach(col => {
      if (patch[col] != null && patch[col] !== '') out[col] = patch[col];
    });
    out.id_number = patch.id_number;
    if (patch.id_type) out.id_type = patch.id_type;
    return out;
  }

  /**
   * Upsert workers_registry from form fields on every submit.
   * fieldIds: { registry_column: 'formElementId', ... , id_number: '...' }
   */
  window.upsertWorkerRegistry = async function (fieldIds) {
    const idField = fieldIds.id_number;
    const id = window.normalizeIdentityId(
      (idField && readFormField(idField, 'id_number')) ||
      window._pendingWorkerId
    );
    if (!id) return window._resolvedWorkerId || null;

    const patch = { id_number: id };
    if (window._pendingWorkerIdType) {
      patch.id_type = window._pendingWorkerIdType;
    }

    REGISTRY_UPSERT_COLUMNS.forEach(col => {
      const fid = fieldIds[col];
      if (!fid) return;
      const val = readFormField(fid, col);
      if (val != null && val !== '') patch[col] = val;
    });

    if (!patch.full_name) {
      const nameFid = fieldIds.full_name;
      if (nameFid) {
        const n = readFormField(nameFid, 'full_name');
        if (n) patch.full_name = n;
      }
    }

    if (!patch.full_name) {
      return window._resolvedWorkerId || null;
    }

    if (!patch.id_type) patch.id_type = 'Omang';

    const sb = getSB();
    const { data: existing } = await sb
      .from('workers_registry')
      .select('*')
      .ilike('id_number', id)
      .maybeSingle();

    const merged = mergeRegistryRow(existing, patch);
    const { data, error } = await sb
      .from('workers_registry')
      .upsert(merged, { onConflict: 'id_number' })
      .select('id')
      .maybeSingle();

    if (error) {
      return window._resolvedWorkerId || existing?.id || null;
    }

    window._pendingWorkerId = null;
    window._pendingWorkerIdType = null;
    window._resolvedWorkerId = data?.id || existing?.id || null;

    const hiddenId = fieldIds.worker_registry_id;
    if (hiddenId) {
      const h = document.getElementById(hiddenId);
      if (h && window._resolvedWorkerId) h.value = window._resolvedWorkerId;
    }

    return window._resolvedWorkerId;
  };

  /** @deprecated Use upsertWorkerRegistry(fieldIds) */
  window.saveWorkerIfNew = async function (_formData, fieldIds) {
    return window.upsertWorkerRegistry(fieldIds);
  };

  /** Build display object for worker profile from registry + records */
  window.buildWorkerProfileIdentity = function (registry, incidents, claims) {
    const rep = (incidents && incidents[0]) || {};
    const latestClaim = (claims && claims[0]) || {};

    const idNumber = registry?.id_number ||
      rep.injured_id_number || rep.worker_id_number ||
      latestClaim.claimant_id_number || null;

    return {
      full_name: registry?.full_name ||
        rep.injured_name || rep.worker_name || latestClaim.name_of_claimant,
      id_number: idNumber,
      id_type: registry?.id_type || null,
      sex: registry?.sex || rep.injured_sex || null,
      nationality: registry?.nationality || latestClaim.nationality || null,
      address: registry?.address || rep.worker_address || latestClaim.location || null,
      age_years: registry?.age_years ?? rep.injured_age ?? null,
      date_of_birth: registry?.date_of_birth || null,
      occupation: registry?.occupation ||
        rep.occupation_at_accident || rep.occupation || null,
      usual_occupation: registry?.usual_occupation || rep.usual_occupation || null,
      experience_level: registry?.experience_level || rep.experience_level || null,
      employer_name: window.resolveEmployerName(
        registry?.employer_name,
        rep.employer_name,
        latestClaim.name_of_employer,
        rep.occupier_name
      ),
      employer_telephone: registry?.employer_telephone || rep.employer_telephone || null,
      employer_fax: registry?.employer_fax || rep.employer_fax || null,
      employer_address: registry?.employer_address || null,
      registry_id: registry?.id || rep.worker_registry_id || latestClaim.worker_registry_id || null,
    };
  };

  // ── Lookup widget ──────────────────────────────────────────
  window.attachWorkerLookup = function (config) {
    const container = document.getElementById(config.containerId);
    if (!container) {
      return;
    }

    container.innerHTML = `
      <div class="wl-type-toggle">
        <button type="button" class="wl-type-btn active" id="wl-btn-omang"
                onclick="wlSetType('Omang')">🪪 Omang (National ID)</button>
        <button type="button" class="wl-type-btn" id="wl-btn-passport"
                onclick="wlSetType('Passport')">📘 Passport</button>
      </div>
      <div class="wl-input-row">
        <input type="text" id="wl-id-input" placeholder="Enter Omang number…" maxlength="8" pattern="[0-9]{8}" inputmode="numeric"
               oninput="wlOnInput()" onkeydown="if(event.key==='Enter'){event.preventDefault();wlLookup()}"
               autocomplete="off">
        <button type="button" class="wl-lookup-btn" id="wl-btn" onclick="wlLookup()">🔍 Look Up</button>
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

    window.wlSetType = function (type) {
      currentIdType = type;
      document.getElementById('wl-btn-omang').classList.toggle('active', type === 'Omang');
      document.getElementById('wl-btn-passport').classList.toggle('active', type === 'Passport');
      const inp = document.getElementById('wl-id-input');
      if (type === 'Omang') {
        inp.maxLength = 8; inp.pattern = '[0-9]{8}'; inp.inputMode = 'numeric';
      } else {
        inp.removeAttribute('maxlength'); inp.removeAttribute('pattern'); inp.inputMode = 'text';
      }
      inp.placeholder =
        type === 'Omang' ? 'Enter Omang number…' : 'Enter Passport number…';
      wlClear();
    };

    window.wlOnInput = function () {
      if (!document.getElementById('wl-id-input').value.trim()) wlClear();
    };

    window.wlLookup = async function () {
      const idVal = window.normalizeIdentityId(document.getElementById('wl-id-input').value);
      if (!idVal) {
        setStatus('Enter an ID number first.', 'error');
        return;
      }

      const btn = document.getElementById('wl-btn');
      btn.disabled = true;
      setStatus('Looking up…', 'loading');
      hideBanner();

      const { data, error } = await getSB()
        .from('workers_registry')
        .select('*')
        .ilike('id_number', idVal)
        .maybeSingle();

      btn.disabled = false;

      if (error) {
        setStatus('Lookup error: ' + error.message, 'error');
        return;
      }

      if (data) {
        autofill(data, config.fields);
        showBanner(data);
        setStatus('✅ Worker found — fields auto-filled.', 'found');
        document.getElementById('wl-save-note').style.display = 'none';
        window._pendingWorkerId = null;
        window._pendingWorkerIdType = data.id_type || currentIdType;
        if (config.onFound) config.onFound(data);
      } else {
        setStatus(`⚠ No record found for ${idVal}. Details will be saved to the registry on submit.`, 'notfound');
        const idFieldId = config.fields.id_number;
        if (idFieldId) {
          const el = document.getElementById(idFieldId);
          if (el) el.value = idVal;
        }
        if (config.saveNewWorker !== false) {
          document.getElementById('wl-save-note').style.display = 'block';
          document.getElementById('wl-save-note').textContent =
            'New worker — their details will be saved to the registry when you submit this form.';
          window._pendingWorkerId = idVal;
          window._pendingWorkerIdType = currentIdType;
          window._resolvedWorkerId = null;
        }
      }
    };

    function autofill(worker, fields) {
      Object.entries(fields).forEach(([registryCol, formFieldId]) => {
        if (registryCol === 'worker_registry_id') {
          const el = document.getElementById(formFieldId);
          if (el) el.value = worker.id;
          return;
        }
        if (registryCol === 'id_number') {
          const el = document.getElementById(formFieldId);
          if (el && worker.id_number) el.value = worker.id_number;
          return;
        }
        const val = worker[registryCol];
        if (val == null) return;
        const el = document.getElementById(formFieldId);
        if (!el) return;

        if (registryCol === 'sex') {
          el.value = window.sexToFormValue(val, formFieldId);
        } else if (el.tagName === 'SELECT') {
          const opts = [...el.options];
          const match = opts.find(o =>
            o.value.toLowerCase() === String(val).toLowerCase() ||
            o.text.toLowerCase() === String(val).toLowerCase()
          );
          if (match) el.value = match.value;
        } else {
          el.value = val;
        }

        el.style.transition = 'background 0.3s';
        el.style.background = '#d4edda';
        setTimeout(() => { el.style.background = ''; }, 1800);
      });
      window._resolvedWorkerId = worker.id;
    }

    function showBanner(worker) {
      document.getElementById('wl-banner-name').textContent = worker.full_name;
      const chips = [
        window.formatSexDisplay(worker.sex),
        worker.nationality,
        worker.occupation,
        worker.employer_name,
      ].filter(c => c && c !== '—')
        .map(c => `<span class="wl-chip">${c}</span>`).join('');
      document.getElementById('wl-banner-chips').innerHTML = chips;
      document.getElementById('wl-banner').classList.add('show');
    }

    function hideBanner() {
      document.getElementById('wl-banner').classList.remove('show');
    }

    function setStatus(msg, cls) {
      const el = document.getElementById('wl-status');
      el.textContent = msg;
      el.className = 'wl-status ' + (cls || '');
    }

    function wlClear() {
      setStatus('', '');
      hideBanner();
      document.getElementById('wl-save-note').style.display = 'none';
      window._pendingWorkerId = null;
      window._pendingWorkerIdType = null;
      window._resolvedWorkerId = null;
    }
  };

  window.createWorkerAccount = async function (email, idNumber, fullName) {
    if (!email || !idNumber) return { success: false, error: 'Email and ID required' };
    try {
      const { data: { session } } = await getSB().auth.getSession();
      if (!session) return { success: false, error: 'No active session' };
      const password = Math.random().toString(36).slice(2, 10) + 'A1!' + Math.random().toString(36).slice(2, 6);
      const names = (fullName || '').split(' ');
      const firstName = names[0] || '';
      const surname = names.slice(1).join(' ') || firstName;
      const { data, error } = await getSB().auth.signUp({
        email: email, password: password,
        options: { data: { role: 'worker', first_name: firstName, surname: surname, id_number: idNumber } }
      });
      if (error) throw error;
      const { data: { session: ns } } = await getSB().auth.getSession();
      if ((!ns || ns.user.id !== session.user.id) && session) {
        await getSB().auth.setSession({ access_token: session.access_token, refresh_token: session.refresh_token });
      }
      if (data?.user && typeof window.ensureUserProfile === 'function') {
        await window.ensureUserProfile(data.user);
      }
      return { success: true, userId: data?.user?.id };
    } catch (error) {
      return { success: false, error: error.message };
    }
  };


  window.checkDuplicate = async function (table, column, value, label) {
    if (!value) return { exists: false };
    const { data, error } = await getSB()
      .from(table)
      .select("id")
      .ilike(column, value)
      .limit(1);
    if (error) return { exists: false, error };
    if (data && data.length > 0) {
      const ok = await window.showConfirm(
        `A ${label || "record"} already exists.

Submit anyway? This may create a duplicate.`,
        { title: "⚠ Possible Duplicate", icon: "⚠️", confirmText: "Submit Anyway", cancelText: "Cancel", danger: true }
      );
      return { exists: true, confirmed: ok };
    }
    return { exists: false };
  };
})();
