import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/dependencies/app_dependencies.dart';

void main() {
  test('provides a configured HTTP client without network I/O', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final client = container.read(httpClientProvider);

    expect(client.options.connectTimeout, const Duration(seconds: 15));
    expect(client.options.receiveTimeout, const Duration(seconds: 15));
  });

  test('provides UUID version 7 identifiers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final identifier = container.read(uuidProvider).v7();

    expect(identifier[14], '7');
  });
}
