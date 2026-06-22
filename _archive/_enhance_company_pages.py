#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, sys

# Set stdout to utf-8
sys.stdout.reconfigure(encoding='utf-8')

WEBSITE = r"C:\Users\26772\osh website"

def read_file(name):
    with open(os.path.join(WEBSITE, name), 'r', encoding='utf-8') as f:
        return f.read()

def write_file(name, content):
    with open(os.path.join(WEBSITE, name), 'w', encoding='utf-8') as f:
        f.write(content)

pagination_css = """
/* Pagination */
.pagination-controls { display:flex; justify-content:space-between; align-items:center; padding-top:16px; margin-top:8px; border-top:1px solid #f0f0f0; flex-wrap:wrap; gap:12px; }
.pagination-info { font-size:13px; color:#888; }
.pagination-buttons { display:flex; gap:6px; align-items:center; }
.pagination-buttons button { padding:6px 14px; background:#fff; color:#333; border:1px solid #ddd; border-radius:6px; cursor:pointer; font-size:13px; font-family:inherit; transition:all 0.2s; }
.pagination-buttons button:hover:not(:disabled) { background:#f0f0f0; }
.pagination-buttons button:disabled { opacity:0.4; cursor:not-allowed; }
.pagination-buttons button.active { background:#333; color:#fff; border-color:#333; }
.page-size-select { padding:6px 10px; border:1px solid #ddd; border-radius:6px; font-size:13px; font-family:inherit; margin-left:8px; }
.export-btn { padding:8px 16px; background:linear-gradient(135deg,#fff 0%,#f8f8f8 100%); color:#333; border:2px solid #ddd; border-radius:8px; cursor:pointer; font-weight:600; transition:all 0.3s; font-size:13px; font-family:inherit; }
.export-btn:hover { transform:translateY(-2px); box-shadow:0 4px 10px rgba(0,0,0,0.1); }
"""

# ══════════════════════════════════════════════════════════════
# 1. ENHANCE company-accidents-view.html
# ══════════════════════════════════════════════════════════════

print("=== Enhancing company-accidents-view.html ===")
acc = read_file("company-accidents-view.html")

# 1a. Add pagination CSS before @media
acc = acc.replace("@media (max-width:768px)", pagination_css + "\n@media (max-width:768px)")

# 1b. Add Export button to filters
old_filters = """<input type="text" id="filterSearch" placeholder="Worker / Case #..." oninput="applyFilters()" style="width:160px">
</div>
<button class="refresh-btn" onclick="loadData()">Refresh</button>"""

new_filters = """<input type="text" id="filterSearch" placeholder="Worker / Case #..." oninput="applyFilters()" style="width:160px">
</div>
<button class="refresh-btn" onclick="loadData()">Refresh</button>
<button class="export-btn" onclick="exportCSV()">Export CSV</button>"""

acc = acc.replace(old_filters, new_filters)

# 1c. Add Investigation filter
old_fatal_filter = """<select id="filterFatal" onchange="applyFilters()">
<option value="">All</option>
<option value="Fatal">Fatal</option>
<option value="Non-fatal">Non-fatal</option>
</select>
</div>"""

new_fatal_filter = """<select id="filterFatal" onchange="applyFilters()">
<option value="">All</option>
<option value="Fatal">Fatal</option>
<option value="Non-fatal">Non-fatal</option>
</select>
</div>
<div class="filter-group">
<label>Investigation</label>
<select id="filterInv" onchange="applyFilters()">
<option value="">All Statuses</option>
<option value="Pending">Pending</option>
<option value="In Progress">In Progress</option>
<option value="Completed">Completed</option>
<option value="Closed">Closed</option>
</select>
</div>"""

acc = acc.replace(old_fatal_filter, new_fatal_filter)

# 1d. Add pagination controls
old_empty = """<div id="emptyState" class="empty-state" style="display:none"><p>No accident reports found for your company</p></div>
<div class="row-count" id="rowCount"></div>"""

new_empty = """<div id="emptyState" class="empty-state" style="display:none"><p>No accident reports found for your company</p></div>
<div class="pagination-controls" id="paginationControls" style="display:none">
<div class="pagination-info" id="paginationInfo"></div>
<div class="pagination-buttons">
<span style="font-size:12px;color:#888">Rows:</span>
<select class="page-size-select" id="pageSizeSelect" onchange="changePageSize()">
<option value="25">25</option>
<option value="50" selected>50</option>
<option value="100">100</option>
<option value="250">250</option>
</select>
<button onclick="goToPage(1)" id="firstPageBtn" title="First">&laquo;</button>
<button onclick="goToPage(currentPage - 1)" id="prevPageBtn" title="Previous">&lsaquo;</button>
<span id="pageNumbers"></span>
<button onclick="goToPage(currentPage + 1)" id="nextPageBtn" title="Next">&rsaquo;</button>
<button onclick="goToPage(totalPages)" id="lastPageBtn" title="Last">&raquo;</button>
</div>
</div>
<div class="row-count" id="rowCount"></div>"""

acc = acc.replace(old_empty, new_empty)

