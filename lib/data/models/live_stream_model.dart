import '../../domain/entities/live_stream.dart';

class LiveStreamModel extends LiveStream {
  const LiveStreamModel({
    required super.id,
    required super.name,
    required super.categoryId,
    super.iconUrl,
    super.epgChannelId,
  });

  factory LiveStreamModel.fromJson(Map<String, dynamic> json) {
    return LiveStreamModel(
      id: json['stream_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Canal',
      categoryId: json['category_id']?.toString() ?? '0',
      iconUrl: json['stream_icon']?.toString(),
      epgChannelId: json['epg_channel_id']?.toString(),
    );
  }
}
