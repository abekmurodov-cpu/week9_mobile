import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/cart.dart';

String describe(Object? state) => state is CartState
    ? '${state.itemCount} items, total ${state.total.toStringAsFixed(2)}, '
          'coupon ${state.coupon}, status ${state.status.name}, '
          'undo ${state.history.length}'
    : '$state';

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
      ': ${describe(previousValue)} -> ${describe(newValue)}',
    );
  }
}

/// Logs every state change of every Cubit/Bloc. Emits equal to the current
/// state never reach onChange, which is how a dropped emit becomes visible.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    debugPrint(
      '[onChange] ${bloc.runtimeType}: ${describe(change.currentState)}'
      ' -> ${describe(change.nextState)}',
    );
  }
}
