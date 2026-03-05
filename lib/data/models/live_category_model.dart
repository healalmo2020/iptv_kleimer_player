import '../../domain/entities/live_category.dart';

class LiveCategoryModel extends LiveCategory {
  const LiveCategoryModel({
    required super.id,
    required super.name,
    required super.parentId,
  });

  factory LiveCategoryModel.fromJson(Map<String, dynamic> json) {
    return LiveCategoryModel(
      id: json['category_id']?.toString() ?? '',
      name: json['category_name']?.toString() ?? 'Sin nombre',
      parentId: json['parent_id']?.toString() ?? '0',
    );
  }
}
