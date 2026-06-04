// ============================================
// SHARED UTILITY FUNCTIONS
// Include this script on every page after modal.js
// ============================================

// Format date to dd Mon yyyy (e.g. "14 Mar 2026")
function fmtDate(d) {
    if (!d) return '\u2014';
    return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' });
}

// Escape HTML special characters
function esc(s) {
    if (s == null) return '';
    return String(s)
        .replace(/&/g,'&amp;').replace(/</g,'&lt;')
        .replace(/>/g,'&gt;').replace(/"/g,'&quot;')
        .replace(/'/g,'&#39;');
}

// Universal logout handler (requires modal.js and supabase-config.js)
async function handleLogout() {
    const ok = await showConfirm('You will be signed out of the OSH system.', {
        title: 'Logout', icon: '\uD83D\uDC4B', confirmText: 'Logout', cancelText: 'Stay'
    });
    if (ok) {
        const r = await signOut();
        if (r.success) window.location.href = 'index.html';
        else await showAlert('Logout failed: ' + r.error, { type: 'error' });
    }
}

console.log('Common utilities loaded');
