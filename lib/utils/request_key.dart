import 'dart:math';

final _random = Random.secure();
const _alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

/// A random key for ONE user action, for example one press of "Receive stock".
/// It goes along with the request: if the connection drops and the app sends the SAME key again,
/// the server recognises it and does not apply the action twice.
/// (Checkout will use the same idea for its checkout_key.)
String newRequestKey([int length = 24]) =>
    List.generate(length, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();