import '../../domain/entities/epg_event.dart';

class EpgEventModel extends EpgEvent {
  const EpgEventModel({
    required super.title,
    required super.description,
    super.start,
    super.end,
  });

  factory EpgEventModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final asString = value.toString();
      if (asString.isEmpty) return null;
      final epoch = int.tryParse(asString);
      if (epoch != null) {
        return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
      }
      return DateTime.tryParse(asString);
    }

    return EpgEventModel(
      title: json['title']?.toString() ?? 'Programa',
      description: json['description']?.toString() ?? '',
      start: parseDate(json['start_timestamp'] ?? json['start']),
      end: parseDate(json['stop_timestamp'] ?? json['end']),
    );
  }
}