# 1e. Update applyFilters with investigation filter + pagination
old_apply = """function applyFilters() {
    const type = document.getElementById('filterType').value;
    const fatal = document.getElementById('filterFatal').value;
    const search = document.getElementById('filterSearch').value.toLowerCase().trim();
    renderTable(allRecords.filter(r =>
        (!type || r.report_type === type) &&
        (!fatal || r.injury_fatal === fatal) &&
        (!search || (r.injured_name||'').toLowerCase().includes(search) || (r.accident_case_number||'').toLowerCase().includes(search) || (r._persons||[]).some(function(p){return (p.full_name||'').toLowerCase().includes(search)}))
    ));
}"""

new_apply = """function applyFilters() {
    const type = document.getElementById('filterType').value;
    const fatal = document.getElementById('filterFatal').value;
    const inv = document.getElementById('filterInv').value;
    const search = document.getElementById('filterSearch').value.toLowerCase().trim();
    const filtered = allRecords.filter(r =>
        (!type || r.report_type === type) &&
        (!fatal || r.injury_fatal === fatal) &&
        (!inv || r.investigation_status === inv) &&
        (!search || (r.injured_name||'').toLowerCase().includes(search) || (r.accident_case_number||'').toLowerCase().includes(search) || (r._persons||[]).some(function(p){return (p.full_name||'').toLowerCase().includes(search)}))
    );
    applyPagination(filtered);
}"""

acc = acc.replace(old_apply, new_apply)

# 1f. Update renderTable to add Status button
old_render = """function renderTable(rows) {
    const tbody = document.getElementById('tableBody');
    const empty = document.getElementById('emptyState');
    document.getElementById('rowCount').textContent = rows.length ? `Showing ${rows.length} record${rows.length !== 1 ? 's' : ''}` : '';
    if (!rows.length) { tbody.innerHTML = ''; empty.style.display = 'block'; return; }
    empty.style.display = 'none';
    tbody.innerHTML = rows.map(r => {
        const typeSlug = (r.report_type || '').replace('_','-');
        const invSlug = (r.investigation_status || 'submitted').toLowerCase().replace(' ','_');
        return `<tr>
        <td><span style="font-size:12px;color:#0c5460;font-weight:600">${r.accident_case_number || '-'}</span></td>
        <td><strong>${r.injured_name || '-'}</strong><br><small style="color:#aaa">${r.injured_id_number || ''}</small></td>
        <td>${r.industry_sector || r.nature_of_industry || '-'}</td>
        <td><span class="badge badge-${typeSlug}">${(r.report_type || '').replace('_',' ').toUpperCase()}</span></td>
        <td style="white-space:nowrap">${fmtDate(r.accident_date)}</td>
        <td style="max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${r.accident_place||''}">${r.accident_place || r.premises_address || '-'}</td>
        <td>${(r._fatal_count || r.fatal_count) > 0 ? '<span class="badge badge-fatal">Fatal</span>' : (r.injury_fatal === 'Fatal' ? '<span class="badge badge-fatal">Fatal</span>' : '<span class="badge badge-non-fatal">Non-fatal</span>')}</td>
        <td><span class="badge badge-${invSlug}">${r.investigation_status || 'Pending'}</span></td>
        <td style="white-space:nowrap">${fmtDate(r.report_date)}</td>
        <td style="white-space:nowrap"><button class="action-btn" onclick="viewRecord('${r.id}')\">View</button></td>
        </tr>`;
    }).join('');
}"""

new_render = """function renderTable(rows) {
    const tbody = document.getElementById('tableBody');
    const empty = document.getElementById('emptyState');
    document.getElementById('rowCount').textContent = rows.length ? `Showing ${rows.length} record${rows.length !== 1 ? 's' : ''}` : '';
    if (!rows.length) { tbody.innerHTML = ''; empty.style.display = 'block'; return; }
    empty.style.display = 'none';
    tbody.innerHTML = rows.map(r => {
        const typeSlug = (r.report_type || '').replace('_','-');
        const invSlug = (r.investigation_status || 'submitted').toLowerCase().replace(' ','_');
        return `<tr>
        <td><span style="font-size:12px;color:#0c5460;font-weight:600">${r.accident_case_number || '-'}</span></td>
        <td><strong>${r.injured_name || '-'}</strong><br><small style="color:#aaa">${r.injured_id_number || ''}</small></td>
        <td>${r.industry_sector || r.nature_of_industry || '-'}</td>
        <td><span class="badge badge-${typeSlug}">${(r.report_type || '').replace('_',' ').toUpperCase()}</span></td>
        <td style="white-space:nowrap">${fmtDate(r.accident_date)}</td>
        <td style="max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${r.accident_place||''}">${r.accident_place || r.premises_address || '-'}</td>
        <td>${(r._fatal_count || r.fatal_count) > 0 ? '<span class="badge badge-fatal">Fatal</span>' : (r.injury_fatal === 'Fatal' ? '<span class="badge badge-fatal">Fatal</span>' : '<span class="badge badge-non-fatal">Non-fatal</span>')}</td>
        <td><span class="badge badge-${invSlug}">${r.investigation_status || 'Pending'}</span></td>
        <td style="white-space:nowrap">${fmtDate(r.report_date)}</td>
        <td style="white-space:nowrap">
            <button class="action-btn" onclick="viewRecord('${r.id}')\">View</button>
            <button class="action-btn" onclick="editInvestigation('${r.id}','${r.investigation_status||'Pending'}','${r.submitted_by||''}')\">Status</button>
        </td>
        </tr>`;
    }).join('');
}"""

