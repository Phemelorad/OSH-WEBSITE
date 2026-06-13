// ============================================================
// CUSTOM MODAL LIBRARY  –  replaces alert / confirm / prompt
// ============================================================

(function () {

  // ── Inject shared styles once ──────────────────────────────
  if (!document.getElementById('osh-modal-styles')) {
    const style = document.createElement('style');
    style.id = 'osh-modal-styles';
    style.textContent = `
      /* Overlay */
      .osh-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0,0,0,0.35);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 9999;
        padding: 20px;
        animation: osh-fade-in 0.18s ease;
      }

      /* Box */
      .osh-modal {
        background: #fff;
        border-radius: 14px;
        box-shadow: 0 20px 60px rgba(0,0,0,0.18);
        width: 100%;
        max-width: 420px;
        padding: 32px 30px 24px;
        position: relative;
        animation: osh-slide-up 0.2s ease;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      }

      .osh-modal-icon {
        font-size: 36px;
        text-align: center;
        margin-bottom: 14px;
        line-height: 1;
      }

      .osh-modal-title {
        font-size: 18px;
        font-weight: 700;
        color: #222;
        margin-bottom: 8px;
        text-align: center;
      }

      .osh-modal-message {
        font-size: 14px;
        color: #555;
        text-align: center;
        line-height: 1.6;
        margin-bottom: 22px;
        white-space: pre-line;
      }

      /* Input (prompt) */
      .osh-modal-input {
        width: 100%;
        padding: 11px 14px;
        border: 2px solid #e0e0e0;
        border-radius: 8px;
        font-size: 14px;
        margin-bottom: 20px;
        font-family: inherit;
        transition: border-color 0.2s;
        box-sizing: border-box;
      }
      .osh-modal-input:focus {
        outline: none;
        border-color: #999;
      }

      /* Select (role / status picker) */
      .osh-modal-select {
        width: 100%;
        padding: 11px 14px;
        border: 2px solid #e0e0e0;
        border-radius: 8px;
        font-size: 14px;
        margin-bottom: 20px;
        font-family: inherit;
        background: #fff;
        cursor: pointer;
        transition: border-color 0.2s;
        box-sizing: border-box;
      }
      .osh-modal-select:focus {
        outline: none;
        border-color: #999;
      }

      /* Buttons row */
      .osh-modal-actions {
        display: flex;
        gap: 10px;
        justify-content: center;
      }

      .osh-btn {
        flex: 1;
        padding: 11px 18px;
        border-radius: 8px;
        font-size: 14px;
        font-weight: 600;
        cursor: pointer;
        border: 2px solid #ddd;
        transition: all 0.2s;
        font-family: inherit;
        max-width: 180px;
      }

      .osh-btn-primary {
        background: #333;
        color: #fff;
        border-color: #333;
      }
      .osh-btn-primary:hover {
        background: #111;
        border-color: #111;
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      }

      .osh-btn-secondary {
        background: #fff;
        color: #555;
        border-color: #ddd;
      }
      .osh-btn-secondary:hover {
        background: #f5f5f5;
        transform: translateY(-1px);
      }

      .osh-btn-danger {
        background: #e74c3c;
        color: #fff;
        border-color: #e74c3c;
      }
      .osh-btn-danger:hover {
        background: #c0392b;
        border-color: #c0392b;
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(231,76,60,0.3);
      }

      /* Type accents */
      .osh-modal.type-success .osh-modal-title { color: #155724; }
      .osh-modal.type-error   .osh-modal-title { color: #721c24; }
      .osh-modal.type-warning .osh-modal-title { color: #856404; }
      .osh-modal.type-info    .osh-modal-title { color: #0c5460; }

      /* Toast */
      .osh-toast-container {
        position: fixed;
        bottom: 28px;
        right: 28px;
        display: flex;
        flex-direction: column;
        gap: 10px;
        z-index: 10000;
      }

      .osh-toast {
        background: #222;
        color: #fff;
        padding: 13px 18px;
        border-radius: 10px;
        font-size: 14px;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        max-width: 320px;
        box-shadow: 0 8px 24px rgba(0,0,0,0.18);
        display: flex;
        align-items: center;
        gap: 10px;
        animation: osh-slide-up 0.2s ease;
      }
      .osh-toast.toast-success { background: #1a7a3c; }
      .osh-toast.toast-error   { background: #c0392b; }
      .osh-toast.toast-warning { background: #b7860b; }
      .osh-toast.toast-info    { background: #0c6279; }

      .osh-toast-icon { font-size: 18px; flex-shrink: 0; }
      .osh-toast-msg  { flex: 1; line-height: 1.4; }

      .osh-toast.hiding {
        animation: osh-fade-out 0.3s ease forwards;
      }

      /* Animations */
      @keyframes osh-fade-in  { from { opacity:0 } to { opacity:1 } }
      @keyframes osh-fade-out { from { opacity:1 } to { opacity:0 } }
      @keyframes osh-slide-up {
        from { opacity:0; transform: translateY(18px) }
        to   { opacity:1; transform: translateY(0) }
      }

      @media (max-width: 480px) {
        .osh-modal { padding: 26px 18px 20px; }
        .osh-modal-actions { flex-direction: column; }
        .osh-btn { max-width: 100%; }
      }
    `;
    document.head.appendChild(style);
  }

  // ── Helpers ────────────────────────────────────────────────
  const ICONS = {
    success : '✅',
    error   : '❌',
    warning : '⚠️',
    info    : 'ℹ️',
    confirm : '❓',
    prompt  : '✏️',
    logout  : '👋',
    role    : '🔑',
    status  : '📋',
    claim   : '📄',
  };

  function buildOverlay() {
    const el = document.createElement('div');
    el.className = 'osh-overlay';
    el.addEventListener('click', e => { if (e.target === el) el._dismiss?.(); });
    return el;
  }

  function buildModal(type) {
    const el = document.createElement('div');
    el.className = `osh-modal type-${type}`;
    return el;
  }

  function show(overlay) { document.body.appendChild(overlay); }
  function hide(overlay) { overlay.remove(); }

  // ── 1. showAlert(message, opts) ────────────────────────────
  // opts: { title, type:'success'|'error'|'warning'|'info', icon, btnText, extraBtn }
  //       extraBtn: { text, action } – renders a secondary button that doesn't close the modal
  window.showAlert = function (message, opts = {}) {
    return new Promise(resolve => {
      const type    = opts.type    || 'info';
      const title   = opts.title   || { success:'Success', error:'Error', warning:'Warning', info:'Notice' }[type];
      const icon    = opts.icon    || ICONS[type] || ICONS.info;
      const btnText = opts.btnText || 'OK';
      const extraBtn = opts.extraBtn || null;

      const overlay = buildOverlay();
      const modal   = buildModal(type);

      let extraBtnHTML = '';
      if (extraBtn) {
        extraBtnHTML = `<button class="osh-btn osh-btn-secondary" id="osh-extra">${extraBtn.text}</button>`;
      }

      modal.innerHTML = `
        <div class="osh-modal-icon">${icon}</div>
        <div class="osh-modal-title">${title}</div>
        <div class="osh-modal-message">${message}</div>
        <div class="osh-modal-actions">
          ${extraBtnHTML}
          <button class="osh-btn osh-btn-primary" id="osh-ok">${btnText}</button>
        </div>`;

      overlay._dismiss = () => { hide(overlay); resolve(); };
      overlay.appendChild(modal);
      show(overlay);

      modal.querySelector('#osh-ok').addEventListener('click', overlay._dismiss);
      modal.querySelector('#osh-ok').focus();

      if (extraBtn) {
        modal.querySelector('#osh-extra').addEventListener('click', async (e) => {
          e.stopPropagation();
          await extraBtn.action();
        });
      }
    });
  };

  // ── 2. showConfirm(message, opts) ─────────────────────────
  // opts: { title, type, icon, confirmText, cancelText, danger }
  window.showConfirm = function (message, opts = {}) {
    return new Promise(resolve => {
      const type        = opts.type        || 'confirm';
      const title       = opts.title       || 'Are you sure?';
      const icon        = opts.icon        || ICONS[opts.iconKey || 'confirm'];
      const confirmText = opts.confirmText || 'Confirm';
      const cancelText  = opts.cancelText  || 'Cancel';
      const btnClass    = opts.danger ? 'osh-btn-danger' : 'osh-btn-primary';

      const overlay = buildOverlay();
      const modal   = buildModal(type);

      modal.innerHTML = `
        <div class="osh-modal-icon">${icon}</div>
        <div class="osh-modal-title">${title}</div>
        <div class="osh-modal-message">${message}</div>
        <div class="osh-modal-actions">
          <button class="osh-btn osh-btn-secondary" id="osh-cancel">${cancelText}</button>
          <button class="osh-btn ${btnClass}"        id="osh-confirm">${confirmText}</button>
        </div>`;

      overlay._dismiss = () => { hide(overlay); resolve(false); };
      overlay.appendChild(modal);
      show(overlay);
      modal.querySelector('#osh-cancel') .addEventListener('click', () => { hide(overlay); resolve(false); });
      modal.querySelector('#osh-confirm').addEventListener('click', () => { hide(overlay); resolve(true);  });
      modal.querySelector('#osh-confirm').focus();
    });
  };

  // ── 3. showPrompt(message, defaultValue, opts) ────────────
  window.showPrompt = function (message, defaultValue = '', opts = {}) {
    return new Promise(resolve => {
      const title       = opts.title       || 'Input Required';
      const icon        = opts.icon        || ICONS.prompt;
      const confirmText = opts.confirmText || 'OK';
      const cancelText  = opts.cancelText  || 'Cancel';

      const overlay = buildOverlay();
      const modal   = buildModal('info');

      modal.innerHTML = `
        <div class="osh-modal-icon">${icon}</div>
        <div class="osh-modal-title">${title}</div>
        <div class="osh-modal-message">${message}</div>
        <input class="osh-modal-input" id="osh-input" value="${defaultValue}" />
        <div class="osh-modal-actions">
          <button class="osh-btn osh-btn-secondary" id="osh-cancel">${cancelText}</button>
          <button class="osh-btn osh-btn-primary"   id="osh-confirm">${confirmText}</button>
        </div>`;

      overlay._dismiss = () => { hide(overlay); resolve(null); };
      overlay.appendChild(modal);
      show(overlay);

      const input = modal.querySelector('#osh-input');
      input.focus();
      input.select();
      input.addEventListener('keydown', e => {
        if (e.key === 'Enter') { hide(overlay); resolve(input.value); }
        if (e.key === 'Escape') { hide(overlay); resolve(null); }
      });
      modal.querySelector('#osh-cancel') .addEventListener('click', () => { hide(overlay); resolve(null); });
      modal.querySelector('#osh-confirm').addEventListener('click', () => { hide(overlay); resolve(input.value); });
    });
  };

  // ── 4. showSelect(message, options, defaultValue, opts) ───
  // options: [{ value, label }]
  window.showSelect = function (message, options, defaultValue = '', opts = {}) {
    return new Promise(resolve => {
      const title       = opts.title       || 'Select an Option';
      const icon        = opts.icon        || ICONS[opts.iconKey || 'info'];
      const confirmText = opts.confirmText || 'Confirm';
      const cancelText  = opts.cancelText  || 'Cancel';

      const optionsHTML = options.map(o =>
        `<option value="${o.value}" ${o.value === defaultValue ? 'selected' : ''}>${o.label}</option>`
      ).join('');

      const overlay = buildOverlay();
      const modal   = buildModal('info');

      modal.innerHTML = `
        <div class="osh-modal-icon">${icon}</div>
        <div class="osh-modal-title">${title}</div>
        <div class="osh-modal-message">${message}</div>
        <select class="osh-modal-select" id="osh-select">${optionsHTML}</select>
        <div class="osh-modal-actions">
          <button class="osh-btn osh-btn-secondary" id="osh-cancel">${cancelText}</button>
          <button class="osh-btn osh-btn-primary"   id="osh-confirm">${confirmText}</button>
        </div>`;

      overlay._dismiss = () => { hide(overlay); resolve(null); };
      overlay.appendChild(modal);
      show(overlay);

      const sel = modal.querySelector('#osh-select');
      sel.focus();
      modal.querySelector('#osh-cancel') .addEventListener('click', () => { hide(overlay); resolve(null); });
      modal.querySelector('#osh-confirm').addEventListener('click', () => { hide(overlay); resolve(sel.value); });
    });
  };

  // ── 5. showToast(message, type, duration) ─────────────────
  // type: 'success' | 'error' | 'warning' | 'info'
  window.showToast = function (message, type = 'info', duration = 3500) {
    let container = document.querySelector('.osh-toast-container');
    if (!container) {
      container = document.createElement('div');
      container.className = 'osh-toast-container';
      document.body.appendChild(container);
    }

    const icon  = ICONS[type] || ICONS.info;
    const toast = document.createElement('div');
    toast.className = `osh-toast toast-${type}`;
    toast.innerHTML = `<span class="osh-toast-icon">${icon}</span><span class="osh-toast-msg">${message}</span>`;
    container.appendChild(toast);

    setTimeout(() => {
      toast.classList.add('hiding');
      setTimeout(() => toast.remove(), 300);
    }, duration);
  };

  // ── 6. showClaimDetails(claim) ────────────────────────────
  window.showClaimDetails = function (claim) {
    const statusColors = {
      pending      : '#856404', under_review : '#0c5460',
      approved     : '#155724', rejected     : '#721c24', closed : '#383d41',
    };
    const statusBg = {
      pending      : '#fff3cd', under_review : '#d1ecf1',
      approved     : '#d4edda', rejected     : '#f8d7da', closed : '#e2e3e5',
    };

    function f(label, val) { return val != null && val !== '' ? '<div class="rec-field"><span class="lbl">' + label + '</span><span class="val">' + val + '</span></div>' : ''; }

    const sbg = statusBg[claim.status] || '#eee';
    const sc = statusColors[claim.status] || '#333';
    const statusBadge = claim.status ? '<span style="background:' + sbg + ';color:' + sc + ';padding:3px 10px;border-radius:12px;font-weight:600;font-size:12px">' + claim.status.replace('_',' ').toUpperCase() + '</span>' : '';

    const claimantSection = '<div class="rec-section">' +
      '<div class="rec-section-header worker">\u{1F464} Claimant Details</div>' +
      '<div class="rec-section-body">' +
      f('Claimant', claim.name_of_claimant) +
      f('Gender', claim.gender === 'M' ? 'Male' : 'Female') +
      f('Location', claim.location) +
      f('Nationality', claim.nationality) +
      '</div></div>';

    const injurySection = '<div class="rec-section">' +
      '<div class="rec-section-header incident">\u{1F6A8} Injury Details</div>' +
      '<div class="rec-section-body">' +
      f('File Number', claim.file_number) +
      f('Date of Injury', claim.date_of_injury) +
      f('Cause', claim.cause) +
      f('Nature', claim.nature) +
      f('Incapacity', claim.incapacity_percentage != null ? claim.incapacity_percentage + '%' : '') +
      '</div></div>';

    const employerSection = '<div class="rec-section">' +
      '<div class="rec-section-header employer">\u{1F3E2} Employer</div>' +
      '<div class="rec-section-body">' +
      f('Employer', claim.name_of_employer) +
      f('Industry', claim.industry) +
      '</div></div>';

    const statusSection = claim.status ? '<div class="rec-section">' +
      '<div class="rec-section-header report">\u{2139}\uFE0F Status</div>' +
      '<div class="rec-section-body">' +
      f('Status', statusBadge) +
      '</div></div>' : '';

    const modalHtml = '<div class="rec-modal">' +
      '<div class="rec-modal-header">' +
      '<div>' +
      '<h2>\u{1F4C4} Claim Details</h2>' +
      '<div class="subtitle">' + (claim.file_number || 'Compensation Claim') + '</div>' +
      '</div>' +
      '<button class="rec-modal-close" id="recCloseBtn">\u2715</button>' +
      '</div>' +
      '<div class="rec-modal-body">' +
      claimantSection +
      injurySection +
      employerSection +
      statusSection +
      '</div>' +
      '</div>';

    return new Promise(resolve => {
      const overlay = document.createElement('div');
      overlay.className = 'rec-modal-overlay';
      overlay.innerHTML = modalHtml;
      overlay.querySelector('#recCloseBtn').addEventListener('click', () => { overlay.remove(); resolve(); });
      overlay.addEventListener('click', e => { if (e.target === overlay) { overlay.remove(); resolve(); } });
      document.body.appendChild(overlay);
    });
  }