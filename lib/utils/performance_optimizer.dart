import 'package:flutter/material.dart';

/// Performance optimization utilities
class PerformanceOptimizer {
  /// Debounce input to reduce widget rebuilds
  static Future<T> debounce<T>(
    Future<T> Function() callback, {
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    await Future.delayed(duration);
    return await callback();
  }

  /// Throttle widget rebuilds
  static void throttle(
    VoidCallback callback, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    Future.delayed(duration, callback);
  }
}

/// List optimization - use this for long lists
extension ListPerformance on List {
  /// Chunk list into smaller batches for rendering
  List<List<T>> chunked<T>(int size) {
    List<List<T>> chunks = [];
    for (var i = 0; i < (this as List<T>).length; i += size) {
      chunks.add((this as List<T>).sublist(
        i,
        i + size > (this as List<T>).length ? (this as List<T>).length : i + size,
      ));
    }
    return chunks;
  }
}

/// Responsive design utilities
class ResponsiveSize {
  /// Get responsive value based on screen size
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200) {
      return desktop ?? tablet ?? mobile;
    } else if (width >= 768) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 768 && width < 1200;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  /// Get grid column count based on screen size
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 4;
    if (width >= 768) return 3;
    return 2;
  }

  /// Get responsive padding
  static EdgeInsets responsivePadding(BuildContext context) {
    final isPad = isTablet(context);
    final isDesk = isDesktop(context);

    if (isDesk) return const EdgeInsets.all(32);
    if (isPad) return const EdgeInsets.all(24);
    return const EdgeInsets.all(16);
  }
}

/// Image caching and lazy loading
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const OptimizedImage(
    this.imageUrl, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}

/// Lazy loading list view
class LazyLoadingListView<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) onLoadMore;
  final Widget Function(BuildContext, int, T) itemBuilder;
  final int pageSize;
  final Widget? separator;

  const LazyLoadingListView({
    super.key,
    required this.onLoadMore,
    required this.itemBuilder,
    this.pageSize = 20,
    this.separator,
  });

  @override
  State<LazyLoadingListView<T>> createState() => _LazyLoadingListViewState<T>();
}

class _LazyLoadingListViewState<T> extends State<LazyLoadingListView<T>> {
  late ScrollController _scrollController;
  List<T> items = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final newItems = await widget.onLoadMore(_page);
      if (mounted) {
        setState(() {
          items.addAll(newItems);
          _page++;
          if (newItems.length < widget.pageSize) {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: _scrollController,
      itemCount: items.length + (_isLoading ? 1 : 0) + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => widget.separator ?? const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }
        return widget.itemBuilder(context, index, items[index]);
      },
    );
  }
}
