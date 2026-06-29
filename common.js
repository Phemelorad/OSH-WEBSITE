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

  window.buildWordMatch = function(field, name) {
    var words = name.split(' ').filter(function(w) { return w.length > 2; });
    if (words.length === 0) words = [name];
    return words.map(function(w) { return field + '.ilike.*' + w + '*'; }).join(',');
  };

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
          .select('company_name, physical_address, plot_number, street_name, location, industry_sector')
          .eq('id', companyId)
          .single();
        if (company) {
          companyName = company.company_name || companyName;
          var occEl = document.getElementById('occupierName');
          if (occEl && !occEl.value) occEl.value = companyName;
          var addrEl = document.getElementById('premisesAddress');
          if (addrEl && !addrEl.value) {
            var parts = [company.physical_address, company.plot_number, company.street_name, company.location].filter(Boolean);
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
    }
  };

  window.getUserCompanyName = async function(supabaseClient) {
    try {
      if (!supabaseClient) return null;
      var { data: { user } } = await supabaseClient.auth.getUser();
      if (!user) return null;

      // Primary lookup: user_profiles table
      var { data: profile } = await supabaseClient
        .from('user_profiles')
        .select('company_id')
        .eq('user_id', user.id)
        .maybeSingle();

      if (profile && profile.company_id) {
        var { data: company } = await supabaseClient
          .from('companies')
          .select('company_name')
          .eq('id', profile.company_id)
          .maybeSingle();
        if (company && company.company_name) return company.company_name;
      }

      // Fallback 1: user_metadata (set during registration)
      var meta = user.user_metadata || {};
      var metaName = meta.company_name || meta.companyName;
      if (metaName) return metaName;

      // Fallback 2: try to find company by user's email domain
      if (user.email) {
        var emailDomain = user.email.split('@')[1];
        if (emailDomain) {
          var { data: companyByEmail } = await supabaseClient
            .from('companies')
            .select('company_name')
            .or('email.ilike.%' + emailDomain + '%,owner_email.ilike.%' + emailDomain + '%')
            .limit(1)
            .maybeSingle();
          if (companyByEmail && companyByEmail.company_name) return companyByEmail.company_name;
        }
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



  // ============================================
  // VIEW MODE — Load record data into a form and make it read-only
  // Call from form pages:  window.initViewMode('table_name', { fieldOverrides: {...} })
  // ============================================
  
  window.snakeToCamel = function(str) {
    return str.replace(/_([a-z])/g, function(_, c) { return c.toUpperCase(); });
  };
  
  window.initViewMode = async function(tableName, opts) {
    opts = opts || {};
    var urlParams = new URLSearchParams(window.location.search);
    var id = urlParams.get('id');
    var view = urlParams.get('view');
    
    if (!id || view !== '1') return;
    
    try {
      var { data, error } = await window.supabaseClient
        .from(tableName)
        .select('*')
        .eq('id', id)
        .maybeSingle();
      
      if (error || !data) {
        console.error('initViewMode: Failed to load record', error || 'Not found');
        return;
      }
      
      // Populate standard form fields by ID or name attribute
      Object.keys(data).forEach(function(key) {
        var fieldId = window.snakeToCamel(key);
        var value = data[key];
        var el = document.getElementById(fieldId);
        // Fallback: match by name attribute (snake_case matches DB column)
        if (!el) {
          el = document.getElementsByName(key)[0];
        }
        if (el) {
          if (el.tagName === 'SELECT' || el.tagName === 'TEXTAREA') {
            el.value = value != null ? value : '';
          } else if (el.tagName === 'INPUT') {
            if (el.type === 'radio') {
              var radio = document.querySelector('input[name="' + el.name + '"][value="' + (value || '') + '"]');
              if (radio) radio.checked = true;
            } else if (el.type === 'checkbox') {
              el.checked = value === true || value === 'yes' || value === 'Yes';
            } else {
              el.value = value != null ? value : '';
            }
          }
        }
      });
      
      // Apply field overrides for non-standard mappings
      if (opts.fieldOverrides) {
        Object.keys(opts.fieldOverrides).forEach(function(fieldId) {
          var el = document.getElementById(fieldId);
          if (el) {
            var val = opts.fieldOverrides[fieldId];
            if (typeof val === 'function') {
              val(el, data);
            } else if (el.tagName === 'SELECT' || el.tagName === 'TEXTAREA') {
              el.value = val != null ? val : '';
            } else if (el.tagName === 'INPUT' && el.type !== 'radio' && el.type !== 'checkbox') {
              el.value = val != null ? val : '';
            }
          }
        });
      }
      
      // Custom callback after population
      if (opts.afterPopulate) opts.afterPopulate(data);
      
      // Disable all form inputs (except hidden)
      document.querySelectorAll('input, select, textarea').forEach(function(el) {
        if (el.type !== 'hidden') el.disabled = true;
      });
      
      // Hide submit/reset buttons
      document.querySelectorAll('.form-actions, button[type="submit"], .btn-primary, .btn-secondary, #submitBtn, .reset-btn, [onclick*="resetForm"]').forEach(function(el) {
        el.style.display = 'none';
      });
      
      // Add view-mode header with back and print buttons
      var existingHeader = document.querySelector('.view-mode-header');
      if (!existingHeader) {
        var header = document.createElement('div');
        header.className = 'view-mode-header';
        header.style.cssText = 'display:flex;justify-content:space-between;align-items:center;padding:12px 24px;background:#f8f9fa;border-bottom:2px solid #dee2e6;position:sticky;top:0;z-index:1000';
        header.innerHTML = '<div style="display:flex;align-items:center;gap:12px"><span style="font-size:20px">\uD83D\uDCC4</span><span style="font-weight:600;color:#333;font-size:15px">Viewing Record</span><span style="font-size:12px;color:#888;background:#e9ecef;padding:2px 10px;border-radius:10px">Read Only</span></div><div style="display:flex;gap:8px"><button class="view-mode-print" style="padding:8px 18px;background:#333;color:white;border:none;border-radius:6px;cursor:pointer;font-size:13px;font-weight:600">\uD83D\uDDA8\uFE0F Print</button><button class="view-mode-back" style="padding:8px 18px;background:white;color:#333;border:1px solid #ddd;border-radius:6px;cursor:pointer;font-size:13px;font-weight:600">\u2190 Back</button></div>';
        
        header.querySelector('.view-mode-print').addEventListener('click', function() { window.print(); });
        header.querySelector('.view-mode-back').addEventListener('click', function() { window.history.back(); });
        
        var navbars = document.querySelectorAll('.navbar');
        if (navbars.length > 0) {
          navbars[0].parentNode.insertBefore(header, navbars[0]);
        } else {
          document.body.insertBefore(header, document.body.firstChild);
        }
      }
      
      // Add print CSS
      if (!document.getElementById('view-mode-print-styles')) {
        var ps = document.createElement('style');
        ps.id = 'view-mode-print-styles';
        ps.textContent = '@media print { .view-mode-header, .navbar, .logout-btn, .user-info, .form-actions { display:none !important; } body { background:white !important; } }';
        document.head.appendChild(ps);
      }
      
      // Hide navigation/header elements
      var navbars = document.querySelectorAll('.navbar');
      navbars.forEach(function(n) { n.style.display = 'none'; });
      
    } catch(e) {
      console.error('initViewMode error:', e);
    }
  };

})();
