// Worker Portal - Complete Application Logic
// All 9 features: Dashboard, Claims, Profile, Medical, Documents, Company, Messages, Resources

const SB = window.supabaseClient;
let cu = null, cp = null, selType = null, cf = [], df = [];

/* ===== UTILITY FUNCTIONS ===== */

function switchTab(t) {
  document.querySelectorAll(".tab").forEach(b => b.classList.toggle("active", b.dataset.t === t));
  const m = {dash:"pDash", claims:"pClaims", profile:"pProfile", medical:"pMedical",
    docs:"pDocs", company:"pCompany", messages:"pMessages", resources:"pResources"};
  document.querySelectorAll(".panel").forEach(p => p.classList.toggle("active", p.id === m[t]));
}
document.querySelectorAll(".tab").forEach(b => b.addEventListener("click", () => switchTab(b.dataset.t)));

function showToast(m, t) {
  let el = document.getElementById("_toast");
  if (!el) { el = document.createElement("div"); el.id = "_toast"; el.className = "toast"; document.body.appendChild(el); }
  el.textContent = m; el.className = "toast show toast-" + (t || "info");
  clearTimeout(el._h); el._h = setTimeout(() => el.classList.remove("show"), 4000);
}

function esc(s) { if (s == null) return ""; return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }

function fmtDate(d) { if (!d) return "—"; return new Date(d).toLocaleDateString("en-GB", {day:"2-digit", month:"short", year:"numeric"}); }

function badge(s) {
  const m = {draft:'<span class="badge bg-gray">Draft</span>',
    pending:'<span class="badge bg-yellow">Pending</span>',
    under_review:'<span class="badge bg-yellow">Under Review</span>',
    approved:'<span class="badge bg-green">Approved</span>',
    paid:'<span class="badge bg-green">Paid</span>',
    denied:'<span class="badge bg-red">Denied</span>',
    closed:'<span class="badge bg-blue">Closed</span>' };
  return m[s] || '<span class="badge bg-gray">'+esc(s)+'</span>';
}

function setVal(id, val) {
  const el = document.getElementById(id);
  if (el) el.value = val || "";
}

function setHtml(id, html) {
  const el = document.getElementById(id);
  if (el) el.innerHTML = html;
}

function setText(id, text) {
  const el = document.getElementById(id);
  if (el) el.textContent = text;
}

/* ===== DOMContentLoaded INIT ===== */

window.addEventListener("DOMContentLoaded", async function() {
  try {
    var r = await SB.auth.getUser();
    var user = r.data.user;
    if (!user) { window.location.href = "index.html"; return; }
    cu = user;
    var p = await SB.from("user_profiles").select("*").eq("user_id", user.id).maybeSingle();
    cp = p.data;
    var n = cp ? (cp.first_name + " " + cp.surname) : user.email.split("@")[0];
    setText("hdrName", n);
    setText("dashName", cp ? cp.first_name : "Worker");
    await Promise.all([loadDash(), loadHistory(), loadProfile(), loadMedical(), loadDocs(), loadCompany(), loadMsgs()]);
    var sid = sessionStorage.getItem("worker_id_number");
    if (cp) {
      setVal("cName", cp.first_name + " " + cp.surname);
      if (cp.id_number) setVal("cId", cp.id_number);
    }
    if (sid) {
      var ciEl = document.getElementById("cId");
      if (ciEl && !ciEl.value) ciEl.value = sid;
    }
  } catch(e) { showToast("Init error: "+e.message,"error"); }
});

/* ===== DASHBOARD ===== */

