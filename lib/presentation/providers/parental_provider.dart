import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/local_storage_service.dart';
import 'app_providers.dart';

class ParentalState {
  const ParentalState({
    required this.enabled,
  });

  final bool enabled;

  ParentalState copyWith({
    bool? enabled,
  }) {
    return ParentalState(enabled: enabled ?? this.enabled);
  }
}

class ParentalController extends StateNotifier<ParentalState> {
  ParentalController(this._storage)
      : super(
          ParentalState(enabled: _storage.isParentalEnabled()),
        );

  final LocalStorageService _storage;

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _storage.setParentalEnabled(value);
  }

  Future<void> setPin(String pin) async {
    await _storage.setParentalPin(pin);
  }

  bool validatePin(String pin) => _storage.validateParentalPin(pin);
}

final parentalProvider = StateNotifierProvider<ParentalController, ParentalState>((ref) {
  return ParentalController(ref.watch(localStorageProvider));
});
