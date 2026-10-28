import 'package:flutter/material.dart';
import 'package:handicraft_app/data/business_database.dart';
import 'package:handicraft_app/widgets/business_widgets.dart';

class BusinessHomeScreen extends StatelessWidget {
  const BusinessHomeScreen({
    required this.profile,
    required this.sales,
    required this.permits,
    required this.onRefresh,
    required this.onOpenTab,
    super.key,
  });

  final BusinessProfile profile;
  final List<Sale> sales;
  final List<PermitRecord> permits;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todaySales = sales.where(
      (sale) =>
          sale.soldAt.year == now.year &&
          sale.soldAt.month == now.month &&
          sale.soldAt.day == now.day,
    );
    final todayRevenue = todaySales.fold<double>(
      0,
      (total, sale) => total + sale.total,
    );
    final monthRevenue = sales
        .where(
          (sale) =>
              sale.soldAt.year == now.year && sale.soldAt.month == now.month,
        )
        .fold<double>(0, (total, sale) => total + sale.total);
    final duePermits = permits
        .where((permit) => permit.expiresOn.difference(now).inDays <= 30)
        .toList();
    final recentSales = sales.take(4).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            ScreenHeading(
              title: 'Good day',
              subtitle: profile.businessName.isEmpty
                  ? 'Your handicraft business at a glance'
                  : profile.businessName,
              action: IconButton.filledTonal(
                tooltip: 'Business records',
                onPressed: () => onOpenTab(2),
                icon: const Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF39745A), Color(0xFF24543F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's sales",
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'From recorded transactions',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatBusinessAmount(todayRevenue),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'This month',
                    value: formatBusinessAmount(monthRevenue),
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF39745A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Transactions',
                    value: '${sales.length}',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFFB77932),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SectionTitle(
              'Quick actions',
              action: TextButton(
                onPressed: () => onOpenTab(4),
                child: const Text('Detect a product'),
              ),
            ),
            const SizedBox(height: 10),
            _QuickAction(
              icon: Icons.add_shopping_cart_rounded,
              title: 'Record a sale',
              subtitle: 'Add a transaction to today’s sales',
              onTap: () => onOpenTab(1),
            ),
            const SizedBox(height: 10),
            _QuickAction(
              icon: Icons.event_available_outlined,
              title: 'Review business records',
              subtitle: duePermits.isEmpty
                  ? 'Business details and permits'
                  : '${duePermits.length} permit(s) due within 30 days',
              onTap: () => onOpenTab(2),
            ),
            const SizedBox(height: 24),
            SectionTitle(
              'Recent sales',
              action: TextButton(
                onPressed: () => onOpenTab(1),
                child: const Text('View all'),
              ),
            ),
            Card(
              child: recentSales.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No sales yet',
                      message: 'Your recorded transactions will appear here.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < recentSales.length; i++) ...[
                          _RecentSale(sale: recentSales[i]),
                          if (i < recentSales.length - 1)
                            const Divider(height: 1, indent: 68),
                        ],
                      ],
                    ),
            ),
            if (duePermits.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionTitle('Permit reminders'),
              const SizedBox(height: 8),
              for (final permit in duePermits.take(3))
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.warning_amber_rounded),
                    ),
                    title: Text(permit.name),
                    subtitle: Text(
                      'Renew by ${formatBusinessDate(permit.expiresOn)}',
                    ),
                    trailing: Text(_dueLabel(permit.expiresOn, now)),
                    onTap: () => onOpenTab(2),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _dueLabel(DateTime expiresOn, DateTime now) {
    final days = DateTime(
      expiresOn.year,
      expiresOn.month,
      expiresOn.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Today';
    return '$days days';
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _RecentSale extends StatelessWidget {
  const _RecentSale({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const CircleAvatar(child: Icon(Icons.sell_outlined)),
    title: Text(sale.productName),
    subtitle: Text(
      '${sale.quantity} × ${formatBusinessAmount(sale.unitPrice)}',
    ),
    trailing: Text(
      formatBusinessAmount(sale.total),
      style: Theme.of(context).textTheme.titleSmall,
    ),
  );
}