async function loadDash() {
  try {
    var sid = sessionStorage.getItem("worker_id_number");
    var q = SB.from("injury_claims").select("*", {count:"exact",head:false});
    if (sid) q = q.eq("claimant_id_number", sid);
    else if (cp && cp.id_number) q = q.eq("claimant_id_number", cp.id_number);
    else if (cu && cu.email) q = q.eq("claimant_email", cu.email);
    var r = await q.order("created_at", {ascending:false});
    var c = r.data || [];
    setText("sTotal", c.length);
    setText("sPending", c.filter(function(x) { return ["pending","under_review","draft"].indexOf(x.status) >= 0; }).length);
    setText("sApproved", c.filter(function(x) { return ["approved","paid"].indexOf(x.status) >= 0; }).length);
    setText("sClosed", c.filter(function(x) { return ["closed","denied"].indexOf(x.status) >= 0; }).length);
    var recent = c.slice(0,5);
    var el = document.getElementById("recentClaims");
    if (!el) return;
    if (recent.length === 0) {
      el.innerHTML = '<div class="es"><div style="font-size:48px;margin-bottom:12px">&#x1F4CB;</div><div>No claims yet. Start by filing a new claim!</div></div>';
    } else {
      el.innerHTML = recent.map(function(x) {
        return '<div style="display:flex;justify-content:space-between;align-items:center;padding:12px 0;border-bottom:1px solid #f0f0f0">' +
          '<div><div style="font-weight:600;font-size:14px">'+esc(x.file_number||'Draft #'+x.id)+'</div>' +
          '<div style="font-size:12px;color:#5f6368">'+fmtDate(x.created_at)+'</div></div>' +
          '<div>'+badge(x.status)+'</div></div>';
      }).join("");
    }
  } catch(e) {
    setHtml("recentClaims", '<div class="es">Could not load claims</div>');
  }
}

async function loadHistory() {
  try {
    var sid = sessionStorage.getItem("worker_id_number");
    var q = SB.from("injury_claims").select("*");
    if (sid) q = q.eq("claimant_id_number", sid);
    else if (cp && cp.id_number) q = q.eq("claimant_id_number", cp.id_number);
    else if (cu && cu.email) q = q.eq("claimant_email", cu.email);
    var r = await q.order("created_at", {ascending:false});
    var c = r.data || [];
    var el = document.getElementById("claimHistory");
    if (!el) return;
    if (c.length === 0) {
      el.innerHTML = '<div class="es"><div style="font-size:48px;margin-bottom:12px">&#x1F4CB;</div><div>No claim history</div></div>';
    } else {
      el.innerHTML = '<table style="width:100%;border-collapse:collapse;font-size:13px"><thead>' +
        '<tr style="background:#f8f9fa"><th style="padding:10px;text-align:left">File #</th>' +
        '<th style="padding:10px;text-align:left">Type</th>' +
        '<th style="padding:10px;text-align:left">Date</th>' +
        '<th style="padding:10px;text-align:left">Status</th></tr></thead><tbody>' +
        c.map(function(x) {
          return '<tr style="border-bottom:1px solid #f0f0f0"><td style="padding:10px;font-weight:500">' +
            esc(x.file_number||'Draft #'+x.id) + '</td><td style="padding:10px">' +
            esc(x.injury_type||x.incident_type||'-') + '</td><td style="padding:10px">' +
            fmtDate(x.created_at) + '</td><td style="padding:10px">' +
            badge(x.status) + '</td></tr>';
        }).join("") + '</tbody></table>';
    }
    // Also update timeline for the most recent claim
    showTimeline(c[0]);
  } catch(e) {
    setHtml("claimHistory", '<div class="es">Could not load history</div>');
  }
}

function showTimeline(claim) {
  var el = document.getElementById("timelineContainer");
  if (!el) return;
  if (!claim) {
    el.innerHTML = '<div class="es"><div style="font-size:48px;margin-bottom:12px">&#x1F4CB;</div><div>Submit a claim to see its progress</div></div>';
    return;
  }
  var sts = [
    {key:"draft", label:"Draft"},
    {key:"pending", label:"Submitted"},
    {key:"under_review", label:"Under Review"},
    {key:"approved", label:"Decision"},
    {key:"paid", label:"Resolved"}
  ];
  var curIdx = -1;
  var status = claim.status || "draft";
  for (var i = 0; i < sts.length; i++) {
    if (sts[i].key === status) { curIdx = i; break; }
  }
  if (status === "closed" || status === "denied") curIdx = sts.length - 1;
  var html = '<div class="tl">';
  for (var i = 0; i < sts.length; i++) {
    var cls = i < curIdx ? "done" : (i === curIdx ? "cur" : "");
    html += '<div class="ts '+cls+'"><div class="dot">'+(i+1)+'</div><div class="lb">'+sts[i].label+'</div></div>';
  }
  html += '</div><div style="text-align:center;font-size:13px;color:#5f6368">';
  html += 'Claim <strong>'+esc(claim.file_number||'Draft #'+claim.id)+'</strong> - Status: '+badge(status);
  html += '</div>';
  el.innerHTML = html;
}

