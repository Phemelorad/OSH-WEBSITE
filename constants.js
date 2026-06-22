// ============================================================
// OSH SYSTEM — SHARED CONSTANTS
// Single source of truth for roles, permissions, labels, and colors.
// Include BEFORE role-permissions.js and header.js.
// ============================================================
(function () {
  'use strict';

  const ROLES = Object.freeze({
    VIEWER: 'viewer',
    WORKER: 'worker',
    OFFICER: 'officer',
    ADMIN: 'admin',
    SUPER_ADMIN: 'super_admin',
    COMPANY: 'company',
    MEDICAL_PRACTITIONER: 'medical_practitioner'
  });

  const ALL_ROLES = Object.freeze([
    'viewer', 'worker', 'company', 'medical_practitioner',
    'officer', 'admin', 'super_admin'
  ]);

  const PERMISSIONS = Object.freeze({
    viewer:              Object.freeze({ view_claims: true, submit_claims: false, edit_claims: false, access_admin: false, manage_users: false }),
    worker:              Object.freeze({ view_claims: true, submit_claims: false, edit_claims: false, access_admin: false, manage_users: false }),
    officer:             Object.freeze({ view_claims: true, submit_claims: true, edit_claims: true, edit_own_only: true, access_admin: false, manage_users: false }),
    admin:               Object.freeze({ view_claims: true, submit_claims: true, edit_claims: true, access_admin: true, manage_users: true, manage_super_admins: false }),
    super_admin:         Object.freeze({ view_claims: true, submit_claims: true, edit_claims: true, access_admin: true, manage_users: true, manage_super_admins: true }),
    company:             Object.freeze({ view_claims: true, submit_claims: false, edit_claims: false, access_admin: false, manage_users: false }),
    medical_practitioner: Object.freeze({ view_claims: true, submit_claims: false, edit_claims: false, access_admin: false, manage_users: false, submit_medical_exams: true })
  });

  const ROLE_LABELS = Object.freeze({
    viewer:              '\uD83D\uDC41 Viewer',
    worker:              '\uD83D\uDC77 Worker',
    company:             '\uD83C\uDFE2 Employer',
    medical_practitioner: '\uD83E\uDDBA Medical Practitioner',
    officer:             '\uD83D\uDC6E Officer',
    admin:               '\u2699 Admin',
    super_admin:         '\uD83D\uDD27 Super Admin'
  });

  const ROLE_LABELS_SHORT = Object.freeze({
    viewer:              'Viewer',
    worker:              'Worker',
    company:             'Employer',
    medical_practitioner: 'Medical Practitioner',
    officer:             'Officer',
    admin:               'Admin',
    super_admin:         'Super Admin'
  });

  const ROLE_COLORS = Object.freeze({
    viewer:              '#e2e3e5',
    worker:              '#cce5ff',
    company:             '#cce5ff',
    medical_practitioner: '#e8d5f5',
    officer:             '#d1ecf1',
    admin:               '#fff3cd',
    super_admin:         '#d4edda'
  });

  function getRoleDisplayName(role) {
    return ROLE_LABELS_SHORT[role] || role;
  }

  function getRoleColor(role) {
    return ROLE_COLORS[role] || '#f8f9fa';
  }

  function getRoleLabel(role) {
    return ROLE_LABELS[role] || role;
  }

  function mapRole(formRole) {
    if (formRole === 'osh_officer') return 'officer';
    if (formRole === 'medical_practitioner') return 'medical_practitioner';
    return formRole;
  }

  function isValidRole(role) {
    return ALL_ROLES.indexOf(role) >= 0;
  }

  window.OSH_CONSTANTS = {
    ROLES: ROLES,
    ALL_ROLES: ALL_ROLES,
    PERMISSIONS: PERMISSIONS,
    ROLE_LABELS: ROLE_LABELS,
    ROLE_LABELS_SHORT: ROLE_LABELS_SHORT,
    ROLE_COLORS: ROLE_COLORS,
    getRoleDisplayName: getRoleDisplayName,
    getRoleColor: getRoleColor,
    getRoleLabel: getRoleLabel,
    mapRole: mapRole,
    isValidRole: isValidRole
  };

})();
