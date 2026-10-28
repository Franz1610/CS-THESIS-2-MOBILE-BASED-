import 'package:flutter/material.dart';
import 'package:handicraft_app/data/business_database.dart';
import 'package:handicraft_app/widgets/business_widgets.dart';

class BusinessRecordsScreen extends StatelessWidget {
  const BusinessRecordsScreen({
    required this.repository,
    required this.profile,
    required this.permits,
    required this.onChanged,
    super.key,
  });

  final BusinessRepository repository;
  final BusinessProfile profile;
  final List<PermitRecord> permits;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _addPermit(context),
      icon: const Icon(Icons.add),
      label: const Text('Add permit'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          ScreenHeading(
            title: 'Business records',
            subtitle: 'Keep business details and permit renewals together.',
            action: IconButton.filledTonal(
              tooltip: 'Edit business details',
              onPressed: () => _editProfile(context),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 20),
          _ProfileCard(profile: profile, onEdit: () => _editProfile(context)),
          const SizedBox(height: 24),
          SectionTitle(
            'Permits & renewals',
            action: Text('${permits.length} records'),
          ),
          const SizedBox(height: 8),
          if (permits.isEmpty)
            const Card(
              child: EmptyState(
                icon: Icons.event_note_outlined,
                title: 'No permits added',
                message: 'Add a permit to track its details and renewal date.',
              ),
            )
          else
            for (final permit in permits)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(permit.expiresOn)
                        .withValues(alpha: 0.13),
                    foregroundColor: _statusColor(permit.expiresOn),
                    child: const Icon(Icons.description_outlined),
                  ),
                  title: Text(permit.name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      [
                        if (permit.registrationNumber.isNotEmpty)
                          'No. ${permit.registrationNumber}',
                        'Issued ${formatBusinessDate(permit.issuedOn)}',
                        'Renew by ${formatBusinessDate(permit.expiresOn)}',
                        _statusLabel(permit.expiresOn),
                        if (permit.notes.isNotEmpty) permit.notes,
                      ].join('\n'),
                    ),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Permit options',
                    onSelected: (value) {
                      if (value == 'edit') _editPermit(context, permit);
                      if (value == 'delete') _deletePermit(context, permit);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit permit')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete permit'),
                      ),
                    ],
                  ),
                  onTap: () => _editPermit(context, permit),
                ),
              ),
          const SizedBox(height: 18),
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
                      'Renewal dates are shown in the app dashboard. '
                      'This version does not send background notifications.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _editProfile(BuildContext context) async {
    final updatedProfile = await showDialog<BusinessProfile>(
      context: context,
      builder: (_) => _ProfileDialog(profile: profile),
    );
    if (updatedProfile == null) return;
    try {
      await repository.saveProfile(updatedProfile);
      await onChanged();
    } catch (error, stackTrace) {
      debugPrint('Could not save business details: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        _showError(context, 'Could not save details: $error');
      }
    }
  }

  Future<void> _addPermit(BuildContext context) async {
    final permit = await showDialog<PermitRecord>(
      context: context,
      builder: (_) => const _PermitDialog(),
    );
    if (permit == null) return;
    try {
      await repository.addPermit(permit);
      await onChanged();
    } catch (error, stackTrace) {
      debugPrint('Could not add permit: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) _showError(context, 'Could not add permit: $error');
    }
  }

  Future<void> _editPermit(
    BuildContext context,
    PermitRecord currentPermit,
  ) async {
    final updatedPermit = await showDialog<PermitRecord>(
      context: context,
      builder: (_) => _PermitDialog(permit: currentPermit),
    );
    if (updatedPermit == null) return;
    try {
      await repository.updatePermit(updatedPermit);
      await onChanged();
    } catch (error, stackTrace) {
      debugPrint('Could not update permit: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        _showError(context, 'Could not update permit: $error');
      }
    }
  }

  Future<void> _deletePermit(BuildContext context, PermitRecord permit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this record?'),
        content: Text('Remove ${permit.name} from your permit records?'),
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
    if (confirmed != true || permit.id == null) return;
    try {
      await repository.deletePermit(permit.id!);
      await onChanged();
    } catch (error, stackTrace) {
      debugPrint('Could not delete permit: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        _showError(context, 'Could not delete permit: $error');
      }
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEdit});

  final BusinessProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final fields = <(String, String, IconData)>[
      ('Owner', profile.ownerName, Icons.person_outline),
      ('Registration', profile.registrationNumber, Icons.badge_outlined),
      ('Address', profile.address, Icons.location_on_outlined),
      ('Contact', profile.contactNumber, Icons.phone_outlined),
      ('Email', profile.email, Icons.email_outlined),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: const Icon(Icons.storefront_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    profile.businessName.isEmpty
                        ? 'Your business'
                        : profile.businessName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const Divider(height: 24),
            for (final field in fields)
              if (field.$2.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(field.$3, size: 19),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.$1,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            Text(field.$2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            if (fields.every((field) => field.$2.isEmpty))
              const Text(
                'Add your business information using the edit button.',
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.profile});

  final BusinessProfile profile;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _businessName = TextEditingController(
    text: widget.profile.businessName,
  );
  late final _ownerName = TextEditingController(text: widget.profile.ownerName);
  late final _registration = TextEditingController(
    text: widget.profile.registrationNumber,
  );
  late final _address = TextEditingController(text: widget.profile.address);
  late final _contact = TextEditingController(
    text: widget.profile.contactNumber,
  );
  late final _email = TextEditingController(text: widget.profile.email);

  @override
  void dispose() {
    _businessName.dispose();
    _ownerName.dispose();
    _registration.dispose();
    _address.dispose();
    _contact.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Business information'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_businessName, 'Business name'),
              _field(_ownerName, 'Owner name'),
              _field(_registration, 'Registration number'),
              _field(_address, 'Business address', maxLines: 2),
              _field(
                _contact,
                'Contact number',
                keyboardType: TextInputType.phone,
              ),
              _field(_email, 'Email', keyboardType: TextInputType.emailAddress),
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
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    ),
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      BusinessProfile(
        businessName: _businessName.text.trim(),
        ownerName: _ownerName.text.trim(),
        registrationNumber: _registration.text.trim(),
        address: _address.text.trim(),
        contactNumber: _contact.text.trim(),
        email: _email.text.trim(),
      ),
    );
  }
}

class _PermitDialog extends StatefulWidget {
  const _PermitDialog({this.permit});

  final PermitRecord? permit;

  @override
  State<_PermitDialog> createState() => _PermitDialogState();
}

class _PermitDialogState extends State<_PermitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.permit?.name ?? '');
  late final _number = TextEditingController(
    text: widget.permit?.registrationNumber ?? '',
  );
  late final _notes = TextEditingController(text: widget.permit?.notes ?? '');
  late DateTime _issuedOn = widget.permit?.issuedOn ?? DateTime.now();
  late DateTime _expiresOn =
      widget.permit?.expiresOn ?? DateTime.now().add(const Duration(days: 365));
  String? _dateError;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.permit == null ? 'Add permit or registration' : 'Edit permit',
    ),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Permit name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a permit name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _number,
                decoration: const InputDecoration(
                  labelText: 'Registration / permit number',
                ),
              ),
              const SizedBox(height: 6),
              _dateTile(
                label: 'Issue date',
                value: _issuedOn,
                onTap: () => _selectDate(issueDate: true),
              ),
              _dateTile(
                label: 'Renewal / expiry date',
                value: _expiresOn,
                onTap: () => _selectDate(issueDate: false),
              ),
              if (_dateError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _dateError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
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
      FilledButton(
        onPressed: _save,
        child: Text(widget.permit == null ? 'Save permit' : 'Save changes'),
      ),
    ],
  );

  Widget _dateTile({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(formatBusinessDate(value)),
    trailing: const Icon(Icons.calendar_month_outlined),
    onTap: onTap,
  );

  Future<void> _selectDate({required bool issueDate}) async {
    final current = issueDate ? _issuedOn : _expiresOn;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1980),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (issueDate) {
        _issuedOn = selected;
      } else {
        _expiresOn = selected;
      }
      _dateError = null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_expiresOn.isBefore(_issuedOn)) {
      setState(
        () => _dateError = 'Expiry date must be on or after issue date.',
      );
      return;
    }
    Navigator.pop(
      context,
      PermitRecord(
        id: widget.permit?.id,
        name: _name.text.trim(),
        registrationNumber: _number.text.trim(),
        issuedOn: _issuedOn,
        expiresOn: _expiresOn,
        notes: _notes.text.trim(),
      ),
    );
  }
}

int _daysToExpiry(DateTime date) {
  final today = DateTime.now();
  final expiry = DateTime(date.year, date.month, date.day);
  return expiry.difference(DateTime(today.year, today.month, today.day)).inDays;
}

Color _statusColor(DateTime expiry) {
  final days = _daysToExpiry(expiry);
  if (days < 0) return const Color(0xFFB42318);
  if (days <= 30) return const Color(0xFFB77932);
  return const Color(0xFF39745A);
}

String _statusLabel(DateTime expiry) {
  final days = _daysToExpiry(expiry);
  if (days < 0) return 'Overdue';
  if (days == 0) return 'Today';
  if (days <= 30) return '$days days';
  return 'Active';
}
