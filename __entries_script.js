
        const supabaseClient = window.supabaseClient;
        let allClaims = [];

        // Check authentication on page load
        window.addEventListener('load', async function() {
            const authenticated = await isAuthenticated();
            
            if (!authenticated) {
                window.location.href = 'index.html';
                return;
            }

            // Initialize role system
            await initializeRoleSystem();

            await loadClaims();
            await populateIndustryFilter();
            
            // Enforce permissions
            enforcePermissions();
        });

        async function loadClaims() {
            document.getElementById('claimsLoading').style.display = 'block';
            document.getElementById('claimsContent').style.display = 'none';

            try {
                let query = supabaseClient
                    .from('injury_claims_view')
                    .select('*')
                    .order('created_at', { ascending: false });

                // Apply filters
                const statusFilter = document.getElementById('filterStatus').value;
                const industryFilter = document.getElementById('filterIndustry').value;

                if (statusFilter) {
                    query = query.eq('status', statusFilter);
                }
                if (industryFilter) {
                    query = query.eq('industry', industryFilter);
                }

                const { data: claims, error } = await query;

                if (error) throw error;

                allClaims = claims;

                // Update statistics
                updateStatistics(claims);

                // Render claims table
                renderClaimsTable(claims);

                document.getElementById('claimsLoading').style.display = 'none';
                document.getElementById('claimsContent').style.display = 'block';

            } catch (error) {
                console.error('Error loading claims:', error);
                document.getElementById('claimsLoading').innerHTML = 
                    `<div style="text-align: center; padding: 40px;">
                        <p style="color: #e74c3c; margin-bottom: 10px;">Error loading claims: ${error.message}</p>
                        <button onclick="loadClaims()" style="margin-top: 20px; padding: 10px 20px; background: #333; color: white; border: none; border-radius: 6px; cursor: pointer;">Retry</button>
                    </div>`;
            }
        }

        async function populateIndustryFilter() {
            try {
                const { data: industries, error } = await supabaseClient
                    .from('injury_claims')
                    .select('industry');

                if (error) throw error;

                const uniqueIndustries = [...new Set(industries.map(i => i.industry))].sort();
                const select = document.getElementById('filterIndustry');
                
                uniqueIndustries.forEach(industry => {
                    const option = document.createElement('option');
                    option.value = industry;
                    option.textContent = industry;
                    select.appendChild(option);
                });
            } catch (error) {
                console.error('Error loading industries:', error);
            }
        }

        function updateStatistics(claims) {
            const total = claims.length;
            const pending = claims.filter(c => c.status === 'pending').length;
            const drafts = claims.filter(c => c.status === 'draft').length;
            const approved = claims.filter(c => c.status === 'approved').length;
            
            const submitted = claims.filter(c => c.status !== 'draft' && c.status !== 'cancelled');
            const avgIncapacity = submitted.length > 0
                ? (submitted.reduce((sum, c) => sum + parseFloat(c.incapacity_percentage), 0) / submitted.length).toFixed(1)
                : 0;

            document.getElementById('totalClaims').textContent = total;
            document.getElementById('pendingClaims').textContent = pending;
            document.getElementById('approvedClaims').textContent = approved;
            document.getElementById('draftClaims').textContent = drafts;
            document.getElementById('avgIncapacity').textContent = avgIncapacity + '%';
        }

        function renderClaimsTable(claims) {
            const tbody = document.getElementById('claimsTableBody');
            const emptyState = document.getElementById('emptyState');

            if (claims.length === 0) {
                tbody.innerHTML = '';
                emptyState.style.display = 'block';
                return;
            }

            emptyState.style.display = 'none';
            tbody.innerHTML = claims.map(claim => {
                const canEdit = canEditClaims(claim.submitted_by);
                const editDisabled = !canEdit ? 'disabled' : '';
                const editTitle = !canEdit ? 'title="You can only edit your own claims"' : '';
                
                const fileCell = claim.status === 'draft'
                    ? '<em style="color:#856404">Awaiting submit</em>'
                    : `<strong>${claim.file_number || '—'}</strong>`;
                const completeBtn = claim.status === 'draft'
                    ? `<button class="action-btn" onclick="window.location.href='form.html?draft=${claim.id}'">Complete</button>`
                    : '';

                return `
                <tr>
                    <td>${fileCell}</td>
                    <td>${claim.name_of_claimant}</td>
                    <td>${claim.matched_employer || claim.name_of_employer}</td>
                    <td>${claim.industry}</td>
                    <td>${formatDate(claim.date_of_injury)}</td>
                    <td>${claim.location}</td>
                    <td><strong>${claim.incapacity_percentage}%</strong></td>
                    <td>
                        <span class="badge badge-${claim.status}">
                            ${claim.status.replace('_', ' ').toUpperCase()}
                        </span>
                    </td>
                    <td>${formatDate(claim.created_at)}</td>
                    <td>
                        ${completeBtn}
                        <button class="action-btn" onclick="viewClaim('${claim.id}')">View</button>
                        <button class="action-btn ${editDisabled}" ${editTitle} 
                            onclick="editStatus('${claim.id}', '${claim.status}', '${claim.submitted_by}')"
                            ${!canEdit || claim.status === 'draft' ? 'disabled style="opacity: 0.5; cursor: not-allowed;"' : ''}>
                            Status
                        </button>
                    </td>
                </tr>
            `;
            }).join('');
        }

        function formatDate(dateString) {
            const date = new Date(dateString);
            return date.toLocaleDateString('en-US', { 
                year: 'numeric', 
                month: 'short', 
                day: 'numeric'
            });
        }

        function viewClaim(claimId) {
            const claim = allClaims.find(c => c.id === claimId);
            if (claim) showClaimDetails(claim);
        }

        async function editStatus(claimId, currentStatus, claimOwnerId) {
            if (!canEditClaims(claimOwnerId)) {
                showPermissionDenied('edit this claim');
                return;
            }

            const statuses = [
                { value: 'pending',      label: '🟡 Pending' },
                { value: 'under_review', label: '🔵 Under Review' },
                { value: 'approved',     label: '🟢 Approved' },
                { value: 'rejected',     label: '🔴 Rejected' },
                { value: 'closed',       label: '⚫ Closed' },
            ];

            const newStatus = await showSelect(
                `Current status: <strong>${currentStatus.replace('_',' ').toUpperCase()}</strong>`,
                statuses,
                currentStatus,
                { title: 'Update Claim Status', iconKey: 'status', confirmText: 'Update Status' }
            );

            if (!newStatus || newStatus === currentStatus) return;

            try {
                const { error } = await supabaseClient
                    .from('injury_claims').update({ status: newStatus }).eq('id', claimId);
                if (error) throw error;
                showToast('Status updated successfully', 'success');
                loadClaims();
            } catch (error) {
                await showAlert(error.message, { type: 'error', title: 'Update Failed' });
            }
        }

        function exportToCSV() {
            const headers = ['File Number', 'Claimant', 'Gender', 'Employer', 'Industry', 'Date of Injury', 'Date Reported', 'Date Received', 'Cause', 'Nature', 'Incapacity %', 'Location', 'Nationality', 'Status', 'Submitted'];
            
            const rows = allClaims.map(claim => [
                claim.file_number,
                claim.name_of_claimant,
                claim.gender,
                claim.name_of_employer,
                claim.industry,
                claim.date_of_injury,
                claim.date_reported,
                claim.date_received,
                claim.cause,
                claim.nature,
                claim.incapacity_percentage,
                claim.location,
                claim.nationality,
                claim.status,
                formatDate(claim.created_at)
            ]);

            const csvContent = [headers, ...rows]
                .map(row => row.map(cell => `"${cell}"`).join(','))
                .join('\n');

            const blob = new Blob([csvContent], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `injury_claims_${new Date().toISOString().split('T')[0]}.csv`;
            a.click();
            window.URL.revokeObjectURL(url);
        }


        // -- Pagination --
        let currentPage = 1;
        let pageSize = 50;
        let totalPages = 1;
        let paginatedClaims = [];

        function applyPagination(claims) {
            currentPage = 1;
            paginatedClaims = claims;
            totalPages = Math.ceil(claims.length / pageSize) || 1;
            renderPage();
        }

        function renderPage() {
            const start = (currentPage - 1) * pageSize;
            const end = Math.min(start + pageSize, paginatedClaims.length);
            const pageClaims = paginatedClaims.slice(start, end);
            renderClaimsTable(pageClaims);
            updatePaginationControls();
            const controls = document.getElementById("paginationControls");
            controls.style.display = paginatedClaims.length > 0 ? "flex" : "none";
        }

        function updatePaginationControls() {
            const start = (currentPage - 1) * pageSize + 1;
            const end = Math.min(start + pageSize - 1, paginatedClaims.length);
            document.getElementById("paginationInfo").textContent =
                paginatedClaims.length > 0
                    ? "Showing " + start + "-" + end + " of " + paginatedClaims.length + " claims"
                    : "No claims";
            document.getElementById("firstPageBtn").disabled = currentPage <= 1;
            document.getElementById("prevPageBtn").disabled = currentPage <= 1;
            document.getElementById("nextPageBtn").disabled = currentPage >= totalPages;
            document.getElementById("lastPageBtn").disabled = currentPage >= totalPages;
            let html = "";
            const maxVisible = 5;
            let startPage = Math.max(1, currentPage - Math.floor(maxVisible / 2));
            let endPage = Math.min(totalPages, startPage + maxVisible - 1);
            if (endPage - startPage < maxVisible - 1) {
                startPage = Math.max(1, endPage - maxVisible + 1);
            }
            for (let i = startPage; i <= endPage; i++) {
                const active = i === currentPage ? "active" : "";
                html += "<button class=\"" + active + "\" onclick=\"goToPage(" + i + ")\">" + i + "</button>";
            }
            document.getElementById("pageNumbers").innerHTML = html;
        }

        function goToPage(page) {
            if (page < 1 || page > totalPages) return;
            currentPage = page;
            renderPage();
            document.querySelector(".table-container").scrollIntoView({ behavior: "smooth", block: "start" });
        }

        function changePageSize() {
            pageSize = parseInt(document.getElementById("pageSizeSelect").value);
            totalPages = Math.ceil(paginatedClaims.length / pageSize) || 1;
            currentPage = 1;
            renderPage();
        }

        // Patch loadClaims to use pagination
        const origLoadClaims = loadClaims;
        loadClaims = async function() {
            document.getElementById("claimsLoading").style.display = "block";
            document.getElementById("claimsContent").style.display = "none";
            try {
                let query = supabaseClient.from("injury_claims_view").select("*").order("created_at", { ascending: false });
                const statusFilter = document.getElementById("filterStatus").value;
                const industryFilter = document.getElementById("filterIndustry").value;
                if (statusFilter) query = query.eq("status", statusFilter);
                if (industryFilter) query = query.eq("industry", industryFilter);
                const { data: claims, error } = await query;
                if (error) throw error;
                allClaims = claims;
                updateStatistics(claims);
                applyPagination(claims);
                document.getElementById("claimsLoading").style.display = "none";
                document.getElementById("claimsContent").style.display = "block";
            } catch (error) {
                console.error("Error loading claims:", error);
                document.getElementById("claimsLoading").innerHTML =
                    "<div style="text-align:center;padding:40px;"><p style="color:#e74c3c;margin-bottom:10px;">Error loading claims: " + error.message + "</p><button onclick="loadClaims()" style="margin-top:20px;padding:10px 20px;background:#333;color:white;border:none;border-radius:6px;cursor:pointer;">Retry</button></div>";
            }
        };

    