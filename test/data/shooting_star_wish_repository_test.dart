import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/shooting_star_wish_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores one trimmed wish and clears blank input', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = await ShootingStarWishRepository.create();

    expect(repository.wish, isNull);
    await repository.save('  See the northern lights  ');
    expect(repository.wish, 'See the northern lights');

    await repository.save('   ');
    expect(repository.wish, isNull);
  });
}
