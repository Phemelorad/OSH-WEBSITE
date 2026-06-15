# OSH Role-Based Access Control System

## Overview

The OSH system now implements a comprehensive 4-tier role-based access control system:

### Role Hierarchy

1. **Viewer** (Default)
   - ✅ Can view all claims and entries
   - ❌ Cannot submit new claims
   - ❌ Cannot edit claims
   - ❌ No access to admin panel

2. **Officer**
   - ✅ Can view all claims and entries
   - ✅ Can submit new claims
   - ✅ Can edit **only their own** claims
   - ❌ No access to admin panel

3. **Admin**
   - ✅ Can view all claims and entries
   - ✅ Can submit new claims
   - ✅ Can edit **all claims**
   - ✅ Access to admin panel
   - ✅ Can manage all users **except super admins**
   - ❌ Cannot edit super admin accounts

4. **Super Admin**
   - ✅ Full system access
   - ✅ Can manage **all users** including other super admins
   - ✅ Super admin accounts can only be edited by themselves or other super admins

---

## Database Setup

### Step 1: Run the Role System SQL

Execute the following SQL file in your Supabase SQL Editor:

```sql
-- File: user-roles-setup.sql
```

This will:
- Add `role` column to `user_profiles` table
- Create Row Level Security (RLS) policies for role-based permissions
- Create reference tables and helper functions
- Create audit logging for role changes

### Step 2: Assign Your First Super Admin

Edit and run `setup-super-admin.sql`:

```sql
-- Option 1: By email (RECOMMENDED)
UPDATE user_profiles 
SET role = 'super_admin'
WHERE email = 'your.email@example.com';  -- Replace with your email

-- Option 2: By user_id
UPDATE user_profiles 
SET role = 'super_admin'
WHERE user_id = 'YOUR_USER_ID_HERE';

-- Option 3: Make first user super admin
UPDATE user_profiles 
SET role = 'super_admin'
WHERE id = (SELECT id FROM user_profiles ORDER BY created_at ASC LIMIT 1);
```

### Step 3: Verify Setup

Run this query to verify roles are set up correctly:

```sql
SELECT 
    email,
    first_name,
    surname,
    role,
    created_at
FROM user_profiles
ORDER BY 
    CASE role
        WHEN 'super_admin' THEN 1
        WHEN 'admin' THEN 2
        WHEN 'officer' THEN 3
        WHEN 'viewer' THEN 4
    END;
```

---

## Frontend Integration

All HTML pages have been updated with the role permissions system:

### Files Modified:
- ✅ `admin.html` - Admin panel with role management
- ✅ `entries.html` - Claims viewing with role-based edit permissions
- ✅ `form.html` - Claim submission with role checking
- ✅ `dashboard.html` - Dashboard with role-based navigation
- ✅ `index.html` - Login page
- ✅ `signup.html` - Registration (new users default to 'viewer')

### Integration Pattern:

Each page includes:

```html
<!-- Role Permissions System -->
<script src="role-permissions.js"></script>

<script>
    window.addEventListener('load', async function() {
        // ... authentication check ...
        
        // Initialize role system
        await initializeRoleSystem();
        
        // Check page access (for restricted pages)
        checkPageAccess();
        
        // Enforce UI permissions
        enforcePermissions();
    });
</script>
```

---

## How It Works

### Client-Side Enforcement

The `role-permissions.js` file provides functions to check permissions:

```javascript
// Check specific permissions
hasPermission('submit_claims')      // true/false
canAccessAdmin()                    // admin or super_admin only
canSubmitClaims()                   // officer, admin, or super_admin
canEditClaims(claimOwnerId)        // checks ownership for officers
canManageUsers(targetUserRole)     // checks if can manage target role

// Get current role
getCurrentUserRole()                // returns 'viewer', 'officer', 'admin', or 'super_admin'

// UI updates
updateUIForRole()                   // hides/shows elements based on role
enforcePermissions()                // disables buttons based on role
checkPageAccess()                   // redirects if page is not accessible
```

### Database-Level Enforcement

Row Level Security (RLS) policies enforce permissions at the database level:

#### User Profiles Table:
- **SELECT**: All authenticated users can view all profiles
- **INSERT**: Users can insert their own profile (role defaults to 'viewer')
- **UPDATE**: 
  - Users can update their own profile (but not change their role)
  - Admins can update profiles except super admins
  - Super admins can update all profiles

#### Injury Claims Table:
- **SELECT**: All authenticated users can view all claims
- **INSERT**: Only officers, admins, and super admins can insert
- **UPDATE**: 
  - Officers can update only their own claims
  - Admins and super admins can update all claims

---

## Managing User Roles

### Via Admin Panel (Recommended)

1. Login as an admin or super admin
2. Navigate to **⚙ Admin** panel
3. Find the user in the table
4. Click **"Change Role"** button
5. Select new role: viewer, officer, admin, or super_admin
6. Confirm the change