acc = acc.replace(old_render, new_render)

# 1g. Update loadData to use pagination
old_load_end = """    allRecords = data || [];
    buildStats(allRecords);
    renderTable(allRecords);
    document.getElementById('loadingState').style.display = 'none';
    document.getElementById('tableWrap').style.display = 'block';"""

new_load_end = """    allRecords = data || [];
    buildStats(allRecords);
    applyPagination(allRecords);
    document.getElementById('loadingState').style.display = 'none';
    document.getElementById('tableWrap').style.display = 'block';"""

acc = acc.replace(old_load_end, new_load_end)

# 1h. Replace fmtDate with enhanced functions
old_fmt = """function fmtDate(d) {
    if (!d) return '-';
    return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' });
}
</script>"""

new_functions = """
async function editInvestigation(id, current, ownerId) {
    if (typeof canEditClaims === 'function' && !canEditClaims(ownerId)) {
        showPermissionDenied('edit this report'); return;
    }
    const newStatus = await showSelect(
        'Current: <strong>' + current + '</strong>',
        [{ value:'Pending', label:'Pending' }, { value:'In Progress', label:'In Progress' }, { value:'Completed', label:'Completed' }, { value:'Closed', label:'Closed' }],
        current,
        { title: 'Update Investigation Status', confirmText: 'Update' }
    );
    if (!newStatus || newStatus === current) return;
    const { error } = await SB.from('accident_reports').update({ investigation_status: newStatus }).eq('id', id);
    if (error) { await showAlert(error.message, { type:'error', title:'Update Failed' }); return; }
    showToast('Investigation status updated', 'success');
    allRecords = allRecords.map(r => r.id === id ? { ...r, investigation_status: newStatus } : r);
    applyFilters();
}

function exportCSV() {
    const headers = ['Accident #','Occupier','Industry','Report Type','Injured Name','Age','Sex','ID No','Occupation','Accident Date','Place','Fatal','Disabled 3+ Days','Investigation','Reporter','Report Date','Causation No'];
    const rows = allRecords.map(r => [
        r.accident_case_number, r.occupier_name, r.industry_sector, r.report_type,
        r.injured_name, r.injured_age, r.injured_sex, r.injured_id_number,
        r.occupation_at_accident, r.accident_date, r.accident_place, r.injury_fatal,
        r.disabled_three_days, r.investigation_status, r.reporter_name, r.report_date, r.causation_number
    ]);
    const csv = [headers, ...rows].map(r => r.map(c => '"' + (c||'') + '"').join(',')).join('\\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([csv], { type:'text/csv' }));
    a.download = 'accident_reports_' + new Date().toISOString().split('T')[0] + '.csv';
    a.click();
    URL.revokeObjectURL(a.href);
}

// Pagination
let currentPage = 1;
let pageSize = 50;
let totalPages = 1;
let paginatedRecords = [];

function applyPagination(records) {
    currentPage = 1;
    paginatedRecords = records;
    totalPages = Math.ceil(records.length / pageSize) || 1;
    renderPage();
}

function renderPage() {
    const start = (currentPage - 1) * pageSize;
    const end = Math.min(start + pageSize, paginatedRecords.length);
    renderTable(paginatedRecords.slice(start, end));
    updatePaginationControls();
    const ctrl = document.getElementById("paginationControls");
    if (ctrl) ctrl.style.display = paginatedRecords.length > 0 ? "flex" : "none";
}

function updatePaginationControls() {
    const pi = document.getElementById("paginationInfo");
    if (pi) {
        pi.textContent = paginatedRecords.length > 0
            ? "Showing " + ((currentPage-1)*pageSize+1) + "-" + Math.min(currentPage*pageSize, paginatedRecords.length) + " of " + paginatedRecords.length + " records"
            : "No records";
    }
    ["firstPageBtn","prevPageBtn","nextPageBtn","lastPageBtn"].forEach(function(id) {
        var el = document.getElementById(id);
        if (el) el.disabled = true;
    });
    var fp = document.getElementById("firstPageBtn"); if(fp) fp.disabled = currentPage <= 1;
    var pp = document.getElementById("prevPageBtn"); if(pp) pp.disabled = currentPage <= 1;
    var np = document.getElementById("nextPageBtn"); if(np) np.disabled = currentPage >= totalPages;
    var lp = document.getElementById("lastPageBtn"); if(lp) lp.disabled = currentPage >= totalPages;
    var pn = document.getElementById("pageNumbers");
    if (pn) {
        var html = "";
        var startP = Math.max(1, currentPage - 2);
        var endP = Math.min(totalPages, startP + 4);
        if (endP - startP < 4) startP = Math.max(1, endP - 4);
        for (var i = startP; i <= endP; i++) {
            html += '<button class="' + (i === currentPage ? 'active' : '') + '" onclick="goToPage(' + i + ')">' + i + '</button>';
        }
        pn.innerHTML = html;
    }
}

function goToPage(page) {
    if (page < 1 || page > totalPages) return;
    currentPage = page;
    renderPage();
    var tc = document.querySelector('.table-container');
    if (tc) tc.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function changePageSize() {
    pageSize = parseInt(document.getElementById('pageSizeSelect').value) || 50;
    totalPages = Math.ceil(paginatedRecords.length / pageSize) || 1;
    currentPage = 1;
    renderPage();
}

function fmtDate(d) {
    if (!d) return '-';
    return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' });
}
</script>"""

