class SeriesItem {
  const SeriesItem({
    required this.id,
    required this.name,
    this.coverUrl,
    this.categoryId,
  });

  final String id;
  final String name;
  final String? coverUrl;
  final String? categoryId;
}