**Note**: Admins cannot assign super_admin role or manage existing super admins.

### Via SQL (For Super Admins)

```sql
-- Change a user's role
UPDATE user_profiles 
SET role = 'admin'  -- or 'viewer', 'officer', 'super_admin'
WHERE email = 'user@example.com';

-- View all role changes (audit log)
SELECT * FROM role_change_log 
ORDER BY changed_at DESC;
```

---

## Page Access Rules

### Public Pages (No Login Required)
- `index.html` - Login page
- `signup.html` - Registration page

### Authenticated Pages (All Roles)
- `dashboard.html` - Dashboard home
- `entries.html` - View claims (edit restricted by role)

### Officer+ Required
- `form.html` - Submit claims

### Admin+ Required
- `admin.html` - Admin panel

---

## Permission Matrix

| Feature | Viewer | Officer | Admin | Super Admin |
|---------|--------|---------|-------|-------------|
| View Claims | ✅ | ✅ | ✅ | ✅ |
| Submit Claims | ❌ | ✅ | ✅ | ✅ |
| Edit Own Claims | ❌ | ✅ | ✅ | ✅ |
| Edit All Claims | ❌ | ❌ | ✅ | ✅ |
| Access Admin Panel | ❌ | ❌ | ✅ | ✅ |
| Manage Users | ❌ | ❌ | ✅* | ✅ |
| Manage Super Admins | ❌ | ❌ | ❌ | ✅ |

*Admins can manage viewers, officers, and other admins, but NOT super admins.

---

## Security Features

### 1. **Double-Layer Security**
- Client-side role checking (UX - fast feedback)
- Database RLS policies (Security - enforced at data level)

### 2. **Super Admin Protection**
- Super admin accounts can only be edited by themselves or other super admins
- Admins cannot see or modify super admin role assignments
- Super admin role cannot be assigned through the UI (only via SQL)

### 3. **Audit Trail**
- All role changes are logged in `role_change_log` table
- Tracks: user_id, old_role, new_role, changed_by, timestamp, reason

### 4. **Default to Least Privilege**
- New users default to 'viewer' role
- Must be explicitly promoted by admins

---

## Testing the System

### Test Scenarios:

1. **Viewer Role**
   - Login as viewer
   - Should NOT see "Submit Claim" or "Admin" navigation links
   - Can view entries but cannot edit status

2. **Officer Role**
   - Login as officer
   - Can access form to submit claims
   - Can edit claims they submitted
   - Cannot edit other users' claims
   - Cannot access admin panel

3. **Admin Role**
   - Login as admin
   - Can access admin panel
   - Can edit all claims
   - Can change roles of viewers, officers, and other admins
   - Cannot change super admin roles

4. **Super Admin Role**
   - Full system access
   - Can manage all users including other super admins

---

## Troubleshooting

### Issue: User stuck in viewer role

**Solution**: Admin or super admin needs to change their role:

```sql
UPDATE user_profiles 
SET role = 'officer'  -- or 'admin'
WHERE email = 'user@example.com';
```

### Issue: Cannot access admin panel

**Check**:
1. User role must be 'admin' or 'super_admin'
2. Check browser console for errors
3. Verify RLS policies are active:

```sql
SELECT * FROM pg_policies 
WHERE tablename = 'user_profiles';
```

### Issue: Role changes not taking effect

**Solution**: 
1. Refresh the page (role is loaded on page load)
2. Check role was actually changed in database:

```sql
SELECT email, role FROM user_profiles WHERE email = 'user@example.com';
```

### Issue: "Permission Denied" errors in Supabase

**Solution**: Run the RLS policy setup from `user-roles-setup.sql` again.

---

## Best Practices

1. **Start with One Super Admin**
   - Assign yourself super_admin role first
   - Create other admins as needed

2. **Use Least Privilege**
   - Default users to 'viewer'
   - Promote to 'officer' for regular users who need to submit claims
   - Reserve 'admin' for managers/supervisors
   - Limit 'super_admin' to 1-2 trusted individuals

3. **Regular Audits**
   - Review role assignments monthly
   - Check `role_change_log` for suspicious changes

4. **Backup Before Changes**
   - Export user data before making bulk role changes
   - Test in development environment first

---

## File Reference

### SQL Files:
- `user-roles-setup.sql` - Main role system setup
- `setup-super-admin.sql` - Assign first super admin
- `verify-policies.sql` - Verify RLS policies

### JavaScript Files:
- `role-permissions.js` - Client-side role checking library
- `supabase-config.js` - Supabase connection and auth functions

### HTML Files:
All pages have been updated with role integration.

---

## Support

For issues or questions:
1. Check browser console for JavaScript errors
2. Check Supabase logs for database errors
3. Verify role setup with SQL queries above
4. Review `role_change_log` for audit trail

---

**Last Updated**: Task 6 - Role System Implementation Complete