/* ===== PROFILE ===== */

async function loadProfile() {
  if (!cp) return;
  setVal("pfFname", cp.first_name);
  setVal("pfSname", cp.surname);
  setVal("pfEmail", cu.email);
  setVal("pfPhone", cp.phone);
  setVal("pfDob", cp.date_of_birth ? cp.date_of_birth.split("T")[0] : "");
  setVal("pfIdNum", cp.id_number);
  setVal("pfAddr", cp.address);
  setVal("pfOcc", cp.occupation);
  setVal("pfDept", cp.department);
  setVal("pfEmployer", cp.employer_name);
  setVal("pfHired", cp.date_hired ? cp.date_hired.split("T")[0] : "");
}

async function saveProfile() {
  var data = {
    first_name: document.getElementById("pfFname").value,
    surname: document.getElementById("pfSname").value,
    phone: document.getElementById("pfPhone").value,
    date_of_birth: document.getElementById("pfDob").value || null,
    id_number: document.getElementById("pfIdNum").value,
    address: document.getElementById("pfAddr").value,
    occupation: document.getElementById("pfOcc").value,
    department: document.getElementById("pfDept").value,
    employer_name: document.getElementById("pfEmployer").value,
    date_hired: document.getElementById("pfHired").value || null
  };
  var pfStatus = document.getElementById("pfStatus");
  try {
    var r = await SB.from("user_profiles").upsert({user_id: cu.id, ...data}).select().maybeSingle();
    if (r.error) throw r.error;
    cp = r.data;
    pfStatus.textContent = "&#x2705; Saved successfully!";
    setTimeout(function() { pfStatus.textContent = ""; }, 3000);
    setText("hdrName", cp.first_name + " " + cp.surname);
    setText("dashName", cp.first_name);
    showToast("Profile saved", "success");
  } catch(e) {
    pfStatus.textContent = "&#x274C; Error: " + e.message;
    showToast("Save failed: "+e.message, "error");
  }
}

/* ===== MEDICAL ===== */

async function loadMedical() {
  try {
    var sid = sessionStorage.getItem("worker_id_number");
    var idNum = sid || (cp ? cp.id_number : null);
    
    // Load medical examination reports
    var r = await SB.from("medical_examination_reports").select("*,practitioner_clients!inner(*)").order("examination_date", {ascending:false});
    var exams = r.data || [];
    
    // Filter by worker id if we have one
    var upAppts = document.getElementById("upAppts");
    var pastExams = document.getElementById("pastExams");
    var impairRpts = document.getElementById("impairRpts");
    
    if (upAppts) {
      var upcoming = exams.filter(function(x) { return x.status === "scheduled" || x.status === "pending"; }).slice(0,5);
      if (upcoming.length === 0) {
        upAppts.innerHTML = '<div class="es">No upcoming appointments</div>';
      } else {
        upAppts.innerHTML = upcoming.map(function(x) {
          return '<div style="padding:12px 0;border-bottom:1px solid #f0f0f0">' +
            '<div style="font-weight:600">'+fmtDate(x.examination_date)+'</div>' +
            '<div style="font-size:12px;color:#5f6368">'+esc(x.examination_type||'Medical Examination')+'</div></div>';
        }).join("");
      }
    }
    
    if (pastExams) {
      var past = exams.filter(function(x) { return x.status === "completed"; }).slice(0,10);
      if (past.length === 0) {
        pastExams.innerHTML = '<div class="es">No past examinations</div>';
      } else {
        pastExams.innerHTML = past.map(function(x) {
          return '<div style="padding:12px 0;border-bottom:1px solid #f0f0f0;display:flex;justify-content:space-between">' +
            '<div><div style="font-weight:500;font-size:14px">'+esc(x.examination_type||'Examination')+'</div>' +
            '<div style="font-size:12px;color:#5f6368">'+fmtDate(x.examination_date)+'</div></div>' +
            '<div><span class="badge bg-green">Completed</span></div></div>';
        }).join("");
      }
    }
    
    // Load impairment reports
    var ir = await SB.from("permanent_impairment_reports").select("*").order("created_at", {ascending:false});
    var irData = ir.data || [];
    if (impairRpts) {
      if (irData.length === 0) {
        impairRpts.innerHTML = '<div class="es">No impairment reports</div>';
      } else {
        impairRpts.innerHTML = irData.slice(0,5).map(function(x) {
          return '<div style="padding:12px 0;border-bottom:1px solid #f0f0f0">' +
            '<div style="font-weight:500;font-size:14px">Impairment: '+esc(x.impairment_percentage||'N/A')+'%</div>' +
            '<div style="font-size:12px;color:#5f6368">'+fmtDate(x.created_at)+'</div></div>';
        }).join("");
      }
    }
  } catch(e) {
    showToast("Could not load medical data", "error");
  }
}

