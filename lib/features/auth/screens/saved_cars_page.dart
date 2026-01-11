import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer_car.dart';
import '../../../core/auth/auth_service.dart';
import '../widgets/login_modal.dart';

final customerCarsRepositoryProvider = Provider<CustomerCarsRepository>((ref) {
  return CustomerCarsRepository(FirebaseFirestore.instance);
});

final customerCarsProvider =
    StreamProvider.autoDispose<List<CustomerCar>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    return const Stream.empty();
  }
  final repo = ref.watch(customerCarsRepositoryProvider);
  return repo.watchCars(uid);
});

class CustomerCarsRepository {
  final FirebaseFirestore _firestore;

  CustomerCarsRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('cars');
  }

  Stream<List<CustomerCar>> watchCars(String uid) {
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CustomerCar.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> addCar({
    required String uid,
    required String plate,
    String? note,
  }) async {
    await _collection(uid).add({
      'plate': plate.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCar({required String uid, required String carId}) async {
    await _collection(uid).doc(carId).delete();
  }
}

class SavedCarsPage extends ConsumerWidget {
  const SavedCarsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Cars')),
      body: isLoggedIn ? _CarsList() : _LoggedOutState(),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton(
              onPressed: () => _showAddCarDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _CarsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(customerCarsProvider);

    return cars.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              'No saved cars yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final car = list[index];
            return ListTile(
              title: Text(car.plate),
              subtitle: car.note != null && car.note!.isNotEmpty
                  ? Text(car.note!)
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final uid = ref.read(currentUidProvider);
                  if (uid == null) return;
                  await ref
                      .read(customerCarsRepositoryProvider)
                      .deleteCar(uid: uid, carId: car.id);
                },
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

class _LoggedOutState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Log in to save your cars',
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

Future<void> _showAddCarDialog(BuildContext context, WidgetRef ref) async {
  final plateController = TextEditingController();
  final noteController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add car'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: plateController,
                decoration: const InputDecoration(labelText: 'Plate number'),
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Plate is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: noteController,
                decoration:
                    const InputDecoration(labelText: 'Color or description'),
              ),
            ],
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
              await ref.read(customerCarsRepositoryProvider).addCar(
                    uid: uid,
                    plate: plateController.text,
                    note: noteController.text,
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