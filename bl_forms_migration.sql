-- BL Form 43-02: Wages of Worker
CREATE TABLE IF NOT EXISTS bl_form_43_02_wages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_registry_id uuid REFERENCES public.workers_registry(id),
    submitted_by uuid REFERENCES auth.users(id),
    basic_pay_frequency TEXT,
    basic_pay_amount DECIMAL(12,2),
    month_1_pay DECIMAL(12,2), month_1_voucher TEXT,
    month_2_pay DECIMAL(12,2), month_2_voucher TEXT,
    month_3_pay DECIMAL(12,2), month_3_voucher TEXT,
    month_4_pay DECIMAL(12,2), month_4_voucher TEXT,
    month_5_pay DECIMAL(12,2), month_5_voucher TEXT,
    month_6_pay DECIMAL(12,2), month_6_voucher TEXT,
    month_7_pay DECIMAL(12,2), month_7_voucher TEXT,
    month_8_pay DECIMAL(12,2), month_8_voucher TEXT,
    month_9_pay DECIMAL(12,2), month_9_voucher TEXT,
    month_10_pay DECIMAL(12,2), month_10_voucher TEXT,
    month_11_pay DECIMAL(12,2), month_11_voucher TEXT,
    month_12_pay DECIMAL(12,2), month_12_voucher TEXT,
    other_remuneration_amount DECIMAL(12,2),
    average_monthly_wage DECIMAL(12,2),
    employer_name TEXT,
    employer_designation TEXT,
    employer_signature TEXT,
    employer_date DATE,
    worker_name TEXT,
    worker_address TEXT,
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- BL Form 43-07: Certificate of Insurance
CREATE TABLE IF NOT EXISTS certificate_of_insurance (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    submitted_by uuid REFERENCES auth.users(id),
    employer_name TEXT NOT NULL,
    employer_address TEXT,
    certificate_date DATE,
    signature TEXT,
    signatory_status TEXT,
    company_seal_url TEXT,
    insurer_name TEXT,
    policy_number TEXT,
    coverage_period_start DATE,
    coverage_period_end DATE,
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- BL Form 43-11: Notification of Medical Attendance
CREATE TABLE IF NOT EXISTS medical_attendance_notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_registry_id uuid REFERENCES public.workers_registry(id),
    submitted_by uuid REFERENCES auth.users(id),
    worker_name TEXT NOT NULL,
    worker_address TEXT,
    date_of_notice DATE,
    practitioner_name TEXT NOT NULL,
    place_of_examination TEXT,
    date_of_examination DATE,
    time_of_examination TIME,
    notification_date DATE,
    signature TEXT,
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
