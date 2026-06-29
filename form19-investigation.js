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
  window.location.href = 'OHS_Form19_Full.html?id=' + id + '&view=1';
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