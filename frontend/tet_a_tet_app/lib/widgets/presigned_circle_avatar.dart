import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

/// CircleAvatar с асинхронной загрузкой presigned URL из S3
class PresignedCircleAvatar extends StatefulWidget {
  final String? photoKey;
  final double radius;
  final Color? backgroundColor;
  final Widget? child;

  const PresignedCircleAvatar({
    super.key,
    this.photoKey,
    this.radius = 24,
    this.backgroundColor,
    this.child,
  });

  @override
  State<PresignedCircleAvatar> createState() => _PresignedCircleAvatarState();
}

class _PresignedCircleAvatarState extends State<PresignedCircleAvatar> {
  final _api = ApiService();
  String? _presignedUrl;
  bool _isLoading = true;

  static final Map<String, String> _urlCache = {};
  static final Map<String, DateTime> _cacheExpiry = {};

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void didUpdateWidget(PresignedCircleAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoKey != widget.photoKey) {
      _loadUrl();
    }
  }

  Future<void> _loadUrl() async {
    if (widget.photoKey == null) {
      setState(() {
        _isLoading = false;
        _presignedUrl = null;
      });
      return;
    }

    try {
      final cacheKey = widget.photoKey!;
      final cachedUrl = _urlCache[cacheKey];
      final cacheTime = _cacheExpiry[cacheKey];

      if (cachedUrl != null && cacheTime != null) {
        final isExpired = DateTime.now().difference(cacheTime).inSeconds >= 850;
        if (!isExpired) {
          setState(() {
            _presignedUrl = cachedUrl;
            _isLoading = false;
          });
          return;
        }
      }

      final url = await _api.getPhotoUrlByKey(widget.photoKey!);
      if (mounted) {
        if (url != null) {
          _urlCache[cacheKey] = url;
          _cacheExpiry[cacheKey] = DateTime.now();
        }
        setState(() {
          _presignedUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _presignedUrl = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.grey[300],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_presignedUrl == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.grey[300],
        child: widget.child ?? Icon(Icons.person, color: Colors.grey[600]),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      backgroundImage: CachedNetworkImageProvider(_presignedUrl!),
      child: widget.child,
    );
  }
}