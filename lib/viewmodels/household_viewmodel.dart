import 'dart:async';

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
  StreamSubscription<HouseholdMember?>? _membershipSubscription;
  bool _isLoading = false;
  String? _error;
  String? _loadedUid;
  int _membershipGeneration = 0;

  List<Household> get households => List.unmodifiable(_households);
  Household? get current => _current;
  HouseholdMember? get membership => _membership;
  HouseholdRole? get role => _membership?.role;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasHousehold => _current != null;
  bool get isOwner => role == HouseholdRole.owner;
  bool get canManageHousehold => role?.canManageHousehold ?? false;
  bool get canWriteInventory => role?.canWriteInventory ?? false;

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
      await _bindMembership(household.id);
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
      await _bindMembership(household.id);
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
      await _bindMembership(selected.id);
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
    _membershipGeneration++;
    final subscription = _membershipSubscription;
    _membershipSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
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
      await _bindMembership(_current?.id);
      notifyListeners();
    } catch (e) {
      _households = [];
      _current = null;
      await _bindMembership(null);
      _error = 'Failed to load households: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _bindMembership(String? householdId) async {
    final generation = ++_membershipGeneration;
    await _membershipSubscription?.cancel();
    _membershipSubscription = null;

    if (householdId == null) {
      _membership = null;
      return;
    }

    _membership = await _service.getMembership(householdId);
    if (generation != _membershipGeneration) return;

    _membershipSubscription = _service.watchMembership(householdId).listen(
      (membership) {
        if (generation != _membershipGeneration || _current?.id != householdId) {
          return;
        }
        _membership = membership;
        notifyListeners();
        if (membership == null && !_isLoading) {
          unawaited(_reload());
        }
      },
      onError: (Object error) {
        if (generation != _membershipGeneration) return;
        _error = 'Failed to refresh household access: $error';
        notifyListeners();
      },
    );
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
