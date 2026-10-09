import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/features/permissions/domain/services/permission_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = PermissionEngine(
    permissions: {'sales.view', 'sales.create', 'stock.view'},
    membreActif: true,
    perimetreIds: {'boutique-a'},
  );

  test('vérifie une ou plusieurs permissions', () {
    expect(engine.has('sales.create'), isTrue);
    expect(engine.has('sales.delete'), isFalse);
    expect(engine.hasAll(['sales.view', 'stock.view']), isTrue);
    expect(engine.hasAll(['sales.view', 'users.manage']), isFalse);
    expect(engine.hasAny(['users.manage', 'stock.view']), isTrue);
  });

  test('refus explicite avec la permission manquante', () {
    final d = engine.checkAll(['sales.view', 'users.manage']);
    expect(d, isA<AccessDenied>());
    expect((d as AccessDenied).ruleCode, RuleCodes.permissionDenied);
    expect(d.params['permission'], 'users.manage');
  });

  test('périmètre : seulement les périmètres affectés', () {
    expect(engine.canAccessPerimetre('boutique-a'), isTrue);
    expect(engine.canAccessPerimetre('boutique-b'), isFalse,
        reason: 'un superviseur de la boutique A n\'accède pas à la boutique B');
    expect((engine.checkPerimetre('boutique-b') as AccessDenied).ruleCode, RuleCodes.perimetreDenied);
  });

  test('perimetres.access_all : accès à tous les périmètres', () {
    const admin = PermissionEngine(
      permissions: {'perimetres.access_all'},
      membreActif: true,
      perimetreIds: {},
    );
    expect(admin.canAccessPerimetre('nimporte'), isTrue);
  });

  test('membre suspendu : aucune permission', () {
    const suspendu = PermissionEngine(
      permissions: {'sales.view', 'perimetres.access_all'},
      membreActif: false,
      perimetreIds: {'boutique-a'},
    );
    expect(suspendu.has('sales.view'), isFalse);
    expect(suspendu.canAccessPerimetre('boutique-a'), isFalse);
  });
}
