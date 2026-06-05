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
        gap: 2px;
      }

      .header-user .user-name {
        font-size: 13px;
        font-weight: 600;
        color: #333;
      }

      .header-user .user-meta {
        display: flex;
        gap: 8px;
        align-items: center;
      }

      .header-user .user-designation {
        font-size: 11px;
        color: #777;
      }

      .header-user .user-company-name {
        font-size: 11px;
        color: #888;
      }

      .header-logout {
        padding: 8px 18px;
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
      }

      .header-logout:hover {
        background: #f5f5f5;
        border-color: #bbb;
        color: #222;
      }

      .header-user .user-name .role-badge {
        display: inline-block;
        background: #e8e8e8;
        color: #555;
        padding: 2px 10px;
        border-radius: 12px;
        font-size: 11px;
        font-weight: 600;
        margin-left: 8px;
        vertical-align: middle;
        line-height: normal;
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
            <div class="header-subtitle">Ministry of Labour &amp; Home Affairs · Occupational Health &amp; Safety</div>
          </div>
        </div>
        <div class="header-right">
          <div class="header-user">
            <div class="user-name" id="userName">
              Loading...
              <span class="role-badge" id="userRoleBadge"></span>
            </div>
            <div class="user-meta">
              <span class="user-designation" id="userDesignation"></span>
              <!-- Hidden fallback IDs for backward compatibility with page scripts -->
              <span id="userDept" style="display:none"></span>
              <span id="userDepartment" style="display:none"></span>
              <span id="userCompanyName" style="display:none"></span>
            </div>
          </div>
          <button class="header-logout" onclick="handleLogout()">Sign Out</button>
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
    const pageTitle = titleEl ? titleEl.textContent.trim() : 'OSH Management System';

    const header = buildHeader(pageTitle);
    navbar.replaceWith(header);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', inject);
  } else {
    inject();
  }

  console.log('OSH header loaded');
})();