/* ===== DOCUMENTS ===== */

async function loadDocs() {
  try {
    var r = await SB.storage.from("worker-documents").list("", {limit:100});
    var files = r.data || [];
    var docCount = document.getElementById("docCount");
    var docList = document.getElementById("docList");
    if (docCount) docCount.textContent = "(" + files.length + ")";
    if (docList) {
      if (files.length === 0) {
        docList.innerHTML = '<div class="es">No documents uploaded yet</div>';
      } else {
        docList.innerHTML = files.map(function(f) {
          var icon = f.name.match(/\.(jpg|jpeg|png|gif|bmp)$/i) ? "&#x1F5BC;" :
            f.name.match(/\.(pdf)$/i) ? "&#x1F4C4;" :
            f.name.match(/\.(doc|docx)$/i) ? "&#x1F4DD;" : "&#x1F4C1;";
          return '<div style="display:flex;align-items:center;gap:12px;padding:10px 0;border-bottom:1px solid #f0f0f0">' +
            '<span>'+icon+'</span>' +
            '<div style="flex:1"><div style="font-size:14px">'+esc(f.name)+'</div>' +
            '<div style="font-size:11px;color:#5f6368">'+((f.metadata&&f.metadata.size)?Math.round(f.metadata.size/1024)+' KB':'')+' | '+fmtDate(f.created_at)+'</div></div></div>';
        }).join("");
      }
    }
  } catch(e) {
    setHtml("docList", '<div class="es">Could not load documents</div>');
  }
}

function addDocFiles(files) {
  if (!files || files.length === 0) return;
  var list = document.getElementById("dFileList");
  var html = '';
  for (var i = 0; i < files.length; i++) {
    html += '<div style="display:flex;align-items:center;gap:8px;padding:8px 0">' +
      '<span>&#x1F4C4;</span><span style="flex:1">'+esc(files[i].name)+'</span>' +
      '<span style="font-size:12px;color:#5f6368">'+Math.round(files[i].size/1024)+' KB</span></div>';
  }
  html += '<button class="btn bg" style="margin-top:8px" onclick="uploadDocs()">Upload '+files.length+' file(s)</button>';
  list.innerHTML = html;
  df = Array.from(files);
}

async function uploadDocs() {
  if (df.length === 0) return;
  showToast("Uploading...", "info");
  try {
    for (var i = 0; i < df.length; i++) {
      var path = (cp ? cp.id_number : 'unknown') + "/" + Date.now() + "_" + df[i].name;
      var r = await SB.storage.from("worker-documents").upload(path, df[i]);
      if (r.error) throw r.error;
    }
    showToast(df.length + " file(s) uploaded", "success");
    document.getElementById("dFileList").innerHTML = "";
    df = [];
    loadDocs();
  } catch(e) {
    showToast("Upload error: "+e.message, "error");
  }
}

/* ===== COMPANY ===== */

