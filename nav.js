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
//   worker-claims           → worker-claims.html
//   medical-examination     → medical-examination.html
//   admin                   → admin.html
//   company-book-inspection → company-book-inspection.html
//   company-monitoring      → company-monitoring.html
// ============================================================

(function () {

  // ── Inject CSS once ──────────────────────────────────────
  if (!document.getElementById('osh-nav-styles')) {
    const s = document.createElement('style');
    s.id = 'osh-nav-styles';        s.textContent = `
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

      /* Caret for dropdowns */
      .osh-caret {
        font-size: 9px;
        opacity: 0.5;
        margin-left: 2px;
        transition: transform 0.2s;
      }

      .osh-nav-item:hover .osh-caret,
      .osh-nav-item.open   .osh-caret {
        transform: rotate(180deg);
        opacity: 0.8;
      }

      /* Dropdown panel */
      .osh-dropdown {
        display: none;
        position: absolute;
        top: 100%;
        left: 0;
        min-width: 210px;
        background: white;
        border: 1px solid #e8e8e8;
        border-radius: 0 0 10px 10px;
        box-shadow: 0 8px 24px rgba(0,0,0,0.12);
        z-index: 600;
        overflow: hidden;
        animation: osh-drop-in 0.15s ease;
      }

      .osh-nav-item:hover .osh-dropdown,
      .osh-nav-item.open   .osh-dropdown {
        display: block;
      }

      @keyframes osh-drop-in {
        from { opacity: 0; transform: translateY(-6px); }
        to   { opacity: 1; transform: translateY(0); }
      }

      .osh-dropdown a {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 11px 18px;
        font-size: 13px;
        font-weight: 500;
        color: #444;
        text-decoration: none;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        transition: background 0.15s, color 0.15s;
        border-bottom: 1px solid #f5f5f5;
      }

      .osh-dropdown a:last-child { border-bottom: none; }

      .osh-dropdown a:hover {
        background: #f5f5f5;
        color: #111;
      }

      /* Notification badge */
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
      }

      .notification-badge.zero {
        display: none;
      }

      .osh-nav-btn .notification-badge {
        margin-left: 8px;
        font-size: 9px;
        min-width: 16px;
        height: 16px;
        padding: 0 4px;
      }

      .osh-dropdown a.active {
        background: #f0f0f0;
        color: #111;
        font-weight: 700;
      }

      .osh-dropdown a .dd-icon {
        font-size: 15px;
        width: 20px;
        text-align: center;
        flex-shrink: 0;
      }

      /* Active parent highlight */
      .osh-nav-item.has-active > .osh-nav-btn {
        color: #111;
        border-bottom: 3px solid #222;
        background: #fafafa;
      }

      @media (max-width: 768px) {
        .osh-nav { flex-direction: column; }
        .osh-nav-item { width: 100%; }
        .osh-nav-btn { width: 100%; height: 48px; justify-content: space-between; border-bottom: 1px solid #f0f0f0; }
        .osh-nav-btn.active, .osh-nav-item.has-active > .osh-nav-btn {
          border-bottom: 1px solid #f0f0f0;
          border-left: 4px solid #222;
        }
        .osh-dropdown { position: static; border-radius: 0; box-shadow: none; border: none; background: #fafafa; animation: none; }
        .osh-nav-item:hover .osh-dropdown { display: none; }
        .osh-nav-item.open .osh-dropdown  { display: block; }
        .osh-dropdown a { padding-left: 32px; }
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
      single: true,
      hideFor: ['viewer', 'worker', 'company']
    },
    {
      id: 'company-view',
      label: '🏢 Employer Details',
      href: 'company-view.html',
      single: true,
      hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin']
    },
    {
      id: 'book-inspection',
      label: '📅 Book Inspection',
      hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin'],
      children: [
        { id: 'company-book-inspection', icon: '📝', label: 'New Booking',       href: 'company-book-inspection.html' },
        { id: 'company-bookings',        icon: '📋', label: 'My Bookings',       href: 'company-bookings.html', notification:'company-bookings-responded' },
      ]
    },
    {
      id: 'accident',
      label: '🚨 Report Accident',
      href: 'accident-report.html',
      single: true,
      hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin']
    },
    {
      id: 'injury-disease',
      label: '🏥 Report Injury / Disease',
      href: 'injury-disease-report.html',
      single: true,
      hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin']
    },
    {
      id: 'company-monitoring',
      label: '📊 Monitoring Dashboard',
      href: 'company-monitoring.html',
      single: true,
      hideFor: ['viewer', 'worker', 'officer', 'admin', 'super_admin'],
      notification: 'company-bookings-responded'
    },
    {
      id: 'inspection',
      label: '🔍 Inspections',
      hideFor: ['company', 'viewer', 'worker'],
      children: [
        { id: 'inspection-form',     icon: '🔍', label: 'New Inspection',       href: 'inspection.html' },
        { id: 'inspection-bookings', icon: '📅', label: 'Inspection Bookings',  href: 'inspection-bookings.html', notification:'inspection-bookings-pending' },
        { id: 'inspection-records',  icon: '📁', label: 'Inspection Records',   href: 'inspection-entries.html' },
      ]
    },
    {
      id: 'accident',
      label: '🚨 Accidents',
      hideFor: ['company', 'viewer', 'worker'],
      children: [
        { id: 'accident',         icon: '🚨', label: 'New Accident Report', href: 'accident-report.html' },
        { id: 'accident-entries', icon: '📊', label: 'View Reports',        href: 'accident-entries.html' },
      ]
    },
    {
      id: 'injury',
      label: '🏥 Injuries',
      hideFor: ['company', 'viewer', 'worker'],
      children: [
        { id: 'injury-disease',         icon: '🏥', label: 'New Report',             href: 'injury-disease-report.html' },
        { id: 'injury-disease-entries', icon: '📊', label: 'View Reports',           href: 'injury-disease-entries.html' },
        { id: 'worker-profile',         icon: '👤', label: 'Worker Profile',         href: 'worker-profile.html' },
      ]
    },
    {
      id: 'claims',
      label: '📋 Claims',
      hideFor: ['company', 'viewer', 'worker'],
      children: [
        { id: 'claims-submit',  icon: '📝', label: 'Submit Claim',  href: 'form.html' },
        { id: 'claims-entries', icon: '📊', label: 'View Entries',  href: 'entries.html' },
      ]
    },
    {
      id: 'worker-claims',
      label: '📋 My Claims',
      href: 'worker-claims.html',
      single: true,
      hideFor: ['viewer', 'officer', 'admin', 'super_admin', 'company', 'medical_practitioner']
    },
    {
      id: 'medical-practitioner',
      label: '🩺 Medical Exams',
      hideFor: ['viewer', 'worker', 'company', 'officer', 'admin', 'super_admin'],
      children: [
        { id: 'medical-examination', icon: '🩺', label: 'Medical Exam (Form 43/03)', href: 'medical-examination.html' },
      ]
    },
    {
      id: 'company-register',
      label: '🏢 Employers',
      href: 'company-register.html',
      single: true,
      hideFor: ['company']
    },
    {
      id: 'admin',
      label: '⚙ Admin',
      hideFor: ['company', 'viewer', 'worker', 'officer'],
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
        btn.innerHTML = `${item.label} <span class="osh-caret">▼</span>`;
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
          a.innerHTML = `<span class="dd-icon">${child.icon}</span>${child.label}`;
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

  console.log('DOSH nav loaded, active:', active);
})();
