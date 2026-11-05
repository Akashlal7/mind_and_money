import 'dart:math';

/// Secure unique identifier generator without requiring third-party libraries.
class IdGenerator {
  static final Random _random = Random.secure();

  /// Generates a unique 24-character hex ID incorporating microseconds timestamp
  /// and secure random bytes.
  static String generate() {
    final nowMicros = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randomPart1 = _random
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    final randomPart2 = _random
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    return '$nowMicros$randomPart1$randomPart2';
  }
}
