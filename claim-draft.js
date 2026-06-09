// ============================================================
// Auto-create & complete compensation claim drafts from incidents
// ============================================================

(function () {

  function getSB() {
    // Uses the shared Supabase client from supabase-config.js
    // Must be loaded before this script on every page
    return window.supabaseClient;
  }

  function todayISO() {
    return new Date().toISOString().slice(0, 10);
  }

  function sexToGender(sex) {
    const n = window.normalizeSex ? window.normalizeSex(sex) : sex;
    if (n === 'Male') return 'M';
    if (n === 'Female') return 'F';
    return 'M';
  }

  window.mapIndustryFromAccidentSector = function (sector) {
    const m = {
      Manufacturing: 'MANUFACTURING',
      Services: 'SERVICES',
      Construction: 'CONSTRUCTION',
      Agriculture: 'AGRICULTURE',
      Transport: 'TRANSPORT',
      Retail: 'RETAIL',
      Government: 'GOVT',
      Parastatal: 'PARASTATAL',
    };
    return m[sector] || 'SERVICES';
  };

  async function fetchRegistry(registryId) {
    if (!registryId) return null;
    const { data } = await getSB()
      .from('workers_registry')
      .select('nationality, address, sex')
      .eq('id', registryId)
      .maybeSingle();
    return data;
  }

  async function findExistingDraft(sourceType, sourceId) {
    const { data } = await getSB()
      .from('injury_claims')
      .select('id')
      .eq('source_type', sourceType)
      .eq('source_id', sourceId)
      .eq('status', 'draft')
      .maybeSingle();
    return data?.id || null;
  }

  /**
   * Create draft claim from Form 60 payload (after insert).
   * @returns {Promise<string|null>} draft claim UUID
   */
  window.createClaimDraftFromAccident = async function (report, reportId, userId, registryId) {
    if (!reportId || !userId) return null;

    const existing = await findExistingDraft('accident', reportId);
    if (existing) return existing;

    const reg = await fetchRegistry(registryId || report.worker_registry_id);
    const injuryDate = report.accident_date || todayISO();

    const draft = {
      source_type: 'accident',
      source_id: reportId,
      status: 'draft',
      submitted_by: userId,
      worker_registry_id: registryId || report.worker_registry_id || null,
      file_number: null,
      name_of_claimant: report.injured_name || 'To be confirmed',
      claimant_id_number: (report.injured_id_number || '').toUpperCase() || null,
      gender: sexToGender(report.injured_sex || reg?.sex),
      nationality: reg?.nationality || 'Botswana',
      location: reg?.address || report.premises_address || 'To be confirmed',
      name_of_employer: report.occupier_name || 'To be confirmed',
      industry: window.mapIndustryFromAccidentSector(report.industry_sector),
      date_of_injury: injuryDate,
      date_reported: report.report_date || todayISO(),
      date_received: todayISO(),
      cause: report.accident_description || 'See Form 60 accident report',
      nature: report.accident_description || report.machinery_involved || 'See Form 60',
      incapacity_percentage: 0,
    };

    if (!draft.claimant_id_number) {
      // Cannot create draft without an ID number — skip silently
      return null;
    }

    const { data, error } = await getSB()
      .from('injury_claims')
      .insert([draft])
      .select('id')
      .maybeSingle();

    if (error) {
      return null;
    }
    return data?.id || null;
  };

  /**
   * Create draft claim from Form 43/10 payload.
   */
  window.createClaimDraftFromInjuryDisease = async function (report, reportId, userId, registryId) {
    if (!reportId || !userId) return null;

    const existing = await findExistingDraft('injury_disease', reportId);
    if (existing) return existing;

    const reg = await fetchRegistry(registryId || report.worker_registry_id);
    const injuryDate = report.incident_date || todayISO();

    const draft = {
      source_type: 'injury_disease',
      source_id: reportId,
      status: 'draft',
      submitted_by: userId,
      worker_registry_id: registryId || report.worker_registry_id || null,
      file_number: null,
      name_of_claimant: report.worker_name || 'To be confirmed',
      claimant_id_number: (report.worker_id_number || '').toUpperCase() || null,
      gender: sexToGender(reg?.sex) || 'M',
      nationality: reg?.nationality || 'Botswana',
      location: report.worker_address || reg?.address || '',
      name_of_employer: report.employer_name || 'To be confirmed',
      industry: 'SERVICES',
      date_of_injury: injuryDate,
      date_reported: report.report_date || todayISO(),
      date_received: todayISO(),
      cause: report.nature_of_injuries || 'See Form 43/10 report',
      nature: report.nature_of_injuries || 'See Form 43/10',
      incapacity_percentage: 0,
    };

    if (!draft.claimant_id_number) {
      // Cannot create draft without an ID number — skip silently
      return null;
    }

    const { data, error } = await getSB()
      .from('injury_claims')
      .insert([draft])
      .select('id')
      .maybeSingle();

    if (error) {
      return null;
    }
    return data?.id || null;
  };

  window.promptCompleteClaimDraft = async function (draftId, reportLabel) {
    if (!draftId) return;
    const go = await showConfirm(
      `A compensation claim <strong>draft</strong> was created from this ${reportLabel}. ` +
      `Open it now to complete required fields and submit?`,
      {
        title: 'Complete compensation claim?',
        icon: '✅',
        confirmText: 'Complete claim',
        cancelText: 'Later',
      }
    );
    if (go) window.location.href = `form.html?draft=${draftId}`;
  };

  window.loadClaimDraftIntoForm = async function (draftId) {
    const sb = getSB();
    const { data, error } = await sb
      .from('injury_claims')
      .select('*')
      .eq('id', draftId)
      .eq('status', 'draft')
      .maybeSingle();

    if (error || !data) {
      await showAlert(
        (error && error.message) || 'Draft claim not found or already submitted.',
        { type: 'warning', title: 'Draft unavailable' }
      );
      return null;
    }

    const set = (id, val) => {
      const el = document.getElementById(id);
      if (el && val != null && val !== '') el.value = val;
    };

    set('draftClaimId', data.id);
    set('sourceType', data.source_type || '');
    set('sourceId', data.source_id || '');
    set('workerRegistryId', data.worker_registry_id || '');
    set('nameOfEmployer', data.name_of_employer);
    set('industry', data.industry);
    set('claimantIdNumber', data.claimant_id_number);
    set('nameOfClaimant', data.name_of_claimant);
    set('gender', data.gender);
    set('nationality', data.nationality);
    set('location', data.location);
    set('dateOfInjury', data.date_of_injury);
    set('dateReported', data.date_reported);
    set('dateReceived', data.date_received);
    set('cause', data.cause);
    set('nature', data.nature);
    set('incapacity', data.incapacity_percentage);

    const banner = document.getElementById('draftBanner');
    if (banner) {
      const src = data.source_type === 'accident'
        ? 'OHS Form 60 (Accident Report)'
        : data.source_type === 'injury_disease'
        ? 'BL Form 43/10 (Injury & Disease Report)'
        : 'incident report';
      banner.style.display = 'block';
      banner.innerHTML = `
        <strong>📝 Draft claim</strong> — Pre-filled from ${src}.
        Review all fields, then submit to assign file number
        <strong>OHS/COMP/…</strong>.`;
    }

    if (typeof refreshClaimFileNumberPreview === 'function') {
      refreshClaimFileNumberPreview();
    }

    return data;
  };

  window.cancelClaimDraft = async function (draftId) {
    const ok = await showConfirm(
      'This draft will be marked cancelled. You can still file a claim manually later.',
      { title: 'Cancel draft?', icon: '🗑️', confirmText: 'Cancel draft', cancelText: 'Keep', danger: true }
    );
    if (!ok) return false;

    const { error } = await getSB()
      .from('injury_claims')
      .update({ status: 'cancelled' })
      .eq('id', draftId)
      .eq('status', 'draft');

    if (error) {
      await showAlert(error.message, { type: 'error', title: 'Could not cancel' });
      return false;
    }
    return true;
  };
})();
