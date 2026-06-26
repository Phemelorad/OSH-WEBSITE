// OHS Form 19 investigation tab functions
function switchTab(tab) {
  document.getElementById('tabAccidents').classList.toggle('active', tab === 'accidents');
  document.getElementById('tabForm19').classList.toggle('active', tab === 'form19');
  document.getElementById('tabContentAccidents').style.display = tab === 'accidents' ? 'block' : 'none';
  document.getElementById('tabContentForm19').style.display = tab === 'form19' ? 'block' : 'none';
  if (tab === 'form19' && allForm19.length === 0) loadForm19Data();
  if (tab === 'accidents') buildStats(allAccidents);
}

async function loadForm19Data() {
  var loadingEl = document.getElementById('form19Loading');
  var wrapEl = document.getElementById('form19TableWrap');
  if (loadingEl) loadingEl.style.display = 'block';
  if (wrapEl) wrapEl.style.display = 'none';
  try {
    var { data, error } = await SB.from('ohs_form_19').select('*').order('incident_date', { ascending: false });
    if (error) throw error;
    allForm19 = data || [];
    buildForm19Stats(allForm19);
    renderForm19Table(allForm19);
  } catch (err) {
    console.error('Form 19 load error:', err);
    var emptyEl = document.getElementById('form19EmptyState');
    if (emptyEl) {
      emptyEl.innerHTML = '<p style="color:#e74c3c">Error loading Form 19 entries. <button onclick="loadForm19Data()" style="margin-top:8px;padding:8px 20px;background:#333;color:white;border:none;border-radius:6px;cursor:pointer">Retry</button></p>';
      emptyEl.style.display = 'block';
    }
  } finally {
    if (loadingEl) loadingEl.style.display = 'none';
  }
}

function buildForm19Stats(entries) {
  var total = entries.length;
  var open = entries.filter(function(e) { return e.inv_status === 'Open' || e.inv_status === 'Pending' || !e.inv_status; }).length;
  var inProgress = entries.filter(function(e) { return e.inv_status === 'In Progress'; }).length;
  var completed = entries.filter(function(e) { return e.inv_status === 'Completed' || e.inv_status === 'Closed'; }).length;
  document.getElementById('statTotal').textContent = total;
  document.getElementById('statAccidents').textContent = open;
  document.getElementById('statInjuries').textContent = inProgress;
  document.getElementById('statPending').textContent = open;
  document.getElementById('statInProgress').textContent = inProgress;
  document.getElementById('statCompleted').textContent = completed;
}

function renderForm19Table(entries) {
  var tbody = document.getElementById('form19TableBody');
  var empty = document.getElementById('form19EmptyState');
  var rowCount = document.getElementById('form19RowCount');
  var wrap = document.getElementById('form19TableWrap');
  if (rowCount) rowCount.textContent = entries.length ? 'Showing ' + entries.length + ' form 19 entr' + (entries.length !== 1 ? 'ies' : 'y') : '';
  if (!entries.length) {
    if (tbody) tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    if (wrap) wrap.style.display = 'none';
    return;
  }
  if (empty) empty.style.display = 'none';
  if (wrap) wrap.style.display = 'block';
  if (tbody) tbody.innerHTML = entries.map(function(e) {
    var statusSlug = (e.inv_status || 'pending').toLowerCase().replace(/\s+/g, '-');
    return '<tr>' +
      '<td><strong>' + esc(e.inv_ref_no || '—') + '</strong></td>' +
      '<td>' + esc(e.employer_name || '—') + '</td>' +
      '<td>' + esc(e.injured_name || '—') + '</td>' +
      '<td>' + (e.incident_date ? fmtDate(e.incident_date) : '—') + '</td>' +
      '<td>' + esc(e.incident_location || '—') + '</td>' +
      '<td><span class="badge badge-' + statusSlug + '">' + esc(e.inv_status || 'Pending') + '</span></td>' +
      '<td>' + esc(e.lead_investigator || e.investigator_name || '—') + '</td>' +
      '<td style="white-space:nowrap">' +
        '<button class="action-btn" onclick="viewForm19(\'' + e.id + '\')">📋 View</button>' +
        (e.inv_ref_no ? '<a href="OHS_Form19_Full.html?id=' + e.id + '" class="action-btn" target="_blank">📝 Open Form</a>' : '') +
      '</td>' +
    '</tr>';
  }).join('');
}

