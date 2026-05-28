import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? partnerId;
  final String? pairCode;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.partnerId,
    this.pairCode,
    required this.createdAt,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] as String,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      partnerId: data['partnerId'] as String?,
      pairCode: data['pairCode'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'partnerId': partnerId,
        'pairCode': pairCode,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