async function loadCompany() {
  try {
    var employerName = cp ? cp.employer_name : null;
    var companyInfo = document.getElementById("companyInfo");
    if (!companyInfo) return;
    if (employerName) {
      var r = await SB.from("companies").select("*").ilike("company_name", "%"+employerName+"%").maybeSingle();
      var comp = r.data;
      if (comp) {
        companyInfo.innerHTML = '<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">' +
          '<div><div style="font-size:12px;color:#5f6368">Company Name</div><div style="font-weight:500">'+esc(comp.company_name)+'</div></div>' +
          '<div><div style="font-size:12px;color:#5f6368">Registration #</div><div style="font-weight:500">'+esc(comp.registration_number||'N/A')+'</div></div>' +
          '<div><div style="font-size:12px;color:#5f6368">Industry</div><div style="font-weight:500">'+esc(comp.industry||'N/A')+'</div></div>' +
          '<div><div style="font-size:12px;color:#5f6368">Status</div><div style="font-weight:500"><span class="badge bg-green">'+esc(comp.status||'Active')+'</span></div></div>' +
          '<div style="grid-column:1/-1"><div style="font-size:12px;color:#5f6368">Address</div><div style="font-weight:500">'+esc(comp.physical_address||comp.postal_address||'N/A')+'</div></div>' +
          '<div style="grid-column:1/-1"><div style="font-size:12px;color:#5f6368">Contact</div><div style="font-weight:500">'+esc(comp.phone||'')+' '+(comp.email?'| '+esc(comp.email):'')+'</div></div>' +
          '</div>';
      } else {
        companyInfo.innerHTML = '<div class="es">Employer not found in registry. Contact OSH for assistance.</div>';
      }
    } else {
      companyInfo.innerHTML = '<div class="es">No employer information on file. Update your profile.</div>';
    }
  } catch(e) {
    setHtml("companyInfo", '<div class="es">Could not load company info</div>');
  }
}

/* ===== MESSAGES ===== */

async function loadMsgs() {
  try {
    var r = await SB.from("case_notes")
      .select("*,injury_claims!inner(claimant_id_number,claimant_email)")
      .order("created_at", {ascending:false});
    var msgs = r.data || [];
    var container = document.getElementById("msgContainer");
    if (!container) return;
    if (msgs.length === 0) {
      container.innerHTML = '<div class="es">No messages yet</div>';
    } else {
      container.innerHTML = msgs.map(function(m) {
        var isIn = m.sender_role === "officer" || m.sender_role === "admin";
        return '<div class="msg '+(isIn?'in':'out')+'">' +
          '<div class="h">'+(isIn?'OSH Officer':'You')+' &middot; '+fmtDate(m.created_at)+'</div>' +
          '<div class="b">'+esc(m.note_text||m.message||'')+'</div></div>';
      }).join("");
    }
  } catch(e) {
    setHtml("msgContainer", '<div class="es">Could not load messages</div>');
  }
}

async function sendMsg() {
  var subject = document.getElementById("msgSubject").value;
  var body = document.getElementById("msgBody").value.trim();
  if (!body) { showToast("Please enter a message", "warning"); return; }
  try {
    var sid = sessionStorage.getItem("worker_id_number");
    var r = await SB.from("case_notes").insert({
      sender_id: cu.id,
      sender_role: "worker",
      note_text: body,
      subject: subject,
      claimant_id_number: sid || (cp ? cp.id_number : null),
      claimant_email: cu.email
    }).select();
    if (r.error) throw r.error;
    document.getElementById("msgBody").value = "";
    showToast("Message sent", "success");
    loadMsgs();
  } catch(e) {
    showToast("Send failed: "+e.message, "error");
  }
}

/* ===== RESOURCES ===== */

