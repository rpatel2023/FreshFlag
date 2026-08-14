import 'package:flutter/foundation.dart';

import '../models/household.dart';
import '../services/household_service.dart';
import '../services/invite_service.dart';

class HouseholdViewModel extends ChangeNotifier {
  final HouseholdService _service = HouseholdService.instance;
  final InviteService _invites = InviteService.instance;

  List<Household> _households = [];
  Household? _current;
  HouseholdMember? _membership;
  bool _isLoading = false;
  String? _error;
  String? _loadedUid;

  List<Household> get households => List.unmodifiable(_households);
  Household? get current => _current;
  HouseholdMember? get membership => _membership;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasHousehold => _current != null;
  bool get isOwner => _membership?.role == HouseholdRole.owner;

  Future<void> initializeForUser(String uid) async {
    if (_loadedUid == uid && !_isLoading) return;
    _loadedUid = uid;
    await _reload();
  }

  Future<Household> createHousehold({
    required String name,
    required String timezone,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final household = await _service.createHousehold(
        name: name,
        timezone: timezone,
      );
      _households = [
        household,
        ..._households.where((h) => h.id != household.id),
      ];
      _current = household;
      _membership = await _service.getMembership(household.id);
      notifyListeners();
      return household;
    } catch (e) {
      _error = 'Failed to create household: $e';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<Household> joinHousehold(String inviteCode) async {
    _setLoading(true);
    _error = null;
    try {
      final household = await _invites.joinHousehold(inviteCode);
      _households = await _service.listMyHouseholds();
      _current = household;
      _membership = await _service.getMembership(household.id);
      notifyListeners();
      return household;
    } catch (e) {
      _error = 'Failed to join household: $e';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectHousehold(String householdId) async {
    final selected = _households.where((h) => h.id == householdId).firstOrNull;
    if (selected == null) throw StateError('Household not available');
    if (_current?.id == selected.id) return;

    _setLoading(true);
    _error = null;
    try {
      await _service.setPreferredHousehold(selected.id);
      _current = selected;
      _membership = await _service.getMembership(selected.id);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to switch household: $e';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _loadedUid = null;
    _households = [];
    _current = null;
    _membership = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> _reload() async {
    _setLoading(true);
    _error = null;
    try {
      final preferredId = await _service.getPreferredHouseholdId();
      _households = await _service.listMyHouseholds();
      _current = _pickCurrent(preferredId);
      _membership = _current == null
          ? null
          : await _service.getMembership(_current!.id);
      notifyListeners();
    } catch (e) {
      _households = [];
      _current = null;
      _membership = null;
      _error = 'Failed to load households: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Household? _pickCurrent(String? preferredId) {
    if (_households.isEmpty) return null;
    if (preferredId != null) {
      for (final household in _households) {
        if (household.id == preferredId) return household;
      }
    }
    return _households.first;
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
