import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/login_session.dart';
import '../../../models/stored_account.dart';
import '../data/account_store.dart';
import '../data/auth_service.dart';
import '../data/session_service.dart';

/// Singletons (data layer).
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final accountStoreProvider = Provider<AccountStore>((ref) => AccountStore());
final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(),
);

/// Current Firebase user (null when signed out). The router redirects on this.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Locally remembered accounts for quick switching.
final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, List<StoredAccount>>(
      AccountsNotifier.new,
    );

class AccountsNotifier extends AsyncNotifier<List<StoredAccount>> {
  AccountStore get _store => ref.read(accountStoreProvider);

  @override
  Future<List<StoredAccount>> build() => _store.getAccounts();

  /// Remembers an account after a successful sign-in.
  Future<void> remember(StoredAccount account) async {
    await _store.upsertAccount(account);
    state = AsyncData(await _store.getAccounts());
  }

  Future<void> remove(String uid) async {
    await _store.removeAccount(uid);
    state = AsyncData(await _store.getAccounts());
  }
}

/// Sessions / login history for a given uid.
final sessionsProvider = StreamProvider.autoDispose
    .family<List<LoginSession>, String>((ref, uid) {
      return ref.watch(sessionServiceProvider).watchSessions(uid);
    });
