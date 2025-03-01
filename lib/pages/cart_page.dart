import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../supabase_client.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<CartItem> _cartItems = [];
  bool _loading = true;
  bool _placingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    try {
      final response = await supabase
          .from('cart_items')
          .select('*, product:products(*)')
          .eq('user_id', supabase.auth.currentUser!.id);

      setState(() {
        _cartItems = (response as List).map((item) {
          final product = Product.fromJson(item['product']);
          return CartItem.fromJson(item, product);
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cart: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _updateQuantity(CartItem item, int quantity) async {
    try {
      await supabase
          .from('cart_items')
          .update({'quantity': quantity})
          .eq('id', item.id);

      setState(() {
        item.quantity = quantity;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating quantity: $e')),
        );
      }
    }
  }

  Future<void> _removeItem(CartItem item) async {
    try {
      await supabase
          .from('cart_items')
          .delete()
          .eq('id', item.id);

      setState(() {
        _cartItems.remove(item);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
    }
  }

  Future<void> _placeOrder() async {
    if (_cartItems.isEmpty) return;

    setState(() => _placingOrder = true);

    try {
      final totalAmount = _cartItems.fold<double>(
        0,
        (total, item) => total + item.total,
      );

      final orderResponse = await supabase
          .from('orders')
          .insert({
            'user_id': supabase.auth.currentUser!.id,
            'total_amount': totalAmount,
          })
          .select()
          .single();

      await supabase.from('order_items').insert(
        _cartItems.map((item) => {
          'order_id': orderResponse['id'],
          'product_id': item.product.id,
          'quantity': item.quantity,
          'unit_price': item.product.price,
        }).toList(),
      );

      await supabase
          .from('cart_items')
          .delete()
          .eq('user_id', supabase.auth.currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _cartItems.clear();
          _placingOrder = false;
        });
        // Navigate back to home after successful order
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing order: $e')),
        );
        setState(() => _placingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _cartItems.fold<double>(
      0,
      (total, item) => total + item.total,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your cart is empty',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Continue Shopping'),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _cartItems[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: CartItemTile(
                                item: item,
                                onUpdateQuantity: _updateQuantity,
                                onRemove: _removeItem,
                              ),
                            );
                          },
                          childCount: _cartItems.length,
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _cartItems.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _placingOrder ? null : _placeOrder,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _placingOrder
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(),
                              )
                            : const Text(
                                'Place Order',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class CartItemTile extends StatelessWidget {
  final CartItem item;
  final Function(CartItem, int) onUpdateQuantity;
  final Function(CartItem) onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete,
          color: Colors.red.shade700,
        ),
      ),
      onDismissed: (_) => onRemove(item),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.product.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${item.product.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            onPressed: item.quantity > 1
                                ? () => onUpdateQuantity(item, item.quantity - 1)
                                : null,
                          ),
                          Text(
                            '${item.quantity}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            onPressed: item.quantity < item.product.stockQuantity
                                ? () => onUpdateQuantity(item, item.quantity + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 