import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/debug/dev_environment.dart';

void main() {
  test('ordinary debug runs are local-only', () {
    expect(kOfflineDevMode, isTrue);
  });
}
