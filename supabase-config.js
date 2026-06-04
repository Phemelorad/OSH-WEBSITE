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
                        role: userData.role || 'viewer'
                    }
                }
            });

            if (authError) throw authError;

            // Check if user was created successfully
            if (!authData.user) {
                throw new Error('User creation failed');
            }

            // Wait a moment for the session to be established
            await new Promise(resolve => setTimeout(resolve, 500));

            // If this is a company registration, create the company record first
            let companyId = null;
            if (userData.role === 'company' && userData.companyName) {
                const { data: companyData, error: companyError } = await supabaseClient
                    .from('companies')
                    .insert([{
                        company_name: userData.companyName,
                        industry: userData.industry || null,
                        location: userData.location || null,
                        telephone: userData.companyPhone || null,
                        owner_name: userData.ownerName || null,
                        owner_email: userData.ownerEmail || null
                    }])
                    .select('id')
                    .single();

                if (companyError) {
                    console.warn('Company creation failed:', companyError);
                    // Non-fatal — profile will still be created without company link
                } else if (companyData) {
                    companyId = companyData.id;
                }
            }

            // Get the current session to ensure we're authenticated
            const { data: { session } } = await supabaseClient.auth.getSession();
            
            if (!session) {
                // User created but not logged in (email confirmation required)
                return { 
                    success: true, 
                    data: authData,
                    message: 'Please verify your email before logging in'
                };
            }

            // User is authenticated, now insert profile
            const profileFields = {
                user_id: authData.user.id,
                first_name: userData.firstName,
                surname: userData.surname,
                email: userData.email,
                department: userData.department || 'osh',
                location: userData.location || 'Not specified',
                role: userData.role || 'viewer',
                created_at: new Date().toISOString()
            };

            if (companyId && userData.role === 'company') {
                profileFields.company_id = companyId;
            }

            const { data: profileData, error: profileError } = await supabaseClient
                .from('user_profiles')
                .insert([profileFields])
                .select();

            if (profileError) {
                console.warn('Profile creation failed:', profileError);
                // Don't throw error - profile can be created on first login
            }

            return { success: true, data: authData };
        } catch (error) {
            return { success: false, error: handleError(error) };
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

            // Store session info if "remember me" is checked
            if (remember) {
                localStorage.setItem('rememberMe', 'true');
            }

            // Check if user profile exists, create if not
            if (data.user) {
                const { data: profile, error: profileError } = await supabaseClient
                    .from('user_profiles')
                    .select('*')
                    .eq('user_id', data.user.id)
                    .single();

                if (profileError && profileError.code === 'PGRST116') {
                    // Profile doesn't exist, create it from user metadata
                    const metadata = data.user.user_metadata;
                    const { error: insertError } = await supabaseClient
                        .from('user_profiles')
                        .insert([
                            {
                                user_id: data.user.id,
                                first_name: metadata.first_name || 'User',
                                surname: metadata.surname || 'Name',
                                email: data.user.email,
                                department: metadata.department || 'osh',
                                location: metadata.location || 'Not specified',
                                created_at: new Date().toISOString()
                            }
                        ]);

                    if (insertError) {
                        console.warn('Could not create profile on login:', insertError);
                    }
                }
            }

            return { success: true, data: data };
        } catch (error) {
            return { success: false, error: handleError(error) };
        }
    };

    // Sign out function
    window.signOut = async function() {
        try {
            const { error } = await supabaseClient.auth.signOut();
            if (error) throw error;
            localStorage.removeItem('rememberMe');
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
                .single();

            if (error) throw error;
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

    // Reset password
    window.resetPassword = async function(email) {
        try {
            const { error } = await supabaseClient.auth.resetPasswordForEmail(email, {
                redirectTo: window.location.origin + '/reset-password.html'
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

    console.log('Supabase configuration loaded successfully');
})();
