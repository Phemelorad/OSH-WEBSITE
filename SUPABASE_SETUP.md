# Supabase Backend Setup Instructions

## Prerequisites
- A Supabase account (sign up at https://supabase.com)

## Step 1: Create a Supabase Project

1. Go to https://supabase.com and sign in
2. Click "New Project"
3. Fill in the project details:
   - Project Name: OSH Website
   - Database Password: (choose a strong password)
   - Region: (choose closest to your location)
4. Click "Create New Project"
5. Wait for the project to be provisioned (takes 1-2 minutes)

## Step 2: Get Your Project Credentials

1. In your Supabase project dashboard, go to **Settings** > **API**
2. Find and copy these two values:
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **anon public key** (long string of characters)

## Step 3: Configure Your Application

1. Open the file `supabase-config.js`
2. Replace the placeholder values:
   ```javascript
   const SUPABASE_URL = 'YOUR_SUPABASE_URL'; // Replace with your Project URL
   const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY'; // Replace with your anon key
   ```

## Step 4: Create Database Table

1. In your Supabase dashboard, go to **SQL Editor**
2. Click "New Query"
3. Copy and paste the following SQL:

```sql
-- Create user_profiles table
CREATE TABLE user_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    surname TEXT NOT NULL,
    email TEXT NOT NULL,
    department TEXT NOT NULL,
    location TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Users can read their own profile
CREATE POLICY "Users can view own profile"
    ON user_profiles
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile"
    ON user_profiles
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON user_profiles
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Create index for faster queries
CREATE INDEX user_profiles_user_id_idx ON user_profiles(user_id);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

4. Click **Run** to execute the query

## Step 5: Configure Email Authentication

1. In your Supabase dashboard, go to **Authentication** > **Providers**
2. Make sure **Email** is enabled (it should be by default)
3. Optional: Configure email templates in **Authentication** > **Email Templates**

### Email Settings (Important!)

For development/testing:
- Supabase provides a default email service
- Check your spam folder for verification emails

For production:
1. Go to **Settings** > **Auth**
2. Configure a custom SMTP server (recommended: SendGrid, AWS SES, or Mailgun)
3. Update the "Site URL" to your production domain
4. Update "Redirect URLs" to include your production domain

## Step 6: Configure Site URL

1. Go to **Authentication** > **URL Configuration**
2. Set **Site URL** to your website URL:
   - Development: `http://localhost:3000` or `http://127.0.0.1:5500`
   - Production: `https://yourdomain.com`
3. Add redirect URLs if needed

## Step 7: Test Your Setup

1. Open `index.html` in a browser
2. Click "Sign up" and create a test account
3. Check your email for the verification link
4. Click the verification link
5. Return to `index.html` and log in with your credentials
6. You should be redirected to the dashboard

## Project Structure

```
osh website/
├── index.html              # Login page
├── signup.html             # Registration page
├── dashboard.html          # User dashboard (after login)
├── supabase-config.js      # Supabase configuration and functions
└── SUPABASE_SETUP.md      # This file
```

## Available Functions

The `supabase-config.js` file provides these functions:

- `signUp(userData)` - Register a new user
- `signIn(email, password, remember)` - Login a user
- `signOut()` - Logout current user
- `getCurrentUser()` - Get current authenticated user
- `getUserProfile(userId)` - Get user profile data
- `updateUserProfile(userId, updates)` - Update user profile
- `resetPassword(email)` - Send password reset email
- `isAuthenticated()` - Check if user is logged in

## Security Notes

### Row Level Security (RLS)
- RLS is enabled on the `user_profiles` table
- Users can only view and edit their own profiles
- This prevents unauthorized access to other users' data

### Environment Variables
For production, consider:
1. Moving credentials to environment variables
2. Using a build process to inject credentials
3. Never commit real credentials to version control

### Password Requirements
Current requirements:
- Minimum 8 characters
- Mix of uppercase and lowercase letters
- Numbers
- Special characters (recommended)

You can adjust these in `signup.html` validation code.

## Troubleshooting

### Email not received
- Check spam folder
- Verify email settings in Supabase dashboard
- For production, configure custom SMTP

### Login fails
- Verify user has confirmed their email
- Check browser console for error messages
- Verify credentials in `supabase-config.js`

### Database errors
- Ensure SQL script ran successfully
- Check table exists in **Table Editor**
- Verify RLS policies are created

### CORS errors
- Add your domain to allowed URLs in Supabase settings
- Check Site URL and Redirect URLs configuration

## Additional Features to Consider

1. **Password Reset Page**: Create `reset-password.html` for password recovery
2. **Email Verification**: Add a custom verification page
3. **Profile Edit**: Allow users to update their profile information
4. **Admin Panel**: Add role-based access control
5. **Audit Logging**: Track user activities
6. **Two-Factor Authentication**: Enable 2FA in Supabase

## Support

For more information:
- Supabase Documentation: https://supabase.com/docs
- Supabase Auth Guide: https://supabase.com/docs/guides/auth
- Community: https://github.com/supabase/supabase/discussions
