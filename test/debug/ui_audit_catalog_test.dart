import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/debug/ui_audit_catalog.dart';
import 'package:inner_stars/debug/ui_audit_specimens.dart';

void main() {
  test('audit entries have stable unique ids and complete review metadata', () {
    final ids = uiAuditCatalog.map((item) => item.id).toList();
    expect(ids.toSet(), hasLength(ids.length));

    for (final item in uiAuditCatalog) {
      expect(item.id, matches(RegExp(r'^[a-z0-9-]+$')));
      expect(item.origins, isNotEmpty, reason: item.id);
      expect(item.states, isNotEmpty, reason: item.id);
      expect(item.differences, isNotEmpty, reason: item.id);
      expect(item.rationale, isNotEmpty, reason: item.id);
      expect(item.risks, isNotEmpty, reason: item.id);
      expect(item.options, isNotEmpty, reason: item.id);
      expect(item.recommendation, isNotEmpty, reason: item.id);
    }
  });

  test('every audit category is represented', () {
    final represented = uiAuditCatalog.map((item) => item.category).toSet();
    expect(represented, containsAll(UiAuditCategory.values));
  });

  test('catalog contains current variants and candidate standards', () {
    expect(
      uiAuditCatalog.where((item) => item.kind == UiAuditKind.existing),
      isNotEmpty,
    );
    expect(
      uiAuditCatalog.where((item) => item.kind == UiAuditKind.candidate),
      isNotEmpty,
    );
  });

  test('every audit entry has one visual comparison', () {
    expect(
      supportedUiAuditSpecimenIds,
      uiAuditCatalog.map((item) => item.id).toSet(),
    );
  });
}
