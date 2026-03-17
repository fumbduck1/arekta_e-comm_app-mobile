/// GraphQL query and mutation strings for User profile
class UserQueries {
  UserQueries._();

  /// Get current user profile
  static const String getMe = r'''
    query GetMe($userId: uuid!) {
      users_by_pk(id: $userId) {
        id
        email
        name
        phone
        role
        avatar_url
        created_at
        vendor {
          id
          shop_name
          shop_description: description
          logo_url
          is_approved
          created_at
        }
      }
    }
  ''';
}

class UserMutations {
  UserMutations._();

  /// Update user profile
  static const String updateProfile = r'''
    mutation UpdateProfile(
      $name: String,
      $phone: String,
      $avatarUrl: String
    ) {
      update_users(
        where: {},
        _set: {
          name: $name,
          phone: $phone,
          avatar_url: $avatarUrl
        }
      ) {
        returning {
          id
          name
          phone
          avatar_url
        }
      }
    }
  ''';

  /// Register as vendor (create vendor profile)
  static const String registerAsVendor = r'''
    mutation RegisterAsVendor(
      $userId: uuid!,
      $shopName: String!,
      $shopDescription: String,
      $logoUrl: String
    ) {
      insert_vendors_one(object: {
        user_id: $userId,
        shop_name: $shopName,
        description: $shopDescription,
        logo_url: $logoUrl
      }) {
        id
        user_id
        shop_name
        is_approved
      }
    }
  ''';

  /// Update user role (ensure correct role after signup)
  static const String updateUserRole = r'''
    mutation UpdateUserRole($role: String!) {
      update_users(
        where: {},
        _set: { role: $role }
      ) {
        returning {
          id
          role
        }
      }
    }
  ''';
}
