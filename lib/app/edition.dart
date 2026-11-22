import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Which edition this build is. The Offline edition
/// (`flutter build apk --flavor offline`) is the same clock with no
/// INTERNET permission: no account, no sync, no downloads. It installs as
/// its own app (`dev.sagron.zerotrustclock.offline`).
const bool offlineEdition =
    String.fromEnvironment('FLUTTER_APP_FLAVOR') == 'offline';

/// [offlineEdition], for the screens. Tests override it.
final offlineEditionProvider = Provider<bool>((ref) => offlineEdition);

/// The account of the Offline edition: there is none, and nothing here
/// reaches a server. The screens that would call the rest are not shown.
class NoAccountBackend implements AccountBackend {
  const NoAccountBackend();

  @override
  String? get currentUserId => null;

  @override
  String? get currentEmail => null;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('The Offline edition has no account');
}
