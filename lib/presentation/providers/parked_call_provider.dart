import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/parked_call_store.dart';

final parkedCallStoreProvider = ChangeNotifierProvider<ParkedCallStore>((ref) {
  final store = ParkedCallStore.instance;
  ref.onDispose(() {});
  return store;
});
