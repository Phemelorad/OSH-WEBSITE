# OSH Role System - Quick Reference Card

## 🚀 2-Minute Setup

```sql
-- 1. Run in Supabase SQL Editor:
-- Copy entire user-roles-setup.sql and RUN

-- 2. Make yourself super admin:
UPDATE user_profiles 
SET role = 'super_admin'
WHERE email = 'YOUR_EMAIL@example.com';

-- 3. Verify:
SELECT email, role FROM user_profiles WHERE role = 'super_admin';
```

**Done!** Login and you'll see your role badge.

---

## 📋 Role Quick Reference

| Role | Badge Color | Can Submit? | Can Edit? | Admin Panel? |
|------|-------------|-------------|-----------|--------------|
| Viewer | Gray | ❌ | ❌ | ❌ |
| Officer | Blue | ✅ | Own only | ❌ |
| Admin | Yellow | ✅ | All | ✅ |
| Super Admin | Green | ✅ | All | ✅ Full |

---

## 🔑 Common SQL Commands

### View All Users with Roles
```sql
SELECT email, first_name, surname, role, is_active
FROM user_profiles
ORDER BY role, email;
```

### Change User Role
```sql
UPDATE user_profiles 
SET role = 'officer'  -- viewer | officer | admin | super_admin
WHERE email = 'user@example.com';
```

### View Role Changes (Audit Log)
```sql
SELECT 
    up.email,
    rcl.old_role || ' → ' || rcl.new_role as change,
    rcl.changed_at
FROM role_change_log rcl
JOIN user_profiles up ON up.user_id = rcl.user_id
ORDER BY rcl.changed_at DESC
LIMIT 10;
```

### Promote Multiple Users
```sql
-- Make all users from specific location officers
UPDATE user_profiles 
SET role = 'officer'
WHERE location = 'Head Office' AND role = 'viewer';
```

### Reset User to Viewer
```sql
UPDATE user_profiles 
SET role = 'viewer'
WHERE email = 'user@example.com';
```

---

## 🎯 Permission Cheat Sheet

### Can View Claims?
- ✅ Everyone (all roles)

### Can Submit Claims?
- ❌ Viewer
- ✅ Officer, Admin, Super Admin

### Can Edit Claims?
- ❌ Viewer
- ✅ Officer (own only)
- ✅ Admin (all)
- ✅ Super Admin (all)

### Can Access Admin Panel?
- ❌ Viewer, Officer
- ✅ Admin, Super Admin

### Can Manage Users?
- ❌ Viewer, Officer
- ✅ Admin (except super admins)
- ✅ Super Admin (everyone)

---

## 💻 JavaScript Functions

```javascript
// Check if user can do something
hasPermission('submit_claims')      // true/false
canAccessAdmin()                    // admin+ only
canSubmitClaims()                   // officer+ only
canEditClaims(claimOwnerId)        // checks ownership for officers

// Get current role info
getCurrentUserRole()                // 'viewer' | 'officer' | 'admin' | 'super_admin'
getCurrentUserId()                  // current user's ID

// UI updates
updateUIForRole()                   // update nav, badges
enforcePermissions()                // disable unauthorized buttons
checkPageAccess()                   // redirect if not allowed
```

---

## 🎨 UI Indicators

### Role Badges (Next to Username)
- **Viewer** - Gray badge, "Viewer"
- **Officer** - Blue badge, "Officer"
- **Admin** - Yellow badge, "Admin"
- **Super Admin** - Green badge, "Super Admin"

### Navigation Visibility
- **All Roles**: Home, View Entries
- **Officer+**: Submit Claim form
- **Admin+**: Admin panel

### Button States
- **Enabled**: Normal button
- **Disabled**: Grayed out, no hover effect
- **Tooltip**: Hover shows "You do not have permission..."

---

## 🔍 Troubleshooting One-Liners

### Can't access admin panel?
```sql
SELECT email, role FROM user_profiles WHERE email = 'YOUR_EMAIL';
-- If not admin/super_admin, run: UPDATE user_profiles SET role = 'admin' WHERE email = 'YOUR_EMAIL';
```

### Edit buttons not working?
```javascript
// Check browser console for: "User role: viewer"
// Fix: Admin needs to change your role to officer or higher
```

### Role not showing?
```javascript
// Hard refresh: Ctrl + Shift + R (Windows) or Cmd + Shift + R (Mac)
```

### "Permission denied" database errors?
```sql
-- Re-run setup:
-- Paste entire user-roles-setup.sql again
```

### Super admin can't be edited in admin panel?
```
This is by design. Super admins can only be managed via SQL or by themselves.
```

---

## 📊 Statistics Queries

### Role Distribution
```sql
SELECT 
    role,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as percentage
FROM user_profiles
GROUP BY role
ORDER BY 
    CASE role
        WHEN 'super_admin' THEN 1
        WHEN 'admin' THEN 2
        WHEN 'officer' THEN 3
        WHEN 'viewer' THEN 4
    END;
```

