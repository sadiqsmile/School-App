import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/student_base.dart';

/// Service for exporting attendance reports to Excel and PDF
class AttendanceReportService {
  AttendanceReportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({
    String schoolId = AppConfig.schoolId,
  }) {
    return _firestore.collection('schools').doc(schoolId);
  }

  String dateId(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  String classSectionId({required String classId, required String sectionId}) {
    return '${classId}_$sectionId';
  }

  // ============================================================================
  // DATA FETCHING
  // ============================================================================

  /// Fetch attendance data for export
  Future<List<Map<String, dynamic>>> fetchAttendanceData({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime startDate,
    required DateTime endDate,
    required List<StudentBase> students,
  }) async {
    final csId = classSectionId(classId: classId, sectionId: sectionId);

    final snapshot = await _schoolDoc(schoolId: schoolId)
        .collection('attendance')
        .doc(csId)
        .collection('days')
        .where('meta.date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('meta.date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final attendanceData = <Map<String, dynamic>>[];

    for (final student in students) {
      var present = 0;
      var absent = 0;
      var holidays = 0;

      for (final doc in snapshot.docs) {
        final studentsData = doc.data()['students'] as Map<String, dynamic>?;
        final studentData = studentsData?[student.id] as Map<String, dynamic>?;
        final status = studentData?['status'] as String?;

        if (status == 'P') present++;
        if (status == 'A') absent++;
        if (status == 'H') holidays++;
      }

      final total = present + absent;
      final percentage = total > 0 ? (present / total) * 100 : 100.0;

      attendanceData.add({
        'rollNumber': student.admissionNo ?? '',
        'name': student.fullName,
        'totalPresent': present,
        'totalAbsent': absent,
        'totalHolidays': holidays,
        'percentage': percentage,
        'studentId': student.id,
      });
    }

    // Sort by roll number
    attendanceData.sort((a, b) {
      final aRoll = a['rollNumber'] as String;
      final bRoll = b['rollNumber'] as String;
      
      // Try to parse as numbers first
      final aNum = int.tryParse(aRoll);
      final bNum = int.tryParse(bRoll);
      
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      
      return aRoll.compareTo(bRoll);
    });

    return attendanceData;
  }

  // ============================================================================
  // EXCEL EXPORT
  // ============================================================================

  /// Generate Excel report
  Future<String> generateExcelReport({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime startDate,
    required DateTime endDate,
    required List<StudentBase> students,
    required String reportTitle,
  }) async {
    try {
      // Fetch data
      final data = await fetchAttendanceData(
        schoolId: schoolId,
        classId: classId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate,
        students: students,
      );

      // Create workbook
      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];

      // Set column widths
      sheet.getRangeByName('A1').columnWidth = 10;
      sheet.getRangeByName('B1').columnWidth = 25;
      sheet.getRangeByName('C1').columnWidth = 12;
      sheet.getRangeByName('D1').columnWidth = 12;
      sheet.getRangeByName('E1').columnWidth = 12;
      sheet.getRangeByName('F1').columnWidth = 15;

      // Title
      sheet.getRangeByName('A1:F1').merge();
      sheet.getRangeByName('A1').setText(reportTitle);
      sheet.getRangeByName('A1').cellStyle.fontSize = 14;
      sheet.getRangeByName('A1').cellStyle.bold = true;
      sheet.getRangeByName('A1').cellStyle.hAlign = xlsio.HAlignType.center;

      // Date range
      final dateRange =
          '${_formatDate(startDate)} to ${_formatDate(endDate)}';
      sheet.getRangeByName('A2:F2').merge();
      sheet.getRangeByName('A2').setText('Period: $dateRange');
      sheet.getRangeByName('A2').cellStyle.hAlign = xlsio.HAlignType.center;

      // Headers
      final headers = [
        'Roll No',
        'Student Name',
        'Present',
        'Absent',
        'Holidays',
        'Percentage (%)'
      ];
      
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.getRangeByIndex(4, i + 1);
        cell.setText(headers[i]);
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#4CAF50';
        cell.cellStyle.fontColor = '#FFFFFF';
        cell.cellStyle.hAlign = xlsio.HAlignType.center;
      }

      // Data rows
      var rowIndex = 5;
      for (final record in data) {
        sheet.getRangeByIndex(rowIndex, 1).setText(record['rollNumber']);
        sheet.getRangeByIndex(rowIndex, 2).setText(record['name']);
        sheet.getRangeByIndex(rowIndex, 3).setNumber(record['totalPresent'].toDouble());
        sheet.getRangeByIndex(rowIndex, 4).setNumber(record['totalAbsent'].toDouble());
        sheet.getRangeByIndex(rowIndex, 5).setNumber(record['totalHolidays'].toDouble());
        sheet.getRangeByIndex(rowIndex, 6).setNumber(record['percentage']);

        // Color code percentage
        final percentage = record['percentage'] as double;
        final percentCell = sheet.getRangeByIndex(rowIndex, 6);
        
        if (percentage >= 85) {
          percentCell.cellStyle.backColor = '#C8E6C9'; // Light green
        } else if (percentage >= 75) {
          percentCell.cellStyle.backColor = '#FFF9C4'; // Light yellow
        } else {
          percentCell.cellStyle.backColor = '#FFCDD2'; // Light red
        }

        rowIndex++;
      }

      // Summary row
      rowIndex++;
      sheet.getRangeByIndex(rowIndex, 1).setText('TOTAL');
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.bold = true;
      
      final totalPresent = data.fold(0, (sum, item) => sum + (item['totalPresent'] as int));
      final totalAbsent = data.fold(0, (sum, item) => sum + (item['totalAbsent'] as int));
      final totalHolidays = data.fold(0, (sum, item) => sum + (item['totalHolidays'] as int));
      final avgPercentage = data.isEmpty ? 0.0 : data.fold(0.0, (sum, item) => sum + (item['percentage'] as double)) / data.length;

      sheet.getRangeByIndex(rowIndex, 3).setNumber(totalPresent.toDouble());
      sheet.getRangeByIndex(rowIndex, 4).setNumber(totalAbsent.toDouble());
      sheet.getRangeByIndex(rowIndex, 5).setNumber(totalHolidays.toDouble());
      sheet.getRangeByIndex(rowIndex, 6).setNumber(avgPercentage);
      
      sheet.getRangeByIndex(rowIndex, 1, rowIndex, 6).cellStyle.bold = true;
      sheet.getRangeByIndex(rowIndex, 1, rowIndex, 6).cellStyle.backColor = '#E0E0E0';

      // Save file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_${classId}_${sectionId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      throw Exception('Error generating Excel report: $e');
    }
  }

