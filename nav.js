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
        color: #111;
        border-bottom: 3px solid #222;
        background: #fafafa;
      }

      /* ── Caret for dropdowns ─────────────────────────── */
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
        background: #f0f2f5;
        color: #111;
        font-weight: 700;
        border-left-color: #222;
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
        color: #111;
        border-bottom: 3px solid #222;
        background: #fafafa;
      }

      /* ── Responsive (mobile) ──────────────────────────── */
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
        label: '\u2302 Dashboard',
        href: 'dashboard.html',
        single: true,
        hideFor: ['viewer', 'worker', 'company']
      },
      {
        id: 'company-view',
        label: '\uD83C\uDFE2 Employer Details',
        href: 'company-view.html',
        single: true,
        hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin', 'medical_practitioner']
      },
      {
        id: 'book-inspection',
        label: '\uD83D\uDCC5 Book Inspection',
        hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin', 'medical_practitioner'],
        children: [
          { id: 'company-book-inspection', icon: '\uD83D\uDCDD', label: 'New Booking',       href: 'company-book-inspection.html' },
          { id: 'company-bookings',        icon: '\uD83D\uDCCB', label: 'My Bookings',       href: 'company-bookings.html', notification:'company-bookings-responded' },
        ]
      },
      {
        id: 'accident',
        label: '\uD83D\uDEA8 Report Accident',
        href: 'accident-report.html',
        single: true,
        hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin', 'medical_practitioner']
      },
      {
        id: 'injury-disease',
        label: '\uD83C\uDFE5 Report Injury / Disease',
        href: 'injury-disease-report.html',
        single: true,
        hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin', 'medical_practitioner']
      },
      {
        id: 'company-monitoring',
        label: '\uD83D\uDCCA Monitoring Dashboard',
        href: 'company-monitoring.html',
        single: true,
        hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin', 'medical_practitioner'],
        notification: 'company-bookings-responded'
      },
      {
        id: 'inspection',
        label: '\uD83D\uDD0D Inspections',
        hideFor: ['company', 'viewer', 'worker', 'medical_practitioner'],
        children: [
          { id: 'inspection-form',     icon: '\uD83D\uDD0D', label: 'New Inspection',       href: 'inspection.html' },
          { id: 'inspection-bookings', icon: '\uD83D\uDCC5', label: 'Inspection Bookings',  href: 'inspection-bookings.html', notification:'inspection-bookings-pending' },
          { id: 'inspection-records',  icon: '\uD83D\uDCC1', label: 'Inspection Records',   href: 'inspection-entries.html' },
        ]
      },
      {
        id: 'accident',
        label: '\uD83D\uDEA8 Accidents',
        hideFor: ['company', 'viewer', 'worker', 'medical_practitioner'],
        children: [
          { id: 'accident',         icon: '\uD83D\uDEA8', label: 'New Accident Report', href: 'accident-report.html' },
          { id: 'accident-entries', icon: '\uD83D\uDCCA', label: 'View Reports',        href: 'accident-entries.html' },
        ]
      },
      {
        id: 'injury',
        label: '\uD83C\uDFE5 Injuries',
        hideFor: ['company', 'viewer', 'worker', 'medical_practitioner'],
        children: [
          { id: 'injury-disease',         icon: '\uD83C\uDFE5', label: 'New Report',             href: 'injury-disease-report.html' },
          { id: 'injury-disease-entries', icon: '\uD83D\uDCCA', label: 'View Reports',           href: 'injury-disease-entries.html' },
          { id: 'worker-profile',         icon: '\uD83D\uDC64', label: 'Worker Profile',         href: 'worker-profile.html' },
        ]
      },
      {
        id: 'investigation',
        label: '🔍 Investigations',
        hideFor: ['company', 'viewer', 'worker', 'medical_practitioner'],
        children: [
          { id: 'investigation-view', icon: '🔍', label: 'View Investigations', href: 'investigation.html' },
        ]
      },
      {
        id: 'claims',
        label: '\uD83D\uDCCB Claims',
        hideFor: ['company', 'viewer', 'worker', 'medical_practitioner'],
        children: [
          { id: 'claims-submit',  icon: '\uD83D\uDCDD', label: 'Submit Claim',  href: 'form.html' },
          { id: 'claims-entries', icon: '\uD83D\uDCCA', label: 'View Entries',  href: 'entries.html' },
        ]
      },
      {
        id: 'case-tracking',
        label: '📊 My Cases',
        href: 'case-tracking.html',
        single: true,
        hideFor: ['viewer', 'officer', 'admin', 'super_admin', 'company', 'medical_practitioner']
      },
      {
        id: 'worker-claims',
        label: '\uD83D\uDCCB My Claims',
        href: 'worker-claims.html',
        single: true,
        hideFor: ['viewer', 'officer', 'admin', 'super_admin', 'company', 'medical_practitioner']
      },
      {
        id: 'medical-practitioner',
        label: 'Medical Exams',
        hideFor: ['viewer', 'worker', 'company', 'officer', 'admin', 'super_admin'],
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
        hideFor: ['viewer', 'worker', 'company', 'officer', 'admin', 'super_admin']
      },
      {
        id: 'clientele',
        label: '\uD83D\uDC65 Clientele',
        href: 'clientele.html',
        single: true,
        hideFor: ['viewer', 'worker', 'company', 'officer', 'admin', 'super_admin']
      },
      {
        id: 'company-register',
        label: '\uD83C\uDFE2 Employers',
        href: 'company-register.html',
        single: true,
        hideFor: ['company', 'worker', 'medical_practitioner']
      },
      {
        id: 'admin',
        label: '\u2699 Admin',
        hideFor: ['company', 'viewer', 'worker', 'officer', 'medical_practitioner'],
        href: 'admin.html',
        single: true
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
        btn.textContent = item.label;
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

  // ── Inject the nav ───────────────────────────────────────
  function inject() {
    const nav = buildNav();

    // If header.js has already injected .site-header, append nav inside it
    const siteHeader = document.querySelector('.site-header');
    if (siteHeader) {
      siteHeader.appendChild(nav);
      return;
    }

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

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inject);
  } else {
    inject();
  }

  // ── Fetch notification counts from Supabase ────────────
  // Called shortly after injection to update notification badges.
  // Uses the global supabaseClient (available once all scripts load).
  // Badges auto-dismiss once the user visits the relevant page.
  async function fetchNotificationCounts() {
    try {
      const sb = window.supabaseClient;
      if (!sb) return;

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
      const respondedBadge = document.getElementById('notif-company-bookings-responded');
      if (respondedBadge) {
        try {
          const cachedCount = sessionStorage.getItem('company_booking_responses');
          const count = cachedCount ? parseInt(cachedCount, 10) : 0;
          respondedBadge.textContent = count;
          respondedBadge.classList.toggle('zero', count === 0);
        } catch (e) {
          respondedBadge.classList.add('zero');
        }
        const parentBadge = document.getElementById('parent-notif-company-bookings-responded');
        if (parentBadge) {
          parentBadge.textContent = respondedBadge?.textContent || '0';
          parentBadge.classList.toggle('zero', respondedBadge?.classList.contains('zero'));
        }
      }
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
