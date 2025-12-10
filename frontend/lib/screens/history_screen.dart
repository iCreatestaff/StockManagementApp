import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String? _operationType;
  int _currentPage = 1;
  List<Movement> _movements = [];
  int _total = 0;
  int _totalPages = 1;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getMovements(
        operationType: _operationType,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        page: _currentPage,
      );
      setState(() {
        _movements = result.data;
        _total = result.total;
        _totalPages = result.totalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Color _getOperationColor(String type) {
    switch (type) {
      case 'add':
        return Colors.green;
      case 'take':
        return Colors.red;
      case 'adjust':
        return Colors.orange;
      case 'edit':
        return Colors.blue;
      case 'undo':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getOperationIcon(String type) {
    switch (type) {
      case 'add':
        return Icons.add_circle;
      case 'take':
        return Icons.remove_circle;
      case 'adjust':
        return Icons.tune;
      case 'edit':
        return Icons.edit;
      case 'undo':
        return Icons.undo;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movement History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMovements),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search in details...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _loadMovements(),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String?>(
                  value: _operationType,
                  hint: const Text('All Types'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Types')),
                    DropdownMenuItem(value: 'add', child: Text('Add')),
                    DropdownMenuItem(value: 'take', child: Text('Take')),
                    DropdownMenuItem(value: 'adjust', child: Text('Adjust')),
                    DropdownMenuItem(value: 'edit', child: Text('Edit')),
                    DropdownMenuItem(value: 'undo', child: Text('Undo')),
                  ],
                  onChanged: (v) {
                    setState(() => _operationType = v);
                    _loadMovements();
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _loadMovements,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _movements.isEmpty
                        ? const Center(child: Text('No movements found'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _movements.length,
                            itemBuilder: (context, index) {
                              final m = _movements[index];
                              final color = _getOperationColor(m.operationType);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Opacity(
                                  opacity: m.isUndone ? 0.5 : 1.0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(_getOperationIcon(m.operationType), color: color),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    m.productName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: color.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      m.operationType.toUpperCase(),
                                                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  if (m.isUndone) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.shade200,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text('UNDONE', style: TextStyle(fontSize: 10)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${m.oldQuantity} → ${m.newQuantity} (${m.quantityChange >= 0 ? '+' : ''}${m.quantityChange})',
                                                style: TextStyle(color: Colors.grey.shade600),
                                              ),
                                              Text(
                                                'By ${m.username} • ${dateFormat.format(m.timestamp)}',
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                              ),
                                              if (m.details != null && m.details!.isNotEmpty)
                                                Text(
                                                  m.details!,
                                                  style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (!m.isUndone && ['add', 'take', 'adjust'].contains(m.operationType))
                                          ElevatedButton(
                                            onPressed: () => _undoMovement(m),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Undo'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          // Pagination
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 1
                      ? () {
                          setState(() => _currentPage--);
                          _loadMovements();
                        }
                      : null,
                ),
                Text('Page $_currentPage of $_totalPages'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages
                      ? () {
                          setState(() => _currentPage++);
                          _loadMovements();
                        }
                      : null,
                ),
                const SizedBox(width: 16),
                Text('$_total total', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _undoMovement(Movement m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo Operation'),
        content: Text(
          'Undo this ${m.operationType} operation?\n\n'
          'Product: ${m.productName}\n'
          'Change: ${m.quantityChange >= 0 ? '+' : ''}${m.quantityChange}\n'
          'This will reverse the stock change.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Undo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(apiServiceProvider).undoMovement(m.id);
        _loadMovements();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Operation undone successfully')),
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
