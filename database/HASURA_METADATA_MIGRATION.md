# Hasura Metadata Migration - Fix GraphQL Review User Relationships

## Issue
GraphQL query error: `field 'user' not found in type: 'reviews'`  
Error path: `$.selectionSet.products.selectionSet.reviews.selectionSet.user`

## Root Cause
The `reviews` table has a foreign key relationship to `users`, but:
1. The public role didn't have permission to access the `user` relationship through reviews
2. The `users` table didn't allow public role to read user data (name, avatar_url)

## Solution
Update Hasura metadata to:
1. Add `"relationships"` field to reviews table select permissions
2. Add public role select permission to users table

## Changes Required

### 1. Reviews Table - Add Relationship Permissions

**For public role** in reviews select_permissions:
```json
{
  "role": "public",
  "permission": {
    "columns": ["id", "user_id", "product_id", "rating", "comment", "created_at"],
    "relationships": ["user", "product"],
    "allow_aggregations": true,
    "filter": {}
  },
  "comment": "Public read-only access to all reviews with user and product relationships"
}
```

**For client role** in reviews select_permissions:
```json
{
  "role": "client",
  "permission": {
    "columns": ["id", "user_id", "product_id", "rating", "comment", "created_at"],
    "relationships": ["user", "product"],
    "allow_aggregations": true,
    "filter": {}
  },
  "comment": "Client read-only access to all reviews with user and product relationships"
}
```

### 2. Users Table - Add Public Role Read Access

**Add new permission** (insert after client role):
```json
{
  "role": "public",
  "permission": {
    "columns": ["id", "name", "avatar_url"],
    "filter": {}
  },
  "comment": "Public can see basic user info (name, avatar) for reviews"
}
```

## How to Update Hasura

### Option 1: Use Hasura Console
1. Go to Hasura Console for your project
2. Navigate to **Data** → **Tables** → **reviews**
3. Click **Permissions** tab
4. For each role (public, client):
   - Edit select permission
   - Add `"relationships": ["user", "product"]` to the JSON
5. Navigate to **Data** → **Tables** → **users**
6. Click **Permissions** tab
7. Add new permission for public role with columns: id, name, avatar_url

### Option 2: Update h1.json and Reload
1. Update h1.json with changes from h1.json in this repository
2. Reload metadata in Hasura Console (gear icon → Reload)
3. Or use Hasura CLI: `hasura metadata reload`

## Verification
After applying changes:
1. Restart the Flutter app
2. Click on a product card
3. Product details should load without GraphQL errors
4. Reviews should display with reviewer names and avatars

## Files Modified
- `database/h1.json` - Updated select_permissions and relationships
