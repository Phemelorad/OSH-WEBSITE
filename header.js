// ============================================================
// SHARED SITE HEADER
// Include this BEFORE nav.js on every page.
// It replaces the existing .navbar div with a unified header
// containing the crest, page title, user info, and nav container.
// ============================================================

(function () {

  // ── Inject CSS once ──────────────────────────────────────
  if (!document.getElementById('osh-header-styles')) {
    const s = document.createElement('style');
    s.id = 'osh-header-styles';
    s.textContent = `
      .site-header {
        background: white;
        border-bottom: 1px solid #e0e0e0;
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
      }

      .header-top {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 14px 28px;
        gap: 16px;
        flex-wrap: wrap;
      }

      .header-brand {
        display: flex;
        align-items: center;
        gap: 16px;
        flex: 1;
        min-width: 200px;
      }

      .header-crest-img {
        width: 70px;
        height: 48px;
        object-fit: contain;
        display: block;
        flex-shrink: 0;
      }

      .header-titles {
        display: flex;
        flex-direction: column;
        gap: 2px;
      }

      .header-titles h1 {
        font-size: 17px;
        font-weight: 700;
        color: #222;
        line-height: 1.2;
        margin: 0;
      }

      .header-subtitle {
        font-size: 11px;
        color: #888;
        font-weight: 500;
        letter-spacing: 0.3px;
      }

      .header-right {
        display: flex;
        align-items: center;
        gap: 18px;
        flex-shrink: 0;
      }

      .header-user {
        display: flex;
        flex-direction: column;
        align-items: flex-end;
        gap: 4px;
      }

      .header-user-name {
        font-size: 14px;
        font-weight: 700;
        color: #222;
        line-height: 1.3;
      }

      .header-user-designation {
        font-size: 12px;
        color: #777;
        line-height: 1.3;
      }

      .header-user-role {
        line-height: 1;
      }

      .header-user-role .role-badge {
        display: inline-block;
        background: #e8e8e8;
        color: #555;
        padding: 3px 14px;
        border-radius: 12px;
        font-size: 11px;
        font-weight: 600;
        cursor: pointer;
        transition: background 0.15s;
        position: relative;
      }

      .header-user-role .role-badge:hover {
        background: #d5d5d5;
      }

      .header-user-role .role-badge.has-override {
        background: #d4edda;
        color: #155724;
        border: 1px solid #c3e6cb;
      }

      .header-logout {
        padding: 6px 18px;
        background: none;
        border: 1.5px solid #ddd;
        border-radius: 6px;
        font-size: 12px;
        font-weight: 600;
        color: #555;
        cursor: pointer;
        font-family: inherit;
        transition: all 0.2s;
        white-space: nowrap;
        margin-top: 2px;
      }

      .header-logout:hover {
        background: #f5f5f5;
        border-color: #bbb;
        color: #222;
      }

      .role-switcher {
        display: none;
        position: absolute;
        top: 100%;
        right: 0;
        min-width: 180px;
        background: white;
        border: 1px solid #e0e0e0;
        border-radius: 8px;
        box-shadow: 0 6px 20px rgba(0,0,0,0.12);
        z-index: 700;
        overflow: hidden;
        margin-top: 4px;
      }

      .role-switcher.open {
        display: block;
      }

      .role-switcher-item {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 10px 14px;
        font-size: 12px;
        font-weight: 500;
        color: #444;
        cursor: pointer;
        transition: background 0.12s;
        border-bottom: 1px solid #f5f5f5;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      }

      .role-switcher-item:last-child {
        border-bottom: none;
      }

      .role-switcher-item:hover {
        background: #f5f5f5;
      }

      .role-switcher-item.active {
        background: #f0f0f0;
        font-weight: 700;
        color: #111;
      }

      .role-switcher-item .rs-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        flex-shrink: 0;
        display: inline-block;
      }

      .role-switcher-divider {
        border: none;
        border-top: 1px solid #eee;
        margin: 0;
      }

      @media (max-width: 768px) {
        .header-top {
          padding: 12px 16px;
          flex-direction: column;
          align-items: flex-start;
          gap: 10px;
        }
        .header-brand {
          width: 100%;
        }
        .header-titles h1 { font-size: 15px; }
        .header-right {
          width: 100%;
          justify-content: space-between;
        }
        .header-user { align-items: flex-start; }
      }
    `;
    document.head.appendChild(s);
  }

  // ── Build the header ─────────────────────────────────────
  function buildHeader(pageTitle) {
    const header = document.createElement('header');
    header.className = 'site-header';

    header.innerHTML = `
      <div class="header-top">
        <div class="header-brand">
          <img src="Code-of-Arms-colour.png" alt="Coat of Arms" class="header-crest-img">
          <div class="header-titles">
            <h1>${pageTitle}</h1>
            <div class="header-subtitle">Ministry of Labour &amp; Home Affairs · Department of Occupational Health &amp; Safety</div>
          </div>
        </div>
        <div class="header-right">
          <div class="header-user">
            <div class="header-user-name" id="userName">Loading...</div>
            <div class="header-user-designation" id="userDesignation"></div>
            <div class="header-user-role">
              <span class="role-badge" id="userRoleBadge" onclick="toggleRoleSwitcher(event)">
                <div class="role-switcher" id="roleSwitcher"></div>
              </span>
            </div>
            <button class="header-logout" onclick="handleLogout()">Sign Out</button>
            <!-- Hidden fallback IDs for backward compatibility with page scripts -->
            <span id="userDept" style="display:none"></span>
            <span id="userDepartment" style="display:none"></span>
            <span id="userCompanyName" style="display:none"></span>
          </div>
        </div>
      </div>
    `;

    return header;
  }

  // ── Inject: replace .navbar with the new header ──────────
  function inject() {
    const navbar = document.querySelector('.navbar');
    if (!navbar) return;

    // Extract the page title from the existing navbar h1
    const titleEl = navbar.querySelector('h1');
    const pageTitle = titleEl ? titleEl.textContent.trim() : 'DOSH Management System';

    const header = buildHeader(pageTitle);
    navbar.replaceWith(header);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inject);
  } else {
    inject();
  }

  // ── Build role switcher dropdown contents ────────────────
  function buildRoleSwitcher() {
    const sw = document.getElementById('roleSwitcher');
    if (!sw) return;

    const roles = ['viewer', 'worker', 'company', 'medical_practitioner', 'officer', 'admin', 'super_admin'];
    const labels = {
      viewer: '👁 Viewer', worker: '👷 Worker', company: '🏢 Employer',
      medical_practitioner: '🩺 Medical Practitioner', officer: '👮 Officer',
      admin: '⚙ Admin', super_admin: '🔧 Super Admin'
    };
    const colors = {
      viewer: '#e2e3e5', worker: '#cce5ff', company: '#cce5ff',
      medical_practitioner: '#e8d5f5', officer: '#d1ecf1',
      admin: '#fff3cd', super_admin: '#d4edda'
    };

    let currentRole = '';
    try {
      // Use the exported getter (let doesn't create window property)
      if (window.RolePermissions?.getCurrentUserRole) {
        const r = window.RolePermissions.getCurrentUserRole();
        if (r) currentRole = r;
      }
      // Fallback: read from cached profile
      if (!currentRole) {
        const cached = window.getCachedUserProfile ? window.getCachedUserProfile() : null;
        if (cached) currentRole = cached.role || '';
      }
    } catch (e) {}

    const hasOverride = window.hasRoleOverride ? window.hasRoleOverride() : false;

    // Role items
    roles.forEach(role => {
      const item = document.createElement('div');
      item.className = 'role-switcher-item' + (role === currentRole ? ' active' : '');
      item.innerHTML = `<span class="rs-dot" style="background:${colors[role] || '#ccc'}"></span> ${labels[role] || role}`;
      item.onclick = function(e) {
        e.stopPropagation();
        closeRoleSwitcher();
        if (role !== currentRole) {
          window.switchRole(role);
        }
      };
      sw.appendChild(item);
    });

    // Divider + Reset option (only show if override is active)
    if (hasOverride) {
      const divider = document.createElement('hr');
      divider.className = 'role-switcher-divider';
      sw.appendChild(divider);

      const reset = document.createElement('div');
      reset.className = 'role-switcher-item';
      reset.innerHTML = '↩ Reset to real role';
      reset.onclick = function(e) {
        e.stopPropagation();
        closeRoleSwitcher();
        window.clearRoleOverride();
      };
      sw.appendChild(reset);
    }
  }

  // ── Toggle role switcher ──────────────────────────────────
  window.toggleRoleSwitcher = function(e) {
    e.stopPropagation();
    const sw = document.getElementById('roleSwitcher');
    if (!sw) return;
    // Build contents once
    if (!sw.children.length) {
      buildRoleSwitcher();
    }
    sw.classList.toggle('open');
  };

  function closeRoleSwitcher() {
    const sw = document.getElementById('roleSwitcher');
    if (sw) sw.classList.remove('open');
  }

  // Close on click outside
  document.addEventListener('click', function(e) {
    if (!e.target.closest('.role-badge')) {
      closeRoleSwitcher();
    }
  });

  // Mark badge if override is active
  function markOverrideBadge() {
    const badge = document.getElementById('userRoleBadge');
    if (badge && window.hasRoleOverride && window.hasRoleOverride()) {
      badge.classList.add('has-override');
    }
  }

  // Wait for role badge to be populated before marking
  const badgeObserver = new MutationObserver(function() {
    markOverrideBadge();
  });
  const badgeEl = document.getElementById('userRoleBadge');
  if (badgeEl) {
    badgeObserver.observe(badgeEl, { childList: true, subtree: true, characterData: true });
  }
  // Also try immediately
  setTimeout(markOverrideBadge, 500);

})();
