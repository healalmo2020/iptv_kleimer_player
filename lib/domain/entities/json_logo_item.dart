class JsonLogoItem {
  final String canal;
  final String url;
  final String paisCodigo;
  final String pais;

  const JsonLogoItem({
    required this.canal,
    required this.url,
    required this.paisCodigo,
    required this.pais,
  });

  factory JsonLogoItem.fromJson(Map<String, dynamic> json) {
    return JsonLogoItem(
      canal: json['canal'] as String,
      url: json['url'] as String,
      paisCodigo: json['pais_codigo'] as String,
      pais: json['pais'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canal': canal,
      'url': url,
      'pais_codigo': paisCodigo,
      'pais': pais,
    };
  }
}
