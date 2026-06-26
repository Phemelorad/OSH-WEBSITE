(function () {
  "use strict";

// ============================================
// SHARED UTILITY FUNCTIONS
// Include this script on every page after modal.js
// ============================================

/**
 * Format a date value to a human-readable string (e.g. "14 Mar 2026").
 * @param {Date|string|number|null|undefined} d - Date value (ISO string, timestamp, or Date object)
 * @returns {string} Formatted date string or em-dash if input is null/undefined
 */
function fmtDate(d) {
    if (!d) return '\u2014';
    return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' });
}

/**
 * Escape HTML special characters to prevent XSS.
 * @param {*} s - Value to escape (converted to string)
 * @returns {string} HTML-escaped string or empty string if input is null/undefined
 */
function esc(s) {
    if (s == null) return '';
    return String(s)
        .replace(/&/g,'&amp;').replace(/</g,'&lt;')
        .replace(/>/g,'&gt;').replace(/"/g,'&quot;')
        .replace(/'/g,'&#39;');
}

/**
 * Universal logout handler.
 * Confirms with the user, then calls signOut() and redirects to login.
 * @requires modal.js (showConfirm, showAlert)
 * @requires supabase-config.js (signOut)
 * @returns {Promise<void>}
 */
async function handleLogout() {
    const ok = await showConfirm('You will be signed out of the DOSH system.', {
        title: 'Logout', icon: '\uD83D\uDC4B', confirmText: 'Logout', cancelText: 'Stay'
    });
    if (ok) {
        const r = await signOut();
        if (r.success) window.location.href = 'index.html';
        else await showAlert('Logout failed: ' + r.error, { type: 'error' });
    }
}



  // Export globally for HTML onclick handlers and inline scripts
  window.handleLogout = handleLogout;
  window.fmtDate = fmtDate;
  window.esc = esc;

  window.autoFillCompanyFields = async function() {
    try {
      if (!window.supabaseClient) return;
      var { data: { user } } = await window.supabaseClient.auth.getUser();
      if (!user) return;
      var { data: profile } = await window.supabaseClient
        .from('user_profiles')
        .select('role, company_id')
        .eq('user_id', user.id)
        .single();
      if (!profile || profile.role !== 'company') return;
      var companyId = profile.company_id;
      var companyName = profile.company_name;
      if (companyId) {
        var { data: company } = await window.supabaseClient
          .from('companies')
          .select('company_name, physical_address, plot_number, street_name, location, industry_sector, town_city')
          .eq('id', companyId)
          .single();
        if (company) {
          companyName = company.company_name || companyName;
          var occEl = document.getElementById('occupierName');
          if (occEl && !occEl.value) occEl.value = companyName;
          var addrEl = document.getElementById('premisesAddress');
          if (addrEl && !addrEl.value) {
            var parts = [company.physical_address, company.plot_number, company.street_name, company.location, company.town_city].filter(Boolean);
            addrEl.value = parts.join(', ');
          }
          var indEl = document.getElementById('natureOfIndustry');
          if (indEl && !indEl.value && company.industry_sector) indEl.value = company.industry_sector;
        }
      }
      if (companyName) {
        var occEl = document.getElementById('occupierName');
        if (occEl && !occEl.value) occEl.value = companyName;
      }
    } catch (e) {
      console.warn('autoFillCompanyFields:', e);
  window.getUserCompanyName = async function(supabaseClient) {
    try {
      if (!supabaseClient) return null;
      var { data: { user } } = await supabaseClient.auth.getUser();
      if (!user) return null;
      var { data: profile } = await supabaseClient
        .from('user_profiles')
        .select('company_id, company_name')
        .eq('user_id', user.id)
        .maybeSingle();
      if (!profile) return null;
      if (profile.company_name) return profile.company_name;
      if (profile.company_id) {
        var { data: company } = await supabaseClient
          .from('companies')
          .select('company_name')
          .eq('id', profile.company_id)
          .maybeSingle();
        if (company) return company.company_name;
      }
      return null;
    } catch (e) {
      console.warn('getUserCompanyName:', e);
      return null;
    }
  };



  // ============================================
  // MID-SCREEN POPUP SYSTEM
  // ============================================

  /** Inject popup CSS once */
  if (!document.getElementById('osh-popup-styles')) {
    var ps = document.createElement('style');
    ps.id = 'osh-popup-styles';
    ps.textContent = `
      .osh-popup-overlay {
        position: fixed; top: 0; left: 0; right: 0; bottom: 0;
        background: rgba(0,0,0,0.45);
        display: flex; align-items: center; justify-content: center;
        z-index: 99999;
        animation: osh-popup-fadein 0.2s ease;
      }
      .osh-popup-card {
        background: #fff;
        border-radius: 16px;
        padding: 40px 48px;
        max-width: 420px;
        width: 90%;
        text-align: center;
        box-shadow: 0 20px 60px rgba(0,0,0,0.2);
        animation: osh-popup-scalein 0.25s cubic-bezier(0.25, 0.46, 0.45, 0.94);
        position: relative;
      }
      .osh-popup-icon {
        font-size: 48px;
        margin-bottom: 16px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .osh-popup-icon .spinner {
        width: 48px; height: 48px;
        border: 4px solid #e8e8e8;
        border-top-color: #333;
        border-radius: 50%;
        animation: osh-spin 0.8s linear infinite;
      }
      .osh-popup-icon .checkmark {
        width: 56px; height: 56px;
        border-radius: 50%;
        background: #43a047;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 28px;
        color: #fff;
        animation: osh-popup-scalein 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
      }
      .osh-popup-icon .errorx {
        width: 56px; height: 56px;
        border-radius: 50%;
        background: #e53935;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 28px;
        color: #fff;
        animation: osh-popup-scalein 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
      }
      .osh-popup-message {
        font-size: 16px;
        color: #333;
        font-weight: 600;
        line-height: 1.5;
        margin-bottom: 8px;
      }
      .osh-popup-sub {
        font-size: 13px;
        color: #888;
        margin-top: 4px;
      }
      .osh-popup-btn {
        margin-top: 20px;
        padding: 10px 32px;
        background: #333;
        color: #fff;
        border: none;
        border-radius: 8px;
        font-size: 14px;
        font-weight: 600;
        cursor: pointer;
        font-family: inherit;
        transition: background 0.2s;
      }
      .osh-popup-btn:hover { background: #111; }
      @keyframes osh-popup-fadein { from { opacity: 0; } to { opacity: 1; } }
      @keyframes osh-popup-scalein { from { opacity: 0; transform: scale(0.85); } to { opacity: 1; transform: scale(1); } }
      @keyframes osh-spin { to { transform: rotate(360deg); } }
    `;
    document.head.appendChild(ps);
  }

  /** Remove any existing popup overlay */
  function removePopup() {
    var existing = document.querySelector('.osh-popup-overlay');
    if (existing) existing.remove();
  }

  /**
   * Show a mid-screen popup
   * @param {'loading'|'success'|'error'} type
   * @param {string} message - Main popup text
   * @param {object} [opts]
   * @param {string} [opts.sub] - Subtitle/secondary text
   * @param {number} [opts.autoHide] - Auto-close after N ms (success only)
   * @param {string} [opts.btnText] - Button label (default: 'OK' for success/error)
   * @param {function} [opts.onClose] - Callback when popup closes
   */
  window.showPopup = function(type, message, opts) {
    opts = opts || {};
    removePopup();

    var overlay = document.createElement('div');
    overlay.className = 'osh-popup-overlay';

    var card = document.createElement('div');
    card.className = 'osh-popup-card';

    // Icon
    var iconDiv = document.createElement('div');
    iconDiv.className = 'osh-popup-icon';
    if (type === 'loading') {
      iconDiv.innerHTML = '<div class="spinner"></div>';
    } else if (type === 'success') {
      iconDiv.innerHTML = '<div class="checkmark">✔</div>';
    } else if (type === 'error') {
      iconDiv.innerHTML = '<div class="errorx">✖</div>';
    }
    card.appendChild(iconDiv);

    // Message
    var msgDiv = document.createElement('div');
    msgDiv.className = 'osh-popup-message';
    msgDiv.textContent = message;
    card.appendChild(msgDiv);

    // Subtitle
    if (opts.sub) {
      var subDiv = document.createElement('div');
      subDiv.className = 'osh-popup-sub';
      subDiv.textContent = opts.sub;
      card.appendChild(subDiv);
    }

    // Button (not for loading)
    if (type !== 'loading') {
      var btn = document.createElement('button');
      btn.className = 'osh-popup-btn';
      btn.textContent = opts.btnText || 'OK';
      btn.onclick = function() { removePopup(); if (opts.onClose) opts.onClose(); };
      card.appendChild(btn);
    }

    overlay.appendChild(card);
    document.body.appendChild(overlay);

    // Auto-hide for success
    if (type === 'success' && opts.autoHide) {
      setTimeout(function() { removePopup(); if (opts.onClose) opts.onClose(); }, opts.autoHide);
    }

    return {
      close: function() {
        removePopup();
        if (opts.onClose) opts.onClose();
      }
    };
  };

  /** Show loading popup with spinner */
  window.showLoading = function(message) {
    return window.showPopup('loading', message || 'Processing...');
  };

  /** Hide loading popup */
  window.hideLoading = function() {
    removePopup();
  };

  /** Show success popup with green checkmark */
  window.showSuccess = function(message, autoHide) {
    return window.showPopup('success', message, { autoHide: autoHide !== false ? 3000 : false });
  };

  /** Show error popup */
  window.showError = function(message, opts) {
    opts = opts || {};
    return window.showPopup('error', message, { btnText: opts.btnText || 'OK', onClose: opts.onClose });
  };


})();
