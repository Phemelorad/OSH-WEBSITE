// ============================================================
// CLAIM SERVICE — shared claim query logic
// Single source of truth for loading, filtering, and updating claims.
// Include AFTER supabase-config.js and BEFORE page scripts.
// Usage: var claims = await loadClaims({ status: "pending" });
// ============================================================
(function () {
  "use strict";

  function getSB() {
    return window.supabaseClient;
  }

  /**
   * Load claims with optional filters.
   * @param {Object} opts
   * @param {string} [opts.status] - Filter by status (eq)
   * @param {string} [opts.industry] - Filter by industry (eq)
   * @param {string} [opts.claimantIdNumber] - Filter by claimant ID (eq)
   * @param {string} [opts.claimantIdNumberIlike] - Filter by claimant ID (ilike)
   * @param {string} [opts.workerRegistryId] - Filter by worker registry ID (eq)
   * @param {string} [opts.employerName] - Filter by employer name (ilike)
   * @param {string} [opts.nameOfEmployer] - Filter by exact employer name (eq)
   * @param {string} [opts.fileNumber] - Filter by file number (eq)
   * @param {string} [opts.searchQuery] - Fuzzy search across name, ID, file number (or)
   * @param {string} [opts.nameOfClaimant] - Filter by claimant name (ilike)
   * @param {string[]} [opts.inStatus] - Filter by multiple statuses (in)
   * @param {string} [opts.inField] - Field name for "in" filter
   * @param {string[]} [opts.inValues] - Values for "in" filter
   * @param {boolean} [opts.excludeDrafts] - Exclude draft status
   * @param {boolean} [opts.selectCount] - Return { data, count }
   * @param {number} [opts.limit] - Max results
   * @param {string} [opts.selectCols] - Specific columns (default: *)
   * @param {string} [opts.orderBy] - Column to order by (default: created_at)
   * @param {boolean} [opts.orderAsc] - Ascending order (default: false)
   * @param {string} [opts.view] - View name (default: injury_claims)
   * @param {string|number} [opts.id] - Lookup by claim ID
   * @returns {Promise<Array|Object>}
   */
  window.loadClaims = async function(opts) {
    opts = opts || {};
    var sb = getSB();
    if (!sb) return opts.selectCount ? { data: [], count: 0 } : [];

    var viewName = opts.view || "injury_claims";
    var cols = opts.selectCols || "*";
    var countOpts = opts.selectCount ? { count: "exact", head: false } : {};
    var query = sb.from(viewName).select(cols, countOpts);

    if (opts.id)                query = query.eq("id", opts.id);
    if (opts.status)            query = query.eq("status", opts.status);
    if (opts.industry)          query = query.eq("industry", opts.industry);
    if (opts.claimantIdNumber)  query = query.eq("claimant_id_number", opts.claimantIdNumber);
    if (opts.claimantIdNumberIlike) query = query.ilike("claimant_id_number", opts.claimantIdNumberIlike);
    if (opts.workerRegistryId)  query = query.eq("worker_registry_id", opts.workerRegistryId);
    if (opts.nameOfEmployer)    query = query.eq("name_of_employer", opts.nameOfEmployer);
    if (opts.employerName)      query = query.ilike("name_of_employer", "%" + opts.employerName + "%");
    if (opts.fileNumber)        query = query.eq("file_number", opts.fileNumber);
    if (opts.nameOfClaimant)    query = query.ilike("name_of_claimant", "%" + opts.nameOfClaimant + "%");
    if (opts.inStatus && opts.inStatus.length) query = query.in("status", opts.inStatus);
    if (opts.inField && opts.inValues && opts.inValues.length) query = query.in(opts.inField, opts.inValues);
    if (opts.excludeDrafts)     query = query.neq("status", "draft");

    if (opts.searchQuery) {
      var q = opts.searchQuery;
      var pat = "%" + q + "%";
      var upper = q.toUpperCase();
      var idPat = "%" + upper + "%";
      query = query.neq("status", "draft")
        .or("name_of_claimant.ilike." + pat + ",claimant_id_number.ilike." + idPat + ",file_number.ilike." + pat);
    }

    query = query.order(opts.orderBy || "created_at", { ascending: opts.orderAsc || false });

    if (opts.limit) query = query.limit(opts.limit);

    try {
      var result = await query;
      if (result.error) throw result.error;
      return opts.selectCount ? { data: result.data || [], count: result.count || 0 } : (result.data || []);
    } catch (e) {
      console.error("Error loading claims:", e);
      return opts.selectCount ? { data: [], count: 0 } : [];
    }
  };

  /**
   * Load a single claim by ID.
   */
  window.loadClaimById = async function(id) {
    var result = await window.loadClaims({ id: id, limit: 1 });
    return (result && result.length) ? result[0] : null;
  };

  /**
   * Load unique industries from non-draft claims.
   */
  window.loadUniqueIndustries = async function() {
    var sb = getSB();
    if (!sb) return [];
    try {
      var r = await sb.from("injury_claims").select("industry").neq("status", "draft");
      if (r.error) throw r.error;
      return [...new Set((r.data || []).map(function(i){return i.industry;}))].sort();
    } catch (e) {
      console.error("Error loading industries:", e);
      return [];
    }
  };

  /**
   * Update claim status.
   */
  window.updateClaimStatus = async function(claimId, newStatus) {
    var sb = getSB();
    if (!sb) return false;
    try {
      var result = await sb.from("injury_claims").update({ status: newStatus, updated_at: new Date().toISOString() }).eq("id", claimId);
      if (result.error) throw result.error;
      return true;
    } catch (e) {
      console.error("Error updating claim status:", e);
      return false;
    }
  };

  /**
   * Get claim statistics from an array of claims.
   */
  window.getClaimStats = function(claims) {
    var stats = {
      total: claims.length,
      pending: 0, approved: 0, rejected: 0,
      draft: 0, closed: 0, under_review: 0, submitted: 0, cancelled: 0
    };
    claims.forEach(function(c) {
      if (stats.hasOwnProperty(c.status)) stats[c.status]++;
    });
    return stats;
  };

  /**
   * Format a date string (e.g. "14 Mar 2026").
   */
  window.formatClaimDate = function(dateString) {
    if (!dateString) return "—";
    return new Date(dateString).toLocaleDateString("en-GB", {
      day: "2-digit", month: "short", year: "numeric"
    });
  };

  /**
   * Get the status badge HTML for a claim status.
   */
  window.statusBadge = function(status) {
    if (!status) return "";
    var labels = {
      draft: "Draft", pending: "Pending", under_review: "Under Review",
      approved: "Approved", rejected: "Rejected", closed: "Closed",
      submitted: "Submitted", cancelled: "Cancelled"
    };
    var label = labels[status] || status.replace(/_/g, " ").replace(/\b\w/g, function(c){return c.toUpperCase();});
    return "<span class=\"status-badge " + status + "\">" + label + "</span>";
  };

})();
