import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';
import 'cart_event.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc(this._api) : super(const CartState()) {
    on<CartProductAdded>(_onEdit);
    on<CartProductRemoved>(_onEdit);
    on<CartQtyChanged>(_onEdit);
    on<CartCouponApplied>(_onEdit);
    on<CartUndone>(_onEdit);
    // While a checkout runs, further CartCheckoutRequested events are ignored.
    on<CartCheckoutRequested>(_onCheckout, transformer: droppable());
  }

  final CheckoutApi _api;

  void _onEdit(CartEvent event, Emitter<CartState> emit) {
    final next = switch (event) {
      CartProductAdded(:final product) => state.copyWith(
        lines: state.lines.withProduct(product),
      ),
      CartProductRemoved(:final productId) => state.copyWith(
        lines: state.lines.without(productId),
      ),
      CartQtyChanged(:final productId, :final delta) => state.copyWith(
        lines: state.lines.changeQty(productId, delta),
      ),
      CartCouponApplied(:final code) => state.applyCoupon(code),
      CartUndone() => state.undo(),
      CartCheckoutRequested() => state, // handled by _onCheckout
    };
    emit(event.isUndoable ? state.recordTo(next) : next);
  }

  Future<void> _onCheckout(
    CartCheckoutRequested event,
    Emitter<CartState> emit,
  ) async {
    if (state.lines.isEmpty) return;
    emit(state.startCheckout());
    try {
      final orderId = await _api.submit(state.total);
      if (emit.isDone) return; // bloc closed while awaiting
      emit(state.checkoutSucceeded(orderId));
    } on CheckoutException catch (e) {
      if (emit.isDone) return;
      emit(state.checkoutFailed(e.message));
    }
  }
}
