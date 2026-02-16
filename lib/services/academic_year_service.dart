import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

class AcademicYearService {
  AcademicYearService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> getActiveAcademicYearId() async {
    final doc = await _firestore
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('settings')
        .doc('app')
        .get();

    final data = doc.data();
    final configured = data == null ? null : data['activeAcademicYearId'] as String?;
    return configured ?? AppConfig.fallbackAcademicYearId;
  }
}
