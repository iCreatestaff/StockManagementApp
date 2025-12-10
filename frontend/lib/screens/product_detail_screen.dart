import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  Product? _product;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final product = await api.getProduct(widget.productId);
      setState(() {
        _product = product;
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
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadProduct, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final product = _product!;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    _showEditDialog();
                    break;
                  case 'adjust':
                    _showAdjustDialog();
                    break;
                  case 'toggle':
                    _toggleActive();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
                const PopupMenuItem(value: 'adjust', child: Text('Adjust Stock')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(product.isActive ? 'Deactivate' : 'Activate'),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: product.isLowStock ? Colors.orange.shade100 : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        size: 48,
                        color: product.isLowStock ? Colors.orange.shade800 : Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('SKU: ${product.sku}', style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: product.isActive ? Colors.green.shade100 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  product.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: product.isActive ? Colors.green.shade800 : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (product.isLowStock && product.isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning, size: 16, color: Colors.orange.shade800),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Low Stock',
                                        style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${product.quantity}',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: product.isLowStock ? Colors.orange.shade800 : Colors.blue.shade800,
                          ),
                        ),
                        Text(product.unit, style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Details
            Text('Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(label: 'Minimum Quantity', value: '${product.minQuantity} ${product.unit}'),
                    if (product.category != null)
                      _DetailRow(label: 'Category', value: product.category!),
                    if (product.location != null)
                      _DetailRow(label: 'Location', value: product.location!),
                    if (product.notes != null && product.notes!.isNotEmpty)
                      _DetailRow(label: 'Notes', value: product.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Take action (for all users if active)
            if (product.isActive && product.quantity > 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTakeDialog(),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Take from Stock'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTakeDialog() async {
    final quantityController = TextEditingController();
    final detailsController = TextEditingController();
    final product = _product!;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(quantityController.text);
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid quantity')),
                );
                return;
              }
              if (qty > product.quantity) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot take more than available')),
                );
                return;
              }

              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm'),
                  content: Text(
                    'Take $qty ${product.unit} from ${product.name}?\n\n'
                    'Current: ${product.quantity} → New: ${product.quantity - qty}',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
                  ],
                ),
              );

              if (confirm == true) {
                Navigator.pop(context);
                try {
                  await ref.read(apiServiceProvider).takeFromStock(
                    product.id,
                    qty,
                    detailsController.text.isNotEmpty ? detailsController.text : null,
                  );
                  _loadProduct();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Took $qty ${product.unit} from ${product.name}')),
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
            },
            child: const Text('Take'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final product = _product!;
    final nameController = TextEditingController(text: product.name);
    final skuController = TextEditingController(text: product.sku);
    final unitController = TextEditingController(text: product.unit);
    final minQtyController = TextEditingController(text: product.minQuantity.toString());
    final categoryController = TextEditingController(text: product.category ?? '');
    final locationController = TextEditingController(text: product.location ?? '');
    final notesController = TextEditingController(text: product.notes ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: skuController, decoration: const InputDecoration(labelText: 'SKU')),
              TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit')),
              TextField(controller: minQtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Quantity')),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
              TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
              TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm'),
                  content: const Text('Save changes to this product?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await ref.read(apiServiceProvider).updateProduct(product.id, {
                    'name': nameController.text,
                    'sku': skuController.text,
                    'unit': unitController.text,
                    'minQuantity': int.tryParse(minQtyController.text) ?? 0,
                    'category': categoryController.text.isNotEmpty ? categoryController.text : null,
                    'location': locationController.text.isNotEmpty ? locationController.text : null,
                    'notes': notesController.text.isNotEmpty ? notesController.text : null,
                  });
                  Navigator.pop(context);
                  _loadProduct();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Product updated')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdjustDialog() async {
    final product = _product!;
    final quantityController = TextEditingController();
    final detailsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current: ${product.quantity} ${product.unit}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: 'Adjustment (+ to add, - to remove)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              decoration: InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final adj = int.tryParse(quantityController.text);
              if (adj == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number')),
                );
                return;
              }
              final newQty = product.quantity + adj;
              if (newQty < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Adjustment would result in negative stock')),
                );
                return;
              }

              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Adjustment'),
                  content: Text(
                    'Adjust stock by ${adj >= 0 ? '+' : ''}$adj\n\n'
                    'Current: ${product.quantity} → New: $newQty',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
                  ],
                ),
              );

              if (confirm == true) {
                Navigator.pop(context);
                try {
                  await ref.read(apiServiceProvider).adjustStock(
                    product.id,
                    adj,
                    detailsController.text.isNotEmpty ? detailsController.text : null,
                  );
                  _loadProduct();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stock adjusted')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive() async {
    final product = _product!;
    final action = product.isActive ? 'deactivate' : 'activate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${product.isActive ? 'Deactivate' : 'Activate'} Product'),
        content: Text('Are you sure you want to $action "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(apiServiceProvider).setProductActive(product.id, !product.isActive);
        _loadProduct();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Product ${product.isActive ? 'deactivated' : 'activated'}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
