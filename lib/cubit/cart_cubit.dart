import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit(this._api)
    : super(const CartState()); // initial state via constructor

  final CheckoutApi _api;

  /// History lives in the state so BlocBuilder can observe `canUndo`. When
  /// nothing changed, `emit` receives an equal state and the Cubit drops it.
  void _record(CartState next) => emit(state.recordTo(next));

  void add(Product p) =>
      _record(state.copyWith(lines: state.lines.withProduct(p)));

  void remove(String id) =>
      _record(state.copyWith(lines: state.lines.without(id)));

  void changeQty(String id, int delta) =>
      _record(state.copyWith(lines: state.lines.changeQty(id, delta)));

  void applyCoupon(String code) => _record(state.applyCoupon(code));

  void undo() => emit(state.undo());

  Future<void> checkout() async {
    // Hand-written "droppable": a Cubit has no event transformers.
    if (state.isSubmitting || state.lines.isEmpty) return;
    emit(state.startCheckout());
    try {
      final orderId = await _api.submit(state.total);
      if (isClosed) return; // page popped mid-checkout: emit would throw
      emit(state.checkoutSucceeded(orderId));
    } on CheckoutException catch (e) {
      if (isClosed) return;
      emit(state.checkoutFailed(e.message));
    }
  }
}
