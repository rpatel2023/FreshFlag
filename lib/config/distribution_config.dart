/// Compile-time distribution characteristics for FreshFlag.
///
/// The SideStore build uses a free Apple Personal Team and intentionally does
/// not depend on APNs/FCM. Standard/paid builds keep remote push available.
class DistributionConfig {
  static const bool isSideStore = bool.fromEnvironment(
    'FRESHFLAG_SIDESTORE',
    defaultValue: false,
  );

  static const bool supportsRemotePush = !isSideStore;
}
