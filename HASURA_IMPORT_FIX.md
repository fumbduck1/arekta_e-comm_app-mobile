# Fix Hasura Cloud Import Error

## Problem
```
Failed importing metadata
cannot continue due to inconsistent metadata
Inconsistent object: table "admin_"
```

## Root Cause
The metadata file `h1.json` references a function `admin_vendor_rank` that hasn't been created in your Hasura Cloud database yet. The function is defined in `admin_analytics_functions.sql` but needs to be created in your PostgreSQL database first.

## Solution - Two Approaches

### Approach 1: Import Metadata Now, Add Function Later (RECOMMENDED)

#### Step 1: Use Updated h1.json
The corrected `h1.json` now has the problematic function reference removed. 

**File Location:** `database/h1.json`

Features included:
- ✅ All table definitions and permissions
- ✅ Relationship permissions for reviews.user (for reviewer names/avatars)
- ✅ Public role access to users table
- ❌ admin_vendor_rank function (removed to fix import error)

#### Step 2: Import to Hasura Cloud
1. Go to Hasura Console
2. Click gear icon → **Metadata** → **Import metadata**
3. Upload the corrected `database/h1.json`
4. Should import successfully without errors

#### Step 3: Create the Admin Vendor Rank Function (Optional)
After Hasura is set up, you can optionally add the `admin_vendor_rank` function:

1. Run the SQL from `database/admin_analytics_functions.sql` on your Hasura database
2. Once created, add the function to Hasura metadata:
   - Go to **Data** → **SQL**
   - The function should auto-detect
   - Go to **Settings** → **Functions**
   - Enable the `admin_vendor_rank` function as a query root field

### Approach 2: Start Fresh with Clean Metadata

If you want to start completely fresh:

```sql
-- Run this SQL in your Hasura database first
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Run all SQL files in order:
-- 1. db_init.sql (schema and basic tables)
-- 2. admin_analytics_functions.sql (admin functions)
-- 3. procedures.sql (stored procedures)
-- 4. views.sql (helper views)
-- 5. product_moderation_and_analytics_migration.sql (migration steps)
```

Then import the metadata.

## What I Fixed

### Changes to h1.json:
1. **Removed**:
   - `admin_vendor_rank` function reference that was causing import conflict

2. **Kept intact**:
   - All relationship permissions for reviews.user access (fixes GraphQL "field user not found" error)
   - Public role access to users table for reviewer profiles
   - All table definitions and RLS policies

## Verification Checklist

After importing the metadata to Hasura Cloud:

- [ ] Metadata imports without errors
- [ ] All tables visible in Hasura Console
- [ ] Reviews relationship shows user info
- [ ] Public can view reviews with reviewer names
- [ ] Product detail GraphQL query returns successful

## Related Files
- `FIX_GUIDE_REVIEWS_ERROR.md` - GraphQL reviews.user permissions setup
- `QUICK_REFERENCE.md` - Testing guide
- `database/HASURA_METADATA_MIGRATION.md` - Detailed metadata changes

## Next Steps
1. Import the corrected `h1.json` to Hasura Cloud
2. Restart Flutter app
3. Test product details and reviews display

## Questions?
Check the metadata:
- `database/h1.json` - Updated metadata (functions removed)
- `database/hasura_metadata_full.json` - Original full metadata for reference
