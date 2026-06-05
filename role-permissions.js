// ============================================
// ROLE-BASED PERMISSIONS HANDLER
// ============================================

const ROLES = {
    VIEWER: 'viewer',
    WORKER: 'worker',
    OFFICER: 'officer',
    ADMIN: 'admin',
    SUPER_ADMIN: 'super_admin',
    COMPANY: 'company'
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
    }
};

// Current user role (will be set on page load)
let currentUserRole = null;
let currentUserId = null;

// Initialize role system
async function initializeRoleSystem() {
    try {
        const userResult = await getCurrentUser();
        if (!userResult.success || !userResult.user) {
            console.error('No user logged in');
            return false;
        }

        currentUserId = userResult.user.id;

        const profileResult = await getUserProfile(currentUserId);
        if (profileResult.success && profileResult.data) {
            currentUserRole = profileResult.data.role || 'viewer';
            console.log('User role:', currentUserRole);
            
            // Update UI based on role
            updateUIForRole();
            return true;
        }
        return false;
    } catch (error) {
        console.error('Error initializing role system:', error);
        return false;
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

// Add role badge to navbar
function addRoleBadge() {
    const roleNames = {
        viewer: 'Viewer',
        worker: 'Worker',
        officer: 'Officer',
        admin: 'Admin',
        super_admin: 'Super Admin',
        company: 'Company'
    };

    const roleBadgeHTML = `
        <span style="
            background: #f0f0f0;
            color: #666;
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
            margin-left: 10px;
        ">${roleNames[currentUserRole] || 'User'}</span>
    `;

    const userNameElements = document.querySelectorAll('.user-name');
    userNameElements.forEach(element => {
        if (!element.querySelector('span[style*="border-radius: 12px"]')) {
            element.insertAdjacentHTML('beforeend', roleBadgeHTML);
        }
    });
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

// Hide nav items based on role
function applyNavVisibility() {
    if (!currentUserRole) return;
    document.querySelectorAll('.osh-nav-item[data-hide-for]').forEach(item => {
        const hideForRoles = (item.dataset.hideFor || '').split(',').map(r => r.trim());
        if (hideForRoles.includes(currentUserRole)) {
            item.style.display = 'none';
        } else {
            item.style.display = '';
        }
    });
}

// Check if the current user is a company account
function isCompanyUser() {
    return currentUserRole === 'company';
}

// Get the company name from the user's profile (for company users)
// Uses the provided supabase client, or falls back to a global one
window.getUserCompanyName = async function(supabaseClient) {
    try {
        const userResult = await getCurrentUser();
        if (!userResult.success || !userResult.user) return null;

        const profileResult = await getUserProfile(userResult.user.id);
        if (!profileResult.success || !profileResult.data) return null;

        const profile = profileResult.data;

        // If user has a company_id, look up the company name
        if (profile.company_id && profile.role === 'company') {
            // Accept a passed client, or use window.SB (set by company-register.html), or create a fresh one
            const sb = supabaseClient || window.SB || null;
            if (!sb) return null;

            const { data } = await sb
                .from('companies')
                .select('company_name')
                .eq('id', profile.company_id)
                .maybeSingle();

            if (data) return data.company_name;
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
        company: 'Company'
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
        company: '#cce5ff'
    };
    return colors[role] || '#f8f9fa';
}

// Check if current page should be accessible
function checkPageAccess() {
    const currentPage = window.location.pathname.split('/').pop();
    
    // Admin page requires admin or super_admin role
    if (currentPage === 'admin.html' && !canAccessAdmin()) {
        alert('Access Denied\n\nYou do not have permission to access the admin panel.');
        window.location.href = 'Untitled-1.html';
        return false;
    }

    // Form page requires officer or higher
    if (currentPage === 'form.html' && !canSubmitClaims()) {
        alert('Access Denied\n\nYou do not have permission to submit claims.');
        window.location.href = 'Untitled-1.html';
        return false;
    }

    return true;
}

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
        getCurrentUserId: () => currentUserId
    };
}

console.log('Role permissions system loaded');
