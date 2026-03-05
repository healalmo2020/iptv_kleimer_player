import '../../domain/entities/series_item.dart';

class SeriesItemModel extends SeriesItem {
  const SeriesItemModel({
    required super.id,
    required super.name,
    super.coverUrl,
    super.categoryId,
  });

  factory SeriesItemModel.fromJson(Map<String, dynamic> json) {
    return SeriesItemModel(
      id: json['series_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Serie',
      coverUrl: json['cover']?.toString(),
      categoryId: json['category_id']?.toString(),
    );
  }
}
