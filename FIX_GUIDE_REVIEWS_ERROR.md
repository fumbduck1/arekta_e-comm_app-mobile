# Product Detail Loading Error - Fix Guide

## Current Issue
When clicking a product card, you see:
```
Error loading product
OperationException(linkException: null, graphqlErrors:
[GraphQLError(message: field 'user' not found in type: 'reviews'...)]
```

## What We Fixed
✅ **Route Navigation** - Product cards now correctly navigate to the product details page  
✅ **Route Handler** - Enhanced error handling and logging in main.dart  
⏳ **Database Permissions** - Hasura metadata updated locally (needs Hasura reload)

## What's Happening Now
1. The route is working correctly (you can see "Product Detail Route: productId=..." in logs)
2. The Flutter app successfully loads the product detail screen
3. The GraphQL query tries to fetch reviews with reviewer names (user field)
4. Hasura rejects the request because the public role doesn't have permission to access the user relationship

## Root Cause
The GraphQL query tries to select:
```graphql
reviews {
  id
  rating
  comment
  created_at
  user {        # ← Hasura blocks this for public role
    id
    name
    avatar_url
  }
}
```

But Hasura permissions don't allow the public role to access the `user` relationship on reviews.

## Solution: Update Hasura Connected in Your Backend

### Step 1: Open Hasura Console
Access your Hasura GraphQL engine dashboard (https://your-hasura-url/console)

### Step 2: Update Reviews Table Permissions
1. Go to **Data** → **reviews table**
2. Click **Permissions** tab
3. For the **public** role select permission:
   - Edit the permission JSON
   - Add: `"relationships": ["user", "product"]`
   - Save

Example (the permission should look like this):
```json
{
  "columns": ["id", "user_id", "product_id", "rating", "comment", "created_at"],
  "relationships": ["user", "product"],
  "allow_aggregations": true,
  "filter": {}
}
```

4. Repeat for **client** role if it exists

### Step 3: Add Public Access to Users Table
1. Go to **Data** → **users table** 
2. Click **Permissions** tab
3. Add a **new permission for public role**:
   - **Columns**: id, name, avatar_url (NOT email/phone for privacy)
   - **Filter**: {} (empty, allow all)
   - **Comment**: "Public can see user profiles for reviews"

### Step 4: Reload Hasura Metadata
- Hasura Console: Click gear icon → **Reload metadata**
- Or use CLI: `hasura metadata reload`

### Step 5: Restart Flutter App
```bash
flutter clean
flutter pub get
flutter run
```

## Alternative: Quick Workaround (While Pending Hasura Changes)
If you can't update Hasura immediately, you can create a public query without the user relationship:

In `lib/core/graphql/queries/product_queries.dart`, add:
```dart
static const String getProductByIdPublic = r'''
  query GetProductByIdPublic($id: uuid!) {
    products(where: { id: { _eq: $id } }, limit: 1) {
      id
      name
      description
      price
      compare_at_price: sale_price
      stock_qty: stock
      images
      is_active
      created_at
      category {
        id
        name
        slug
      }
      vendor {
        id
        shop_name
        shop_description: description
        logo_url
      }
      reviews_aggregate {
        aggregate {
          avg { rating }
          count
        }
      }
    }
  }
''';
```

Then use this query for unauthenticated requests. But this is a workaround - proper Hasura permissions are the correct solution.

## Expected Result
After applying the fix:
1. ✅ Click product card → navigates to details (working)
2. ✅ GraphQL query executes without errors
3. ✅ Product details display with ratings and reviews
4. ✅ Reviewer names and avatars show in review section
5. ✅ No error messages

## Files Reference
- Migration details: `database/HASURA_METADATA_MIGRATION.md`
- Updated metadata: `database/h1.json` (for reference)

## Questions?
- Check raw logs: Look for "[GraphQLService]" messages
- Get more details: ProductDetailScreen builds with try-catch error handling
- Verify GraphQL: Use Hasura's GraphQL Explorer to test the query directly