acc = acc.replace(old_fmt, new_functions)
write_file("company-accidents-view.html", acc)
print("[OK] company-accidents-view.html enhanced")

# ══════════════════════════════════════════════════════════════
# 2. ENHANCE company-injuries-view.html
# ══════════════════════════════════════════════════════════════

print("=== Enhancing company-injuries-view.html ===")
inj = read_file("company-injuries-view.html")

# 2a. Add pagination CSS
inj = inj.replace("@media (max-width:768px)", pagination_css + "\n@media (max-width:768px)")

# 2b. Add Export button
old_inj_filters = """<input type="text" id="filterSearch" placeholder="Worker name..." oninput="applyFilters()" style="width:160px">
</div>
<button class="refresh-btn" onclick="loadData()">Refresh</button>"""

new_inj_filters = """<input type="text" id="filterSearch" placeholder="Worker / Employer..." oninput="applyFilters()" style="width:160px">
</div>
<button class="refresh-btn" onclick="loadData()">Refresh</button>
<button class="export-btn" onclick="exportCSV()">Export CSV</button>"""

inj = inj.replace(old_inj_filters, new_inj_filters)

# 2c. Add Status filter
old_inj_fatal = """<select id="filterDeath" onchange="applyFilters()">
<option value="">All</option>
<option value="Yes">Fatal (Yes)</option>
<option value="No">Non-Fatal (No)</option>
</select>
</div>"""

new_inj_fatal = """<select id="filterDeath" onchange="applyFilters()">
<option value="">All</option>
<option value="Yes">Fatal (Yes)</option>
<option value="No">Non-Fatal (No)</option>
</select>
</div>
<div class="filter-group">
<label>Status</label>
<select id="filterStatus" onchange="applyFilters()">
<option value="">All Statuses</option>
<option value="submitted">Submitted</option>
<option value="under_review">Under Review</option>
<option value="processed">Processed</option>
<option value="closed">Closed</option>
</select>
</div>"""

inj = inj.replace(old_inj_fatal, new_inj_fatal)

# 2d. Add Employer and Report Date columns to table header
old_inj_header = """<th>Worker</th>
<th>Occupation</th>
<th>Type</th>"""

new_inj_header = """<th>Worker</th>
<th>Occupation</th>
<th>Employer</th>
<th>Type</th>"""

inj = inj.replace(old_inj_header, new_inj_header)

old_inj_header2 = """<th>Temp. Incap.</th>
<th>Status</th>
<th>Actions</th>"""

new_inj_header2 = """<th>Temp. Incap.</th>
<th>Status</th>
<th>Report Date</th>
<th>Actions</th>"""

inj = inj.replace(old_inj_header2, new_inj_header2)

# 2e. Add pagination controls
old_inj_empty = """<div id="emptyState" class="empty-state" style="display:none"><p>No injury or disease reports found for your company</p></div>
<div class="row-count" id="rowCount"></div>"""

new_inj_empty = """<div id="emptyState" class="empty-state" style="display:none"><p>No injury or disease reports found for your company</p></div>
<div class="pagination-controls" id="paginationControls" style="display:none">
<div class="pagination-info" id="paginationInfo"></div>
<div class="pagination-buttons">
<span style="font-size:12px;color:#888">Rows:</span>
<select class="page-size-select" id="pageSizeSelect" onchange="changePageSize()">
<option value="25">25</option>
<option value="50" selected>50</option>
<option value="100">100</option>
<option value="250">250</option>
</select>
<button onclick="goToPage(1)" id="firstPageBtn" title="First">&laquo;</button>
<button onclick="goToPage(currentPage - 1)" id="prevPageBtn" title="Previous">&lsaquo;</button>
<span id="pageNumbers"></span>
<button onclick="goToPage(currentPage + 1)" id="nextPageBtn" title="Next">&rsaquo;</button>
<button onclick="goToPage(totalPages)" id="lastPageBtn" title="Last">&raquo;</button>
</div>
</div>
<div class="row-count" id="rowCount"></div>"""

inj = inj.replace(old_inj_empty, new_inj_empty)

