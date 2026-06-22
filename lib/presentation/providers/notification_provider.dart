import 'package:flutter/material.dart';

import '../../data/services/notification_service.dart';

/// Provider for NotificationService
class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;

  NotificationProvider({NotificationService? service}) : _service = service ?? NotificationService() {
    _initialize();
  }

  void _initialize() {
    _service.initialize();
    _service.addListener(notifyListeners);
  }

  NotificationService get service => _service;

  List<NotificationModel> get notifications => _service.notifications;
  List<NotificationModel> get unreadNotifications =>
      _service.unreadNotifications;
  int get unreadCount => _service.unreadCount;

  Future<void> markAsRead(String id) async {
    await _service.markAsRead(id);
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await _service.markAllAsRead();
    notifyListeners();
  }

  @override
  void dispose() {
    _service.cleanup();
    _service.removeListener(notifyListeners);
    super.dispose();
  }
}
