import 'package:cloud_firestore/cloud_firestore.dart';

class ParentLoginRequest {
  const ParentLoginRequest({
    required this.id,
    required this.mobile,
    required this.authUid,
    required this.parentName,
    required this.children,
    required this.status,
    this.createdAt,
    this.approvedAt,
    this.approvedByUid,
  });

  final String id;
  final String mobile;
  final String authUid;
  final String parentName;
  final List<String> children; // studentIds
  final String status; // "pending" | "approved" | "rejected"
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String? approvedByUid;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory ParentLoginRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    DateTime? readTs(Object? v) => v is Timestamp ? v.toDate() : null;

    final childrenRaw = data['children'] as List?;
    final children = (childrenRaw ?? const [])
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return ParentLoginRequest(
      id: doc.id,
      mobile: (data['mobile'] as String?)?.trim() ?? '',
      authUid: (data['authUid'] as String?)?.trim() ?? '',
      parentName: (data['parentName'] as String?)?.trim() ?? '',
      children: children,
      status: (data['status'] as String?)?.trim() ?? 'pending',
      createdAt: readTs(data['createdAt']),
      approvedAt: readTs(data['approvedAt']),
      approvedByUid: data['approvedByUid'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'mobile': mobile.trim(),
      'authUid': authUid.trim(),
      'parentName': parentName.trim(),
      'children': children,
      'status': status.trim(),
      'createdAt': createdAt,
      'approvedAt': approvedAt,
      'approvedByUid': approvedByUid,
    };
  }
}
