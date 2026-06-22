(function () {
  "use strict";

// ============================================================
// ROLE-BASED PERMISSIONS HANDLER
// Depends on: supabase-config.js, constants.js
// ============================================================
(function () {
  'use strict';

  // ── Re-export constants for convenience ─────────────────
  var C = window.OSH_CONSTANTS;
  if (!C) {
    console.error('constants.js must be loaded before role-permissions.js');
    return;
  }

  var ROLES = C.ROLES;
  var PERMISSIONS = C.PERMISSIONS;

  // Current user role (will be set on page load)
  var currentUserRole = null;
  var currentUserId = null;

  // ── Dev role override ────────────────────────────────────
  var DEV_ROLE_KEY = 'dev_role_override';

  window.switchRole = function(role) {
    if (!role) return;
    sessionStorage.setItem(DEV_ROLE_KEY, role);
    window.location.reload();
  };

  window.clearRoleOverride = function() {
    sessionStorage.removeItem(DEV_ROLE_KEY);
    window.location.reload();
  };

  window.hasRoleOverride = function() {
    try {
      return !!sessionStorage.getItem(DEV_ROLE_KEY);
    } catch (e) { return false; }
  };

  function getEffectiveRole(realRole) {
    try {
      var override = sessionStorage.getItem(DEV_ROLE_KEY);
      if (override && C.isValidRole(override)) {
        return override;
      }
    } catch (e) {}
    return realRole;
  }

  // ── Initialize role system ─────────────────────────────
  async function initializeRoleSystem() {
    try {
      var cached = window.getCachedUserProfile ? window.getCachedUserProfile() : null;
      if (cached && cached.user_id && cached.role) {
        currentUserId = cached.user_id;
        currentUserRole = getEffectiveRole(cached.role);
        if (currentUserRole === 'super_admin') {
          var el = document.getElementById('userRoleContainer');
          if (el) el.style.display = '';
        }
        updateHeaderDisplay(cached);
        updateUIForRole();
        setTimeout(function() { refreshUserProfileInBackground(); }, 100);
        return true;
      }

      var userResult = await getCurrentUser();
      if (!userResult.success || !userResult.user) {
        return false;
      }

      currentUserId = userResult.user.id;

      var profileResult = await getUserProfile(currentUserId);
      if (profileResult.success && profileResult.data) {
        currentUserRole = getEffectiveRole(profileResult.data.role || 'viewer');
        if (currentUserRole === 'super_admin') {
          var el = document.getElementById('userRoleContainer');
          if (el) el.style.display = '';
        }

        await enrichProfileWithCompanyName(profileResult.data);

        if (window.cacheUserProfile) {
          window.cacheUserProfile(profileResult.data);
        }

        updateHeaderDisplay(profileResult.data);
        updateUIForRole();
        return true;
      }
      return false;
    } catch (error) {
      console.error('Error initializing role system:', error);
      return false;
    }
  }

  // ── Header display ─────────────────────────────────────
  function updateHeaderDisplay(profile) {
    if (!profile) return;
    var nameEl = document.getElementById('userName');
    var desigEl = document.getElementById('userDesignation');
    var fullName = (profile.first_name + ' ' + profile.surname).trim();

    if (profile.role === 'company') {
      if (nameEl) {
        nameEl.textContent = profile.company_name || fullName || 'Company';
      }
      if (desigEl) {
        desigEl.textContent = '';
        desigEl.style.display = 'none';
      }
    } else {
      if (nameEl && fullName) {
        nameEl.textContent = fullName;
      }
      if (desigEl) {
        desigEl.style.display = '';
        desigEl.textContent = profile.designation || '';
      }
    }
  }

  // ── Company name enrichment ────────────────────────────
  function isValidUUID(str) {
    if (typeof str !== 'string') return false;
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str.trim());
  }

  async function enrichProfileWithCompanyName(profile) {
    if (!profile || profile.role !== 'company' || !profile.company_id) return profile;
    if (profile.company_name) return profile;
    try {
      var sb = window.supabaseClient;
      if (!sb) return profile;

      var companyId = ('' + profile.company_id).trim();
      if (!isValidUUID(companyId)) {
        console.warn('Invalid company_id format:', profile.company_id);
        return profile;
      }

      var result = await sb
        .from('companies')
        .select('company_name')
        .eq('id', companyId)
        .maybeSingle();

      if (result.error) {
        console.warn('Failed to enrich company name:', result.error);
        return profile;
      }
      if (result.data) {
        profile.company_name = result.data.company_name;
      }
    } catch (e) {
      console.warn('Error enriching company name:', e);
    }
    return profile;
  }

  window.enrichProfileWithCompanyName = enrichProfileWithCompanyName;

  async function refreshUserProfileInBackground() {
    try {
      var userResult = await getCurrentUser();
      if (!userResult.success || !userResult.user) return;
      var profileResult = await getUserProfile(userResult.user.id);
      if (profileResult.success && profileResult.data) {
        await enrichProfileWithCompanyName(profileResult.data);
        var effective = getEffectiveRole(profileResult.data.role);
        if (effective !== currentUserRole) {
          currentUserRole = effective;
          updateUIForRole();
        }
        if (window.cacheUserProfile) {
          window.cacheUserProfile(profileResult.data);
        }
        if (effective === 'company' && profileResult.data.company_name) {
          updateHeaderDisplay(profileResult.data);
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  // ── Permission checks ─────────────────────────────────
  function hasPermission(permission) {
    if (!currentUserRole) return false;
    return PERMISSIONS[currentUserRole] && PERMISSIONS[currentUserRole][permission] === true;
  }

  function canAccessAdmin() { return hasPermission('access_admin'); }
  function canSubmitClaims() { return hasPermission('submit_claims'); }

  function canEditClaims(claimOwnerId) {
    if (!hasPermission('edit_claims')) return false;
    if (currentUserRole === ROLES.OFFICER) {
      return claimOwnerId === currentUserId;
    }
    return true;
  }

  function canManageUsers(targetUserRole) {
    if (!hasPermission('manage_users')) return false;
    if (currentUserRole === ROLES.ADMIN && targetUserRole === ROLES.SUPER_ADMIN) {
      return false;
    }
    return true;
  }

  function canEditUser(targetUserId, targetUserRole) {
    if (targetUserId === currentUserId) return true;
    return canManageUsers(targetUserRole);
  }

  // ── UI updates ────────────────────────────────────────
  function applyNavVisibility() {
    // Nav visibility handled by updateUIForRole() for specific links
    // and by the nav.js configuration system
  }

  function updateUIForRole() {
    document.querySelectorAll('[href="admin.html"], [onclick*="admin.html"]').forEach(function(link) {
      link.style.display = canAccessAdmin() ? '' : 'none';
    });

    document.querySelectorAll('[href="form.html"], [onclick*="form.html"]').forEach(function(button) {
      if (canSubmitClaims()) {
        button.style.display = '';
      } else {
        button.style.display = 'none';
        button.disabled = true;
      }
    });

    addRoleBadge();
    applyNavVisibility();
  }

  function addRoleBadge() {
    var el = document.getElementById('userRoleBadge');
    if (el && currentUserRole) {
      el.textContent = C.getRoleDisplayName(currentUserRole);
    }
  }

  function enforcePermissions() {
    if (currentUserRole === ROLES.VIEWER) {
      document.querySelectorAll('.action-btn, button[onclick*="edit"], button[onclick*="update"]').forEach(function(button) {
        var txt = button.textContent.toLowerCase();
        if (txt.indexOf('edit') >= 0 || txt.indexOf('update') >= 0 || txt.indexOf('status') >= 0) {
          button.disabled = true;
          button.style.opacity = '0.5';
          button.style.cursor = 'not-allowed';
          }
        });
      }
    }

  function showPermissionDenied(action) {
    if (typeof window.showAlert === "function") {
      window.showAlert("Access denied. You do not have permission to " + action + ".", { type: "error", title: "Permission Denied" });
    } else {
      alert("Access denied. You do not have permission to " + action + ".");
    }
  }

  function setUserNameSafely(name) {
    var el = document.getElementById("userName");
    if (el && name) {
      el.textContent = name;
    }
  }

  function checkPageAccess() {
    if (!currentUserRole) {
      window.location.href = "index.html";
      return false;
    }
    return true;
  }

  window.RolePermissions = {
    ROLES: ROLES, PERMISSIONS: PERMISSIONS,
    initializeRoleSystem: initializeRoleSystem,
    hasPermission: hasPermission, canAccessAdmin: canAccessAdmin, canSubmitClaims: canSubmitClaims,
    canEditClaims: canEditClaims, canManageUsers: canManageUsers, canEditUser: canEditUser,
    updateUIForRole: updateUIForRole, enforcePermissions: enforcePermissions,
    showPermissionDenied: showPermissionDenied,
    getRoleDisplayName: C.getRoleDisplayName, getRoleColor: C.getRoleColor,
    checkPageAccess: checkPageAccess,
    getCurrentUserRole: function() { return currentUserRole; },
    getCurrentUserId: function() { return currentUserId; },
    ALL_ROLES: C.ALL_ROLES
  };

  // Expose critical functions globally for HTML pages
  window.initializeRoleSystem = initializeRoleSystem;
  window.showPermissionDenied = showPermissionDenied;
  window.checkPageAccess = checkPageAccess;
  window.canEditClaims = canEditClaims;
  window.canManageUsers = canManageUsers;
  window.enforcePermissions = enforcePermissions;
  window.setUserNameSafely = setUserNameSafely;
  window.getRoleDisplayName = C.getRoleDisplayName;

  })();

})();