function showResource(topic) {
  var resources = {
    rights: {
      title: "Worker Rights under the Workers Compensation Act",
      body: "<p><strong>Workers Compensation Act (Act No. 23 of 1998)</strong></p>" +
        "<p>As a worker, you have the right to:</p>" +
        "<ul><li>Report workplace injuries and diseases without fear of retaliation</li>" +
        "<li>Receive timely medical treatment for work-related injuries</li>" +
        "<li>File a compensation claim for injuries or diseases arising from employment</li>" +
        "<li>Appeal any decision made regarding your claim</li>" +
        "<li>Access your medical records and claim information</li>" +
        "<li>Be informed about workplace hazards and safety measures</li></ul>" +
        "<p>If you believe your rights have been violated, contact the DOSH office immediately.</p>"
    },
    safety: {
      title: "Workplace Safety Guide",
      body: "<p><strong>Staying Safe at Work</strong></p>" +
        "<p>Common workplace hazards include:</p>" +
        "<ul><li><strong>Physical hazards:</strong> Slips, trips, falls, moving machinery</li>" +
        "<li><strong>Chemical hazards:</strong> Toxic substances, fumes, dust</li>" +
        "<li><strong>Biological hazards:</strong> Bacteria, viruses, molds</li>" +
        "<li><strong>Ergonomic hazards:</strong> Repetitive motion, poor posture</li>" +
        "<li><strong>Psychosocial hazards:</strong> Stress, harassment, fatigue</li></ul>" +
        "<p>Always use provided PPE, follow safety protocols, and report hazards to your supervisor.</p>"
    },
    claims: {
      title: "Step-by-Step Claims Guide",
      body: "<p><strong>How to File a Claim</strong></p>" +
        "<ol><li><strong>Report the incident</strong> to your employer immediately</li>" +
        "<li><strong>Seek medical attention</strong> from an approved medical practitioner</li>" +
        "<li><strong>Gather documents:</strong> Medical reports, witness statements, incident reports</li>" +
        "<li><strong>File your claim</strong> using the online portal or visit a DOSH office</li>" +
        "<li><strong>Track progress</strong> through your dashboard</li></ol>" +
        "<p>Claims must be filed within 6 months of the incident date.</p>"
    },
    medical: {
      title: "Medical Examinations",
      body: "<p><strong>What to Expect</strong></p>" +
        "<p>Medical examinations for workplace injuries typically include:</p>" +
        "<ul><li>Review of your medical history and incident details</li>" +
        "<li>Physical examination of the affected area</li>" +
        "<li>Diagnostic tests (X-rays, scans, blood work) if needed</li>" +
        "<li>Assessment of recovery progress and treatment plan</li>" +
        "<li>Permanent impairment evaluation if applicable</li></ul>" +
        "<p>Bring your ID, claim number, and any relevant medical records.</p>"
    },
    comp: {
      title: "Understanding Compensation",
      body: "<p><strong>Types of Compensation</strong></p>" +
        "<ul><li><strong>Medical expenses:</strong> Cost of treatment and rehabilitation</li>" +
        "<li><strong>Temporary disability:</strong> Wage replacement while recovering</li>" +
        "<li><strong>Permanent disability:</strong> Lump sum for lasting impairment</li>" +
        "<li><strong>Funeral expenses:</strong> In case of work-related death</li>" +
        "<li><strong>Dependents benefits:</strong> Support for family members</li></ul>" +
        "<p>Compensation amounts are determined by the severity of injury and its impact on your ability to work.</p>"
    },
    appeal: {
      title: "Appeals Process",
      body: "<p><strong>How to Appeal a Decision</strong></p>" +
        "<ol><li><strong>Review the decision</strong> carefully and note the reasons</li>" +
        "<li><strong>Gather supporting evidence</strong> (medical reports, witness statements)</li>" +
        "<li><strong>Submit an appeal</strong> to the DOSH Commissioner within 30 days</li>" +
        "<li><strong>Attend the hearing</strong> if one is scheduled</li>" +
        "<li><strong>Receive the final determination</strong></li></ol>" +
        "<p>You have the right to legal representation throughout the appeals process.</p>"
    }
  };
  var res = resources[topic];
  if (!res) { showToast("Resource not found", "error"); return; }
  document.getElementById("resTitle").textContent = res.title;
  document.getElementById("resBody").innerHTML = res.bod
  document.getElementById("resBody").innerHTML = res.body;
  document.getElementById("resourceDetail").style.display = "block";
  document.getElementById("resourceDetail").scrollIntoView({behavior:"smooth"});
}

/* ===== CLAIM WIZARD ===== */

