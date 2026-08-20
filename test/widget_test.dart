import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/models/grocery_item.dart';
import 'package:freshflag/models/household.dart';
import 'package:freshflag/models/household_invite.dart';
import 'package:freshflag/models/inventory_category.dart';
import 'package:freshflag/models/notification_rule.dart';
import 'package:freshflag/models/product_lookup_result.dart';

void main() {
  group('GroceryItem persistence', () {
    test('round-trips all persisted fields', () {
      final updatedAt = DateTime.utc(2026, 8, 14, 14, 30);
      final item = GroceryItem(
        id: 'item-1',
        name: 'Milk',
        quantity: 2,
        category: 'Dairy',
        barcode: '0123456789012',
        addedDate: DateTime(2026, 8, 14),
        expiryDate: DateTime(2026, 8, 20),
        imageUrl: 'https://example.test/milk.jpg',
        notes: 'Use first',
        location: 'Fridge',
        isConsumed: true,
        householdId: 'house-1',
        createdByUid: 'owner-1',
        updatedByUid: 'member-2',
        updatedAt: updatedAt,
      );

      final map = item.toMap();
      final restored = GroceryItem.fromMap(map);

      expect(map['expiryDate'], '2026-08-20');
      expect(restored, item);
      expect(restored.notes, 'Use first');
      expect(restored.location, 'Fridge');
      expect(restored.isConsumed, isTrue);
      expect(restored.barcode, '0123456789012');
      expect(restored.householdId, 'house-1');
      expect(restored.createdByUid, 'owner-1');
      expect(restored.updatedByUid, 'member-2');
      expect(restored.updatedAt, updatedAt);
    });

    test(
      'supports legacy timestamp expiry records and missing audit fields',
      () {
        final restored = GroceryItem.fromMap({
          'id': 'legacy-1',
          'name': 'Bread',
          'quantity': 1,
          'category': 'Bakery',
          'barcode': null,
          'addedDate': '2026-08-14T12:34:56.000',
          'expiryDate': '2026-08-17T21:15:00.000',
          'imageUrl': null,
        });

        expect(restored.expiryDate, DateTime(2026, 8, 17));
        expect(restored.toMap()['expiryDate'], '2026-08-17');
        expect(restored.notes, isNull);
        expect(restored.location, isNull);
        expect(restored.isConsumed, isFalse);
        expect(restored.householdId, isNull);
        expect(restored.createdByUid, isNull);
      },
    );

    test('normalizes constructor expiry values to calendar dates', () {
      final item = GroceryItem(
        id: 'date-only-1',
        name: 'Yogurt',
        quantity: 1,
        category: 'Dairy',
        addedDate: DateTime(2026, 8, 14, 18, 30),
        expiryDate: DateTime(2026, 8, 20, 23, 59),
      );

      expect(item.expiryDate, DateTime(2026, 8, 20));
      expect(item.toMap()['expiryDate'], '2026-08-20');
    });

    test('normalizes expiry calculations to calendar days', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final item = GroceryItem(
        id: 'date-1',
        name: 'Yogurt',
        quantity: 1,
        category: 'Dairy',
        addedDate: today,
        expiryDate: today.add(const Duration(days: 3, hours: 18)),
      );

      expect(item.daysUntilExpiry, 3);
      expect(item.isExpiringSoon, isTrue);
    });
  });

  group('Household persistence', () {
    test('round-trips household ownership and timezone', () {
      final now = DateTime.utc(2026, 8, 14);
      final household = Household(
        id: 'house-1',
        name: 'Patel Household',
        ownerUid: 'owner-1',
        memberUids: const ['owner-1', 'member-2'],
        timezone: 'America/Toronto',
        createdAt: now,
        updatedAt: now,
      );

      final restored = Household.fromMap(household.id, household.toMap());
      expect(restored.id, 'house-1');
      expect(restored.name, 'Patel Household');
      expect(restored.ownerUid, 'owner-1');
      expect(restored.memberUids, ['owner-1', 'member-2']);
      expect(restored.timezone, 'America/Toronto');
    });

    test('round-trips member role', () {
      final member = HouseholdMember(
        uid: 'owner-1',
        role: HouseholdRole.owner,
        joinedAt: DateTime.utc(2026, 8, 14),
      );
      final restored = HouseholdMember.fromMap(member.uid, member.toMap());
      expect(restored.uid, member.uid);
      expect(restored.role, HouseholdRole.owner);
      expect(restored.joinedAt, member.joinedAt);
    });
  });

  group('HouseholdInvite', () {
    test('normalizes human-entered invite codes', () {
      expect(HouseholdInvite.normalizeCode(' abcd-efgh 2345 '), 'ABCDEFGH2345');
    });

    test('reports active only while status is active and unexpired', () {
      final active = HouseholdInvite(
        code: 'ABCDEFGH2345',
        householdId: 'house-1',
        createdByUid: 'owner-1',
        createdAt: DateTime.utc(2026, 8, 14),
        expiresAt: DateTime.utc(2100, 1, 1),
        status: HouseholdInviteStatus.active,
      );
      final revoked = HouseholdInvite(
        code: 'ABCDEFGH2345',
        householdId: 'house-1',
        createdByUid: 'owner-1',
        createdAt: DateTime.utc(2026, 8, 14),
        expiresAt: DateTime.utc(2100, 1, 1),
        status: HouseholdInviteStatus.revoked,
      );

      expect(active.isActive, isTrue);
      expect(revoked.isActive, isFalse);
    });
  });

  group('NotificationRule', () {
    test('round-trips configured reminder fields', () {
      final rule = NotificationRule(
        id: 'rule-1',
        daysBefore: 3,
        titleTemplate: '{item} expires soon',
        bodyTemplate: '{item} expires in {days} days.',
        sendTime: '09:00',
        enabled: true,
        createdAt: DateTime.utc(2026, 8, 14),
        updatedAt: DateTime.utc(2026, 8, 14, 1),
      );

      final restored = NotificationRule.fromMap(rule.id, rule.toMap());
      expect(restored.id, rule.id);
      expect(restored.daysBefore, 3);
      expect(restored.sendTime, '09:00');
      expect(restored.enabled, isTrue);
    });

    test('normalizes and validates local send time', () {
      expect(NotificationRule.normalizeSendTime('9:05'), '09:05');
      expect(
        () => NotificationRule.normalizeSendTime('24:00'),
        throwsFormatException,
      );
      expect(
        () => NotificationRule.normalizeSendTime('9:5'),
        throwsFormatException,
      );
    });

    test('renders supported message variables', () {
      final rendered = NotificationRule.renderTemplate(
        '{item} x{quantity} expires in {days} days ({expiry_date}) at {location}',
        item: 'Milk',
        days: 2,
        expiryDate: '2026-08-20',
        quantity: 3,
        location: 'Fridge',
      );
      expect(rendered, 'Milk x3 expires in 2 days (2026-08-20) at Fridge');
    });
  });

  group('ProductLookupResult', () {
    test('prefers English Open Food Facts product names', () {
      final product = ProductLookupResult.fromOpenFoodFactsProduct('12345678', {
        'product_name': 'Lait partiellement ecreme',
        'product_name_en': 'Partly skimmed milk',
        'generic_name_en': 'Milk',
      });
      expect(product.name, 'Partly skimmed milk');
    });

    test('parses the Open Food Facts fields FreshFlag needs', () {
      final product = ProductLookupResult.fromOpenFoodFactsProduct(
        '3017620422003',
        {'product_name': 'Hazelnut Spread', 'quantity': '400 g'},
      );
      expect(product.barcode, '3017620422003');
      expect(product.name, 'Hazelnut Spread');
      expect(product.quantityLabel, '400 g');
    });

    test('falls back to a generic product name', () {
      final product = ProductLookupResult.fromOpenFoodFactsProduct('12345678', {
        'product_name': '   ',
        'generic_name': 'Tomato sauce',
      });
      expect(product.name, 'Tomato sauce');
      expect(product.quantityLabel, isNull);
    });

    test('rejects records without a usable display name', () {
      expect(
        () => ProductLookupResult.fromOpenFoodFactsProduct('12345678', {
          'quantity': '500 g',
        }),
        throwsFormatException,
      );
    });
  });

  group('InventoryCategories', () {
    test('normalizes and includes custom categories from inventory items', () {
      final categories = InventoryCategories.forItems([
        GroceryItem(
          id: 'item-1',
          name: 'Soup',
          quantity: 1,
          category: '  Canned goods  ',
          addedDate: DateTime(2026, 8, 20),
          expiryDate: DateTime(2026, 9, 1),
        ),
      ], includeAll: true);

      expect(categories.first, InventoryCategories.allLabel);
      expect(categories, contains('Canned goods'));
      expect(categories, contains(InventoryCategories.otherLabel));
    });

    test(
      'includes saved custom categories without matching inventory items',
      () {
        final categories = InventoryCategories.forItems(
          const [],
          savedCategories: const ['Pantry staples'],
        );

        expect(categories, contains('Pantry staples'));
      },
    );

    test('cleans blank and repeated-space category names', () {
      expect(
        InventoryCategories.clean('  Pantry   staples '),
        'Pantry staples',
      );
      expect(InventoryCategories.clean('   '), isNull);
    });
  });
}
