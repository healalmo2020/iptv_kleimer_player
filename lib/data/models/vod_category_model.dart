import '../../domain/entities/vod_category.dart';

class VodCategoryModel extends VodCategory {
  const VodCategoryModel({
    required super.id,
    required super.name,
    required super.parentId,
  });

  factory VodCategoryModel.fromJson(Map<String, dynamic> json) {
    return VodCategoryModel(
      id: json['category_id']?.toString() ?? '',
      name: json['category_name']?.toString() ?? 'Sin nombre',
      parentId: json['parent_id']?.toString() ?? '0',
    );
  }
}
