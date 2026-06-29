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
//   case-tracking           → case-tracking.html
//   worker-claims           → worker-claims.html
//   medical-examination     → medical-examination.html
//   clientele               → clientele.html
//   admin                   → admin.html
//   company-book-inspection → company-book-inspection.html
//   company-monitoring      → company-monitoring.html
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
        opacity: 1;
        transition: opacity 0.2s ease;
      }

      .osh-nav.osh-nav-loading {
        opacity: 0;
        pointer-events: none;
      }

      /* Top-level nav items */
      .osh-nav-item {
        position: relative;
      }

      /* ── Animated bottom-border indicator ────────────── */
      .osh-nav-item::after {
        content: '';
        position: absolute;
        bottom: 0;
        left: 50%;
        width: 0;
        height: 3px;
        background: #222;
        border-radius: 2px 2px 0 0;
        transform: translateX(-50%);
        transition: width 0.22s cubic-bezier(0.25, 0.46, 0.45, 0.94);
        z-index: 1;
        pointer-events: none;
      }

      .osh-nav-item:hover::after {
        width: 70%;
      }

      /* Active item: full-width bottom border (override the hover indicator) */
      .osh-nav-item.has-active::after,
      .osh-nav-item:has(> .osh-nav-btn.active)::after {
        content: none;
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
        transition: background 0.2s ease, color 0.2s ease, box-shadow 0.2s ease;
        white-space: nowrap;
        position: relative;
        overflow: hidden;
      }

      /* Subtle background shimmer on hover */
      .osh-nav-btn::before {
        content: '';
        position: absolute;
        inset: 0;
        background: linear-gradient(135deg, transparent 0%, rgba(0,0,0,0.03) 50%, transparent 100%);
        opacity: 0;
        transition: opacity 0.3s ease;
        pointer-events: none;
      }

      .osh-nav-btn:hover::before {
        opacity: 1;
      }

      .osh-nav-btn:hover {
        background: #f7f7f7;
        color: #1a1a1a;
      }

      .osh-nav-btn.active {
        color: #000;
        border-bottom: 3px solid #222;
        background: linear-gradient(180deg, #f0f0f0 0%, #fafafa 100%);
        font-weight: 700;
        position: relative;
      }
      .osh-nav-btn.active::before {
        content: '';
        position: absolute;
        top: -1px;
        left: 50%;
        transform: translateX(-50%);
        width: 6px;
        height: 6px;
        background: #222;
        border-radius: 50%;
      }     /* ── Caret for dropdowns ─────────────────────────── */
      .osh-caret {
        font-size: 9px;
        opacity: 0.45;
        margin-left: 2px;
        transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.2s;
      }

      .osh-nav-item:hover .osh-caret,
      .osh-nav-item.open   .osh-caret {
        transform: rotate(180deg) translateY(1px);
        opacity: 0.85;
      }

      /* ── Dropdown panel ──────────────────────────────── */
      .osh-dropdown {
        display: none;
        position: absolute;
        top: 100%;
        left: 0;
        min-width: 220px;
        background: white;
        border: 1px solid #e8e8e8;
        border-radius: 0 0 12px 12px;
        box-shadow: 0 12px 32px rgba(0,0,0,0.13);
        z-index: 600;
        overflow: hidden;
        animation: osh-drop-in 0.18s cubic-bezier(0.25, 0.46, 0.45, 0.94);
      }

      .osh-nav-item:hover .osh-dropdown,
      .osh-nav-item.open   .osh-dropdown {
        display: block;
      }

      @keyframes osh-drop-in {
        from { opacity: 0; transform: translateY(-8px) scale(0.97); }
        to   { opacity: 1; transform: translateY(0) scale(1); }
      }

      /* ── Dropdown links ──────────────────────────────── */
      .osh-dropdown a {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 12px 18px;
        padding-left: 16px;
        font-size: 13px;
        font-weight: 500;
        color: #444;
        text-decoration: none;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        transition: background 0.18s ease, color 0.18s ease, padding-left 0.18s ease;
        border-bottom: 1px solid #f5f5f5;
        border-left: 3px solid transparent;
        position: relative;
      }

      .osh-dropdown a:last-child { border-bottom: none; }

      .osh-dropdown a:hover {
        background: #f5f7fa;
        color: #111;
        padding-left: 24px;
        border-left-color: #222;
      }

      /* ── Dropdown active state ────────────────────────── */
      .osh-dropdown a.active {
        background: #e8ecf0;
        color: #000;
        font-weight: 700;
        border-left-color: #000;
        border-left-width: 4px;
        padding-left: 15px;
      }
      .osh-dropdown a.active::after {
        content: '◀';
        font-size: 9px;
        color: #222;
        margin-left: auto;
        opacity: 0.6;
      }     
/* Nav icon images */
.nav-icon {
width: 25px;
height: 25px;
vertical-align: middle;
margin-right: 6px;
flex-shrink: 0;
object-fit: contain;
}
.dd-icon img {
width: 20px;
height: 20px;
margin-right: 6px;
vertical-align: middle;
}
.osh-dropdown a .dd-icon img {
margin-right: 6px;
}

.osh-dropdown a .dd-icon {
        font-size: 15px;
        width: 20px;
        text-align: center;
        flex-shrink: 0;
        transition: transform 0.18s ease;
      }

      .osh-dropdown a:hover .dd-icon {
        transform: scale(1.15);
      }

      /* ── Notification badge ──────────────────────────── */
      .notification-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 20px;
        height: 18px;
        padding: 0 6px;
        background: #e74c3c;
        color: white;
        border-radius: 10px;
        font-size: 10px;
        font-weight: 700;
        line-height: 1;
        margin-left: auto;
        flex-shrink: 0;
        transition: transform 0.2s ease;
      }

      .notification-badge.zero {
        display: none;
      }

      .osh-dropdown a:hover .notification-badge {
        transform: scale(1.1);
      }

      .osh-nav-btn .notification-badge {
        margin-left: 8px;
        font-size: 9px;
        min-width: 16px;
        height: 16px;
        padding: 0 4px;
      }

      .osh-nav-btn:hover .notification-badge {
        transform: scale(1.1);
      }

      /* Active parent highlight */
      .osh-nav-item.has-active > .osh-nav-btn {
        color: #000;
        border-bottom: 3px solid #222;
        background: linear-gradient(180deg, #f0f0f0 0%, #fafafa 100%);
        font-weight: 700;
      }     /* ── Responsive (mobile) ──────────────────────────── */
      @media (max-width: 768px) {
        .osh-nav { flex-direction: column; }
        .osh-nav-item { width: 100%; }
        .osh-nav-item::after { display: none; }
        .osh-nav-btn { width: 100%; height: 48px; justify-content: space-between; border-bottom: 1px solid #f0f0f0; }
        .osh-nav-btn::before { display: none; }
        .osh-nav-btn:hover { background: #f5f5f5; }
        .osh-nav-btn.active, .osh-nav-item.has-active > .osh-nav-btn {
          border-bottom: 1px solid #f0f0f0;
          border-left: 4px solid #222;
        }
        .osh-dropdown { position: static; border-radius: 0; box-shadow: none; border: none; background: #fafafa; animation: none; }
        .osh-nav-item:hover .osh-dropdown { display: none; }
        .osh-nav-item.open .osh-dropdown  { display: block; }
        .osh-dropdown a { padding-left: 32px; }
        .osh-dropdown a:hover { padding-left: 38px; }
      }
    `;
    document.head.appendChild(s);
  }

  // ── Nav structure ────────────────────────────────────────
  const active = window.OSH_ACTIVE_PAGE || '';

  const MENU = [
    {
        id: 'dashboard',
        label: '<img src="ICONS/DASHBOARD.png" class="nav-icon"> Dashboard',
        href: 'dashboard.html',
        single: true,
        hideFor: ['viewer', 'worker', 'company']
      },
      {
        id: 'company-view',
        label: '<img src="ICONS/COMPANY.png" class="nav-icon"> Employer Details',
        href: 'company-view.html',
        single: true,
        hideFor: ['viewer', 'worker', 'dosh_officer', 'admin', 'super_admin', 'medical_practitioner']
      },
      {
        id: 'book-inspection',
        label: '<img src="ICONS/BOOKINGS.png" class="nav-icon"> Book Inspection',
        hideFor: ['viewer', 'worker', 'dosh_officer', 'admin', 'super_admin', 'medical_practitioner'],
        children: [
          { id: 'company-book-inspection', icon: '<img src="ICONS/BOOKINGS.png" class="dd-icon">', label: 'New Booking',       href: 'company-book-inspection.html' },
          { id: 'company-bookings',        icon: '<img src="ICONS/BOOKINGS.png" class="dd-icon">', label: 'My Bookings',       href: 'company-bookings.html', notification:'company-bookings-responded' },
        ]
      },
      {
        id: 'accident',
        label: '<img src="ICONS/ACCIDENT.png" class="nav-icon"> Report Accident',
        hideFor: ['viewer', 'worker', 'dosh_officer', 'admin', 'super_admin', 'medical_practitioner'],
        children: [
          { id: 'accident-report', icon: '<img src="ICONS/ACCIDENT.png" class="dd-icon">', label: 'New Report', href: 'accident-report.html' },
          { id: 'company-accidents-view', icon: '<img src="ICONS/ACCIDENT.png" class="dd-icon">', label: 'My Accidents', href: 'company-accidents-view.html', notification:'company-accidents' },
        ]
      },
      {
        id: 'injury-disease',
        label: '<img src="ICONS/INJURY.png" class="nav-icon"> Report Injury / Disease',
        hideFor: ['viewer', 'worker', 'dosh_officer', 'admin', 'super_admin', 'medical_practitioner'],
        children: [
          { id: 'injury-disease-report', icon: '<img src="ICONS/INJURY.png" class="dd-icon">', label: 'New Report', href: 'injury-disease-report.html' },
          { id: 'company-injuries-view', icon: '<img src="ICONS/INJURY.png" class="dd-icon">', label: 'My Injuries', href: 'company-injuries-view.html', notification:'company-injuries' },
        ]
      },
      {
        id: 'company-monitoring',
        label: '<img src="ICONS/DASHBOARD.png" class="nav-icon"> Monitoring Dashboard',
        href: 'company-monitoring.html',
        single: true,
        hideFor: ['viewer', 'worker', 'dosh_officer', 'admin', 'super_admin', 'medical_practitioner'],
        notification: 'company-bookings-responded'
      },


      {
        id: 'inspection',
        label: '<img src="ICONS/INSPECTION.png" class="nav-icon"> Inspections',
        hideFor: ['viewer', 'company', 'medical_practitioner'],
        children: [
          { id: 'inspection-form',     icon: '<img src="ICONS/INVESTIGATION.png" class="dd-icon">', label: 'New Inspection',       href: 'inspection.html' },
          { id: 'inspection-bookings', icon: '<img src="ICONS/BOOKINGS.png" class="dd-icon">', label: 'Inspection Bookings',  href: 'inspection-bookings.html', notification:'inspection-bookings-pending' },
          { id: 'inspection-records',  icon: '<img src="ICONS/RECORD.png" class="dd-icon">', label: 'Inspection Records',   href: 'inspection-entries.html' },
        ]
      },
      {
        id: 'accident',
        label: '<img src="ICONS/ACCIDENT.png" class="nav-icon"> Accidents',
        hideFor: ['viewer', 'company', 'medical_practitioner'],
        children: [
          { id: 'accident',         icon: '<img src="ICONS/ACCIDENT.png" class="dd-icon">', label: 'New Accident Report', href: 'accident-report.html' },
          { id: 'accident-entries', icon: '<img src="ICONS/VIEW.png" class="dd-icon">', label: 'View Reports',        href: 'accident-entries.html' , notification:'new-accidents'},
        ]
      },
      {
        id: 'injury',
        label: '<img src="ICONS/INJURY.png" class="nav-icon"> Injuries',
        hideFor: ['viewer', 'company', 'medical_practitioner'],
        children: [
          { id: 'injury-disease',         icon: '<img src="ICONS/INJURY.png" class="dd-icon">', label: 'New Report',             href: 'injury-disease-report.html' },
          { id: 'injury-disease-entries', icon: '<img src="ICONS/VIEW.png" class="dd-icon">', label: 'View Reports',           href: 'injury-disease-entries.html' , notification:'new-injuries'},
          { id: 'worker-profile',         icon: '<img src="ICONS/WORKER_PROFILE.png" class="dd-icon">', label: 'Worker Profile',         href: 'worker-profile.html' },
        ]
      },
      {
        id: 'investigation',
        label: '<img src="ICONS/INVESTIGATION.png" class="nav-icon"> Investigations',
        hideFor: ['viewer', 'medical_practitioner'],
        children: [
          { id: 'conduct-investigation', icon: '<img src="ICONS/INVESTIGATION.png" class="dd-icon">', label: 'Conduct Investigation', href: 'OHS_Form19_Full.html' },
          { id: 'investigation-view', icon: '<img src="ICONS/INSPECTION.png" class="dd-icon">', label: 'View Investigations', href: 'investigation.html' , notification:'new-investigations'},
        ]
      },
      {
        id: 'claims',
        label: '<img src="ICONS/CLAIM.png" class="nav-icon"> Claims',
        hideFor: ['viewer', 'company', 'medical_practitioner'],
        children: [
          { id: 'claims-submit',  icon: '<img src="ICONS/SUBMIT_CLAIM.png" class="dd-icon">', label: 'Submit Claim',  href: 'form.html' },
          { id: 'claims-entries', icon: '<img src="ICONS/VIEW.png" class="dd-icon">', label: 'View Entries',  href: 'entries.html' , notification:'new-claims'},
          { id: 'checklist', icon: '<img src="ICONS/CLAIM.png" class="dd-icon">', label: 'Claim Checklist',  href: 'checklist.html' },
        ]
      },
      {
        id: 'case-tracking',
        label: '<img src="ICONS/DASHBOARD.png" class="nav-icon"> My Cases',
        href: 'case-tracking.html',
        single: true,
        hideFor: ['viewer', 'dosh_officer', 'admin', 'super_admin', 'company', 'medical_practitioner']
      },
      {
        id: 'worker-claims',
        label: '<img src="ICONS/CLAIM.png" class="nav-icon"> My Claims',
        href: 'worker-claims.html',
        single: true,
        hideFor: ['viewer', 'dosh_officer', 'admin', 'super_admin', 'company', 'medical_practitioner']
      },
      {
        id: 'medical-practitioner',
        label: 'Medical Exams',
        hideFor: ['viewer', 'worker', 'company', 'dosh_officer', 'admin', 'super_admin'],
        children: [
          { id: 'medical-examination', icon: '', label: 'Medical Exam (Form 43/03)', href: 'medical-examination.html' },
        ]
      },
      {
        id: 'permanent-impairment',
        label: 'Permanent Impairment Eval',
        href: 'permanent-impairment.html',
        single: true,
        icon: '',
        hideFor: ['viewer', 'worker', 'company', 'dosh_officer', 'admin', 'super_admin']
      },
      {
        id: 'clientele',
        label: '<img src="ICONS/COMPANY.png" class="nav-icon"> Clientele',
        href: 'clientele.html',
        single: true,
        hideFor: ['viewer', 'worker', 'company', 'dosh_officer', 'admin', 'super_admin']
      },
      {
        id: 'company-register',
        label: '<img src="ICONS/COMPANY.png" class="nav-icon"> Employers',
        href: 'company-register.html',
        single: true,
        hideFor: ['company', 'worker', 'medical_practitioner']
      },
      {
        id: 'admin',
        label: '<img src="ICONS/ADMIN.png" class="nav-icon"> Admin',
        hideFor: ['company', 'viewer', 'worker', 'dosh_officer', 'medical_practitioner'],
        href: 'admin.html',
        single: true
      },
      {
        id: 'debug',
        label: '🛠️ Debug Console',
        hideFor: ['company', 'viewer', 'worker', 'dosh_officer', 'medical_practitioner'],
        href: 'debug-console.html',
        single: true
      },
      {
        id: 'bl-forms',
        label: '📋 BL Forms',
        hideFor: ['company', 'viewer', 'worker', 'dosh_officer', 'medical_practitioner'],
        children: [
          { id: 'form-43-02', icon: '<img src="ICONS/wages.png" class="dd-icon">', label: 'Form 43/02 - Wages', href: 'form-43-02-wages.html' },
          { id: 'form-43-03', icon: '<img src="ICONS/medical exams.png" class="dd-icon">', label: 'Form 43/03 - Medical Exam', href: 'form-43-03-medical.html' },
          { id: 'form-43-04', icon: '<img src="ICONS/CLAIM.png" class="dd-icon">', label: 'Form 43/04 - Incapacity', href: 'form-43-04-incapacity.html' },
          { id: 'form-43-07', icon: '<img src="ICONS/insurance.png" class="dd-icon">', label: 'Form 43/07 - Insurance', href: 'form-43-07-insurance.html' },
          { id: 'form-43-11', icon: '<img src="ICONS/medical attendance.png" class="dd-icon">', label: 'Form 43/11 - Medical Attendance', href: 'form-43-11-attendance.html' }
        ]
      },
  ];

  // ── Build HTML ───────────────────────────────────────────
  function buildNav() {
    const nav = document.createElement('nav');
    nav.className = 'osh-nav osh-nav-loading';

    MENU.forEach(item => {
      const li = document.createElement('div');
      li.className = 'osh-nav-item';

      // Check if this item or any child is active
      const isSelfActive = item.id === active;
      const isChildActive = !item.single && item.children?.some(c => c.id === active);
      if (isChildActive) li.classList.add('has-active');

      // Apply role-based visibility
      if (item.hideFor) li.dataset.hideFor = item.hideFor.join(',');

      if (item.single) {
        // Direct link button
        const btn = document.createElement('button');
        btn.className = 'osh-nav-btn' + (isSelfActive ? ' active' : '');
        btn.innerHTML = item.label;
        btn.onclick = () => { window.location.href = item.href; };
        // Add notification badge if configured
        if (item.notification) {
          const badge = document.createElement('span');
          badge.className = 'notification-badge zero';
          badge.id = 'notif-' + item.notification;
          btn.appendChild(badge);
        }
        li.appendChild(btn);
      } else {
        // Dropdown trigger
        const btn = document.createElement('button');
        btn.className = 'osh-nav-btn';
        btn.innerHTML = `${item.label} <span class=\"osh-caret\">\u25BC</span>`;
        // Add notification badge to parent button if any child has notifications
        const childNotif = item.children?.find(c => c.notification);
        if (childNotif) {
          const badge = document.createElement('span');
          badge.className = 'notification-badge zero';
          badge.id = 'parent-notif-' + childNotif.notification;
          btn.appendChild(badge);
        }
        btn.addEventListener('click', (e) => {
          // Close all OTHER open dropdowns first
          document.querySelectorAll('.osh-nav-item.open').forEach(el => {
            if (el !== li) el.classList.remove('open');
          });
          // Toggle this one
          li.classList.toggle('open');
        });
        li.appendChild(btn);

        // Dropdown panel
        const dd = document.createElement('div');
        dd.className = 'osh-dropdown';
        item.children.forEach(child => {
          const a = document.createElement('a');
          a.href = child.href;
          a.className = child.id === active ? 'active' : '';
          a.innerHTML = (child.icon ? `<span class=\"dd-icon\">${child.icon}</span>` : '') + child.label;
          // Add notification badge if configured
          if (child.notification) {
            const badge = document.createElement('span');
            badge.className = 'notification-badge zero';
            badge.id = 'notif-' + child.notification;
            a.appendChild(badge);
          }
          dd.appendChild(a);
        });
        li.appendChild(dd);
      }

      nav.appendChild(li);
    });

    return nav;
  }

  // ── Close dropdowns when clicking outside ────────────────
  document.addEventListener('click', e => {
    if (!e.target.closest('.osh-nav-item')) {
      document.querySelectorAll('.osh-nav-item.open')
        .forEach(el => el.classList.remove('open'));
    }
  });

  // ── Apply role-based visibility ─────────────────────────────────
  function applyRoleVisibility() {
    if (window.RolePermissions && typeof window.RolePermissions.updateUIForRole === "function") {
      window.RolePermissions.updateUIForRole();
    }
  }

  // ── Inject the nav ───────────────────────────────────────
  function inject() {
    const nav = buildNav();

    // If header.js has already injected .site-header, append nav inside it
    const siteHeader = document.querySelector('.site-header');
    if (siteHeader) {
      siteHeader.appendChild(nav);
    } else {
      // Fallback: replace existing .site-nav or insert after .navbar
      const existing = document.querySelector('.site-nav');
      if (existing) {
        existing.replaceWith(nav);
      } else {
        const navbar = document.querySelector('.navbar');
        if (navbar) navbar.insertAdjacentElement('afterend', nav);
        else document.body.prepend(nav);
      }
    }

    // ── Wait for role before revealing nav ──────────────
    // If role is already known (e.g. cached path), reveal immediately.
    // Otherwise register a one-time callback — role-permissions.js
    // calls window.onRoleReady(role) at every exit of initializeRoleSystem.
    // 4 s safety fallback so nav never stays hidden forever.
    function revealNav() {
      applyRoleVisibility();
      nav.classList.remove('osh-nav-loading');
    }

    if (window.currentUserRole) {
      revealNav();
    } else {
      const timeout = setTimeout(revealNav, 4000);
      window.onRoleReady = function (role) {
        clearTimeout(timeout);
        revealNav();
      };
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inject);
  } else {
    inject();
  }

  // ---- Helper: update a single notification badge from Supabase count ----
  async function updateBadgeCount(notifKey, table, filterField, filterValue) {
    try {
      const sb = window.supabaseClient;
      if (!sb) return;

      const { count, error } = await sb
        .from(table)
        .select('id', { count: 'exact', head: true })
        .eq(filterField, filterValue);

      if (!error && typeof count === 'number') {
        let show = true;
        try {
          const seenRaw = sessionStorage.getItem(notifKey + '_seen');
          if (seenRaw !== null) {
            const seen = parseInt(seenRaw, 10);
            if (count <= seen) show = false;
          }
        } catch (e) {}

        const displayCount = show ? count : 0;
        const badge = document.getElementById('notif-' + notifKey);
        if (badge) {
          badge.textContent = displayCount;
          badge.classList.toggle('zero', displayCount === 0);
        }
        const parentBadge = document.getElementById('parent-notif-' + notifKey);
        if (parentBadge) {
          parentBadge.textContent = displayCount;
          parentBadge.classList.toggle('zero', displayCount === 0);
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  // ── Fetch notification counts from Supabase ────────────
  // Called shortly after injection to update notification badges.
  // Uses the global supabaseClient (available once all scripts load).
  // Badges auto-dismiss once the user visits the relevant page.
  async function fetchNotificationCounts() {
    try {
      const sb = window.supabaseClient;
      if (!sb) return;

      // ── Company-scoped notifications ─────────────────────
      var companyName = null;
      try {
        if (window.currentUserRole === 'company' && typeof window.getUserCompanyName === 'function') {
          companyName = await window.getUserCompanyName(sb);
        }
      } catch (e) {}

      if (companyName) {
        // Company: new accidents (My Accidents badge)
        try {
          var { count: accCount, error: accError } = await sb
            .from('accident_reports')
            .select('id', { count: 'exact', head: true })
            .ilike('occupier_name', '%' + companyName + '%');
          if (!accError && typeof accCount === 'number') {
            var show = true;
            try {
              var seenRaw = sessionStorage.getItem('company-accidents_seen');
              if (seenRaw !== null && accCount <= parseInt(seenRaw, 10)) show = false;
            } catch (e) {}
            var displayCount = show ? accCount : 0;
            var badge = document.getElementById('notif-company-accidents');
            if (badge) {
              badge.textContent = displayCount;
              badge.classList.toggle('zero', displayCount === 0);
            }
            var parentBadge = document.getElementById('parent-notif-company-accidents');
            if (parentBadge) {
              parentBadge.textContent = displayCount;
              parentBadge.classList.toggle('zero', displayCount === 0);
            }
          }
        } catch (e) {}

        // Company: new injuries (My Injuries badge)
        try {
          var { count: injCount, error: injError } = await sb
            .from('injury_disease_reports')
            .select('id', { count: 'exact', head: true })
            .ilike('employer_name', '%' + companyName + '%');
          if (!injError && typeof injCount === 'number') {
            var show = true;
            try {
              var seenRaw = sessionStorage.getItem('company-injuries_seen');
              if (seenRaw !== null && injCount <= parseInt(seenRaw, 10)) show = false;
            } catch (e) {}
            var displayCount = show ? injCount : 0;
            var badge = document.getElementById('notif-company-injuries');
            if (badge) {
              badge.textContent = displayCount;
              badge.classList.toggle('zero', displayCount === 0);
            }
            var parentBadge = document.getElementById('parent-notif-company-injuries');
            if (parentBadge) {
              parentBadge.textContent = displayCount;
              parentBadge.classList.toggle('zero', displayCount === 0);
            }
          }
        } catch (e) {}
      }

      // ── Officer-side: pending inspection bookings ──────
      const { count: pendingCount, error: pendingError } = await sb
        .from('inspection_bookings')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending');

      if (!pendingError && typeof pendingCount === 'number') {
        // Check if user has already seen this many (or more) pending bookings
        let show = true;
        try {
          const seenRaw = sessionStorage.getItem('inspections_seen_pending');
          if (seenRaw !== null) {
            const seen = parseInt(seenRaw, 10);
            if (pendingCount <= seen) show = false;
          }
        } catch (e) {}

        const count = show ? pendingCount : 0;
        const badge = document.getElementById('notif-inspection-bookings-pending');
        if (badge) {
          badge.textContent = count;
          badge.classList.toggle('zero', count === 0);
        }
        const parentBadge = document.getElementById('parent-notif-inspection-bookings-pending');
        if (parentBadge) {
          parentBadge.textContent = count;
          parentBadge.classList.toggle('zero', count === 0);
        }
      }

      // ── Company-side: responded bookings (read from sessionStorage) ─
      // The company-monitoring page stores this count after loading data.
      // Dismissed when the user opens company-bookings.html or company-monitoring.html.
      // Uses _seen pattern: badge shows count only if > seen count.
      const respondedBadge = document.getElementById('notif-company-bookings-responded');
      if (respondedBadge) {
        try {
          var cachedCount = sessionStorage.getItem('company_booking_responses');
          var count = cachedCount ? parseInt(cachedCount, 10) : 0;
          var seenRaw = sessionStorage.getItem('company-bookings-responded_seen');
          // Show badge only if there are more responses since user last viewed
          if (seenRaw !== null && count <= parseInt(seenRaw, 10)) count = 0;
          respondedBadge.textContent = count;
          respondedBadge.classList.toggle('zero', count === 0);
        } catch (e) {
          respondedBadge.classList.add('zero');
        }
        var parentBadge = document.getElementById('parent-notif-company-bookings-responded');
        if (parentBadge) {
          parentBadge.textContent = respondedBadge?.textContent || '0';
          parentBadge.classList.toggle('zero', respondedBadge?.classList.contains('zero'));
        }
      }

      // ── Officer-side: new submitted accident reports ──────────
      await updateBadgeCount('new-accidents', 'accident_reports', 'status', 'submitted');

      // ── Officer-side: new submitted injury/disease reports ────
      await updateBadgeCount('new-injuries', 'injury_disease_reports', 'status', 'submitted');

      // ── Officer-side: new injury claims ───────────────────────
      await updateBadgeCount('new-claims', 'injury_claims', 'status', 'submitted');

      // ── Officer-side: new investigations pending ──────────────
      await updateBadgeCount('new-investigations', 'accident_reports', 'investigation_status', 'Pending');

    } catch (e) {
      // Silently fail — notifications are non-critical
    }
  }

  // Schedule fetching after DOM is ready and scripts are loaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => setTimeout(fetchNotificationCounts, 500));
  } else {
    setTimeout(fetchNotificationCounts, 500);
  }

  // Also re-fetch when returning to tab (user might have changed tabs)
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
      setTimeout(fetchNotificationCounts, 200);
    }
  });


})();
