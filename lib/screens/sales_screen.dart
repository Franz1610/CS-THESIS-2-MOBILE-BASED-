import 'package:flutter/material.dart';
import 'package:handicraft_app/data/business_database.dart';
import 'package:handicraft_app/widgets/business_widgets.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({
    required this.repository,
    required this.sales,
    required this.inventory,
    required this.onChanged,
    required this.onOpenInventory,
    super.key,
  });

  final BusinessRepository repository;
  final List<Sale> sales;
  final List<InventoryStock> inventory;
  final Future<void> Function() onChanged;
  final VoidCallback onOpenInventory;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = sales.where(
      (sale) => sale.soldAt.year == now.year && sale.soldAt.month == now.month,
    );
    final revenue = thisMonth.fold<double>(
      0,
      (total, sale) => total + sale.total,
    );
    final hasStock = inventory.any((item) => item.quantity > 0);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: hasStock ? () => _addSale(context) : null,
        icon: const Icon(Icons.add),
        label: const Text('Record sale'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            const ScreenHeading(
              title: 'Sales tracking',
              subtitle: 'Record transactions and monitor your revenue.',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Revenue this month',
                    value: formatBusinessAmount(revenue),
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF39745A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Transactions',
                    value: '${thisMonth.length}',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFFB77932),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!hasStock)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('No products in stock'),
                  subtitle: const Text(
                    'Add stock from detection or adjust inventory before '
                    'recording a sale.',
                  ),
                  trailing: TextButton(
                    onPressed: onOpenInventory,
                    child: const Text('Inventory'),
                  ),
                ),
              ),
            SectionTitle('Transaction history'),
            const SizedBox(height: 8),
            if (sales.isEmpty)
              const Card(
                child: EmptyState(
                  icon: Icons.point_of_sale_outlined,
                  title: 'No transactions recorded',
                  message: 'Tap “Record sale” to add your first transaction.',
                ),
              )
            else
              for (final sale in sales)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.shopping_bag_outlined),
                    ),
                    title: Text(sale.productName),
                    subtitle: Text(
                      '${formatBusinessDate(sale.soldAt)}  •  '
                      '${sale.quantity} × ${formatBusinessAmount(sale.unitPrice)}'
                      '${sale.notes.isEmpty ? '' : '\n${sale.notes}'}',
                    ),
                    isThreeLine: sale.notes.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatBusinessAmount(sale.total),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Sale options',
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deleteSale(context, sale);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete sale'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSale(BuildContext context) async {
    final sale = await showDialog<Sale>(
      context: context,
      builder: (_) => _SaleDialog(inventory: inventory),
    );
    if (sale == null) return;
    try {
      await repository.addSale(sale);
      await onChanged();
    } catch (error, stackTrace) {
      debugPrint('Could not record sale: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        _showError(context, 'Could not record the sale: $error');
      }
    }
  }

  Future<void> _deleteSale(BuildContext context, Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this sale?'),
        content: Text(
          'Remove the sale for ${sale.productName}? Its quantity will be '
          'returned to inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || sale.id == null) return;
    try {
      await repository.deleteSale(sale.id!);
      await onChanged();
    } catch (error, stackTrace) {
      debugPrint('Could not delete sale: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        _showError(context, 'Could not delete the sale: $error');
      }
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SaleDialog extends StatefulWidget {
  const _SaleDialog({required this.inventory});

  final List<InventoryStock> inventory;

  @override
  State<_SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<_SaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _notes = TextEditingController();
  String? _selectedProduct;
  DateTime _soldAt = DateTime.now();

  List<InventoryStock> get _availableProducts =>
      widget.inventory.where((item) => item.quantity > 0).toList();

  int get _selectedStock =>
      _availableProducts
          .where((item) => item.productName == _selectedProduct)
          .firstOrNull
          ?.quantity ??
      0;

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableProducts = _availableProducts;
    return AlertDialog(
      title: const Text('Record a sale'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      availableProducts.any(
                        (item) => item.productName == _selectedProduct,
                      )
                      ? _selectedProduct
                      : null,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: [
                    for (final item in availableProducts)
                      DropdownMenuItem(
                        value: item.productName,
                        child: Text(
                          '${item.productName.replaceAll('_', ' ')} '
                          '(${item.quantity} in stock)',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedProduct = value);
                    _formKey.currentState?.validate();
                  },
                  validator: (value) =>
                      value == null ? 'Select an in-stock product' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          helperText: _selectedProduct == null
                              ? null
                              : '$_selectedStock available',
                        ),
                        validator: (value) {
                          final quantity = int.tryParse(value ?? '');
                          if (quantity == null || quantity < 1) {
                            return 'Enter a number above zero';
                          }
                          if (quantity > _selectedStock) {
                            return 'Only $_selectedStock in stock';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Unit price',
                        ),
                        validator: (value) {
                          final price = double.tryParse(value ?? '');
                          return price == null || !price.isFinite || price < 0
                              ? 'Enter a valid price'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sale date'),
                  subtitle: Text(formatBusinessDate(_soldAt)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _selectDate,
                ),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save sale')),
      ],
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _soldAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _soldAt = selected);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Sale(
        productName: _selectedProduct!,
        quantity: int.parse(_quantity.text),
        unitPrice: double.parse(_price.text),
        soldAt: _soldAt,
        notes: _notes.text.trim(),
      ),
    );
  }
}
