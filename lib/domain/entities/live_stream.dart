class LiveStream {
  const LiveStream({
    required this.id,
    required this.name,
    required this.categoryId,
    this.iconUrl,
    this.epgChannelId,
  });

  final String id;
  final String name;
  final String categoryId;
  final String? iconUrl;
  final String? epgChannelId;
}