### Recent Role Changes
```sql
SELECT 
    COUNT(*) as total_changes,
    COUNT(DISTINCT user_id) as users_affected,
    MAX(changed_at) as last_change
FROM role_change_log
WHERE changed_at > NOW() - INTERVAL '7 days';
```

### Active Users by Role
```sql
SELECT 
    role,
    COUNT(*) as active_count
FROM user_profiles
WHERE is_active = true
GROUP BY role;
```

---

## 🛡️ Security Quick Checks

### Verify RLS Policies Active
```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies 
WHERE tablename IN ('user_profiles', 'injury_claims')
ORDER BY tablename, cmd;
-- Should see multiple policies for each table
```

### Check Role Column
```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND column_name = 'role';
-- Should return: role | text | 'viewer'::text
```

### Verify Audit Log
```sql
SELECT COUNT(*) FROM role_change_log;
-- Should return > 0 if any roles have been changed
```

---

## 📱 Page Access Rules

| Page | Viewer | Officer | Admin | Super Admin |
|------|:------:|:-------:|:-----:|:-----------:|
| index.html (Login) | Public | Public | Public | Public |
| signup.html | Public | Public | Public | Public |
| Untitled-1.html (Home) | ✅ | ✅ | ✅ | ✅ |
| entries.html (View) | ✅ | ✅ | ✅ | ✅ |
| form.html (Submit) | ❌→Home | ✅ | ✅ | ✅ |
| admin.html | ❌→Home | ❌→Home | ✅ | ✅ |

*❌→Home = Redirected to home with alert*

---

## 🔄 Role Change Workflow

### Via Admin Panel (Recommended):
1. Login as admin/super admin
2. Go to **⚙ Admin**
3. Find user
4. Click **"Change Role"**
5. Select new role
6. Confirm ✅

### Via SQL (Super Admins Only):
```sql
UPDATE user_profiles 
SET role = 'NEW_ROLE'
WHERE email = 'user@example.com';
```

### Bulk Changes:
```sql
-- Promote all viewers in a location
UPDATE user_profiles 
SET role = 'officer'
WHERE location = 'Main Office' AND role = 'viewer';
```

---

## 💡 Tips & Tricks

### Make Everyone at a Location an Officer
```sql
UPDATE user_profiles 
SET role = 'officer'
WHERE location ILIKE '%head office%';
```

### Find Users Without Activity
```sql
SELECT email, role, created_at
FROM user_profiles
WHERE created_at < NOW() - INTERVAL '30 days'
AND role = 'viewer'
ORDER BY created_at ASC;
```

### Demote Inactive Admins
```sql
UPDATE user_profiles 
SET role = 'viewer'
WHERE role = 'admin' 
AND is_active = false;
```

### Export Role Distribution (CSV)
```sql
COPY (
    SELECT role, COUNT(*) as count
    FROM user_profiles
    GROUP BY role
) TO '/tmp/role_distribution.csv' WITH CSV HEADER;
```

---

## 📚 Documentation Files

| File | Purpose | When to Use |
|------|---------|-------------|
| **SETUP_CHECKLIST.md** | Quick setup steps | First-time setup |
| **ROLES_SETUP_GUIDE.md** | Detailed guide | Reference & troubleshooting |
| **IMPLEMENTATION_SUMMARY.md** | Complete overview | Understanding the system |
| **QUICK_REFERENCE.md** | This file | Daily use & common tasks |

---

## 🆘 Emergency Commands

### Restore Super Admin Access
```sql
-- If you lose super admin access, run this:
UPDATE user_profiles 
SET role = 'super_admin'
WHERE email = 'YOUR_EMAIL@example.com';
```

### Reset All Roles to Viewer
```sql
-- CAREFUL! This resets everyone except super admins
UPDATE user_profiles 
SET role = 'viewer'
WHERE role != 'super_admin';
```

### Disable Role System (Emergency)
```sql
-- Temporarily disable RLS (makes everyone admin-like)
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE injury_claims DISABLE ROW LEVEL SECURITY;

-- Re-enable when fixed:
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE injury_claims ENABLE ROW LEVEL SECURITY;
```

---

## 📞 Support Checklist

Before asking for help, check:
- [ ] Browser console for errors (F12)
- [ ] Supabase logs for database errors
- [ ] Role is correct: `SELECT email, role FROM user_profiles WHERE email = 'YOUR_EMAIL';`
- [ ] RLS policies active: `SELECT * FROM pg_policies WHERE tablename = 'user_profiles';`
- [ ] Hard refresh done (Ctrl+Shift+R)
- [ ] Tried different browser/incognito mode

---

**Last Updated**: Implementation Complete
**Version**: 1.0
**Status**: ✅ Production Ready