# 2f. Rewrite loadData - remove accident merging
old_inj_load = """async function loadData() {
    document.getElementById('loadingState').style.display = 'block';
    document.getElementById('tableWrap').style.display = 'none';
    
    console.log('[DEBUG] Querying injury_disease_reports with:', companyName);
    const words = companyName.split(' ').filter(w => w.length > 2);
    if (words.length === 0) words = [companyName];
    const injOrConditions = words.map(w => 'employer_name.ilike.*' + w + '*').join(',');
    const accOrConditions = words.map(w => 'occupier_name.ilike.*' + w + '*').join(',');
    
    const [injRes, accRes] = await Promise.all([
        SB.from('injury_disease_reports')
          .select('*')
          .or(injOrConditions)
          .order('incident_date', { ascending: false }),
        SB.from('accident_reports')
          .select('*')
          .or(accOrConditions)
          .order('accident_date', { ascending: false })
    ]);
    
    const injuries = (injRes.data || []).map(function(r) { return Object.assign({}, r, { _source: 'injury_report' }); });
    const accidents = (accRes.data || []).map(function(r) { return Object.assign({}, r, { _source: 'accident' }); });
    
    // Merge and sort by date (newest first)
    allRecords = injuries.concat(accidents).sort(function(a, b) {
        var da = new Date(a.incident_date || a.accident_date || 0);
        var db = new Date(b.incident_date || b.accident_date || 0);
        return db - da;
    });
    
    console.log('[DEBUG] Injury reports:', injuries.length, ', Accident-linked injuries:', accidents.length, ', Total:', allRecords.length);
    
    if (injRes.error) {
        document.getElementById('loadingState').innerHTML = '<p style="color:#e74c3c;padding:40px;text-align:center">Error loading: ' + injRes.error.message + '<br><button onclick="loadData()" style="margin-top:12px;padding:8px 20px;background:#333;color:white;border:none;border-radius:6px;cursor:pointer">Retry</button></p>';
        return;
    }
    if (accRes.error) {
        console.warn('Accident query error:', accRes.error.message);
    }
    
    buildStats(allRecords);
    renderTable(allRecords);
    document.getElementById('loadingState').style.display = 'none';
    document.getElementById('tableWrap').style.display = 'block';
}"""

new_inj_load = """async function loadData() {
    document.getElementById('loadingState').style.display = 'block';
    document.getElementById('tableWrap').style.display = 'none';
    
    console.log('[DEBUG] Querying injury_disease_reports with:', companyName);
    const words = companyName.split(' ').filter(w => w.length > 2);
    if (words.length === 0) words = [companyName];
    const orConditions = words.map(w => 'employer_name.ilike.*' + w + '*').join(',');
    
    const { data, error } = await SB
        .from('injury_disease_reports')
        .select('*')
        .or(orConditions)
        .order('incident_date', { ascending: false });
    
    console.log('[DEBUG] Results:', data?.length || 0, 'rows, error:', error?.message || 'OK');
    if (data && data.length > 0) console.log('[DEBUG] Sample:', JSON.stringify(data[0]).slice(0,200));
    
    if (error) {
        document.getElementById('loadingState').innerHTML = '<p style="color:#e74c3c;padding:40px;text-align:center">Error: ' + error.message + '<br><button onclick="loadData()" style="margin-top:12px;padding:8px 20px;background:#333;color:white;border:none;border-radius:6px;cursor:pointer">Retry</button></p>';
        return;
    }
    
    allRecords = data || [];
    buildStats(allRecords);
    applyPagination(allRecords);
    document.getElementById('loadingState').style.display = 'none';
    document.getElementById('tableWrap').style.display = 'block';
}"""

inj = inj.replace(old_inj_load, new_inj_load)

# 2g. Rewrite buildStats
old_inj_stats = """function buildStats(rows) {
    const now = new Date(), month = new Date(now.getFullYear(), now.getMonth(), 1);
    document.getElementById('statTotal').textContent = rows.length;
    document.getElementById('statInjury').textContent = rows.filter(function(r) { return r._source === 'accident' || r.incident_type === 'Injury'; }).length;
    document.getElementById('statDisease').textContent = rows.filter(function(r) { return r.incident_type === 'Disease'; }).length;
    document.getElementById('statDeath').textContent = rows.filter(function(r) { return r.resulted_death === 'Yes' || r.injury_fatal === 'Fatal'; }).length;
    document.getElementById('statMonth').textContent = rows.filter(function(r) {
        var d = new Date(r.incident_date || r.accident_date || r.created_at);
        return d >= month;
    }).length;
}"""

new_inj_stats = """function buildStats(rows) {
    const now = new Date(), month = new Date(now.getFullYear(), now.getMonth(), 1);
    document.getElementById('statTotal').textContent = rows.length;
    document.getElementById('statInjury').textContent = rows.filter(function(r) { return r.incident_type === 'Injury'; }).length;
    document.getElementById('statDisease').textContent = rows.filter(function(r) { return r.incident_type === 'Disease'; }).length;
    document.getElementById('statDeath').textContent = rows.filter(function(r) { return r.resulted_death === 'Yes'; }).length;
    document.getElementById('statMonth').textContent = rows.filter(function(r) {
        var d = new Date(r.incident_date || r.created_at);
        return d >= month;
    }).length;
}"""

inj = inj.replace(old_inj_stats, new_inj_stats)

# 2h. Rewrite applyFilters
old_inj_filter = """function applyFilters() {
    const type = document.getElementById('filterType').value;
    const death = document.getElementById('filterDeath').value;
    const search = document.getElementById('filterSearch').value.toLowerCase().trim();
    renderTable(allRecords.filter(function(r) {
        var isAcc = r._source === 'accident';
        var rType = isAcc ? 'Accident Injury' : (r.incident_type || 'Injury');
        var rDeath = isAcc ? r.injury_fatal : r.resulted_death;
        var rName = (isAcc ? r.injured_name : r.worker_name) || '';
        return (!type || rType === type) &&
               (!death || rDeath === death) &&
               (!search || rName.toLowerCase().includes(search));
    }));
}"""

