import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:storage/storage.dart';

/// Where the app is in the auth lifecycle. [unknown] is the boot state, before
/// storage has been checked — the router keeps the user on the splash until it
/// resolves.
enum SessionStatus { unknown, authenticated, unauthenticated }

/// Immutable snapshot of the current session.
class SessionState {
  const SessionState({required this.status, this.user});

  const SessionState.unknown() : status = SessionStatus.unknown, user = null;

  final SessionStatus status;
  final AppUser? user;

  bool get isAuthenticated => status == SessionStatus.authenticated;
}

/// Owns the session: restores it from local storage at startup and persists
/// sign-in/out. Persistence goes through the `storage` [KeyValueStore], so the
/// token/user store can change without touching this logic.
class SessionController extends Notifier<SessionState> {
  static const _userKey = 'session_user';
  static const _tokenKey = 'session_token';
  static const _refreshKey = 'session_refresh_token';

  KeyValueStore get _store => ref.read(cacheStoreProvider);

  @override
  SessionState build() {
    final api = ref.read(apiClientProvider);
    api.setOnUnauthorized(() {
      signOut();
    });
    api.setOnTokensRefreshed((accessToken, refreshToken) async {
      await _store.write(_tokenKey, accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _store.write(_refreshKey, refreshToken);
      }
    });
    return const SessionState.unknown();
  }

  /// Restores a persisted session, if any. Called once from the splash.
  Future<void> bootstrap() async {
    final raw = _store.read<String>(_userKey);
    final token = _store.read<String>(_tokenKey);
    final refreshToken = _store.read<String>(_refreshKey);

    if (token != null && token.isNotEmpty) {
      ref.read(apiClientProvider).setAuthToken(token);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      ref.read(apiClientProvider).setRefreshToken(refreshToken);
    }

    if (raw == null || token == null || token.isEmpty) {
      state = const SessionState(status: SessionStatus.unauthenticated);
      return;
    }
    try {
      final user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      state = SessionState(status: SessionStatus.authenticated, user: user);
    } catch (_) {
      await signOut();
    }
  }

  Future<void> signIn(AppUser user) async {
    await _store.write(_userKey, jsonEncode(user.toJson()));
    final token = ref.read(apiClientProvider).authToken;
    final refreshToken = ref.read(apiClientProvider).refreshToken;

    if (token != null && token.isNotEmpty) {
      await _store.write(_tokenKey, token);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _store.write(_refreshKey, refreshToken);
    }
    state = SessionState(status: SessionStatus.authenticated, user: user);
  }

  Future<void> updateUser(AppUser user) async {
    await _store.write(_userKey, jsonEncode(user.toJson()));
    state = SessionState(status: SessionStatus.authenticated, user: user);
  }

  Future<void> signOut() async {
    await _store.delete(_userKey);
    await _store.delete(_tokenKey);
    await _store.delete(_refreshKey);
    ref.read(apiClientProvider).setAuthToken(null);
    ref.read(apiClientProvider).setRefreshToken(null);
    state = const SessionState(status: SessionStatus.unauthenticated);
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
