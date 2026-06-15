// ============================================
// ROLE-BASED PERMISSIONS HANDLER
// ============================================

const ROLES = {
    VIEWER: 'viewer',
    WORKER: 'worker',
    OFFICER: 'officer',
    ADMIN: 'admin',
    SUPER_ADMIN: 'super_admin',
    COMPANY: 'company',
    MEDICAL_PRACTITIONER: 'medical_practitioner'
};

const PERMISSIONS = {
    viewer: {
        view_claims: true,
        submit_claims: false,
        edit_claims: false,
        access_admin: false,
        manage_users: false
    },
    worker: {
        view_claims: true,
        submit_claims: false,
        edit_claims: false,
        access_admin: false,
        manage_users: false
    },
    officer: {
        view_claims: true,
        submit_claims: true,
        edit_claims: true,
        edit_own_only: true,
        access_admin: false,
        manage_users: false
    },
    admin: {
        view_claims: true,
        submit_claims: true,
        edit_claims: true,
        access_admin: true,
        manage_users: true,
        manage_super_admins: false
    },
    super_admin: {
        view_claims: true,
        submit_claims: true,
        edit_claims: true,
        access_admin: true,
        manage_users: true,
        manage_super_admins: true
    },
    company: {
        view_claims: true,
        submit_claims: false,
        edit_claims: false,
        access_admin: false,
        manage_users: false
    },
    medical_practitioner: {
        view_claims: true,
        submit_claims: false,
        edit_claims: false,
        access_admin: false,
        manage_users: false,
        submit_medical_exams: true
    }
};

// Current user role (will be set on page load)
let currentUserRole = null;
let currentUserId = null;

// ── Dev role override ──────────────────────────────────────
// Allows a developer to quickly test different roles using a single account.
// Stores the desired role in sessionStorage; cleared on logout.
const DEV_ROLE_KEY = 'dev_role_override';

// Switch to a different role (dev/testing only — no database changes)
// Sets the override in sessionStorage and reloads the page.
window.switchRole = function(role) {
    if (!role) return;
    sessionStorage.setItem(DEV_ROLE_KEY, role);
    window.location.reload();
};

// Clear the dev role override and reload to the user's real role
window.clearRoleOverride = function() {
    sessionStorage.removeItem(DEV_ROLE_KEY);
    window.location.reload();
};

// Check if a dev role override is active
window.hasRoleOverride = function() {
    try {
        return !!sessionStorage.getItem(DEV_ROLE_KEY);
    } catch (e) { return false; }
};

// Get the current effective role (considering any dev override)
function getEffectiveRole(realRole) {
    try {
        const override = sessionStorage.getItem(DEV_ROLE_KEY);
        if (override && ['viewer','worker','officer','admin','super_admin','company','medical_practitioner'].includes(override)) {

            return override;
        }
    } catch (e) {}
    return realRole;
}

