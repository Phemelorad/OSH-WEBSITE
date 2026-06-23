/* ─── OSH Bootstrap — Centralized Global Validation & Stubs ───
 * Load this FIRST on every page, before any other scripts.
 * It validates that all expected globals exist and provides
 * graceful fallbacks so pages don't crash with cryptic errors.
 ─────────────────────────────────────────────────────────────── */

(function () {
  'use strict';

  var VERSION = '1.0.0';

  var DEPENDENCIES = [
    { name: 'supabaseClient',          source: 'supabase-config.js', critical: true },
    { name: 'OSH_CONSTANTS',           source: 'constants.js',       critical: true },
    { name: 'ROLES',                   source: 'role-permissions.js',critical: true },
    { name: 'RolePermissions',         source: 'role-permissions.js',critical: true },
    { name: 'rolePermissions',         source: 'role-permissions.js',critical: true },
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
    { name: 'currentUserRole',         source: 'role-permissions.js'},
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
      if (dep.name === 'currentUserRole') {
        if (!('currentUserRole' in window)) {
          var warned = false;
          Object.defineProperty(window, 'currentUserRole', {
            get: function () {
              if (!warned) { console.warn('[bootstrap] currentUserRole accessed but not yet set'); warned = true; }
              return null;
            },
            set: function (v) { Object.defineProperty(window, 'currentUserRole', { value: v, writable: true, configurable: true }); },
            configurable: true
          });
        }
      } else {
        var warned = false;
        window[dep.name] = function () {
          if (!warned) { console.warn('[bootstrap] ' + dep.name + '() called — not yet defined (from ' + dep.source + ')'); warned = true; }
        };
      }
    }
  });

  if (missingCritical.length > 0) {
    console.error('[bootstrap] CRITICAL missing: ' + missingCritical.map(function(d){return d.name+' ('+d.source+')'}).join(', '));
  } else if (missingAll.length > 0) {
    console.warn('[bootstrap] ' + missingAll.length + ' stubs created: ' + missingAll.map(function(d){return d.name}).join(', '));
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

  console.log('[bootstrap] loaded — ' + (missingAll.length ? missingAll.length + ' stubs' : 'all OK'));
})();
