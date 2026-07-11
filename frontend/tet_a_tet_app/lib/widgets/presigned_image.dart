import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

/// Умный виджет изображения, который автоматически получает presigned URL из S3
/// 
/// photoKey: ключ файла в S3 (например "avatars/123.jpg" или поле url из Photo/Avatar)
/// 
/// Параметры:
/// - placeholder: виджет-заглушка пока грузится URL
/// - errorWidget: виджет ошибки если не удалось загрузить
/// - fit: как вписывать изображение (по умолчанию BoxFit.cover)
/// - width/height: размеры виджета
class PresignedImage extends StatefulWidget {
  final String photoKey;
  final Widget? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final BoxFit fit;
  final double? width;
  final double? height;

  const PresignedImage({
    super.key,
    required this.photoKey,
    this.placeholder,
    this.errorWidget,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<PresignedImage> createState() => _PresignedImageState();
}

class _PresignedImageState extends State<PresignedImage> {
  final _api = ApiService();
  
  String? _presignedUrl;
  bool _isLoading = true;
  bool _hasError = false;
  
  // Кэш URL'ей на уровне приложения (статичный)
  static final Map<String, String> _urlCache = {};
  static final Map<String, DateTime> _cacheExpiry = {};

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void didUpdateWidget(PresignedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если photoKey изменился — перезагружаем URL
    if (oldWidget.photoKey != widget.photoKey) {
      _loadUrl();
    }
  }

  Future<void> _loadUrl() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final cacheKey = widget.photoKey;
      
      // Проверяем кэш
      final cachedUrl = _urlCache[cacheKey];
      final cacheTime = _cacheExpiry[cacheKey];
      
      // Если URL в кэше и не протух (15 минут = 900 секунд)
      if (cachedUrl != null && cacheTime != null) {
        final isExpired = DateTime.now().difference(cacheTime).inSeconds >= 850; // обновляем за 50 сек до истечения
        if (!isExpired) {
          setState(() {
            _presignedUrl = cachedUrl;
            _isLoading = false;
          });
          return;
        }
      }

      // Запрашиваем новый presigned URL
      final url = await _api.getPhotoUrlByKey(widget.photoKey);
      
      if (mounted && url != null) {
        // Сохраняем в кэш
        _urlCache[cacheKey] = url;
        _cacheExpiry[cacheKey] = DateTime.now();
        
        setState(() {
          _presignedUrl = url;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Заглушка пока грузится
    if (_isLoading) {
      return widget.placeholder ?? Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Ошибка загрузки
    if (_hasError || _presignedUrl == null) {
      return widget.errorWidget?.call(context, '', null) ?? Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
      );
    }

    // Отображаем изображение с кэшированием
    return CachedNetworkImage(
      imageUrl: _presignedUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => widget.placeholder ?? Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => widget.errorWidget?.call(context, url, error) ?? Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
      ),
    );
  }
}