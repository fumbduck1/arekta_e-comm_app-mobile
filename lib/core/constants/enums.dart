/// User roles in the application matching Hasura RBAC
enum UserRole {
  client,
  vendor,
  superAdmin;

  /// Hasura role string
  String get hasuraRole {
    switch (this) {
      case UserRole.client:
        return 'client';
      case UserRole.vendor:
        return 'vendor';
      case UserRole.superAdmin:
        return 'super_admin';
    }
  }

  /// Human-readable label
  String get label {
    switch (this) {
      case UserRole.client:
        return 'Customer';
      case UserRole.vendor:
        return 'Vendor';
      case UserRole.superAdmin:
        return 'Admin';
    }
  }

  /// Parse from database/API string
  static UserRole fromString(String value) {
    switch (value) {
      case 'vendor':
        return UserRole.vendor;
      case 'super_admin':
        return UserRole.superAdmin;
      case 'client':
      default:
        return UserRole.client;
    }
  }
}
