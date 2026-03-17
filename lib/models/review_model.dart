class ReviewModel {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final ReviewUser? user;

  const ReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.user,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      user: json['user'] != null
          ? ReviewUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReviewUser {
  final String id;
  final String? name;
  final String? avatarUrl;

  const ReviewUser({required this.id, this.name, this.avatarUrl});

  factory ReviewUser.fromJson(Map<String, dynamic> json) {
    return ReviewUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
