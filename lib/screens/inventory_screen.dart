import 'package:flutter/material.dart';
import 'package:handicraft_app/data/business_database.dart';
import 'package:handicraft_app/widgets/business_widgets.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({
    required this.repository,
    required this.inventory,
    required this.onChanged,
    super.key,
  });

  final BusinessRepository repository;
  final List<InventoryStock> inventory;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final totalItems = inventory.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
    final stockedProducts = inventory.where((item) => item.quantity > 0).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const ScreenHeading(
            title: 'Inventory',
            subtitle: 'Your detected handicraft products and stock levels.',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Items in stock',
                  value: '$totalItems',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF39745A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Products stocked',
                  value: '$stockedProducts / ${handicraftProducts.length}',
                  icon: Icons.category_outlined,
                  color: const Color(0xFFB77932),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'On the Detect tab, point the camera at your products '
                      'and tap “Add to inventory”. Confirmed detections increase '
                      'the stock count.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionTitle('Handicraft products'),
          const SizedBox(height: 8),
          for (final product in inventory)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                leading: CircleAvatar(
                  backgroundColor: product.quantity > 0
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.local_mall_outlined),
                ),
                title: Text(
                  product.productName.replaceAll('_', ' '),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${product.quantity} ${product.quantity == 1 ? 'item' : 'items'}'
                  '${product.updatedAt == null ? ' • No stock added yet' : ' • Updated ${formatBusinessDate(product.updatedAt!)}'}',
                ),
                trailing: IconButton(
                  tooltip: 'Adjust stock',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editQuantity(context, product),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editQuantity(
    BuildContext context,
    InventoryStock product,
  ) async {
    var enteredQuantity = '${product.quantity}';
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust stock'),
        content: TextFormField(
          initialValue: enteredQuantity,
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (value) => enteredQuantity = value,
          decoration: InputDecoration(
            labelText: product.productName.replaceAll('_', ' '),
            helperText: 'Enter the new total quantity in stock.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(enteredQuantity.trim());
              if (value == null || value < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a whole number of zero or more.'),
                  ),
                );
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Save quantity'),
          ),
        ],
      ),
    );
    if (quantity == null) return;
    try {
      await repository.setInventoryQuantity(product.productName, quantity);
      await onChanged();
    } catch (error, stackTrace) {
      debugPrint('Could not adjust inventory quantity: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update stock: $error')),
        );
      }
    }
  }
}
