import 'dart:convert';

import 'package:authentication_repository/authentication_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuthenticationRepository', () {
    test('reads cached user JSON and falls back to empty user on malformed cache', () async {
      SharedPreferences.setMockInitialValues({
        'user': jsonEncode({
          'userId': 'user-id',
          'phoneNumber': '+123456789',
          'userName': 'Unit Tester',
        }),
      });

      final prefs = await SharedPreferences.getInstance();
      final repository = AuthenticationRepository(sharedPreferences: prefs);

      expect(repository.currentUser.userId, 'user-id');
      expect(repository.currentUser.phoneNumber, '+123456789');
      expect(repository.currentUser.userName, 'Unit Tester');
    });

    test('returns User.empty when cached value cannot be decoded', () async {
      SharedPreferences.setMockInitialValues({
        'user': 'invalid-json',
      });

      final prefs = await SharedPreferences.getInstance();
      final repository = AuthenticationRepository(sharedPreferences: prefs);

      expect(repository.currentUser, User.empty);
    });
  });
}
