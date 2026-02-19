import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/academic_year_service.dart';
import '../services/academic_year_admin_service.dart';
import '../services/attendance_service.dart';
import '../services/admin_data_service.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/exam_service.dart';
import '../services/exam_csv_service.dart';
import '../services/homework_service.dart';
import '../services/messaging_service.dart';
import '../services/notification_service.dart';
import '../services/notification_local_service.dart';
import '../services/notification_token_service.dart';
import '../services/parent_data_service.dart';
import '../services/student_csv_import_service.dart';
import '../services/parent_csv_import_service.dart';
import '../services/teacher_assignment_csv_import_service.dart';
import '../services/exam_result_csv_import_service.dart';
import '../services/class_section_csv_import_service.dart';
import '../services/storage_service.dart';
import '../services/teacher_data_service.dart';
import '../services/teacher_contact_parents_service.dart';
import '../services/teacher_directory_service.dart';
import '../services/timetable_service.dart';
import '../services/user_profile_service.dart';

// Core service providers used across the app.
//
// NOTE: This file intentionally does NOT include any Cloud Functions / bootstrap
// providers. The project is designed to work on the Firebase FREE plan.

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService();
});

final academicYearServiceProvider = Provider<AcademicYearService>((ref) {
  return AcademicYearService();
});

final academicYearAdminServiceProvider = Provider<AcademicYearAdminService>((ref) {
  return AcademicYearAdminService();
});

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService();
});

final examServiceProvider = Provider<ExamService>((ref) {
  return ExamService();
});

final examCsvServiceProvider = Provider<ExamCsvService>((ref) {
  return ExamCsvService();
});

final homeworkServiceProvider = Provider<HomeworkService>((ref) {
  return HomeworkService();
});

final timetableServiceProvider = Provider<TimetableService>((ref) {
  return TimetableService();
});

final adminDataServiceProvider = Provider<AdminDataService>((ref) {
  return AdminDataService();
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});

final teacherDataServiceProvider = Provider<TeacherDataService>((ref) {
  return TeacherDataService();
});

final teacherContactParentsServiceProvider = Provider<TeacherContactParentsService>((ref) {
  return TeacherContactParentsService();
});

final teacherDirectoryServiceProvider = Provider<TeacherDirectoryService>((ref) {
  return TeacherDirectoryService();
});

final parentDataServiceProvider = Provider<ParentDataService>((ref) {
  return ParentDataService();
});

final studentCsvImportServiceProvider = Provider<StudentCsvImportService>((ref) {
  return StudentCsvImportService();
});

final parentCsvImportServiceProvider = Provider<ParentCsvImportService>((ref) {
  return ParentCsvImportService();
});

final teacherAssignmentCsvImportServiceProvider = Provider<TeacherAssignmentCsvImportService>((ref) {
  return TeacherAssignmentCsvImportService();
});

final examResultCsvImportServiceProvider = Provider<ExamResultCsvImportService>((ref) {
  return ExamResultCsvImportService();
});

final classSectionCsvImportServiceProvider = Provider<ClassSectionCsvImportService>((ref) {
  return ClassSectionCsvImportService();
});

final messagingServiceProvider = Provider<MessagingService>((ref) {
  return MessagingService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationTokenServiceProvider = Provider<NotificationTokenService>((ref) {
  return NotificationTokenService();
});

final notificationLocalServiceProvider = Provider<NotificationLocalService>((ref) {
  return NotificationLocalService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
