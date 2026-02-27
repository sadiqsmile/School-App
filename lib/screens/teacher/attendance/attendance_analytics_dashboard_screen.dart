import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/attendance_analytics_service.dart';
import '../../../services/attendance_report_service.dart';
import '../../../services/attendance_service_enhanced.dart';
import '../../../widgets/loading_view.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

/// Attendance Analytics Dashboard with charts and export功能
class AttendanceAnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AttendanceAnalyticsDashboardScreen({
    super.key,
    required this.classId,
    required this.sectionId,
  });

  final String classId;
  final String sectionId;

  @override
  ConsumerState<AttendanceAnalyticsDashboardScreen> createState() =>
      _AttendanceAnalyticsDashboardScreenState();
}

class _AttendanceAnalyticsDashboardScreenState
    extends ConsumerState<AttendanceAnalyticsDashboardScreen> {
  final _analyticsService = AttendanceAnalyticsService();
  final _reportService = AttendanceReportService();
  final _attendanceService = AttendanceServiceEnhanced();

  DateTime _selectedMonth = DateTime.now();
  bool _loading = true;
  bool _exporting = false;

  List<Map<String, dynamic>> _monthlyData = [];
  Map<String, dynamic>? _overallStats;
  Map<String, dynamic>? _distribution;
  List<Map<String, dynamic>> _lowAttendanceStudents = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);

    try {
      final startOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      // Load all analytics data
      final results = await Future.wait([
        _analyticsService.getMonthlyChartData(
          schoolId: 'school_001',
          classId: widget.classId,
          sectionId: widget.sectionId,
          month: _selectedMonth,
        ),
        _analyticsService.getOverallStatistics(
          schoolId: 'school_001',
          classId: widget.classId,
          sectionId: widget.sectionId,
          startDate: startOfMonth,
          endDate: endOfMonth,
        ),
        _analyticsService.getStudentWiseDistribution(
          schoolId: 'school_001',
          classId: widget.classId,
          sectionId: widget.sectionId,
          startDate: startOfMonth,
          endDate: endOfMonth,
        ),
        _analyticsService.getLowAttendanceStudents(
          schoolId: 'school_001',
          classId: widget.classId,
          sectionId: widget.sectionId,
          startDate: startOfMonth,
          endDate: endOfMonth,
          threshold: 75.0,
        ),
      ]);

      setState(() {
        _monthlyData = results[0] as List<Map<String, dynamic>>;
        _overallStats = results[1] as Map<String, dynamic>;
        _distribution = results[2] as Map<String, dynamic>;
        _lowAttendanceStudents = results[3] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      _showError('Error loading analytics: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ============================================================================
  // EXPORT FUNCTIONS
  // ============================================================================

  Future<void> _exportToExcel() async {
    setState(() => _exporting = true);

    try {
      // Get students
      final studentsSnapshot = await _attendanceService
          .watchStudentsForClassSection(
            classId: widget.classId,
            sectionId: widget.sectionId,
          )
          .first;

      final startOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      final filePath = await _reportService.generateExcelReport(
        schoolId: 'school_001',
        classId: widget.classId,
        sectionId: widget.sectionId,
        startDate: startOfMonth,
        endDate: endOfMonth,
        students: studentsSnapshot,
        reportTitle:
            'Attendance Report - ${widget.classId} ${widget.sectionId}',
      );

      if (!mounted) return;
      _showSuccess('Excel report generated: $filePath');
      
      // Open file
      if (await File(filePath).exists()) {
        await _openFile(filePath);
      }
    } catch (e) {
      _showError('Error generating Excel: $e');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _exportToPdf() async {
    setState(() => _exporting = true);

    try {
      // Get students
      final studentsSnapshot = await _attendanceService
          .watchStudentsForClassSection(
            classId: widget.classId,
            sectionId: widget.sectionId,
          )
          .first;

      final startOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      final filePath = await _reportService.generatePdfReport(
        schoolId: 'school_001',
        classId: widget.classId,
        sectionId: widget.sectionId,
        startDate: startOfMonth,
        endDate: endOfMonth,
        students: studentsSnapshot,
        reportTitle:
            'Attendance Report - ${widget.classId} ${widget.sectionId}',
      );

      if (!mounted) return;
      _showSuccess('PDF report generated: $filePath');
      
      // Open file
      if (await File(filePath).exists()) {
        await _openFile(filePath);
      }
    } catch (e) {
      _showError('Error generating PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      print('Error opening file: $e');
    }
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics - ${widget.classId}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (value) {
              if (value == 'excel') {
                _exportToExcel();
              } else if (value == 'pdf') {
                _exportToPdf();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Export to Excel'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Export to PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month selector
                    _buildMonthSelector(),
                    const SizedBox(height: 16),

                    // Overall statistics cards
                    if (_overallStats != null) _buildStatisticsCards(),
                    const SizedBox(height: 24),

                    // Daily attendance bar chart
                    _buildDailyChartSection(),
                    const SizedBox(height: 24),

                    // Attendance trend line chart
                    _buildTrendChartSection(),
                    const SizedBox(height: 24),

                    // Student distribution pie chart
                    _buildDistributionSection(),
                    const SizedBox(height: 24),

                    // Low attendance alerts
                    _buildLowAttendanceSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month - 1,
                  );
                });
                _loadAnalytics();
              },
            ),
            Text(
              DateFormat('MMMM yyyy').format(_selectedMonth),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month + 1,
                  );
                });
                _loadAnalytics();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final stats = _overallStats!;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Days',
            '${stats['totalDays']}',
            Icons.calendar_today,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Present',
            '${stats['totalPresent']}',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Absent',
            '${stats['totalAbsent']}',
            Icons.cancel,
            Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Percentage',
            '${(stats['percentage'] as double).toStringAsFixed(1)}%',
            Icons.analytics,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChartSection() {
    if (_monthlyData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No data available')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barGroups: _monthlyData.asMap().entries.map((entry) {
                    final data = entry.value;
                    final percentage = data['percentage'] as double;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: percentage,
                          color: percentage >= 85
                              ? Colors.green
                              : percentage >= 75
                                  ? Colors.orange
                                  : Colors.red,
                          width: 16,
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < _monthlyData.length) {
                            final day = _monthlyData[value.toInt()]['day'];
                            return Text('$day',
                                style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChartSection() {
    if (_monthlyData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _monthlyData.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value['percentage'] as double,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionSection() {
    if (_distribution == null) {
      return const SizedBox.shrink();
    }

    final excellent = _distribution!['excellent'] as int;
    final good = _distribution!['good'] as int;
    final average = _distribution!['average'] as int;
    final belowAverage = _distribution!['belowAverage'] as int;
    final poor = _distribution!['poor'] as int;
    final total = excellent + good + average + belowAverage + poor;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Student Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          if (excellent > 0)
                            PieChartSectionData(
                              value: excellent.toDouble(),
                              title: '$excellent',
                              color: Colors.green,
                              radius: 60,
                            ),
                          if (good > 0)
                            PieChartSectionData(
                              value: good.toDouble(),
                              title: '$good',
                              color: Colors.lightGreen,
                              radius: 60,
                            ),
                          if (average > 0)
                            PieChartSectionData(
                              value: average.toDouble(),
                              title: '$average',
                              color: Colors.yellow,
                              radius: 60,
                            ),
                          if (belowAverage > 0)
                            PieChartSectionData(
                              value: belowAverage.toDouble(),
                              title: '$belowAverage',
                              color: Colors.orange,
                              radius: 60,
                            ),
                          if (poor > 0)
                            PieChartSectionData(
                              value: poor.toDouble(),
                              title: '$poor',
                              color: Colors.red,
                              radius: 60,
                            ),
                        ],
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('Excellent (≥95%)', Colors.green, excellent),
                      _buildLegendItem('Good (85-94%)', Colors.lightGreen, good),
                      _buildLegendItem('Average (75-84%)', Colors.yellow, average),
                      _buildLegendItem(
                          'Below Avg (65-74%)', Colors.orange, belowAverage),
                      _buildLegendItem('Poor (<65%)', Colors.red, poor),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLowAttendanceSection() {
    if (_lowAttendanceStudents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Low Attendance Alert',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lowAttendanceStudents.length,
              itemBuilder: (context, index) {
                final student = _lowAttendanceStudents[index];
                final percentage = student['percentage'] as double;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Text(
                      student['rollNumber'] ?? '?',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text(student['studentName'] ?? 'Unknown'),
                  subtitle: Text(
                    'P: ${student['present']} | A: ${student['absent']}',
                  ),
                  trailing: Chip(
                    label: Text('${percentage.toStringAsFixed(1)}%'),
                    backgroundColor: Colors.red.shade100,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
