import 'product.dart';

class CartItem {
  final String id;
  final Product product;
  int quantity;

  CartItem({
    required this.id,
    required this.product,
    required this.quantity,
  });

  double get total => product.price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json, Product product) {
    return CartItem(
      id: json['id'],
      product: product,
      quantity: json['quantity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'quantity': quantity,
    };
  }
} 