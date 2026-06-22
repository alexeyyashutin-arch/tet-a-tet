class UrlHelper {
  /// Формирует полный URL для изображения
  /// Если URL уже абсолютный (начинается с http:// или https://), возвращает его как есть
  /// Если URL относительный (начинается с /), добавляет baseUrl
  static String getImageUrl(String? url, String baseUrl) {
    if (url == null || url.isEmpty) return '';
    
    // Если URL уже абсолютный — возвращаем как есть
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    // Если URL относительный — добавляем baseUrl
    return '$baseUrl$url';
  }
}