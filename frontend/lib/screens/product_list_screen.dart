import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();
  String _sortBy = 'name';
  String _sortOrder = 'asc';
  bool? _isActive = true;
  bool _lowStockOnly = false;
  int _currentPage = 1;

  bool _isLoading = true;
  String? _error;
  List<Product> _products = [];
  int _total = 0;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getProducts(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        isActive: _isActive,
        lowStock: _lowStockOnly,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        page: _currentPage,
      );
      setState(() {
        _products = result.data;
        _total = result.total;
        _totalPages = result.totalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or SKU...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _loadProducts(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _loadProducts,
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Status filter
                    DropdownButton<bool?>(
                      value: _isActive,
                      hint: const Text('Status'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: true, child: Text('Active')),
                        DropdownMenuItem(value: false, child: Text('Inactive')),
                      ],
                      onChanged: (value) {
                        setState(() => _isActive = value);
                        _loadProducts();
                      },
                    ),
                    const SizedBox(width: 16),
                    // Low stock filter
                    FilterChip(
                      label: const Text('Low Stock'),
                      selected: _lowStockOnly,
                      onSelected: (value) {
                        setState(() => _lowStockOnly = value);
                        _loadProducts();
                      },
                    ),
                    const Spacer(),
                    // Sort dropdown
                    DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(value: 'name', child: Text('Name')),
                        DropdownMenuItem(value: 'sku', child: Text('SKU')),
                        DropdownMenuItem(value: 'quantity', child: Text('Quantity')),
                      ],
                      onChanged: (value) {
                        setState(() => _sortBy = value!);
                        _loadProducts();
                      },
                    ),
                    IconButton(
                      icon: Icon(_sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward),
                      onPressed: () {
                        setState(() => _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc');
                        _loadProducts();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Product list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadProducts,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text('No products found', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _products.length,
                                  itemBuilder: (context, index) {
                                    final product = _products[index];
                                    return _ProductCard(
                                      product: product,
                                      isAdmin: isAdmin,
                                      onTap: () => _openProductDetail(product),
                                      onTake: () => _showTakeDialog(product),
                                    );
                                  },
                                ),
                              ),
                              // Pagination
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(13),
                                      blurRadius: 4,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: _currentPage > 1
                                          ? () {
                                              setState(() => _currentPage--);
                                              _loadProducts();
                                            }
                                          : null,
                                    ),
                                    Text('Page $_currentPage of $_totalPages'),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: _currentPage < _totalPages
                                          ? () {
                                              setState(() => _currentPage++);
                                              _loadProducts();
                                            }
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Text('$_total total products', style: TextStyle(color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateProductDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            )
          : null,
    );
  }

  void _openProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(productId: product.id),
      ),
    ).then((_) => _loadProducts());
  }

  Future<void> _showTakeDialog(Product product) async {
    final quantityController = TextEditingController();
    final detailsController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Take from ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: ${product.quantity} ${product.unit}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Quantity to take',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text);
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid quantity')),
                );
                return;
              }
              if (qty > product.quantity) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Cannot take more than available')),
                );
                return;
              }
              Navigator.pop(dialogContext, {
                'quantity': qty,
                'details': detailsController.text.isNotEmpty ? detailsController.text : null,
              });
            },
            child: const Text('Take'),
          ),
        ],
      ),
    );

    if (result != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(
            'Take ${result['quantity']} ${product.unit} from ${product.name}?\n\n'
            'Current: ${product.quantity} → New: ${product.quantity - (result['quantity'] as int)}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await ref.read(apiServiceProvider).takeFromStock(
            product.id,
            result['quantity'] as int,
            result['details'] as String?,
          );
          _loadProducts();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Took ${result['quantity']} ${product.unit} from ${product.name}')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _showCreateProductDialog() async {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final quantityController = TextEditingController(text: '0');
    final unitController = TextEditingController(text: 'pcs');
    final minQuantityController = TextEditingController(text: '0');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: skuController,
                decoration: InputDecoration(
                  labelText: 'SKU *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Initial Qty',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minQuantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Min Quantity (Low Stock Threshold)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty || skuController.text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Name and SKU are required')),
                );
                return;
              }
              Navigator.pop(dialogContext, {
                'name': nameController.text,
                'sku': skuController.text,
                'quantity': int.tryParse(quantityController.text) ?? 0,
                'unit': unitController.text,
                'minQuantity': int.tryParse(minQuantityController.text) ?? 0,
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm'),
          content: Text('Create product "${result['name']}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await ref.read(apiServiceProvider).createProduct(result);
          _loadProducts();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product created successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }
    }
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onTake;

  const _ProductCard({
    required this.product,
    required this.isAdmin,
    required this.onTap,
    required this.onTake,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 8,
                height: 60,
                decoration: BoxDecoration(
                  color: product.isActive
                      ? (product.isLowStock ? Colors.orange : Colors.green)
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!product.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Inactive', style: TextStyle(fontSize: 12)),
                          ),
                        if (product.isLowStock && product.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, size: 14, color: Colors.orange.shade800),
                                const SizedBox(width: 4),
                                Text('Low Stock', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${product.sku}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (product.category != null)
                      Text(
                        'Category: ${product.category}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Quantity
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.quantity}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: product.isLowStock ? Colors.orange.shade800 : Colors.blue.shade800,
                    ),
                  ),
                  Text(product.unit, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(width: 16),
              // Take button
              if (product.isActive && product.quantity > 0)
                ElevatedButton.icon(
                  onPressed: onTake,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Take'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
