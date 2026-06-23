/* ─── OSH Role Config — Single Source of Truth ───
 * Defines what each role can see/do on every page.
 * Companies, Workers, OSH Officers, Admins — all in one place.
 * Use OSH_ROLE_CONFIG.getView(pageId, role) to check access.
 ─────────────────────────────────────────────────────────── */

window.OSH_ROLE_CONFIG = (function () {
  'use strict';

  var config = {
    dashboard: {
      label: 'Dashboard',
      roles: ['company', 'worker', 'dosh_officer', 'admin', 'super_admin', 'medical_practitioner'],
      company:     { canView: true, stats: 'company' },
      worker:      { canView: true, stats: 'worker' },
      dosh_officer:{ canView: true, stats: 'all' },
      admin:       { canView: true, stats: 'all' },
      super_admin: { canView: true, stats: 'all' },
      medical_practitioner: { canView: true, stats: 'medical' }
    },
    checklist: {
      label: 'Claim Checklist',
      roles: ['company', 'worker', 'dosh_officer', 'admin', 'super_admin'],
      company:  { canView: true, canSubmit: true, autoFillCompany: true },
      worker:   { canView: true, canSubmit: true },
      dosh_officer: { canView: true, canSubmit: false, showReview: true },
      admin:    { canView: true, canSubmit: true, showReview: true },
      super_admin: { canView: true, canSubmit: true, showReview: true }
    },
    'form': {
      label: 'Submit Claim',
      roles: ['company', 'worker', 'dosh_officer', 'admin', 'super_admin'],
      company:  { canEdit: true, canSubmit: true, showFields: ['occupierName', 'companyAddress', 'companyIndustry'] },
      worker:   { canEdit: true, canSubmit: true, showFields: ['workerName', 'workerId', 'workerContact'] },
      dosh_officer: { canEdit: false, canSubmit: false, showReview: true },
      admin:    { canEdit: true, canSubmit: true, showFields: 'all' },
      super_admin: { canEdit: true, canSubmit: true, showFields: 'all' }
    },
    'accident-report': {
      label: 'Accident Report',
      roles: ['company', 'worker', 'dosh_officer', 'admin', 'super_admin'],
      company:  { canEdit: true, canSubmit: true, showFields: ['occupierName', 'companyInfo', 'accidentDetails'] },
      worker:   { canEdit: true, canSubmit: true, showFields: ['workerInfo', 'accidentDetails'] },
      dosh_officer: { canEdit: false, canSubmit: false, showApproval: true, showInvestigation: true },
      admin:    { canEdit: true, canSubmit: true, showFields: 'all', showApproval: true },
      super_admin: { canEdit: true, canSubmit: true, showFields: 'all', showApproval: true }
    },
    'injury-disease-report': {
      label: 'Injury/Disease Report',
      roles: ['company', 'worker', 'dosh_officer', 'admin', 'super_admin', 'medical_practitioner'],
      company:  { canView: true, canSubmit: true },
      worker:   { canView: true, canSubmit: true },
      dosh_officer: { canView: true, canSubmit: false, showReview: true },
      admin:    { canView: true, canSubmit: true },
      super_admin: { canView: true, canSubmit: true },
      medical_practitioner: { canView: true, canSubmit: true }
    },
    'claim-tracker': {
      label: 'Claim Tracker',
      roles: ['company', 'worker', 'dosh_officer', 'admin', 'super_admin'],
      company:  { canView: true, canTrack: 'own' },
      worker:   { canView: true, canTrack: 'own' },
      dosh_officer: { canView: true, canTrack: 'all' },
      admin:    { canView: true, canTrack: 'all' },
      super_admin: { canView: true, canTrack: 'all' }
    },
    'worker-claims': {
      label: 'My Claims',
      roles: ['worker', 'dosh_officer', 'admin', 'super_admin'],
      worker:{ canView: true, canSubmit: true },
      dosh_officer:{ canView: true, canReview: true },
      admin:{ canView: true, canReview: true },
      super_admin:{ canView: true, canReview: true }
    },
    'company-view': {
      label: 'Company Profile',
      roles: ['company', 'dosh_officer', 'admin', 'super_admin'],
      company:{ canView: true, canEdit: true },
      dosh_officer:{ canView: true, canEdit: false },
      admin:{ canView: true, canEdit: true },
      super_admin:{ canView: true, canEdit: true }
    },
    'company-accidents-view': {
      label: 'Company Accidents',
      roles: ['company', 'dosh_officer', 'admin', 'super_admin'],
      company:{ canView: true, canExport: true },
      dosh_officer:{ canView: true, canExport: true, canInvestigate: true },
      admin:{ canView: true, canExport: true, canInvestigate: true },
      super_admin:{ canView: true, canExport: true, canInvestigate: true }
    },
    'company-injuries-view': {
      label: 'Company Injuries',
      roles: ['company', 'dosh_officer', 'admin', 'super_admin'],
      company:{ canView: true },
      dosh_officer:{ canView: true, canReview: true },
      admin:{ canView: true, canReview: true },
      super_admin:{ canView: true, canReview: true }
    },
    'company-monitoring': {
      label: 'Company Monitoring',
      roles: ['company', 'dosh_officer', 'admin', 'super_admin'],
      company:{ canView: true },
      dosh_officer:{ canView: true, canSchedule: true },
      admin:{ canView: true, canSchedule: true },
      super_admin:{ canView: true, canSchedule: true }
    },
    'inspection-bookings': {
      label: 'Inspection Bookings',
      roles: ['company', 'dosh_officer', 'admin', 'super_admin'],
      company:{ canView: true, canBook: true },
      dosh_officer:{ canView: true, canManage: true },
      admin:{ canView: true, canManage: true },
      super_admin:{ canView: true, canManage: true }
    },
    'medical-examination': {
      label: 'Medical Examination',
      roles: ['company', 'worker', 'medical_practitioner', 'dosh_officer', 'admin', 'super_admin'],
      company:{ canView: true },
      worker:{ canView: true },
      medical_practitioner:{ canView: true, canEdit: true, canSubmit: true },
      dosh_officer:{ canView: true, canReview: true },
      admin:{ canView: true, canReview: true },
      super_admin:{ canView: true, canReview: true }
    },
    'admin': {
      label: 'Admin',
      roles: ['admin', 'super_admin'],
      admin:{ canView: true, canManageUsers: true },
      super_admin:{ canView: true, canManageUsers: true, canManageAdmins: true }
    },
    'case-tracking': {
      label: 'Case Tracking',
      roles: ['dosh_officer', 'admin', 'super_admin'],
      dosh_officer:{ canView: true, canUpdate: true },
      admin:{ canView: true, canUpdate: true },
      super_admin:{ canView: true, canUpdate: true }
    },
    'clientele': {
      label: 'Clientele',
      roles: ['dosh_officer', 'admin', 'super_admin'],
      dosh_officer:{ canView: true },
      admin:{ canView: true },
      super_admin:{ canView: true }
    },
    'inspection-entries': {
      label: 'Inspection Entries',
      roles: ['dosh_officer', 'admin', 'super_admin'],
      dosh_officer:{ canView: true, canEdit: true },
      admin:{ canView: true, canEdit: true, canDelete: true },
      super_admin:{ canView: true, canEdit: true, canDelete: true }
    },
    'permanent-impairment': {
      label: 'Permanent Impairment',
      roles: ['medical_practitioner', 'dosh_officer', 'admin', 'super_admin'],
      medical_practitioner:{ canView: true, canSubmit: true },
      dosh_officer:{ canView: true, canReview: true },
      admin:{ canView: true, canReview: true },
      super_admin:{ canView: true, canReview: true }
    },
    'investigation': {
      label: 'Investigation',
      roles: ['dosh_officer', 'admin', 'super_admin'],
      dosh_officer:{ canView: true, canConduct: true },
      admin:{ canView: true, canConduct: true, canAssign: true },
      super_admin:{ canView: true, canConduct: true, canAssign: true }
    }
  };

  return {
    getView: function (pageId, role) {
      role = role || window.currentUserRole || '';
      pageId = pageId.replace('.html', '');
      var page = config[pageId];
      if (!page) return { canView: false, reason: 'unknown_page' };
      if (!page.roles || page.roles.indexOf(role) === -1) return { canView: false, reason: 'role_not_allowed' };
      var roleCfg = page[role] || {};
      return Object.assign({ canView: true }, roleCfg);
    },
    getPagesForRole: function (role) {
      var result = [];
      for (var id in config) {
        if (config[id].roles && config[id].roles.indexOf(role) !== -1) {
          result.push({ id: id, label: config[id].label });
        }
      }
      return result;
    },
    getAll: function () { return Object.assign({}, config); },
    canAccess: function (pageId, role) {
      return this.getView(pageId, role).canView === true;
    }
  };
})();
