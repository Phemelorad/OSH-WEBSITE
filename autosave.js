/**
 * Form Autosave Utility
 * Saves form data to localStorage and offers draft recovery on reload.
 * Include on any form page via: <script src="autosave.js"></script>
 *
 * Usage:
 *   enableAutosave('formId', 'draftKey', { excludeFields: ['fieldId'], onRestore: () => {} });
 */

function enableAutosave(formId, draftKey, opts = {}) {
  const form = document.getElementById(formId);
  if (!form) return;

  const STORAGE_KEY = 'osh_draft_' + draftKey;
  const exclude = new Set(opts.excludeFields || []);
  let saveTimer = null;

  // Collect form data into a plain object
  function collectData() {
    const data = {};
    const elements = form.querySelectorAll('input, select, textarea');
    elements.forEach(el => {
      if (exclude.has(el.id)) return;
      if (el.type === 'checkbox') {
        data[el.name || el.id] = el.checked;
      } else if (el.type === 'radio') {
        if (el.checked) data[el.name || el.id] = el.value;
      } else {
        data[el.name || el.id] = el.value;
      }
    });
    return data;
  }

  // Restore saved data into the form
  function restoreData(data) {
    if (!data) return false;
    Object.entries(data).forEach(([key, val]) => {
      const el = form.querySelector(`[name="${key}"]`) || document.getElementById(key);
      if (!el) return;
      if (el.type === 'checkbox') {
        el.checked = !!val;
      } else if (el.type === 'radio') {
        const radio = form.querySelector(`[name="${key}"][value="${val}"]`);
        if (radio) radio.checked = true;
      } else {
        el.value = val;
      }
    });
    if (opts.onRestore) opts.onRestore();
    return true;
  }

  // Save to localStorage (debounced)
  function saveDraft() {
    try {
      const data = collectData();
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    } catch (e) {
      // localStorage might be full
    }
  }

  // Debounced save on input
  form.addEventListener('input', () => {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveDraft, 1000);
  });
  form.addEventListener('change', saveDraft);

  // Clear draft on successful submission
  function clearDraft() {
    localStorage.removeItem(STORAGE_KEY);
  }

  // On load, check for existing draft
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      try {
        const data = JSON.parse(saved);
        const hasData = Object.values(data).some(v => v !== '' && v !== false && v !== null && v !== undefined);
        if (hasData && typeof showConfirm === 'function') {
          showConfirm('You have a saved draft from your last session. Would you like to restore it?', {
            title: 'Draft Found',
            confirmText: 'Restore',
            cancelText: 'Discard'
          }).then(ok => {
            if (ok) {
              restoreData(data);
              showToast('Draft restored.', 'info');
            } else {
              clearDraft();
            }
          });
        } else if (hasData) {
          restoreData(data);
        }
      } catch (e) { /* invalid JSON, ignore */ }
    }
  } catch (e) { /* localStorage not available */ }

  return { clearDraft, saveDraft };
}