new_inj_filter = """function applyFilters() {
    const type = document.getElementById('filterType').value;
    const death = document.getElementById('filterDeath').value;
    const status = document.getElementById('filterStatus').value;
    const search = document.getElementById('filterSearch').value.toLowerCase().trim();
    const filtered = allRecords.filter(function(r) {
        return (!type || r.incident_type === type) &&
               (!death || r.resulted_death === death) &&
               (!status || r.status === status) &&
               (!search || (r.worker_name||'').toLowerCase().includes(search) || (r.employer_name||'').toLowerCase().includes(search));
    });
    applyPagination(filtered);
}"""

inj = inj.replace(old_inj_filter, new_inj_filter)

# 2i. Rewrite renderTable
old_inj_render = """function renderTable(rows) {
    const tbody = document.getElementById('tableBody');
    const empty = document.getElementById('emptyState');
    document.getElementById('rowCount').textContent = rows.length ? `Showing ${rows.length} record${rows.length !== 1 ? 's' : ''}` : '';
    if (!rows.length) { tbody.innerHTML = ''; empty.style.display = 'block'; return; }
    empty.style.display = 'none';
    tbody.innerHTML = rows.map(r => {
        const isAcc = r._source === 'accident';
        const workerName = isAcc ? r.injured_name : r.worker_name;
        const workerId   = isAcc ? r.injured_id_number : r.worker_id_number;
        const occupation = isAcc ? r.occupation_at_accident : r.occupation;
        const incType    = isAcc ? 'Accident Injury' : (r.incident_type || 'Injury');
        const typeSlug   = incType.toLowerCase().replace(/ /g,'_');
        const statusSlug = (r.status || 'submitted').toLowerCase().replace(' ','_');
        const incDate    = isAcc ? r.accident_date : r.incident_date;
        const incPlace   = isAcc ? r.accident_place : r.place_of_accident;
        const incNature  = isAcc ? r.accident_description : r.nature_of_injuries;
        const nature     = (incNature || '').length > 60 ? incNature.substring(0,60) + '...' : (incNature || '-');
        const death      = isAcc ? r.injury_fatal : r.resulted_death;
        const deathBadge = death === 'Fatal' ? 'Fatal' : 'No';
        const permIncap  = isAcc ? (r.disabled_three_days === 'Yes' ? 'Yes' : 'No') : (r.permanent_incapacity || 'No');
        const tempIncap  = isAcc ? (r.disabled_three_days === 'Yes' ? 'Yes' : 'No') : (r.temporary_incapacity || 'No');
        const sourceBadge = isAcc
            ? '<span class="badge badge-accident" style="background:#d1ecf1;color:#0c5460">From Accident</span>'
            : '<span class="badge badge-injury">Injury Report</span>';
        return `<tr>
        <td><strong>${workerName || '-'}</strong><br><small style="color:#aaa">${workerId || ''}</small></td>
        <td>${occupation || '-'}</td>
        <td>${sourceBadge}</td>
        <td><span class="badge badge-${typeSlug}">${incType}</span></td>
        <td style="white-space:nowrap">${fmtDate(incDate)}</td>
        <td>${incPlace || '-'}</td>
        <td style="max-width:200px" title="${incNature||''}">${nature}</td>
        <td><span class="badge badge-${deathBadge.toLowerCase()}">${deathBadge}</span></td>
        <td><span class="badge badge-${permIncap.toLowerCase()}">${permIncap}</span></td>
        <td><span class="badge badge-${tempIncap.toLowerCase()}">${tempIncap}</span></td>
        <td><span class="badge badge-${statusSlug}">${r.status || 'submitted'}</span></td>
        <td style="white-space:nowrap"><button class="action-btn" onclick="viewRecord('${r.id}')\">View</button></td>
        </tr>`;
    }).join('');
}"""

new_inj_render = """function renderTable(rows) {
    const tbody = document.getElementById('tableBody');
    const empty = document.getElementById('emptyState');
    document.getElementById('rowCount').textContent = rows.length ? `Showing ${rows.length} record${rows.length !== 1 ? 's' : ''}` : '';
    if (!rows.length) { tbody.innerHTML = ''; empty.style.display = 'block'; return; }
    empty.style.display = 'none';
    tbody.innerHTML = rows.map(r => {
        const typeSlug   = (r.incident_type || 'injury').toLowerCase();
        const statusSlug = (r.status || 'submitted').toLowerCase().replace(' ','_');
        const nature     = (r.nature_of_injuries || '').length > 60 ? r.nature_of_injuries.substring(0,60) + '...' : (r.nature_of_injuries || '-');
        return `<tr>
        <td><strong>${r.worker_name || '-'}</strong><br><small style="color:#aaa">${r.worker_id_number || ''}</small></td>
        <td>${r.occupation || '-'}</td>
        <td>${r.employer_name || '-'}</td>
        <td><span class="badge badge-${typeSlug}">${r.incident_type || '-'}</span></td>
        <td style="white-space:nowrap">${fmtDate(r.incident_date)}</td>
        <td>${r.place_of_accident || '-'}</td>
        <td style="max-width:200px" title="${r.nature_of_injuries||''}">${nature}</td>
        <td><span class="badge badge-${(r.resulted_death||'No').toLowerCase()}">${r.resulted_death || 'No'}</span></td>
        <td><span class="badge badge-${(r.permanent_incapacity||'No').toLowerCase()}">${r.permanent_incapacity || 'No'}</span></td>
        <td><span class="badge badge-${(r.temporary_incapacity||'No').toLowerCase()}">${r.temporary_incapacity || 'No'}</span></td>
        <td><span class="badge badge-${statusSlug}">${r.status || 'submitted'}</span></td>
        <td style="white-space:nowrap">${fmtDate(r.report_date)}</td>
        <td style="white-space:nowrap">
            <button class="action-btn" onclick="viewRecord('${r.id}')\">View</button>
            <button class="action-btn" onclick="editStatus('${r.id}','${r.status||'submitted'}','${r.submitted_by||''}')\">Status</button>
        </td>
        </tr>`;
    }).join('');
}"""

