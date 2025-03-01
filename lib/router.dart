import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/product_detail_page.dart';
import 'pages/cart_page.dart';
import 'pages/orders_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/product/:id',
      builder: (context, state) => ProductDetailPage(
        productId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/cart',
      builder: (context, state) => const CartPage(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersPage(),
    ),
  ],
); 