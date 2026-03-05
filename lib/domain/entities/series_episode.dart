class SeriesEpisode {
  const SeriesEpisode({
    required this.id,
    required this.title,
    required this.season,
    required this.episodeNumber,
    this.containerExtension,
  });

  final String id;
  final String title;
  final int season;
  final int episodeNumber;
  final String? containerExtension;
}
