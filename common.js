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

})();
