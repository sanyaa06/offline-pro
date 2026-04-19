class NetworkService {
  bool _isOnline = true;

  /// Returns the current simulated network status
  bool isOnline() => _isOnline;

  /// Toggles the mock online status
  void toggleOnlineStatus() {
    _isOnline = !_isOnline;
  }
}
