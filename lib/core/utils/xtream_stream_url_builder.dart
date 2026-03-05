class XtreamStreamUrlBuilder {
  const XtreamStreamUrlBuilder._();

  static List<String> liveUrls({
    required String baseUrl,
    required String username,
    required String password,
    required String streamId,
  }) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    return [
      '$normalizedBase/live/$username/$password/$streamId.m3u8',
      '$normalizedBase/live/$username/$password/$streamId.ts',
    ];
  }
}
