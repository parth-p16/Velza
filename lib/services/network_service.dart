import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum VelzaNetworkStatus {
  online,
  offline,
  connecting,
}

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  VelzaNetworkStatus _status = VelzaNetworkStatus.online;
  final _statusController = StreamController<VelzaNetworkStatus>.broadcast();
  Timer? _checkTimer;
  bool _isChecking = false;

  VelzaNetworkStatus get status => _status;
  bool get isOnline => _status == VelzaNetworkStatus.online;
  Stream<VelzaNetworkStatus> get statusStream => _statusController.stream;

  void init() {
    checkConnection();
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 15), (_) => checkConnection());
  }

  Future<bool> checkConnection() async {
    if (_isChecking) return isOnline;
    _isChecking = true;

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _updateStatus(VelzaNetworkStatus.online);
        return true;
      } else {
        _updateStatus(VelzaNetworkStatus.offline);
        return false;
      }
    } on SocketException catch (_) {
      _updateStatus(VelzaNetworkStatus.offline);
      return false;
    } on TimeoutException catch (_) {
      _updateStatus(VelzaNetworkStatus.connecting);
      return false;
    } catch (_) {
      _updateStatus(VelzaNetworkStatus.offline);
      return false;
    } finally {
      _isChecking = false;
    }
  }

  void _updateStatus(VelzaNetworkStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      debugPrint('[Velza Network] Connectivity status changed: ${newStatus.name}');
      _statusController.add(_status);
    }
  }

  void dispose() {
    _checkTimer?.cancel();
    _statusController.close();
  }
}
