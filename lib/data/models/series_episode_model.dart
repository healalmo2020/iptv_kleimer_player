import '../../domain/entities/series_episode.dart';

class SeriesEpisodeModel extends SeriesEpisode {
  const SeriesEpisodeModel({
    required super.id,
    required super.title,
    required super.season,
    required super.episodeNumber,
    super.containerExtension,
  });

  factory SeriesEpisodeModel.fromJson(Map<String, dynamic> json, {required int season}) {
    return SeriesEpisodeModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Episodio',
      season: season,
      episodeNumber: int.tryParse(json['episode_num']?.toString() ?? '0') ?? 0,
      containerExtension: json['container_extension']?.toString(),
    );
  }
}