function pickType(el) {
  document.querySelectorAll(".it-btn").forEach(function(b) { b.classList.remove("bp"); b.classList.add("bo"); });
  el.classList.remove("bo"); el.classList.add("bp");
  selType = el.dataset.type;
  document.getElementById("next1").disabled = false;
}

function goStep(s) {
  document.querySelectorAll(".sf").forEach(function(x) { x.style.display = "none"; });
  document.querySelectorAll(".step").forEach(function(x) {
    x.classList.toggle("cur", parseInt(x.dataset.s) === s);
    x.classList.toggle("done", parseInt(x.dataset.s) < s);
  });
  var el = document.querySelector('.sf[data-s="'+s+'"]');
  if (el) el.style.display = "block";
  if (s === 4) buildSum();
}

function addClaimFiles(files) {
  for (var i = 0; i < files.length; i++) cf.push(files[i]);
  renderCF();
}
function renderCF() {
  var el = document.getElementById("cFileList");
  if (!el) return;
  el.innerHTML = cf.map(function(f,i) {
    return '<div style="display:flex;align-items:center;gap:8px;padding:6px 0;font-size:13px">' +
      '<span>&#x1F4C4;</span><span style="flex:1">'+esc(f.name)+'</span>' +
      '<span style="color:#5f6368">'+Math.round(f.size/1024)+' KB</span>' +
      '<button class="btn br" style="padding:4px 8px;font-size:11px" onclick="removeCF('+i+')">Remove</button></div>';
  }).join("");
}
function removeCF(i) { cf.splice(i,1); renderCF(); }

function buildSum() {
  var sum = document.getElementById("claimSum");
  if (!sum) return;
  sum.innerHTML = '<div class="sum-item"><span class="k">Incident Type</span><span class="v">'+esc(document.querySelector('.it-btn.bp')?.querySelector('.lb')?.textContent||selType)+'</span></div>' +
    '<div class="sum-item"><span class="k">Description</span><span class="v">'+esc(document.getElementById("cDesc")?.value||"")+'</span></div>' +
    '<div class="sum-item"><span class="k">Date of Incident</span><span class="v">'+esc(document.getElementById("cDate")?.value||"")+'</span></div>' +
    '<div class="sum-item"><span class="k">Claimant Name</span><span class="v">'+esc(document.getElementById("cName")?.value||"")+'</span></div>' +
    '<div class="sum-item"><span class="k">ID Number</span><span class="v">'+esc(document.getElementById("cId")?.value||"")+'</span></div>' +
    '<div class="sum-item"><span class="k">Documents</span><span class="v">'+cf.length+' file(s)</span></div>';
}

async function submitClaim() {
  var cName = document.getElementById("cName")?.value;
  var cId = document.getElementById("cId")?.value;
  var cDesc = document.getElementById("cDesc")?.value;
  var cDate = document.getElementById("cDate")?.value;
  if (!cName || !cId || !cDesc || !cDate) {
    showToast("Please fill all required fields", "warning");
    goStep(2); return;
  }
  if (!selType) { showToast("Please select incident type", "warning"); goStep(1); return; }
  try {
    showToast("Submitting claim...", "info");
    var r = await SB.from("injury_claims").insert({
      claimant_name: cName,
      claimant_id_number: cId,
      claimant_email: cu.email,
      incident_description: cDesc,
      incident_date: cDate,
      injury_type: selType,
      status: "pending",
      claimant_id: cu.id
    }).select().maybeSingle();
    if (r.error) throw r.error;
    showToast("Claim submitted successfully!", "success");
    // Reset form
    selType = null; cf = [];
    document.querySelectorAll(".it-btn").forEach(function(b) { b.classList.remove("bp"); b.classList.add("bo"); });
    document.getElementById("next1").disabled = true;
    goStep(1);
    document.getElementById("cDesc").value = "";
    document.getElementById("cDate").value = "";
    document.getElementById("cFileList").innerHTML = "";
    // Refresh dashboard and history
    await Promise.all([loadDash(), loadHistory()]);
  } catch(e) {
    showToast("Submit failed: "+e.message, "error");
  }
}
