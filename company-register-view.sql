-- ============================================================
-- COMPANY REGISTER VIEW
-- Aggregates data from all incident/report tables per company
-- Shows: accidents, injury/disease reports, inspections, claims
-- ============================================================

-- First: create a unique company name list from all tables
-- and join back to get aggregate counts

CREATE OR REPLACE VIEW company_register_view AS
WITH companies AS (
    SELECT DISTINCT occupier_name AS company_name, industry_sector AS industry
    FROM accident_reports WHERE occupier_name IS NOT NULL AND occupier_name != ''
    UNION
    SELECT DISTINCT factory_name AS company_name, industry_type AS industry
    FROM workplace_inspections WHERE factory_name IS NOT NULL AND factory_name != ''
    UNION
    SELECT DISTINCT employer_name AS company_name, NULL::TEXT AS industry
    FROM injury_disease_reports WHERE employer_name IS NOT NULL AND employer_name != ''
    UNION
    SELECT DISTINCT name_of_employer AS company_name, industry AS industry
    FROM injury_claims WHERE name_of_employer IS NOT NULL AND name_of_employer != ''
)
SELECT
    c.company_name,
    c.industry,

    -- Accident reports
    COUNT(DISTINCT ar.id)                                                       AS accident_count,
    COUNT(DISTINCT ar.id) FILTER (WHERE ar.injury_fatal = 'Fatal')              AS fatal_accidents,
    COUNT(DISTINCT ar.id) FILTER (WHERE ar.report_type = 'dangerous_occurrence') AS dangerous_occurrences,
    MAX(ar.accident_date)                                                       AS last_accident_date,

    -- Workplace inspections
    COUNT(DISTINCT wi.id)                                                       AS inspection_count,
    ROUND(AVG(wi.compliance_level)::NUMERIC, 1)                                 AS avg_compliance_level,
    MAX(wi.inspection_date)                                                     AS last_inspection_date,
    COUNT(DISTINCT wi.id) FILTER (WHERE wi.follow_up_required = TRUE)           AS follow_ups_required,
    SUM(wi.employees_male + wi.employees_female)                                AS total_employees,

    -- Injury & disease reports
    COUNT(DISTINCT idr.id)                                                      AS injury_disease_count,
    COUNT(DISTINCT idr.id) FILTER (WHERE idr.incident_type = 'Disease')         AS disease_count,
    COUNT(DISTINCT idr.id) FILTER (WHERE idr.resulted_death = 'Yes')            AS idr_fatalities,
    MAX(idr.incident_date)                                                      AS last_idr_date,

    -- Compensation claims
    COUNT(DISTINCT ic.id)                                                       AS claim_count,
    COUNT(DISTINCT ic.id) FILTER (WHERE ic.status = 'draft')                    AS draft_claims,
    COUNT(DISTINCT ic.id) FILTER (WHERE ic.status = 'approved')                 AS approved_claims,

    -- Overall totals
    (COUNT(DISTINCT ar.id) + COUNT(DISTINCT idr.id))                            AS total_incidents,
    (COUNT(DISTINCT ar.id) FILTER (WHERE ar.injury_fatal = 'Fatal')
     + COUNT(DISTINCT idr.id) FILTER (WHERE idr.resulted_death = 'Yes'))        AS total_fatalities,

    -- Earliest and latest activity
    LEAST(
        MIN(ar.accident_date),
        MIN(wi.inspection_date),
        MIN(idr.incident_date),
        MIN(ic.date_of_injury)
    )                                                                           AS first_activity_date,
    GREATEST(
        MAX(ar.accident_date),
        MAX(wi.inspection_date),
        MAX(idr.incident_date),
        MAX(ic.date_of_injury)
    )                                                                           AS last_activity_date

FROM companies c
LEFT JOIN accident_reports ar         ON ar.occupier_name        = c.company_name
LEFT JOIN workplace_inspections wi    ON wi.factory_name         = c.company_name
LEFT JOIN injury_disease_reports idr  ON idr.employer_name       = c.company_name
LEFT JOIN injury_claims ic            ON ic.name_of_employer     = c.company_name

GROUP BY c.company_name, c.industry
ORDER BY c.company_name ASC;

COMMENT ON VIEW company_register_view IS
    'Aggregated company register — combines accidents, inspections, injury/disease reports, and compensation claims per company';

-- ── Grants ───────────────────────────────────────────────────
GRANT SELECT ON company_register_view TO authenticated;

-- ── Verify ───────────────────────────────────────────────────
SELECT 'company_register_view created successfully!' AS status;

SELECT company_name, accident_count, inspection_count, injury_disease_count, claim_count
FROM company_register_view
WHERE accident_count > 0 OR inspection_count > 0
ORDER BY company_name
LIMIT 20;
