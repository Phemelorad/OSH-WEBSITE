// OHS Form 19 investigation entries functions

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
  var open = entries.filter(function(e) { return e.inv_status === 'Open' || !e.inv_status; }).length;
  var inProgress = entries.filter(function(e) { return e.inv_status === 'In Progress'; }).length;
  var pending = entries.filter(function(e) { return e.inv_status === 'Pending'; }).length;
  var completed = entries.filter(function(e) { return e.inv_status === 'Completed' || e.inv_status === 'Closed'; }).length;
  document.getElementById('statTotal').textContent = total;
  document.getElementById('statOpen').textContent = open;
  document.getElementById('statInProgress').textContent = inProgress;
  document.getElementById('statPending').textContent = pending;
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
      '<td><strong>' + esc(e.inv_ref_no || '\u2014') + '</strong></td>' +
      '<td>' + esc(e.employer_name || '\u2014') + '</td>' +
      '<td>' + esc(e.injured_name || '\u2014') + '</td>' +
      '<td>' + (e.incident_date ? fmtDate(e.incident_date) : '\u2014') + '</td>' +
      '<td>' + esc(e.incident_location || '\u2014') + '</td>' +
      '<td><span class="badge badge-' + statusSlug + '">' + esc(e.inv_status || 'Pending') + '</span></td>' +
      '<td>' + esc(e.lead_investigator || e.investigator_name || '\u2014') + '</td>' +
      '<td style="white-space:nowrap">' +
        '<button class="action-btn" onclick="viewForm19(\'' + e.id + '\')">\U0001f4cb View</button>' +
        (e.inv_ref_no ? '<a href="OHS_Form19_Full.html?id=' + e.id + '" class="action-btn" target="_blank">\U0001f4dd Open Form</a>' : '') +
      '</td>' +
    '</tr>';
  }).join('');
}

