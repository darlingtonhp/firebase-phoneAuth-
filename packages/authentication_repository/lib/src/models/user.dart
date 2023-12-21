import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String? phoneNumber;
  final String userId;
  final String? userName;

  const User({this.phoneNumber, required this.userId, this.userName});

  static const empty = User(userId: '');
  bool get isEmpty => this == User.empty;
  bool get isNotEmpty => this != User.empty;

  @override
  List<Object?> get props => [phoneNumber, userId, userName];

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'phoneNumber': phoneNumber,
      'userName': userName,
      // ... other fields to serialize
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      phoneNumber: json['phoneNumber'],
      userId: json['userId'],
      userName: json['userName'],
    );
  }
}