  // ============================================================================
  // PDF EXPORT
  // ============================================================================

  /// Generate PDF report
  Future<String> generatePdfReport({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime startDate,
    required DateTime endDate,
    required List<StudentBase> students,
    required String reportTitle,
  }) async {
    try {
      // Fetch data
      final data = await fetchAttendanceData(
        schoolId: schoolId,
        classId: classId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate,
        students: students,
      );

      final pdf = pw.Document();

      // Calculate statistics
      final totalPresent = data.fold(0, (sum, item) => sum + (item['totalPresent'] as int));
      final totalAbsent = data.fold(0, (sum, item) => sum + (item['totalAbsent'] as int));
      final avgPercentage = data.isEmpty ? 0.0 : data.fold(0.0, (sum, item) => sum + (item['percentage'] as double)) / data.length;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      reportTitle,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Class: $classId - Section: $sectionId',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 2),
                  ],
                ),
              ),

              // Summary statistics
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatBox('Total Students', '${data.length}'),
                    _buildStatBox('Total Present', '$totalPresent'),
                    _buildStatBox('Total Absent', '$totalAbsent'),
                    _buildStatBox('Avg Attendance', '${avgPercentage.toStringAsFixed(1)}%'),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Data table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Roll No', isHeader: true),
                      _buildTableCell('Student Name', isHeader: true),
                      _buildTableCell('Present', isHeader: true),
                      _buildTableCell('Absent', isHeader: true),
                      _buildTableCell('Percentage', isHeader: true),
                    ],
                  ),
                  // Data rows
                  ...data.map((record) {
                    final percentage = record['percentage'] as double;
                    final color = percentage >= 85
                        ? PdfColors.green50
                        : percentage >= 75
                            ? PdfColors.yellow50
                            : PdfColors.red50;
                    
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: color),
                      children: [
                        _buildTableCell(record['rollNumber']),
                        _buildTableCell(record['name']),
                        _buildTableCell('${record['totalPresent']}'),
                        _buildTableCell('${record['totalAbsent']}'),
                        _buildTableCell('${percentage.toStringAsFixed(1)}%'),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // Footer
              pw.Text(
                'Generated on: ${_formatDateTime(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600,
                ),
              ),
            ];
          },
        ),
      );

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_${classId}_${sectionId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      return filePath;
    } catch (e) {
      throw Exception('Error generating PDF report: $e');
    }
  }

  // ============================================================================
  // PDF HELPER WIDGETS
  // ============================================================================

  pw.Widget _buildStatBox(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
