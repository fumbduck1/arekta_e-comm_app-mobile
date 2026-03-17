class CategoryModel {
  final String id;
  final String name;
  final String? slug;
  final String? imageUrl;
  final String? parentId;

  const CategoryModel({
    required this.id,
    required this.name,
    this.slug,
    this.imageUrl,
    this.parentId,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      imageUrl: json['image_url'] as String?,
      parentId: json['parent_id'] as String?,
    );
  }

  bool get isRoot => parentId == null;
}