function viewForm19(id) {
  var entry = allForm19.find(function(e) { return e.id === id; });
  if (!entry) { showToast('Form 19 entry not found', 'error'); return; }
  function f(label, val) { return val != null && val !== '' ? '<div class="rec-field"><span class="lbl">' + label + '</span><span class="val">' + esc(val) + '</span></div>' : ''; }
  var sections = '';
  sections += '<div class="rec-section"><div class="rec-section-header investigation">📝 Investigation Details</div><div class="rec-section-body">' +
    f('Inv. Reference No', entry.inv_ref_no) + f('Case No', entry.case_no) + f('District', entry.inv_district) +
    f('Lead Investigator', entry.lead_investigator || entry.investigator_name) + f('Inv. Status', entry.inv_status) +
    f('Date Opened', fmtDate(entry.date_opened)) + f('Date Closed', fmtDate(entry.date_closed)) + '</div></div>';
  sections += '<div class="rec-section"><div class="rec-section-header employer">🏢 Employer Information</div><div class="rec-section-body">' +
    f('Employer Name', entry.employer_name) + f('Sector', entry.employer_sector) + f('Contact Person', entry.contact_person) +
    f('Contact Position', entry.contact_position) + f('Plot', entry.employer_plot) + f('Street', entry.employer_street) +
    f('City', entry.employer_city) + f('District', entry.employer_district) + f('Postal', entry.employer_postal) +
    f('Phone', entry.employer_phone) + '</div></div>';
  sections += '<div class="rec-section"><div class="rec-section-header accident">🧑 Injured Person</div><div class="rec-section-body">' +
    f('Name', entry.injured_name) + f('ID Number', entry.injured_id) + f('Date of Birth', fmtDate(entry.injured_dob)) +
    f('Occupation', entry.injured_occupation) + f('Phone', entry.injured_phone) + f('Address', entry.injured_address) +
    f('Nationality', entry.injured_nationality) + f('Sex', entry.sex) + f('Age Group', entry.age_group) +
    f('Marital Status', entry.marital_status) + '</div></div>';
  sections += '<div class="rec-section"><div class="rec-section-header accident">🚨 Incident Information</div><div class="rec-section-body">' +
    f('Date of Incident', fmtDate(entry.incident_date)) + f('Time', entry.incident_time) +
    f('Reported Date', fmtDate(entry.incident_reported_date)) + f('Location', entry.incident_location) +
    f('Summary', entry.incident_summary) + f('Description', entry.incident_description) +
    f('Nature of Work', entry.nature_of_work) + f('Work Experience', entry.work_experience) +
    f('Equipment Used', entry.equipment_used) + f('Employment Type', entry.employment_type) +
    f('Days Absent', entry.days_absent) + '</div></div>';
  var ov = document.createElement('div');
  ov.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.35);display:flex;align-items:center;justify-content:center;z-index:9999;padding:20px';
  ov.innerHTML = '<div style="background:#fff;border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,0.18);width:100%;max-width:640px;max-height:85vh;overflow-y:auto;padding:28px 26px;font-family:inherit">' +
    '<div style="font-size:32px;text-align:center;margin-bottom:8px">📝</div>' +
    '<h2 style="text-align:center;color:#222;font-size:17px;margin-bottom:16px">OHS Form 19 - Investigation Report</h2>' +
    sections +
    '<div style="margin-top:20px;text-align:center"><button id="closeBtn" style="padding:10px 28px;background:#333;color:#fff;border:none;border-radius:8px;font-size:14px;font-weight:600;cursor:pointer">Close</button></div></div>';
  ov.querySelector('#closeBtn').addEventListener('click', function() { ov.remove(); });
  ov.addEventListener('click', function(e) { if (e.target === ov) ov.remove(); });
  document.body.appendChild(ov);
}

function applyForm19Filters() {
  var search = (document.getElementById('form19Search')?.value || '').toLowerCase().trim();
  var status = document.getElementById('form19Status')?.value || '';
  var filtered = allForm19.filter(function(e) {
    if (status && (e.inv_status || 'Pending') !== status) return false;
    if (search) {
      var matches = (e.employer_name || '').toLow
      if (!matches) return false;
    }
    return true;
  });
  renderForm19Table(filtered);
}