// Initialize role system — reads from sessionStorage cache first for instant load
async function initializeRoleSystem() {
    try {
        // ── Try cache first (synchronous — no lag) ────────────
        const cached = window.getCachedUserProfile ? window.getCachedUserProfile() : null;
        if (cached && cached.user_id && cached.role) {
            currentUserId = cached.user_id;
            currentUserRole = getEffectiveRole(cached.role);
    if (currentUserRole === 'super_admin') {
      var el = document.getElementById('userRoleContainer');
      if (el) el.style.display = '';
    }
        

            updateHeaderDisplay(cached);
            updateUIForRole();
            // Refresh cache in background (don't block UI)
            setTimeout(() => refreshUserProfileInBackground(), 100);
            return true;
        }

        // ── Fallback to API calls ────────────────────────────
        const userResult = await getCurrentUser();
        if (!userResult.success || !userResult.user) {
            return false;
        }

        currentUserId = userResult.user.id;

        const profileResult = await getUserProfile(currentUserId);
        if (profileResult.success && profileResult.data) {
            currentUserRole = getEffectiveRole(profileResult.data.role || 'viewer');
    if (currentUserRole === 'super_admin') {
      var el = document.getElementById('userRoleContainer');
      if (el) el.style.display = '';
    }


            // Enrich with company name for company users
            await enrichProfileWithCompanyName(profileResult.data);

            // Cache for next page load
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

// Populate header display from profile data (name, role badge, designation)
// For company users, Row 1 shows the company name and Row 2 shows the person's name.
// For other roles, Row 1 shows the person's name and Row 2 shows their designation (if any).
// NOTE: #userName is a <span> sibling of #userRoleBadge — page scripts can safely
// set userName.textContent without destroying the badge element.
function updateHeaderDisplay(profile) {
    if (!profile) return;
    const nameEl = document.getElementById('userName');
    const desigEl = document.getElementById('userDesignation');

    const fullName = (profile.first_name + ' ' + profile.surname).trim();

    if (profile.role === 'company') {
        // Row 1: Company name only — hide designation row to avoid empty gap
        if (nameEl) {
            nameEl.textContent = profile.company_name || fullName || 'Company';
        }
        if (desigEl) {
            desigEl.textContent = '';
            desigEl.style.display = 'none';
        }
    } else {
        // Row 1: Person's name, Row 2: Designation (if any)
        if (nameEl && fullName) {
            nameEl.textContent = fullName;
        }
        if (desigEl) {
            desigEl.style.display = ''; // ensure visible
            if (profile.designation) {
                desigEl.textContent = profile.designation;
            } else {
                desigEl.textContent = '';
            }
        }
    }
}

// ── Enrich a profile with company_name (from companies table) ──
// Company users have company_id in user_profiles, but the actual
// company_name lives in the companies table. This helper fetches
// it and attaches it so the header can display it.

// Check if a string is a valid UUID (v4 or v7 format)
function isValidUUID(str) {
    if (typeof str !== 'string') return false;
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str.trim());
}

async function enrichProfileWithCompanyName(profile) {
    if (!profile || profile.role !== 'company' || !profile.company_id) return profile;
    if (profile.company_name) return profile; // Already enriched
    try {
        const sb = window.supabaseClient;
        if (!sb) return profile;

        const companyId = ('' + profile.company_id).trim();
        if (!isValidUUID(companyId)) {
            console.warn('Invalid company_id format in profile:', profile.company_id);
            return profile;
        }

        const { data, error } = await sb
            .from('companies')
            .select('company_name')
            .eq('id', companyId)
            .maybeSingle();

        if (error) {
            console.warn('Failed to enrich company name:', error);
            return profile;
        }
        if (data) {
            profile.company_name = data.company_name;
        }
    } catch (e) {
        console.warn('Error enriching company name:', e);
    }
    return profile;
}

// Expose so supabase-config.js's signIn() can also use it
window.enrichProfileWithCompanyName = enrichProfileWithCompanyName;

// Background refresh: fetch latest profile and update cache
async function refreshUserProfileInBackground() {
    try {
        const userResult = await getCurrentUser();
        if (!userResult.success || !userResult.user) return;
        const profileResult = await getUserProfile(userResult.user.id);
        if (profileResult.success && profileResult.data) {
            // Enrich with company name for company users
            await enrichProfileWithCompanyName(profileResult.data);

            // Respect dev role override — use effective role
            const effective = getEffectiveRole(profileResult.data.role);
            if (effective !== currentUserRole) {
                currentUserRole = effective;
                updateUIForRole();
            }
            if (window.cacheUserProfile) {
                window.cacheUserProfile(profileResult.data);
            }

            // Re-apply header for company users (enrichment may just have fetched company_name)
            if (effective === 'company' && profileResult.data.company_name) {
                updateHeaderDisplay(profileResult.data);
            }


        }
    } catch (e) {
        // Silently fail — cache will refresh on next page load
    }
}

// Check if user has specific permission
function hasPermission(permission) {
    if (!currentUserRole) return false;
    return PERMISSIONS[currentUserRole]?.[permission] || false;
}

// Check if user can access admin panel
function canAccessAdmin() {
    return hasPermission('access_admin');
}

// Check if user can submit claims
function canSubmitClaims() {
    return hasPermission('submit_claims');
}

// Check if user can edit claims
function canEditClaims(claimOwnerId = null) {
    if (!hasPermission('edit_claims')) return false;
    
    // Officers can only edit their own claims
    if (currentUserRole === ROLES.OFFICER) {
        return claimOwnerId === currentUserId;
    }
    
    // Admins and super admins can edit any claim
    return true;
}

// Check if user can manage other users
function canManageUsers(targetUserRole = null) {
    if (!hasPermission('manage_users')) return false;
    
    // Admins cannot manage super admins
    if (currentUserRole === ROLES.ADMIN && targetUserRole === ROLES.SUPER_ADMIN) {
        return false;
    }
    
    return true;
}

// Check if user can edit another user's profile
function canEditUser(targetUserId, targetUserRole) {
    // Users can always edit their own profile (except role)
    if (targetUserId === currentUserId) return true;
    
    // Check if user has permission to manage other users
    return canManageUsers(targetUserRole);
}

// Update UI based on user role
function updateUIForRole() {
    // Hide/show admin panel link
    const adminLinks = document.querySelectorAll('[href="admin.html"], [onclick*="admin.html"]');
    adminLinks.forEach(link => {
        if (canAccessAdmin()) {
            link.style.display = '';
        } else {
            link.style.display = 'none';
        }
    });

    // Hide/show submit claim button
    const submitButtons = document.querySelectorAll('[href="form.html"], [onclick*="form.html"]');
    submitButtons.forEach(button => {
        if (canSubmitClaims()) {
            button.style.display = '';
        } else {
            button.style.display = 'none';
            button.disabled = true;
        }
    });

    // Add role badge to UI
    addRoleBadge();

    // Apply nav visibility based on role
    applyNavVisibility();
}

// Add role badge to navbar — refreshes the badge text
function addRoleBadge() {
    const el = document.getElementById('userRoleBadge');
    if (el && currentUserRole) {
        el.textContent = getRoleDisplayName(currentUserRole);
    }
}

// Disable elements based on permissions
function enforcePermissions() {
    // Disable edit buttons for viewers
    if (currentUserRole === ROLES.VIEWER) {
        const editButtons = document.querySelectorAll('.action-btn, button[onclick*="edit"], button[onclick*="update"]');
        editButtons.forEach(button => {
            if (button.textContent.toLowerCase().includes('edit') || 
                button.textContent.toLowerCase().includes('update') ||
                button.textContent.toLowerCase().includes('status')) {
                button.disabled = true;
                button.style.opacity = '0.5';
                button.style.cursor = 'not-allowed';
                button.title = 'You do not have permission to edit';
            }
        });
    }

    // Disable form submission for viewers
    if (!canSubmitClaims()) {
        const forms = document.querySelectorAll('form');
        forms.forEach(form => {
            const submitBtn = form.querySelector('button[type="submit"]');
            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.style.opacity = '0.5';
                submitBtn.title = 'You do not have permission to submit claims';
            }
        });
    }
}

// Hide nav items based on role, then reveal nav
function applyNavVisibility() {
    if (currentUserRole) {
        document.querySelectorAll('.osh-nav-item[data-hide-for]').forEach(item => {
            const hideForRoles = (item.dataset.hideFor || '').split(',').map(r => r.trim());
            if (hideForRoles.includes(currentUserRole)) {
                item.style.display = 'none';
            } else {
                item.style.display = '';
            }
        });
    }
    // Always reveal nav — even if role is unknown (error fallback)
    document.querySelector('.osh-nav')?.classList.remove('osh-nav-loading');
}

// Check if the current user is a company account
function isCompanyUser() {
    return currentUserRole === 'company';
}

// Cached company name key
const COMPANY_NAME_CACHE_KEY = 'osh_company_name';

// Get the company name from the user's profile (for company users)
// Uses the provided supabase client, or falls back to a global one
window.getUserCompanyName = async function(supabaseClient) {
    try {
        const userResult = await getCurrentUser();
        if (!userResult.success || !userResult.user) return null;

        const userId = userResult.user.id;

        // Check cache only if it belongs to THIS user (prevents cross-user data leak)
        try {
            const cachedRaw = sessionStorage.getItem(COMPANY_NAME_CACHE_KEY);
            if (cachedRaw) {
                const cached = JSON.parse(cachedRaw);
                if (cached.userId === userId && cached.companyName) {
                    return cached.companyName;
                }
            }
        } catch (e) {}

        // Check if we have a cached profile with company_name (only if for this user)
        const cached = window.getCachedUserProfile ? window.getCachedUserProfile() : null;
        if (cached && cached.company_name && cached.user_id === userId) {
            try {
                sessionStorage.setItem(COMPANY_NAME_CACHE_KEY, JSON.stringify({
                    userId: userId,
                    companyName: cached.company_name
                }));
            } catch (e) {}
            return cached.company_name;
        }

        const profileResult = await getUserProfile(userId);
        if (!profileResult.success || !profileResult.data) return null;

        const profile = profileResult.data;

        // If user has a company_id, look up the company name
        if (profile.company_id && profile.role === 'company') {
            const sb = supabaseClient || window.SB || null;
            if (!sb) return null;

            const companyId = ('' + profile.company_id).trim();
            if (!isValidUUID(companyId)) {
                console.warn('Invalid company_id format in getUserCompanyName:', profile.company_id);
                return null;
            }

            const { data, error } = await sb
                .from('companies')
                .select('company_name')
                .eq('id', companyId)
                .maybeSingle();

            if (error) {
                console.warn('Failed to look up company name:', error);
                return null;
            }
            if (data) {
                // Cache for subsequent calls — scoped to user ID
                try {
                    sessionStorage.setItem(COMPANY_NAME_CACHE_KEY, JSON.stringify({
                        userId: userId,
                        companyName: data.company_name
                    }));
                } catch (e) {}
                return data.company_name;
            }
        }
        return null;
    } catch (e) {
        console.warn('Could not get company name:', e);
        return null;
    }
};

// Show permission denied message
function showPermissionDenied(action = 'perform this action') {
    alert(`Permission Denied\n\nYou do not have permission to ${action}.\n\nYour role: ${currentUserRole}\nRequired: officer or higher`);
}

// Get role display name
function getRoleDisplayName(role) {
    const names = {
        viewer: 'Viewer',
        worker: 'Worker',
        officer: 'Officer',
        admin: 'Admin',
        super_admin: 'Super Admin',
        company: 'Employer',
        medical_practitioner: 'Medical Practitioner'
    };
    return names[role] || role;
}

// Get role color for badges
function getRoleColor(role) {
    const colors = {
        viewer: '#e2e3e5',
        worker: '#cce5ff',
        officer: '#d1ecf1',
        admin: '#fff3cd',
        super_admin: '#d4edda',
        company: '#cce5ff',
        medical_practitioner: '#e8d5f5'
    };
    return colors[role] || '#f8f9fa';
}

// Check if current page should be accessible
function checkPageAccess() {
    const currentPage = window.location.pathname.split('/').pop();
    
    // Admin page requires admin or super_admin role
    if (currentPage === 'admin.html' && !canAccessAdmin()) {
        alert('Access Denied\n\nYou do not have permission to access the admin panel.');
        window.location.href = 'dashboard.html';
        return false;
    }

    // Form page requires officer or higher
    if (currentPage === 'form.html' && !canSubmitClaims()) {
        alert('Access Denied\n\nYou do not have permission to submit claims.');
        window.location.href = 'dashboard.html';
        return false;
    }

    return true;
}

// All available roles for the dev switcher
const ALL_ROLES = ['viewer', 'worker', 'company', 'medical_practitioner', 'officer', 'admin', 'super_admin'];

// Export for use in other scripts
if (typeof window !== 'undefined') {
    window.RolePermissions = {
        ROLES,
        PERMISSIONS,
        initializeRoleSystem,
        hasPermission,
        canAccessAdmin,
        canSubmitClaims,
        canEditClaims,
        canManageUsers,
        canEditUser,
        updateUIForRole,
        enforcePermissions,
        showPermissionDenied,
        getRoleDisplayName,
        getRoleColor,
        checkPageAccess,
        getCurrentUserRole: () => currentUserRole,
        getCurrentUserId: () => currentUserId,
        ALL_ROLES
    };
}


// ── Header guard for company users ─────────────────────────
// Page scripts often overwrite #userName with the person's full name after
// updateHeaderDisplay() has already set it to the company name for company users.
// This guard uses a MutationObserver to watch for changes and correct them
// for company users — far more efficient than the previous setInterval polling.
//
// Root cause: page-specific scripts (e.g., admin.html, dashboard.html) run their
// own window.load handlers that set userName.textContent directly. The proper
// fix is to have those scripts call setUserNameSafely() instead, but the
// MutationObserver provides backwards compatibility without changing every page.
let _headerGuardObserver = null;
let _headerGuardFired = false;

function cleanupHeaderGuard() {
    if (_headerGuardObserver) {
        _headerGuardObserver.disconnect();
        _headerGuardObserver = null;
    }
}

/**
 * Safe way for page scripts to set the user name in the header.
 * For company users, preserves the company name (not the person's name).
 * For all other roles, sets the name as provided.
 *
 * Usage:  setUserNameSafely('John Doe');
 * Instead of:  document.getElementById('userName').textContent = 'John Doe';
 */
window.setUserNameSafely = function(name) {
    const nameEl = document.getElementById('userName');
    if (!nameEl) return;

    // For company users, always show company name, never the person's name
    if (currentUserRole === 'company') {
        const cached = (typeof window.getCachedUserProfile === 'function')
            ? window.getCachedUserProfile() : null;
        if (cached?.company_name) {
            nameEl.textContent = cached.company_name;
            return;
        }
    }

    nameEl.textContent = name;
};

// Set up a MutationObserver on #userName to catch overwrites by page scripts.
// More efficient than setInterval — only fires on actual DOM mutations.
// Self-destructs after the first correction (page scripts run once on load).
function setupHeaderGuard() {
    const nameEl = document.getElementById('userName');
    if (!nameEl) return;

    // Only needed for company users
    if (currentUserRole !== 'company') return;

    // Disconnect any previous observer
    cleanupHeaderGuard();

    _headerGuardFired = false;

    _headerGuardObserver = new MutationObserver(function() {
        // Guard: only fire once to avoid loops
        if (_headerGuardFired) return;

        const cached = (typeof window.getCachedUserProfile === 'function')
            ? window.getCachedUserProfile() : null;
        const companyName = cached?.company_name;
        if (!companyName || nameEl.textContent === companyName) return;

        // Restore the company name
        _headerGuardFired = true;
        nameEl.textContent = companyName;

        // Also hide the designation row for company users
        const desigEl = document.getElementById('userDesignation');
        if (desigEl) {
            desigEl.textContent = '';
            desigEl.style.display = 'none';
        }

        // Self-destruct — we only needed one correction
        cleanupHeaderGuard();
    });

    // Watch for text content and child node changes
    _headerGuardObserver.observe(nameEl, {
        characterData: true,
        childList: true,
        subtree: true
    });
}

// Start guard after page scripts have had a chance to run.
// Window.load fires after all resources are loaded, which is when
// page-specific scripts (dashboard, admin, etc.) set userName.textContent.
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        // Wait for window.load to ensure page scripts have executed
        window.addEventListener('load', function() {
            setTimeout(setupHeaderGuard, 200);
        });
    });
} else {
    setTimeout(setupHeaderGuard, 1500);
}
