import '../../domain/entities/vod_stream.dart';

class VodStreamModel extends VodStream {
  const VodStreamModel({
    required super.id,
    required super.name,
    required super.categoryId,
    super.coverUrl,
    super.containerExtension,
  });

  factory VodStreamModel.fromJson(Map<String, dynamic> json) {
    return VodStreamModel(
      id: json['stream_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Película',
      categoryId: json['category_id']?.toString() ?? '0',
      coverUrl: json['stream_icon']?.toString(),
      containerExtension: json['container_extension']?.toString(),
    );
  }
}