function viewForm19(id) {
  var entry = allForm19.find(function(e) { return e.id === id; });
  if (!entry) { showToast('Form 19 entry not found', 'error'); return; }
  function f(label, val) { return val != null && val !== '' ? '<div class="rec-field"><span class="lbl">' + label + '</span><span class="val">' + esc(val) + '</span></div>' : ''; }

  // Section 5: Accident Details (per injured person)
  var sec5 = '<div style="border:1px solid #e8e8e8;border-radius:10px;padding:16px;margin-top:12px;background:#fafafa">' +
    '<div style="font-size:14px;font-weight:700;color:#c0392b;margin-bottom:12px;padding-bottom:8px;border-bottom:2px solid #c0392b">5. Accident Details (Per Injured Person)</div>';

  var datePlace = entry.incident_date ? fmtDate(entry.incident_date) : '\u2014';
  if (entry.incident_time) datePlace += ' at ' + esc(entry.incident_time);
  if (entry.incident_location) datePlace += ' \u2014 ' + esc(entry.incident_location);
  sec5 += '<div style="margin-bottom:10px">' +
    '<div style="font-size:12px;font-weight:600;color:#555">5a) Date, Time &amp; Exact Place of Accident in the Workplace</div>' +
    '<div style="font-size:13px;color:#333;margin-top:2px">' + datePlace + '</div></div>';

  var desc = entry.incident_description || '\u2014';
  if (entry.incident_summary) desc += '<br><span style="color:#888;font-size:12px">Summary: ' + esc(entry.incident_summary) + '</span>';
  if (entry.equipment_used) desc += '<br><span style="color:#888;font-size:12px">(If machinery is involved: ' + esc(entry.equipment_used) + ')</span>';
  sec5 += '<div style="margin-bottom:10px">' +
    '<div style="font-size:12px;font-weight:600;color:#555">5b) Description of How Accident Occurred &amp; Extent of Injuries (Including Body Part Affected)</div>' +
    '<div style="font-size:13px;color:#333;margin-top:2px">' + desc + '</div></div>';

  sec5 += '<div style="margin-bottom:10px">' +
    '<div style="font-size:12px;font-weight:600;color:#555">5c) Occupation of Injured at Time of Accident</div>' +
    '<div style="font-size:13px;color:#333;margin-top:2px">' + esc(entry.injured_occupation || '\u2014') +
    (entry.job_task_performed ? '<br><span style="color:#888;font-size:12px">Task being performed: ' + esc(entry.job_task_performed) + '</span>' : '') +
    '</div></div>';

  sec5 += '<div style="margin-bottom:10px">' +
    '<div style="font-size:12px;font-weight:600;color:#555">5d) Level of Experience of Injured Person on the Job at Time of Injury</div>' +
    '<div style="font-size:13px;color:#333;margin-top:2px">' + esc(entry.work_experience || '\u2014') +
    (entry.employment_type ? '<br><span style="color:#888;font-size:12px">Employment type: ' + esc(entry.employment_type) + '</span>' : '') +
    '</div></div>';

  sec5 += '<div style="margin-bottom:4px">' +
    '<div style="font-size:12px;font-weight:600;color:#555">5e) Usual/Normal Occupation of Injured Person</div>' +
    '<div style="font-size:13px;color:#333;margin-top:2px">' + esc(entry.injured_occupation || entry.nature_of_work || '\u2014') + '</div></div>';

  sec5 += '</div>';

  var sections = '';

  sections += '<div class="rec-section"><div class="rec-section-header investigation">\U0001f4dd Investigation Details</div><div class="rec-section-body">' +
    f('Inv. Reference No', entry.inv_ref_no) + f('Case No', entry.case_no) + f('District', entry.inv_district) +
    f('Lead Investigator', entry.lead_investigator || entry.investigator_name) + f('Inv. Status', entry.inv_status) +
    f('Date Opened', fmtDate(entry.date_opened)) + f('Date Closed', fmtDate(entry.date_closed)) + '</div></div>';

  sections += '<div class="rec-section"><div class="rec-section-header employer">\U0001f3e2 Employer Information</div><div class="rec-section-body">' +
    f('Employer Name', entry.employer_name) + f('Sector', entry.employer_sector) + f('Contact Person', entry.contact_person) +
    f('Contact Position', entry.contact_position) + f('Plot', entry.employer_plot) + f('Street', entry.employer_street) +
    f('City', entry.employer_city) + f('District', entry.employer_district) + f('Postal', entry.employer_postal) +
    f('Phone', entry.employer_phone) + '</div></div>';

  sections += '<div class="rec-section"><div class="rec-section-header accident">\U0001f9d1 Injured Person Details &amp; Accident (Section 5)</div><div class="rec-section-body">' +
    f('Full Name', entry.injured_name) + f('Omang/Passport No.', entry.injured_id) + f('Date of Birth', fmtDate(entry.injured_dob)) +
    f('Phone', entry.injured_phone) + f('Home Address', entry.injured_address) +
    f('Nationality', entry.injured_nationality) + f('Sex', entry.sex) + f('Age Group', entry.age_group) +
    f('Marital Status', entry.marital_status) + f('Relationship to Employer', entry.injured_relationship) +
    sec5 + '</div></div>';

  sections += '<div class="rec-section"><div class="rec-section-header accident">\U0001f6a8 Incident Information</div><div class="rec-section-body">' +
    f('Date of Incident', fmtDate(entry.incident_date)) + f('Time', entry.incident_time) +
    f('Reported Date', fmtDate(entry.incident_reported_date)) + f('Location', entry.incident_location) +
    f('First Aid Given?', entry.first_aid_given) +
    f('Other Employees Injured', entry.other_injured_count) +
    f('Days Absent', entry.days_absent) +
    (entry.days_absent_count ? f('Number of Days', entry.days_absent_count) : '') +
    f('Description', entry.incident_description) +
    f('Summary', entry.incident_summary) + '</div></div>';

  sections += '<div class="rec-section"><div class="rec-section-header investigation">\U0001fa7a Injury Result</div><div class="rec-section-body">' +
    f('Fatal', entry.injury_result_fatal) +
    f('Non-Fatal', entry.injury_result_non_fatal) +
    f('Occupational Disease', entry.injury_result_occ_disease) +
    f('Absent From Work', entry.injury_result_absent) +
    f('Light Duty', entry.injury_result_light_duty) +
    f('Sick Leave', entry.injury_result_sick_leave) +
    f('Dangerous Occurrence', entry.injury_result_dangerous) + '</div></div>';

  var ov = document.createElement('div');
  ov.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.35);display:flex;align-items:center;justify-content:center;z-index:9999;padding:20px';
  ov.innerHTML = '<div style="background:#fff;border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,0.18);width:100%;max-width:640px;max-height:85vh;overflow-y:auto;padding:28px 26px;font-family:inherit">' +
    '<div style="font-size:32px;text-align:center;margin-bottom:8px">\U0001f4dd</div>' +
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
      var matches = (e.employer_name || '').toLowerCase().includes(search) ||
        (e.injured_name || '').toLowerCase().includes(search) ||
        (e.inv_ref_no || '').toLowerCase().includes(search);
      if (!matches) return false;
    }
    return true;
  });
  renderForm19Table(filtered);
}