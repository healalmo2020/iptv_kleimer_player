class XtreamStreamUrlBuilder {
  const XtreamStreamUrlBuilder._();

  static String _normalizeBase(String baseUrl) {
    return baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  }

  static List<String> liveUrls({
    required String baseUrl,
    required String username,
    required String password,
    required String streamId,
  }) {
    final normalizedBase = _normalizeBase(baseUrl);

    return [
      '$normalizedBase/live/$username/$password/$streamId.m3u8',
      '$normalizedBase/live/$username/$password/$streamId.ts',
    ];
  }

  static List<String> vodUrls({
    required String baseUrl,
    required String username,
    required String password,
    required String streamId,
    String? extension,
  }) {
    final normalizedBase = _normalizeBase(baseUrl);
    final ext = (extension == null || extension.isEmpty) ? 'mp4' : extension;

    return [
      '$normalizedBase/movie/$username/$password/$streamId.$ext',
      '$normalizedBase/movie/$username/$password/$streamId.mp4',
      '$normalizedBase/movie/$username/$password/$streamId.mkv',
    ];
  }

  static List<String> seriesEpisodeUrls({
    required String baseUrl,
    required String username,
    required String password,
    required String episodeId,
    String? extension,
  }) {
    final normalizedBase = _normalizeBase(baseUrl);
    final ext = (extension == null || extension.isEmpty) ? 'mp4' : extension;

    return [
      '$normalizedBase/series/$username/$password/$episodeId.$ext',
      '$normalizedBase/series/$username/$password/$episodeId.mp4',
      '$normalizedBase/series/$username/$password/$episodeId.mkv',
    ];
  }
}
