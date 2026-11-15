import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stretch goal 1: logs every provider update (compare with AppBlocObserver).
final class LoggingProviderObserver extends ProviderObserver {
  const LoggingProviderObserver();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    debugPrint(
      '[ProviderObserver] ${context.provider.name ?? context.provider.runtimeType}'
      ' updated: $newValue',
    );
  }
}
