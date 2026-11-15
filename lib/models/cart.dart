import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({required this.id, required this.name, required this.price});
  final String id;
  final String name;
  final double price;

  @override
  List<Object?> get props => [id, name, price];
}

const catalog = [
  Product(id: 'p1', name: 'Keyboard', price: 49),
  Product(id: 'p2', name: 'Mouse', price: 25),
  Product(id: 'p3', name: 'Monitor', price: 199),
];

class CartLine extends Equatable {
  const CartLine({required this.product, required this.qty});
  final Product product;
  final int qty;

  @override
  List<Object?> get props => [product, qty];

  double get subtotal => product.price * qty;

  CartLine copyWith({int? qty}) =>
      CartLine(product: product, qty: qty ?? this.qty);
}

/// Pure, style-independent cart logic. Every state holder calls these.
extension CartLines on List<CartLine> {
  List<CartLine> withProduct(Product p) {
    final i = indexWhere((l) => l.product.id == p.id);
    if (i == -1) return [...this, CartLine(product: p, qty: 1)];
    return [
      for (final l in this)
        l.product.id == p.id ? l.copyWith(qty: l.qty + 1) : l,
    ];
  }

  List<CartLine> without(String productId) => [
    for (final l in this)
      if (l.product.id != productId) l,
  ];

  /// Adds [delta] to the line's quantity; a line that drops to 0 is removed.
  List<CartLine> changeQty(String productId, int delta) => [
    for (final l in this)
      if (l.product.id != productId)
        l
      else if (l.qty + delta > 0)
        l.copyWith(qty: l.qty + delta),
  ];

  double get subtotal => fold(0, (s, l) => s + l.subtotal);
  int get itemCount => fold(0, (s, l) => s + l.qty);
}

/// Coupon code → discount rate.
const coupons = {'SAVE10': 0.10};

enum CheckoutStatus { idle, submitting, success, failure }

/// Value equality (via Equatable) matters: Riverpod, Cubit and Bloc all skip
/// notifying when `newState == oldState`.
class CartState extends Equatable {
  const CartState({
    this.lines = const [],
    this.coupon,
    this.couponError,
    this.status = CheckoutStatus.idle,
    this.orderId,
    this.checkoutError,
    this.history = const [],
  });

  final List<CartLine> lines;
  final String? coupon;
  final String? couponError;
  final CheckoutStatus status;
  final String? orderId;
  final String? checkoutError;

  /// Undo snapshots, for state holders that keep history *in* the state
  /// (Cubit, Bloc) so that `canUndo` is observable. setState and Riverpod
  /// keep their history next to the state instead and leave this empty.
  final List<CartState> history;

  @override
  List<Object?> get props => [
    lines,
    coupon,
    couponError,
    status,
    orderId,
    checkoutError,
    history,
  ];

  // Derived values: always computed, never stored, so they cannot go stale.
  int get itemCount => lines.itemCount;
  double get subtotal => lines.subtotal;
  double get discount => subtotal * (coupons[coupon] ?? 0);
  double get total => subtotal - discount;
  bool get isSubmitting => status == CheckoutStatus.submitting;
  bool get canUndo => history.isNotEmpty;

  /// Nullable fields take a function so that `null` can be set explicitly.
  CartState copyWith({
    List<CartLine>? lines,
    String? Function()? coupon,
    String? Function()? couponError,
    CheckoutStatus? status,
    String? Function()? orderId,
    String? Function()? checkoutError,
    List<CartState>? history,
  }) => CartState(
    lines: lines ?? this.lines,
    coupon: coupon != null ? coupon() : this.coupon,
    couponError: couponError != null ? couponError() : this.couponError,
    status: status ?? this.status,
    orderId: orderId != null ? orderId() : this.orderId,
    checkoutError: checkoutError != null ? checkoutError() : this.checkoutError,
    history: history ?? this.history,
  );

  CartState applyCoupon(String code) {
    final normalized = code.trim().toUpperCase();
    return coupons.containsKey(normalized)
        ? copyWith(coupon: () => normalized, couponError: () => null)
        : copyWith(
            coupon: () => null,
            couponError: () => 'Unknown coupon "${code.trim()}"',
          );
  }

  CartState startCheckout() => copyWith(
    status: CheckoutStatus.submitting,
    orderId: () => null,
    checkoutError: () => null,
  );

  /// A successful order empties the cart (and its undo history).
  CartState checkoutSucceeded(String orderId) =>
      CartState(status: CheckoutStatus.success, orderId: orderId);

  CartState checkoutFailed(String message) =>
      copyWith(status: CheckoutStatus.failure, checkoutError: () => message);

  /// What undo restores: the cart contents, without any checkout status.
  CartState get snapshot =>
      CartState(lines: lines, coupon: coupon, couponError: couponError);

  /// Moves to [next], recording this state for undo — unless nothing changed,
  /// in which case [next] is returned as is and the holder's `==` check drops it.
  CartState recordTo(CartState next) =>
      next == this ? next : next.copyWith(history: [...history, snapshot]);

  CartState undo() => history.isEmpty
      ? this
      : history.last.copyWith(history: history.sublist(0, history.length - 1));
}
