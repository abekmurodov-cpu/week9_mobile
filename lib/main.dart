import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bloc/cart_page_bloc.dart';
import 'cubit/cart_page_cubit.dart';
import 'riverpod/cart_page_riverpod.dart';
import 'setstate/cart_page_setstate.dart';

void main() {
  runApp(const ProviderScope(child: CartApp()));
}

class CartApp extends StatelessWidget {
  const CartApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'One Cart, Four Ways',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const HomePage(),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final _pages = <(String, WidgetBuilder)>[
    ('setState', (_) => const SetStateCartPage()),
    ('Riverpod', (_) => const RiverpodCartPage()),
    ('Cubit', (_) => const CubitCartPage()),
    ('Bloc', (_) => const BlocCartPage()),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('One Cart, Four Ways')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, builder) in _pages)
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 220,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: builder)),
                  child: Text('Cart · $label'),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
