import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/models/customer_address.dart';
import '../widgets/login_modal.dart';

final customerAddressesRepositoryProvider =
    Provider<CustomerAddressesRepository>((ref) {
  return CustomerAddressesRepository(FirebaseFirestore.instance);
});

final customerAddressesProvider =
    StreamProvider.autoDispose<List<CustomerAddress>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    return const Stream.empty();
  }
  final repo = ref.watch(customerAddressesRepositoryProvider);
  return repo.watchAddresses(uid);
});

class CustomerAddressesRepository {
  final FirebaseFirestore _firestore;

  CustomerAddressesRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('addresses');
  }

  Stream<List<CustomerAddress>> watchAddresses(String uid) {
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CustomerAddress.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> addAddress({
    required String uid,
    String? label,
    required String home,
    required String road,
    required String block,
    required String city,
    String? flat,
    String? notes,
  }) async {
    await _collection(uid).add({
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'home': home.trim(),
      'road': road.trim(),
      'block': block.trim(),
      'city': city.trim(),
      if (flat != null && flat.trim().isNotEmpty) 'flat': flat.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> deleteAddress({
    required String uid,
    required String addressId,
  }) async {
    await _collection(uid).doc(addressId).delete();
  }
}

class SavedAddressesPage extends ConsumerWidget {
  const SavedAddressesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Addresses')),
      body: isLoggedIn ? _AddressesList() : _LoggedOutState(),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton(
              onPressed: () => _showAddAddressDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _AddressesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(customerAddressesProvider);

    return addresses.when(
      data: (list) {
        if (list.isEmpty) {
          return _EmptyState(onAdd: () => _showAddAddressDialog(context, ref));
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final address = list[index];
            final label = (address.label ?? '').trim();
            final title = label.isNotEmpty ? label : 'Address ${index + 1}';
            final summary = _formatSummary(address);

            return ListTile(
              title: Text(title),
              subtitle: Text(summary),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref, address.id),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Something went wrong. Please try again.'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No saved addresses yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onAdd,
            child: const Text('Add address'),
          ),
        ],
      ),
    );
  }
}

class _LoggedOutState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Please log in to use Saved Addresses',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => showLoginModal(context),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }
}

String _formatSummary(CustomerAddress address) {
  final parts = [
    'Home ${address.home}',
    'Road ${address.road}',
    'Block ${address.block}',
    address.city,
  ];
  return parts.join(', ');
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  String addressId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete address?'),
        content: const Text('This address will be removed from your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;
  final uid = ref.read(currentUidProvider);
  if (uid == null) return;
  await ref
      .read(customerAddressesRepositoryProvider)
      .deleteAddress(uid: uid, addressId: addressId);
}

Future<void> _showAddAddressDialog(BuildContext context, WidgetRef ref) async {
  final labelController = TextEditingController();
  final homeController = TextEditingController();
  final roadController = TextEditingController();
  final blockController = TextEditingController();
  final cityController = TextEditingController();
  final flatController = TextEditingController();
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add address'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  decoration:
                      const InputDecoration(labelText: 'Label (optional)'),
                ),
                TextFormField(
                  controller: homeController,
                  decoration: const InputDecoration(labelText: 'Home'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Home is required';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: roadController,
                  decoration: const InputDecoration(labelText: 'Road'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Road is required';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: blockController,
                  decoration: const InputDecoration(labelText: 'Block'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Block is required';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: flatController,
                  decoration: const InputDecoration(labelText: 'Flat (optional)'),
                ),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final uid = ref.read(currentUidProvider);
              if (uid == null) return;
              await ref.read(customerAddressesRepositoryProvider).addAddress(
                    uid: uid,
                    label: labelController.text,
                    home: homeController.text,
                    road: roadController.text,
                    block: blockController.text,
                    city: cityController.text,
                    flat: flatController.text,
                    notes: notesController.text,
                  );
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}