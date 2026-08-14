import 'package:hive_flutter/hive_flutter.dart';
import '../models/grocery_item.dart';
import '../models/user_model.dart';
import 'firebase_firestore_service.dart';

/// Local cache and settings service.
///
/// During Phase 1, Firestore is the authoritative store for grocery inventory.
/// Grocery writes are persisted remotely first and mirrored to Hive only after
/// the remote operation succeeds. This prevents local-only "success" states.
class LocalDatabaseService {
  static const String _groceryBoxName = 'grocery_items';
  static const String _userBoxName = 'user_data';
  static const String _settingsBoxName = 'app_settings';

  static Box<GroceryItem>? _groceryBox;
  static Box<UserModel>? _userBox;
  static Box? _settingsBox;

  static Future<void> initialize() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(GroceryItemAdapter());
    }

    _groceryBox = await Hive.openBox<GroceryItem>(_groceryBoxName);
    _userBox = await Hive.openBox<UserModel>(_userBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  static Future<void> addGroceryItem(GroceryItem item) async {
    await FirebaseFirestoreService.instance.addGroceryItem(item);
    await _groceryBox?.put(item.id, item);
  }

  static Future<void> updateGroceryItem(GroceryItem item) async {
    await FirebaseFirestoreService.instance.updateGroceryItem(item);
    await _groceryBox?.put(item.id, item);
  }

  static Future<void> deleteGroceryItem(String id) async {
    await FirebaseFirestoreService.instance.deleteGroceryItem(id);
    await _groceryBox?.delete(id);
  }

  static GroceryItem? getGroceryItem(String id) => _groceryBox?.get(id);

  static List<GroceryItem> getAllGroceryItems() =>
      _groceryBox?.values.toList() ?? [];

  static List<GroceryItem> getGroceryItemsByCategory(String category) {
    return _groceryBox?.values
            .where((item) => item.category == category)
            .toList() ??
        [];
  }

  static List<GroceryItem> getExpiringItems({int days = 3}) {
    final now = DateTime.now();
    return _groceryBox?.values
            .where(
              (item) =>
                  !item.isConsumed &&
                  item.expiryDate.isAfter(now) &&
                  item.daysUntilExpiry <= days,
            )
            .toList() ??
        [];
  }

  static List<GroceryItem> getExpiredItems() {
    return _groceryBox?.values
            .where((item) => !item.isConsumed && item.isExpired)
            .toList() ??
        [];
  }

  static List<GroceryItem> getFreshItems() {
    return _groceryBox?.values
            .where(
              (item) =>
                  !item.isConsumed &&
                  !item.isExpired &&
                  item.daysUntilExpiry > 3,
            )
            .toList() ??
        [];
  }

  static Future<void> saveUser(UserModel user) async {
    await _userBox?.put('current_user', user);
  }

  static Future<void> updateUser(UserModel user) async {
    await _userBox?.put('current_user', user);
  }

  static UserModel? getCurrentUser() => _userBox?.get('current_user');

  static Future<void> deleteUser() async {
    await _userBox?.delete('current_user');
  }

  static Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox?.put(key, value);
  }

  static T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox?.get(key, defaultValue: defaultValue) as T?;
  }

  static Future<void> deleteSetting(String key) async {
    await _settingsBox?.delete(key);
  }

  static bool get isFirstLaunch =>
      getSetting('first_launch', defaultValue: true) ?? true;

  static Future<void> setFirstLaunchComplete() =>
      saveSetting('first_launch', false);

  static bool get notificationsEnabled =>
      getSetting('notifications_enabled', defaultValue: true) ?? true;

  static Future<void> setNotificationsEnabled(bool enabled) =>
      saveSetting('notifications_enabled', enabled);

  static int get reminderDays =>
      getSetting('reminder_days', defaultValue: 3) ?? 3;

  static Future<void> setReminderDays(int days) =>
      saveSetting('reminder_days', days);

  static String get themeMode =>
      getSetting('theme_mode', defaultValue: 'light') ?? 'light';

  static Future<void> setThemeMode(String mode) =>
      saveSetting('theme_mode', mode);

  static int get totalItems => _groceryBox?.length ?? 0;

  static int get consumedItems =>
      _groceryBox?.values.where((item) => item.isConsumed).length ?? 0;

  static int get wastedItems => getExpiredItems().length;

  static Future<void> clearAllData() async {
    await _groceryBox?.clear();
    await _userBox?.clear();
    await _settingsBox?.clear();
  }

  static Future<void> close() async {
    await _groceryBox?.close();
    await _userBox?.close();
    await _settingsBox?.close();
  }
}
