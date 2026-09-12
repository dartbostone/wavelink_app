import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';

class ContactsProvider extends ChangeNotifier {
  final UserService _userService = UserService();

  List<UserModel> _allContacts = [];
  List<UserModel> visibleContacts = [];
  String searchQuery = '';
  bool isLoading = true;
  String? errorMessage;

  StreamSubscription<List<UserModel>>? _subscription;

  void start(String myUid) {
    isLoading = true;
    notifyListeners();
    _subscription?.cancel();
    _subscription = _userService.watchContacts(myUid).listen(
      (users) {
        _allContacts = users;
        visibleContacts = _userService.filter(_allContacts, searchQuery);
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        isLoading = false;
        errorMessage = 'Could not load contacts. Check your connection.';
        notifyListeners();
      },
    );
  }

  void search(String query) {
    searchQuery = query;
    visibleContacts = _userService.filter(_allContacts, query);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
