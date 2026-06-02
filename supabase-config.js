// Supabase Configuration
const SUPABASE_URL = 'https://qblogmmknnacaaircrlt.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibG9nbW1rbm5hY2FhaXJjcmx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzODM5MzcsImV4cCI6MjA5NTk1OTkzN30.qQB1DhoAn-W1wqSMyJpwQ3cqX0JWhw54kb_XOb5fU5s';

// Initialize Supabase client
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Helper function to handle errors
function handleError(error) {
    console.error('Error:', error);
    if (error.message) {
        return error.message;
    }
    return 'An unexpected error occurred';
}

// Sign up function
async function signUp(userData) {
    try {
        // Create user with Supabase Auth
        const { data: authData, error: authError } = await supabase.auth.signUp({
            email: userData.email,
            password: userData.password,
            options: {
                data: {
                    first_name: userData.firstName,
                    surname: userData.surname,
                    department: userData.department,
                    location: userData.location
                }
            }
        });

        if (authError) throw authError;

        // Insert additional user data into custom users table
        const { data: profileData, error: profileError } = await supabase
            .from('user_profiles')
            .insert([
                {
                    user_id: authData.user.id,
                    first_name: userData.firstName,
                    surname: userData.surname,
                    email: userData.email,
                    department: userData.department,
                    location: userData.location,
                    created_at: new Date().toISOString()
                }
            ]);

        if (profileError) throw profileError;

        return { success: true, data: authData };
    } catch (error) {
        return { success: false, error: handleError(error) };
    }
}

// Sign in function
async function signIn(email, password, remember = false) {
    try {
        const { data, error } = await supabase.auth.signInWithPassword({
            email: email,
            password: password
        });

        if (error) throw error;

        // Store session info if "remember me" is checked
        if (remember) {
            localStorage.setItem('rememberMe', 'true');
        }

        return { success: true, data: data };
    } catch (error) {
        return { success: false, error: handleError(error) };
    }
}

// Sign out function
async function signOut() {
    try {
        const { error } = await supabase.auth.signOut();
        if (error) throw error;
        localStorage.removeItem('rememberMe');
        return { success: true };
    } catch (error) {
        return { success: false, error: handleError(error) };
    }
}

// Get current user
async function getCurrentUser() {
    try {
        const { data: { user }, error } = await supabase.auth.getUser();
        if (error) throw error;
        return { success: true, user: user };
    } catch (error) {
        return { success: false, error: handleError(error) };
    }
}

// Get user profile
async function getUserProfile(userId) {
    try {
        const { data, error } = await supabase
            .from('user_profiles')
            .select('*')
            .eq('user_id', userId)
            .single();

        if (error) throw error;
        return { success: true, data: data };
    } catch (error) {
        return { success: false, error: handleError(error) };
    }
}

// Update user profile
async function updateUserProfile(userId, updates) {
    try {
        const { data, error } = await supabase
            .from('user_profiles')
            .update(updates)
            .eq('user_id', userId);

        if (error) throw error;
        return { success: true, data: data };
    } catch (error) {
        return { success: false, error: handleError(error) };
    }
}

// Reset password
async function resetPassword(email) {
    try {
        const { error } = await supabase.auth.resetPasswordForEmail(email, {
            redirectTo: window.location.origin + '/reset-password.html'
        });

        if (error) throw error;
        return { success: true };
    } catch (error) {
        return { success: false, error: handleError(error) };
    }
}

// Check if user is authenticated
async function isAuthenticated() {
    const { data: { session } } = await supabase.auth.getSession();
    return session !== null;
}