inj = inj.replace(old_inj_render, new_inj_render)

# 2j. Rewrite viewRecord - remove accident path
old_inj_view = """function viewRecord(id) {
    var r = allRecords.find(function(x) { return x.id === id; });
    if (!r) return;
    function f(label, val) { return val != null && val !== '' ? '<div class="rec-field"><span class="lbl">' + label + '</span><span class="val">' + val + '</span></div>' : ''; }
    
    if (r._source === 'accident') {
        // Accident-linked injury from accident_reports
        var workerSection = '<div class="rec-section"><div class="rec-section-header worker">Injured Worker Details</div><div class="rec-section-body">' +
            f('Full Name', r.injured_name) + f('Age', r.injured_age) + f('Gender', r.injured_sex) + f('ID / Passport', r.injured_id_number) +
            f('Occupation at Accident', r.occupation_at_accident) + f('Normal Occupation', r.usual_occupation) + f('Experience Level', r.experience_level) + '</div></div>';
        
        var accidentSection = '<div class="rec-section"><div class="rec-section-header incident">Accident Details</div><div class="rec-section-body">' +
            f('Date', fmtDate(r.accident_date)) + f('Time', r.accident_time) + f('Place', r.accident_place) +
            f('Description', r.accident_description) + f('Machinery Involved', r.machinery_involved) +
            f('Fatal?', r.injury_fatal) + f('Disabled 3+ Days', r.disabled_three_days) + '</div></div>';
        
        var employerSection = '<div class="rec-section"><div class="rec-section-header employer">Employer Details</div><div class="rec-section-body">' +
            f('Occupier', r.occupier_name) + f('Premises Address', r.premises_address) + f('Industry', r.nature_of_industry) +
            (r.industry_sector ? f('Sector', r.industry_sector) : '') + f('Case Number', r.accident_case_number) + '</div></div>';
        
        var reportSection = '<div class="rec-section"><div class="rec-section-header investigation">Investigation & Reporting</div><div class="rec-section-body">' +
            f('Reporter', r.reporter_name + (r.reporter_designation ? ' (' + r.reporter_designation + ')' : '')) +
            f('Report Date', fmtDate(r.report_date)) + f('Investigation Status', r.investigation_status) +
            f('Official Action', r.official_action) + '</div></div>';
        
        var modalHtml = '<div class="rec-modal">' +
            '<div class="rec-modal-header"><div><h2>Accident-Linked Injury</h2><div class="subtitle">From OHS Form 60 - ' + fmtDate(r.accident_date) + '</div></div>' +
            '<button class="rec-modal-close" id="recCloseBtn">X</button></div>' +
            '<div class="rec-modal-body">' + workerSection + accidentSection + employerSection + reportSection + '</div></div>';
        
        return new Promise(function(resolve) {
            var ov = document.createElement('div');
            ov.className = 'rec-modal-overlay';
            ov.innerHTML = modalHtml;
            ov.querySelector('#recCloseBtn').addEventListener('click', function() { ov.remove(); resolve(); });
            ov.addEventListener('click', function(e) { if (e.target === ov) { ov.remove(); resolve(); } });
            document.body.appendChild(ov);
        });
    }
    
    // Direct injury / disease report (BL Form 43/10)"""

new_inj_view = """function viewRecord(id) {
    var r = allRecords.find(function(x) { return x.id === id; });
    if (!r) return;
    function f(label, val) { return val != null && val !== '' ? '<div class="rec-field"><span class="lbl">' + label + '</span><span class="val">' + val + '</span></div>' : ''; }
    
    // Injury / disease report (BL Form 43/10)"""

inj = inj.replace(old_inj_view, new_inj_view)

# 2k. Add statPerm and statTemp stat cards if missing
if 'id="statPerm"' not in inj:
    old_stats_html = """<div class="stat-card red"><h3>Fatalities</h3><div class="stat-value" id="statDeath">--</div></div>
<div class="stat-card blue"><h3>This Month</h3>"""
    new_stats_html = """<div class="stat-card red"><h3>Fatalities</h3><div class="stat-value" id="statDeath">--</div></div>
<div class="stat-card amber"><h3>Permanent Incapacity</h3><div class="stat-value" id="statPerm">--</div></div>
<div class="stat-card blue"><h3>Temporary Incapacity</h3><div class="stat-value" id="statTemp">--</div></div>
<div class="stat-card blue"><h3>This Month</h3>"""
    if old_stats_html in inj:
        inj = inj.replace(old_stats_html, new_stats_html)
        print("[OK] Added Perm/Temp stat cards")
    else:
        print("[WARN] Could not find statDeath to add Perm/Temp cards")

