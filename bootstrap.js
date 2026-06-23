/* ─── OSH Bootstrap — Centralized Global Validation ───
 * Load this FIRST on every page, before any other scripts.
 * It validates that all expected globals exist and provides
 * a check() method for runtime validation.
 * NOTE: Does NOT create stubs — just reports, so real scripts
 * can define their globals naturally without conflicts.
 ─────────────────────────────────────────────────────────────── */

(function () {
  'use strict';

  var VERSION = '1.0.1';

  var DEPENDENCIES = [
    { name: 'supabaseClient',          source: 'supabase-config.js', critical: true },
    { name: 'OSH_CONSTANTS',           source: 'constants.js',       critical: true },
    { name: 'ROLES',                   source: 'role-permissions.js',critical: true },
    { name: 'RolePermissions',         source: 'role-permissions.js',critical: true },

    { name: 'initializeRoleSystem',    source: 'role-permissions.js',critical: true },
    { name: 'showPermissionDenied',    source: 'role-permissions.js',critical: true },
    { name: 'checkPageAccess',         source: 'role-permissions.js',critical: true },
    { name: 'canEditClaims',           source: 'role-permissions.js'},
    { name: 'switchRole',              source: 'role-permissions.js'},
    { name: 'clearRoleOverride',       source: 'role-permissions.js'},
    { name: 'hasRoleOverride',         source: 'role-permissions.js'},
    { name: 'enrichProfileWithCompanyName', source: 'role-permissions.js'},
    { name: 'applyNavVisibility',      source: 'role-permissions.js'},
    { name: 'getCachedUserProfile',    source: 'role-permissions.js'},
    { name: 'cacheUserProfile',        source: 'role-permissions.js'},
    { name: 'getCurrentUser',          source: 'role-permissions.js'},
    { name: 'getCurrentUserRole',      source: 'role-permissions.js'},
    { name: 'currentUserRole',         source: 'role-permissions.js', critical: true },
    { name: 'handleLogout',            source: 'common.js',          critical: true },
    { name: 'fmtDate',                 source: 'common.js'},
    { name: 'esc',                     source: 'common.js'},
    { name: 'autoFillCompanyFields',   source: 'common.js'},
    { name: 'showAlert',               source: 'common.js'},
    { name: 'toggleRoleSwitcher',      source: 'header.js'},
    { name: 'OSH_ROLE_CONFIG',         source: 'role-config.js',     critical: true }
  ];

  var missingCritical = [];
  var missingAll = [];

  DEPENDENCIES.forEach(function (dep) {
    var exists = (dep.name in window);
    if (!exists) {
      missingAll.push(dep);
      if (dep.critical) missingCritical.push(dep);
    }
  });

  if (missingAll.length > 0) {
    console.log('[bootstrap] ' + missingAll.length + ' deps pending at startup: ' + missingAll.map(function(d){return d.name}).join(', '));
  }

  window.OSH = window.OSH || {};
  window.OSH.bootstrap = {
    version: VERSION,
    missing: missingAll,
    missingCritical: missingCritical,
    ready: function (fn) {
      if (document.readyState !== 'loading') setTimeout(fn, 1);
      else document.addEventListener('DOMContentLoaded', fn);
    },
    check: function () {
      var m = [];
      DEPENDENCIES.forEach(function(d){if(!(d.name in window))m.push(d);});
      return { ok: m.length === 0, missing: m };
    }
  };

  console.log('[bootstrap] v' + VERSION + ' loaded — ' + (missingAll.length ? missingAll.length + ' pending' : 'all OK'));
})();
