// ============================================================
// SHARED DROPDOWN NAVIGATION
// Include this script on every page AFTER the navbar div.
// Set window.OSH_ACTIVE_PAGE before including, e.g.:
//   <script>window.OSH_ACTIVE_PAGE = 'inspection-form';</script>
//
// Page tokens:
//   dashboard               → dashboard.html
//   claims-submit           → form.html
//   claims-entries          → entries.html
//   inspection-form         → inspection.html
//   inspection-records      → inspection-entries.html
//   accident                → accident-report.html
//   accident-entries        → accident-entries.html
//   injury-disease          → injury-disease-report.html
//   injury-disease-entries  → injury-disease-entries.html
//   worker-profile          → worker-profile.html
//   admin                   → admin.html
// ============================================================

(function () {

  // ── Inject CSS once ──────────────────────────────────────
  if (!document.getElementById('osh-nav-styles')) {
    const s = document.createElement('style');
    s.id = 'osh-nav-styles';
    s.textContent = `
      .osh-nav {
        background: white;
        box-shadow: 0 2px 10px rgba(0,0,0,0.08);
        border-top: 1px solid #e8e8e8;
        display: flex;
        align-items: stretch;
        position: relative;
        z-index: 500;
        flex-wrap: wrap;
      }

      /* Top-level nav items */
      .osh-nav-item {
        position: relative;
      }

      .osh-nav-btn {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 0 22px;
        height: 52px;
        background: white;
        border: none;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        font-size: 14px;
        font-weight: 600;
        color: #555;
        cursor: pointer;
        transition: background 0.18s, color 0.18s;
        border-bottom: 3px solid transparent;
        white-space: nowrap;
      }

      .osh-nav-btn:hover {
        background: #f8f8f8;
        color: #222;
      }

      .osh-nav-btn.active {
        color: #111;
        border-bottom: 3px solid #222;
        background: #fafafa;
      }

      @media (max-width: 768px) {
        .osh-nav { flex-direction: column; }
        .osh-nav-item { width: 100%; }
        .osh-nav-btn { width: 100%; height: 48px; border-bottom: 1px solid #f0f0f0; }
        .osh-nav-btn.active { border-bottom: 1px solid #f0f0f0; border-left: 4px solid #222; }
      }
    `;
    document.head.appendChild(s);
  }

  // ── Nav structure ────────────────────────────────────────
  const active = window.OSH_ACTIVE_PAGE || '';

  const MENU = [
    {
      id: 'dashboard',
      label: '⌂ Dashboard',
      href: 'dashboard.html',
      single: true
    },
    {
      id: 'company-view',
      label: '🏢 My Company',
      href: 'company-view.html',
      single: true,
      hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin']
    },
    {
      id: 'company-register',
      label: '🏢 Companies',
      href: 'company-register.html',
      single: true,
      hideFor: ['company']
    },
    {
      id: 'inspection',
      label: '🔍 Inspections',
      href: 'inspection-entries.html',
      single: true,
      activeFor: ['inspection-records', 'inspection-form'],
      hideFor: ['company', 'viewer', 'worker']
    },
    {
      id: 'accident',
      label: '🚨 Accidents',
      href: 'accident-entries.html',
      single: true,
      activeFor: ['accident-entries', 'accident'],
      hideFor: ['company', 'viewer', 'worker']
    },
    {
      id: 'injury',
      label: '🏥 Injuries',
      href: 'injury-disease-entries.html',
      single: true,
      activeFor: ['injury-disease-entries', 'injury-disease', 'worker-profile'],
      hideFor: ['company', 'viewer', 'worker']
    },
    {
      id: 'claims',
      label: '📋 Claims',
      href: 'entries.html',
      single: true,
      activeFor: ['claims-entries', 'claims-submit'],
      hideFor: ['company', 'viewer', 'worker']
    },
    {
      id: 'admin',
      label: '⚙ Admin',
      hideFor: ['company', 'viewer', 'worker'],
      href: 'admin.html',
      single: true
    },
  ];

  // ── Build HTML ───────────────────────────────────────────
  function buildNav() {
    const nav = document.createElement('nav');
    nav.className = 'osh-nav';

    MENU.forEach(item => {
      const li = document.createElement('div');
      li.className = 'osh-nav-item';

      // Check if this item is active
      const isSelfActive = item.id === active || item.activeFor?.includes(active);

      // Apply role-based visibility
      if (item.hideFor) li.dataset.hideFor = item.hideFor.join(',');

      // Direct link button (all items are single links now)
      const btn = document.createElement('button');
      btn.className = 'osh-nav-btn' + (isSelfActive ? ' active' : '');
      btn.textContent = item.label;
      btn.onclick = () => { window.location.href = item.href; };
      li.appendChild(btn);

      nav.appendChild(li);
    });

    return nav;
  }

  // ── Inject the nav ───────────────────────────────────────
  // Replace any existing .site-nav, or insert after .navbar
  function inject() {
    const existing = document.querySelector('.site-nav');
    const nav = buildNav();

    if (existing) {
      existing.replaceWith(nav);
    } else {
      const navbar = document.querySelector('.navbar');
      if (navbar) navbar.insertAdjacentElement('afterend', nav);
      else document.body.prepend(nav);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inject);
  } else {
    inject();
  }

  console.log('OSH nav loaded, active:', active);
})();