# 2l. Replace fmtDate with enhanced functions
old_inj_fmt = """function fmtDate(d) {
    if (!d) return '-';
    return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' });
}
</script>"""

new_inj_functions = """
function editStatus(id, current, ownerId) {
    if (typeof showSelect !== 'function') return;
    showSelect(
        'Current: <strong>' + current + '</strong>',
        [{ value:'submitted', label:'Submitted' }, { value:'under_review', label:'Under Review' }, { value:'processed', label:'Processed' }, { value:'closed', label:'Closed' }],
        current,
        { title: 'Update Status', confirmText: 'Update' }
    ).then(function(newStatus) {
        if (!newStatus || newStatus === current) return;
        SB.from('injury_disease_reports').update({ status: newStatus }).eq('id', id).then(function(res) {
            if (res.error) { showAlert(res.error.message, { type:'error', title:'Update Failed' }); return; }
            showToast('Status updated', 'success');
            allRecords = allRecords.map(function(r) { return r.id === id ? Object.assign({}, r, { status: newStatus }) : r; });
            applyFilters();
        });
    });
}

function exportCSV() {
    const headers = ['Worker Name','ID No','Occupation','Employer','Incident Type','Incident Date','Place','Nature','Death','Perm Incapacity','Temp Incapacity','Report Date','Status'];
    const rows = allRecords.map(r => [
        r.worker_name, r.worker_id_number, r.occupation, r.employer_name,
        r.incident_type, r.incident_date, r.place_of_accident, r.nature_of_injuries,
        r.resulted_death, r.permanent_incapacity, r.temporary_incapacity,
        r.report_date, r.status
    ]);
    const csv = [headers, ...rows].map(r => r.map(c => '"' + (c||'') + '"').join(',')).join('\\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([csv], { type:'text/csv' }));
    a.download = 'injury_disease_reports_' + new Date().toISOString().split('T')[0] + '.csv';
    a.click();
    URL.revokeObjectURL(a.href);
}

// Pagination
let currentPage = 1;
let pageSize = 50;
let totalPages = 1;
let paginatedRecords = [];

function applyPagination(records) {
    currentPage = 1;
    paginatedRecords = records;
    totalPages = Math.ceil(records.length / pageSize) || 1;
    renderPage();
}

function renderPage() {
    const start = (currentPage - 1) * pageSize;
    const end = Math.min(start + pageSize, paginatedRecords.length);
    renderTable(paginatedRecords.slice(start, end));
    updatePaginationControls();
    const ctrl = document.getElementById("paginationControls");
    if (ctrl) ctrl.style.display = paginatedRecords.length > 0 ? "flex" : "none";
}

function updatePaginationControls() {
    const pi = document.getElementById("paginationInfo");
    if (pi) {
        pi.textContent = paginatedRecords.length > 0
            ? "Showing " + ((currentPage-1)*pageSize+1) + "-" + Math.min(currentPage*pageSize, paginatedRecords.length) + " of " + paginatedRecords.length + " records"
            : "No records";
    }
    ["firstPageBtn","prevPageBtn","nextPageBtn","lastPageBtn"].forEach(function(id) {
        var el = document.getElementById(id);
        if (el) el.disabled = true;
    });
    var fp = document.getElementById("firstPageBtn"); if(fp) fp.disabled = currentPage <= 1;
    var pp = document.getElementById("prevPageBtn"); if(pp) pp.disabled = currentPage <= 1;
    var np = document.getElementById("nextPageBtn"); if(np) np.disabled = currentPage >= totalPages;
    var lp = document.getElementById("lastPageBtn"); if(lp) lp.disabled = currentPage >= totalPages;
    var pn = document.getElementById("pageNumbers");
    if (pn) {
        var html = "";
        var startP = Math.max(1, currentPage - 2);
        var endP = Math.min(totalPages, startP + 4);
        if (endP - startP < 4) startP = Math.max(1, endP - 4);
        for (var i = startP; i <= endP; i++) {
            html += '<button class="' + (i === currentPage ? 'active' : '') + '" onclick="goToPage(' + i + ')">' + i + '</button>';
        }
        pn.innerHTML = html;
    }
}

function goToPage(page) {
    if (page < 1 || page > totalPages) return;
    currentPage = page;
    renderPage();
    var tc = document.querySelector('.table-container');
    if (tc) tc.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function changePageSize() {
    pageSize = parseInt(document.getElementById('pageSizeSelect').value) || 50;
    totalPages = Math.ceil(paginatedRecords.length / pageSize) || 1;
    currentPage = 1;
    renderPage();
}

function fmtDate(d) {
    if (!d) return '-';
    return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' });
}
</script>"""

inj = inj.replace(old_inj_fmt, new_inj_functions)

write_file("company-injuries-view.html", inj)
print("[OK] company-injuries-view.html enhanced")

print("\n=== Done ===")
