# OSH Role System - Setup Checklist

## Quick Setup Guide (5 Minutes)

Follow these steps to enable the role-based access control system:

---

### ☑️ Step 1: Run Database Setup (2 minutes)

1. Open your Supabase Dashboard
2. Go to **SQL Editor**
3. Copy and paste the entire contents of `user-roles-setup.sql`
4. Click **RUN**
5. Wait for success message: "✅ User roles system set up successfully!"

**What this does:**
- Adds `role` column to user_profiles table
- Creates RLS policies for role-based permissions
- Sets up audit logging

---

### ☑️ Step 2: Assign First Super Admin (1 minute)

1. Still in Supabase SQL Editor
2. Open `setup-super-admin.sql`
3. **Edit line 6** - Replace `'your.email@example.com'` with YOUR actual email
4. Run the query
5. Verify you see your account listed as super_admin

**Example:**
```sql
UPDATE user_profiles 
SET role = 'super_admin'
WHERE email = 'john.doe@example.com';  -- ← Put your email here
```

---

### ☑️ Step 3: Test the System (2 minutes)

#### 3.1 Test Super Admin Access
1. **Logout** from your current session
2. **Login** with your super admin account
3. You should see a **role badge** next to your name
4. Navigate to **⚙ Admin** panel
5. You should see all users with a "Change Role" button

#### 3.2 Test Role Assignment
1. In Admin panel, click **"Change Role"** for a test user
2. Change their role to `officer`
3. Login as that user (or open in incognito mode)
4. Verify they can access **📋 Submit Claim** but not **⚙ Admin**

#### 3.3 Test Permissions
- **Viewer**: Can only view entries, no edit buttons work
- **Officer**: Can submit and edit own claims only
- **Admin**: Can edit all claims, access admin panel
- **Super Admin**: Full access, can manage all users

---

## ✅ Verification Checklist

Run these quick checks:

### Database Verification
```sql
-- Check role column exists
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name = 'role';

-- Check your super admin role
SELECT email, first_name, surname, role 
FROM user_profiles 
WHERE role = 'super_admin';

-- View all users with roles
SELECT email, role, is_active 
FROM user_profiles 
ORDER BY 
    CASE role
        WHEN 'super_admin' THEN 1
        WHEN 'admin' THEN 2
        WHEN 'officer' THEN 3
        WHEN 'viewer' THEN 4
    END;
```

### Frontend Verification
- [ ] Login page loads without errors
- [ ] Role badge appears next to username after login
- [ ] Admin panel accessible only to admins/super admins
- [ ] Submit Claim form accessible only to officers+
- [ ] Edit buttons disabled for viewers
- [ ] Officers can only edit their own claims

---

## Common Issues & Fixes

### ❌ Issue: "Role column already exists" error
**Fix:** Role system already set up, skip to Step 2

### ❌ Issue: Can't see Admin panel
**Fix:** 
```sql
-- Check your role
SELECT email, role FROM user_profiles WHERE email = 'your@email.com';

-- If not super_admin or admin, update:
UPDATE user_profiles SET role = 'super_admin' WHERE email = 'your@email.com';
```

### ❌ Issue: "Permission denied" errors
**Fix:** Re-run the `user-roles-setup.sql` file completely

### ❌ Issue: Edit buttons still work for viewers
**Fix:** 
1. Hard refresh the page (Ctrl + Shift + R)
2. Clear browser cache
3. Check browser console for JavaScript errors

---

## Default Role Assignment

When new users sign up:
- **Default role**: `viewer`
- **Can be changed by**: Admin or Super Admin
- **Changed via**: Admin panel → "Change Role" button

---

## Role Change Instructions

### For Admins/Super Admins (Via UI):
1. Go to **⚙ Admin** panel
2. Find user in the table
3. Click **"Change Role"**
4. Select: `viewer`, `officer`, `admin`, or `super_admin`
5. Confirm

### For Super Admins (Via SQL):
```sql
-- Change any user's role
UPDATE user_profiles 
SET role = 'officer'  -- or 'admin', 'super_admin', 'viewer'
WHERE email = 'user@example.com';
```

---

## Security Notes

✅ **Super Admin Protection**
- Super admins can only be created via SQL
- Super admin accounts can only be edited by themselves or other super admins
- Admins cannot see or modify super admin accounts

✅ **Double Layer Security**
- Client-side: Fast UI feedback (shows/hides buttons)
- Database-side: Enforced by RLS policies (cannot be bypassed)

✅ **Audit Trail**
- All role changes logged in `role_change_log` table
- View logs: `SELECT * FROM role_change_log ORDER BY changed_at DESC;`

---

## Quick Reference: What Each Role Can Do

| Can Do | Viewer | Officer | Admin | Super Admin |
|--------|:------:|:-------:|:-----:|:-----------:|
| View claims | ✅ | ✅ | ✅ | ✅ |
| Submit claims | ❌ | ✅ | ✅ | ✅ |
| Edit own claims | ❌ | ✅ | ✅ | ✅ |
| Edit all claims | ❌ | ❌ | ✅ | ✅ |
| Admin panel | ❌ | ❌ | ✅ | ✅ |
| Manage users* | ❌ | ❌ | ✅ | ✅ |
| Manage super admins | ❌ | ❌ | ❌ | ✅ |

*Admins can manage all users except super admins

---

## Next Steps

After setup is complete:

1. **Assign Roles** to existing users based on their responsibilities
2. **Test thoroughly** with different role accounts
3. **Document** your specific role assignment policies
4. **Train users** on the new permission system
5. **Review roles** periodically (monthly recommended)

---

## Files Reference

📄 **Setup Files:**
- `user-roles-setup.sql` - Main setup script
- `setup-super-admin.sql` - First super admin assignment
- `ROLES_SETUP_GUIDE.md` - Detailed documentation
- `SETUP_CHECKLIST.md` - This file

📄 **Code Files:**
- `role-permissions.js` - Client-side permission checking
- All `*.html` files - Updated with role integration

---

## Support

**Need Help?**
1. Check `ROLES_SETUP_GUIDE.md` for detailed documentation
2. Review browser console for JavaScript errors
3. Check Supabase logs for database errors
4. Verify setup using SQL queries above

---

**Setup Complete!** 🎉

Your OSH system now has a fully functional role-based access control system.
