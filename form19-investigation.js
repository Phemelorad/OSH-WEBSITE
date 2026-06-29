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
  
  function esc(s) { return s != null ? String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;') : ''; }
  function fmtDate(d) { if (!d) return ''; try { var dt = new Date(d); return isNaN(dt.getTime()) ? d : dt.toISOString().split('T')[0]; } catch(e) { return d; } }
  function inp(type, val) { return '<input type="' + type + '" value="' + esc(val != null ? val : '') + '" disabled>'; }
  function ta(val) { return '<textarea disabled style="min-height:50px">' + esc(val != null ? val : '') + '</textarea>'; }
  function sel(val, opts) { var h = '<select disabled>'; opts.forEach(function(o) { h += '<option' + (val === o ? ' selected' : '') + '>' + esc(o) + '</option>'; }); h += '</select>'; return h; }
  function fg(label, inputHtml) { return '<div class="form-group"><label>' + label + '</label>' + inputHtml + '</div>'; }
  function section_(title) { return '<div class="section-title">' + title + '</div>'; }
  
  // Build form-like content
  var html = '<div class="rec-form-modal" style="background:white;border-radius:12px;display:flex;flex-direction:column;max-height:90vh;width:95%;max-width:1000px">';
  html += '<div class="rec-modal-header" style="flex-shrink:0;display:flex;justify-content:space-between;align-items:center;padding:16px 24px;border-bottom:1px solid #e0e0e0;background:white">';
  html += '<div><h2 style="margin:0;font-size:18px">OHS Form 19 — Investigation Report</h2><div class="subtitle" style="font-size:12px;color:#888">' + esc(entry.inv_ref_no || entry.case_no || '') + '</div></div>';
  html += '<div class="rec-modal-actions"><button class="rec-modal-btn print" onclick="window.print()">\🖨️ Print</button>';
  html += '<button class="rec-modal-close" id="recFormCloseBtn" style="width:32px;height:32px;border-radius:50%;border:none;background:#f5f5f5;cursor:pointer;font-size:18px">\u2715</button></div></div>';
  html += '<div class="form-view-body" style="flex:1;overflow-y:auto;background:#f5f5f5">';
  html += '<div class="form-card"><div class="form-header"><h1>Investigation Report</h1><div class="subtitle">OHS Form 19 — Occupational Health and Safety</div></div>';
  
  // Section 1: Investigation Administration
  html += section_('1. Investigation Administration');
  html += '<div class="form-row form-row-2">' + fg('Investigation Ref No.', inp('text', entry.inv_ref_no)) + fg('Case No.', inp('text', entry.case_no)) + '</div>';
  html += '<div class="form-row form-row-2">' + fg('District', inp('text', entry.inv_district)) + fg('Lead Investigator', inp('text', entry.lead_investigator || entry.investigator_name)) + '</div>';
  html += '<div class="form-row form-row-3">' + fg('Date Assigned', inp('date', entry.date_assigned)) + fg('Date Opened', inp('date', entry.date_opened)) + fg('Date Closed', inp('date', entry.date_closed)) + '</div>';
  html += '<div class="form-row">' + fg('Investigation Status', sel(entry.inv_status || '', ['open', 'in-progress', 'closed', 'reopened'])) + '</div>';
  html += fg('Investigation Team', ta(entry.inv_team));
  
  // Section 2: Employer Information
  html += section_('2. Employer Information');
  html += '<div class="form-row form-row-2">' + fg('Name of Employer', inp('text', entry.employer_name)) + fg('Company Registration', inp('text', entry.company_reg_no)) + '</div>';
  html += '<div class="form-row form-row-4" style="grid-template-columns:repeat(4,1fr)">' + fg('District', inp('text', entry.employer_district)) + fg('City/Town', inp('text', entry.employer_city)) + fg('Plot No.', inp('text', entry.employer_plot)) + fg('Street', inp('text', entry.employer_street)) + '</div>';
  html += '<div class="form-row form-row-2">' + fg('Postal Address', inp('text', entry.employer_postal)) + fg('Telephone', inp('text', entry.employer_phone)) + '</div>';
  html += '<div class="form-row form-row-2">' + fg('Sector', sel(entry.employer_sector || '', ['agriculture','construction','manufacturing','mining','retail','services','transport','hospitality','healthcare','other'])) + fg('Nature of Work', inp('text', entry.nature_of_work)) + '</div>';
  html += '<div class="form-row form-row-2">' + fg('Contact Person', inp('text', entry.contact_person)) + fg('Position', inp('text', entry.contact_position)) + '</div>';
  
  // Section 3: Injured Person
  html += section_('3. Injured/Deceased Person(s) Information');
  html += '<div class="form-row form-row-2">' + fg('Full Name', inp('text', entry.injured_name)) + fg('Omang/Passport', inp('text', entry.injured_id)) + '</div>';
  html += '<div class="form-row form-row-3">' + fg('Date of Birth', inp('date', entry.injured_dob)) + fg('Nationality', inp('text', entry.injured_nationality)) + fg('Telephone', inp('text', entry.injured_phone)) + '</div>';
  html += '<div class="form-row form-row-2">' + fg('Sex', sel(entry.sex || '', ['male','female'])) + fg('Age Group', sel(entry.age_group || '', ['under-25','25-34','35-44','45-54','55-64','65-plus'])) + '</div>';
  html += '<div class="form-row form-row-2">' + fg('Marital Status', sel(entry.marital_status || '', ['married','single','divorced','widowed'])) + fg('Employment Type', sel(entry.employment_type || '', ['full-time','part-time','temporary','seasonal','other'])) + '</div>';
  html += '<div class="form-row form-row-2">' + fg('Occupation', inp('text', entry.injured_occupation)) + fg('Relationship to Employer', inp('text', entry.injured_relationship)) + '</div>';
  html += fg('Home Address', ta(entry.injured_address));
  
  // Section 4: Incident / Accident Information
  html += section_('4. Incident/Accident Information');
  html += '<div class="form-row form-row-3">' + fg('Date of Incident', inp('date', entry.incident_date)) + fg('Time', inp('time', entry.incident_time)) + fg('Reported Date', inp('date', entry.incident_reported_date)) + '</div>';
  html += '<div class="form-row">' + fg('Location', inp('text', entry.incident_location)) + '</div>';
  html += fg('Description of Incident', ta(entry.incident_description));
  html += fg('Summary', ta(entry.incident_summary));
  
  // Section 5: Accident Details
  html += section_('5. Accident Details (Per Injured Person)');
  html += '<div class="form-row form-row-2">' + fg('Occupation at Time', inp('text', entry.injured_occupation)) + fg('Task Being Performed', inp('text', entry.job_task_performed)) + '</div>';
  html += '<div class="form-row form-row-2">' + fg('Work Experience', inp('text', entry.work_experience)) + fg('Employment Type', inp('text', entry.employment_type)) + '</div>';
  html += fg('Equipment Used / Machinery Involved', ta(entry.equipment_used));
  
  // Section 6: Injury Result
  html += section_('6. Injury Result');
  html += '<div class="form-row form-row-3">' + fg('Fatal', sel(entry.injury_result_fatal||'', ['Yes','No'])) + fg('Non-Fatal', sel(entry.injury_result_non_fatal||'', ['Yes','No'])) + fg('Occupational Disease', sel(entry.injury_result_occ_disease||'', ['Yes','No'])) + '</div>';
  html += '<div class="form-row form-row-3">' + fg('Absent From Work', sel(entry.injury_result_absent||'', ['Yes','No'])) + fg('Light Duty', sel(entry.injury_result_light_duty||'', ['Yes','No'])) + fg('Sick Leave', sel(entry.injury_result_sick_leave||'', ['Yes','No'])) + '</div>';
  html += '<div class="form-row">' + fg('Dangerous Occurrence', sel(entry.injury_result_dangerous||'', ['Yes','No'])) + '</div>';
  
  html += '<div class="form-row form-row-2">' + fg('First Aid Given?', inp('text', entry.first_aid_given)) + fg('Other Employees Injured', inp('number', entry.other_injured_count)) + '</div>';
  html += '<div class="form-row form-row-2">' + fg('Days Absent', inp('text', entry.days_absent)) + fg('Days Absent Count', inp('number', entry.days_absent_count)) + '</div>';
  
  html += '</div></div></div>';
  
  var ov = document.createElement('div');
  ov.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.35);display:flex;align-items:center;justify-content:center;z-index:9999;padding:20px';
  ov.innerHTML = html;
  ov.querySelector('#recFormCloseBtn').addEventListener('click', function() { ov.remove(); });
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