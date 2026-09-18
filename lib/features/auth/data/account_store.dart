import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart';
import '../../../models/stored_account.dart';

/// Persists the list of signed-in accounts locally for quick multi-account
/// switching. Stores metadata only — never credentials.
class AccountStore {
  /// Reads all remembered accounts.
  Future<List<StoredAccount>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PrefsKeys.storedAccounts);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => StoredAccount.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupted cache: reset to empty rather than crashing.
      return const [];
    }
  }

  /// Adds or updates an account (dedup by uid) and marks it active.
  Future<void> upsertAccount(StoredAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    final next = <StoredAccount>[
      account,
      ...accounts.where((a) => a.uid != account.uid),
    ];
    await prefs.setString(
      PrefsKeys.storedAccounts,
      jsonEncode(next.map((a) => a.toMap()).toList()),
    );
    await prefs.setString(PrefsKeys.activeAccountUid, account.uid);
  }

  Future<void> removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    final next = accounts.where((a) => a.uid != uid).toList();
    await prefs.setString(
      PrefsKeys.storedAccounts,
      jsonEncode(next.map((a) => a.toMap()).toList()),
    );
    if (prefs.getString(PrefsKeys.activeAccountUid) == uid) {
      await prefs.remove(PrefsKeys.activeAccountUid);
    }
  }

  Future<void> setActive(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.activeAccountUid, uid);
  }

  Future<String?> getActiveUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PrefsKeys.activeAccountUid);
  }
}
