// Supabase Configuration and Functions
(function() {
    'use strict';
    
    // Supabase Configuration
    const SUPABASE_URL = 'https://qblogmmknnacaaircrlt.supabase.co';
    const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibG9nbW1rbm5hY2FhaXJjcmx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzODM5MzcsImV4cCI6MjA5NTk1OTkzN30.qQB1DhoAn-W1wqSMyJpwQ3cqX0JWhw54kb_XOb5fU5s';

    // Initialize Supabase client
    const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    // Expose client globally so other pages/scripts can use it
    window.supabaseClient = supabaseClient;

    // Helper function to handle errors
    // Map form role values to database role values (delegated to constants.js)
    function mapRole(formRole) {
        if (window.OSH_CONSTANTS) {
            return window.OSH_CONSTANTS.mapRole(formRole);
        }
        if (formRole === 'osh_officer') return 'officer';
        if (formRole === 'medical_practitioner') return 'medical_practitioner';
        return formRole;
    }

    function handleError(error) {
        console.error('Error:', error);
        if (error.message) {
            return error.message;
        }
        return 'An unexpected error occurred';
    }

    // Sign up function
    window.signUp = async function(userData) {
        try {
            // Create user with Supabase Auth
            const { data: authData, error: authError } = await supabaseClient.auth.signUp({
                email: userData.email,
                password: userData.password,
                options: {
                    data: {
                        first_name: userData.firstName,
                        surname: userData.surname,
                        department: userData.department || 'osh',
                        location: userData.location,
                        designation: userData.designation || null,
                        role: mapRole(userData.role || 'viewer'),
                        company_name: userData.companyName || null,
                        company_industry: userData.industry || null,
                        company_location: userData.location || null,
                        company_telephone: userData.companyPhone || null,
                        company_owner_name: userData.ownerName || null,
                        company_owner_email: userData.ownerEmail || null,
                        company_cipa_number: userData.cipaNumber || null,
                        company_plot_number: userData.plotNumber || null,
                        company_street_name: userData.streetName || null,
                        company_physical_address: userData.physicalAddress || null,
                        practice_name: userData.practiceName || null,
                        med_reg_number: userData.medRegNumber || null
                    }
                }
            });

            if (authError) throw authError;

            // Check if user was created successfully
            if (!authData.user) {
                throw new Error('User creation failed');
            }

            // Wait a moment for session/trigger to settle
            await new Promise(resolve => setTimeout(resolve, 500));

            // Get the current session to ensure we're authenticated
            const { data: { session } } = await supabaseClient.auth.getSession();
            
            if (!session) {
                // User created but not logged in (email confirmation required).
                // Company/profile creation will happen on first login.
                return { 
                    success: true, 
                    data: authData,
                    message: 'Please verify your email before logging in'
                };
            }

            // Auto-confirmed (email confirmation disabled).
            // Profile/company creation is deferred to ensureUserProfile()
            // which the registration handler will call before redirecting.
            return { success: true, data: authData, autoConfirmed: true, session: session };
        } catch (error) {
            return { success: false, error: handleError(error) };
        }
    };

    // ── Shared: ensure profile + company exist for a user ──
    // Used by both signIn() and the auto-redirect handler
    window.ensureUserProfile = async function(user) {
        if (!user) return { success: false, error: 'No user provided' };

        const { data: profile, error: profileError } = await supabaseClient
            .from('user_profiles')
            .select('*, company_id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (profileError) {
            console.warn('Profile lookup error:', profileError);
        }

        if (!profile) {
            // Profile doesn't exist — create it from user metadata
            const metadata = user.user_metadata;
            const role = mapRole(metadata.role || 'viewer');

            let companyId = null;

            // If this is a company user, try to find or create the company record
            if (role === 'company') {
                const companyName = metadata.company_name || metadata.companyName;
                if (companyName) {
                    const { data: existing } = await supabaseClient
                        .from('companies')
                        .select('id')
                        .ilike('company_name', companyName)
                        .maybeSingle();

                    if (existing) {
                        companyId = existing.id;
                    } else {
                        const companyFields = {
                            company_name: companyName,
                            industry: metadata.company_industry || null,
                            location: metadata.company_location || null,
                            telephone: metadata.company_telephone || null,
                            owner_name: metadata.company_owner_name || null,
                            owner_email: metadata.company_owner_email || null,
                            cipa_number: metadata.company_cipa_number || null,
                            plot_number: metadata.company_plot_number || null,
                            street_name: metadata.company_street_name || null,
                            physical_address: metadata.company_physical_address || null
                        };
                        const { data: newCompany, error: ce } = await supabaseClient
                            .from('companies')
                            .insert([companyFields])
                            .select('id')
                            .maybeSingle();

                        if (ce) {
                            console.warn('Company creation failed:', ce);
                        } else if (newCompany) {
                            companyId = newCompany.id;
                        }
                    }
                }
            }

            const profileFields = {
                user_id: user.id,
                first_name: metadata.first_name || 'User',
                surname: metadata.surname || 'Name',
                email: user.email,
                department: metadata.department || 'osh',
                location: metadata.location || 'Not specified',
                designation: metadata.designation || null,
                role: role,
                created_at: new Date().toISOString()
            };

            if (companyId) {
                profileFields.company_id = companyId;
            }

            const { error: insertError } = await supabaseClient
                .from('user_profiles')
                .insert([profileFields]);

            if (insertError) {
                console.error('Profile creation failed:', insertError);
                return { success: false, error: 'Profile creation failed: ' + insertError.message };
            }

            return { success: true, role: role, company_id: companyId };
        } else {
            // Profile exists — ensure company_id is set for company users
            // NOTE: We do NOT overwrite role from metadata here because the
            // database profile is the source of truth. Metadata only reflects
            // the original registration role and would revert admin-upgraded roles.
            const updates = {};

            if (profile.role === 'company' && !profile.company_id) {
                const metadata = user.user_metadata;
                const companyName = metadata.company_name || metadata.companyName;
                if (companyName) {
                    const { data: company } = await supabaseClient
                        .from('companies')
                        .select('id')
                        .ilike('company_name', companyName)
                        .maybeSingle();

                    if (company) {
                        updates.company_id = company.id;
                    }
                }
            }

            if (Object.keys(updates).length > 0) {
                await supabaseClient
                    .from('user_profiles')
                    .update(updates)
                    .eq('user_id', user.id);
            }

            return { success: true, role: profile.role, company_id: profile.company_id };
        }
    };

    // Sign in function
    window.signIn = async function(email, password, remember = false) {
        try {
            const { data, error } = await supabaseClient.auth.signInWithPassword({
                email: email,
                password: password
            });

            if (error) throw error;

            if (remember) {
                localStorage.setItem('rememberMe', 'true');
            }

            // Ensure profile + company exist, then cache
            if (data.user) {
                await window.ensureUserProfile(data.user);

                // Record last sign-in timestamp (silently — column may not exist yet)
                try {
                    await supabaseClient
                        .from('user_profiles')
                        .update({ last_sign_in: new Date().toISOString() })
                        .eq('user_id', data.user.id);
                } catch (e) {
                    // Column might not exist yet — non-critical
                }

                // Cache the full profile for instant lookup on subsequent pages
                const cacheResult = await supabaseClient
                    .from('user_profiles')
                    .select('*')
                    .eq('user_id', data.user.id)
                    .maybeSingle();
                if (cacheResult.data) {
                    // Enrich with company name so header shows it immediately
                    if (window.enrichProfileWithCompanyName) {
                        await window.enrichProfileWithCompanyName(cacheResult.data);
                    }
                    cacheUserProfile(cacheResult.data);
                }
            }

            return { success: true, data: data };
        } catch (error) {
            let msg = handleError(error) || "Login failed";
            const lc = msg.toLowerCase();
            if (lc.includes("invalid login credentials")) {
                msg = "Invalid email or password. Check your credentials.\n\nIf you haven't verified your email yet, use the \"Resend confirmation?\" link below or check your inbox/spam folder.";
            } else if (lc.includes("email not confirmed")) {
                msg = "Email not yet verified. Please check your inbox (including spam) for the confirmation email, or use the \"Resend confirmation?\" link below.";
            } else if (lc.includes("rate limit") || lc.includes("too many")) {
                msg = "Too many login attempts. Please wait a few minutes before trying again.";
            }
            return { success: false, error: msg };
        }
    };

    // Sign out function
    window.signOut = async function() {
        try {
            const { error } = await supabaseClient.auth.signOut();
            if (error) throw error;
            localStorage.removeItem('rememberMe');
            clearCachedUserProfile();
            // Clear all stale data caches so next user doesn't see previous user's data
            try {
                sessionStorage.removeItem('osh_company_name');
                sessionStorage.removeItem('user');
                sessionStorage.removeItem('company_booking_responses');
            } catch (e) {}
            return { success: true };
        } catch (error) {
            return { success: false, error: handleError(error) };
        }
    };

    // Get current user
    window.getCurrentUser = async function() {
        try {
            const { data: { user }, error } = await supabaseClient.auth.getUser();
            if (error) throw error;
            return { success: true, user: user };
        } catch (error) {
            return { success: false, error: handleError(error) };
        }
    };

    // Get user profile
    window.getUserProfile = async function(userId) {
        try {
            const { data, error } = await supabaseClient
                .from('user_profiles')
                .select('*')
                .eq('user_id', userId)
                .maybeSingle();

            if (error && error.code !== 'PGRST116') {
                return { success: false, error: handleError(error) };
            }
            if (!data) {
                return { success: false, error: 'Profile not found' };
            }
            return { success: true, data: data };
        } catch (error) {
            return { success: false, error: handleError(error) };
        }
    };

    // Update user profile
    window.updateUserProfile = async function(userId, updates) {
        try {
            const { data, error } = await supabaseClient
                .from('user_profiles')
                .update(updates)
                .eq('user_id', userId);

            if (error) throw error;
            return { success: true, data: data };
        } catch (error) {
            return { success: false, error: handleError(error) };
        }
    };

    // Resend confirmation email
    window.resendConfirmation = async function(email) {
        try {
            const { error } = await supabaseClient.auth.resend({
                type: 'signup',
                email: email
            });

            if (error) throw error;
            return { success: true };
        } catch (error) {
            return { success: false, error: handleError(error) };
        }
    };

    // Reset password
    window.resetPassword = async function(email) {
        try {
            // Build correct redirect URL — works for both local and GitHub Pages subpaths
            const basePath = window.location.pathname.replace(/\/[^/]*$/, '');
            const redirectTo = window.location.origin + basePath + '/reset-password.html';

            const { error } = await supabaseClient.auth.resetPasswordForEmail(email, {
                redirectTo: redirectTo
            });

            if (error) throw error;
            return { success: true };
        } catch (error) {
            return { success: false, error: handleError(error) };
        }
    };

    // Check if user is authenticated
    window.isAuthenticated = async function() {
        const { data: { session } } = await supabaseClient.auth.getSession();
        return session !== null;
    };

    // ── User profile cache ──────────────────────────────────────
    const CACHE_KEY = 'osh_user_profile';

    function cacheUserProfile(profile) {
        try {
            sessionStorage.setItem(CACHE_KEY, JSON.stringify({
                ...profile,
                cached_at: Date.now()
            }));
        } catch (e) {
            // sessionStorage may be full or unavailable
        }
    }

    function getCachedUserProfile() {
        try {
            const raw = sessionStorage.getItem(CACHE_KEY);
            if (!raw) return null;
            const data = JSON.parse(raw);
            // Cache valid for 10 minutes, then force refresh
            if (Date.now() - (data.cached_at || 0) > 10 * 60 * 1000) {
                sessionStorage.removeItem(CACHE_KEY);
                return null;
            }
            return data;
        } catch (e) {
            return null;
        }
    }

    function clearCachedUserProfile() {
        try {
            sessionStorage.removeItem(CACHE_KEY);
        } catch (e) {}
    }

    // Expose cache functions globally so all pages can use them
    window.cacheUserProfile = cacheUserProfile;
    window.getCachedUserProfile = getCachedUserProfile;
    window.clearCachedUserProfile = clearCachedUserProfile;
    // ── Company search ───────────────────────────────────────────
    window.searchCompany = async function(name) {
        if (!name || name.length < 3) return null;
        try {
            const { data, error } = await supabaseClient
                .from("companies")
                .select("*")
                .ilike("company_name", name + "%")
                .limit(1);
            if (error) throw error;
            return data && data.length > 0 ? data[0] : null;
        } catch (e) {
            console.warn("Company lookup failed:", e);
            return null;
        }
    };

})();
