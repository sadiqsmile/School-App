import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/analytics_filter.dart';
import '../../services/advanced_analytics_service.dart';
import '../../services/attendance_report_service.dart';
import '../../services/attendance_service_enhanced.dart';
import '../../config/app_config.dart';

/// Advanced Attendance Analytics Dashboard
/// Supports Admin and Class Teachers with comprehensive filtering and visualization
class AdvancedAttendanceAnalyticsDashboard extends ConsumerStatefulWidget {
  const AdvancedAttendanceAnalyticsDashboard({
    super.key,
    required this.userRole,
    this.assignedClassId,
    this.assignedSectionId,
  });

  final String userRole; // 'admin', 'teacher', 'class_teacher'
  final String? assignedClassId;
  final String? assignedSectionId;

  @override
  ConsumerState<AdvancedAttendanceAnalyticsDashboard> createState() =>
      _AdvancedAttendanceAnalyticsDashboardState();
}

class _AdvancedAttendanceAnalyticsDashboardState
    extends ConsumerState<AdvancedAttendanceAnalyticsDashboard>
    with SingleTickerProviderStateMixin {
  
  late AnalyticsFilter _currentFilter;
  late AdvancedAnalyticsService _analyticsService;
  late AttendanceReportService _reportService;
  late AttendanceServiceEnhanced _attendanceService;
  
  bool _loading = false;
  AnalyticsMetrics? _metrics;
  List<ChartDataPoint> _monthlyData = [];
  Map<String, double> _pieData = {};
  List<StudentAttendanceRecord> _lowestStudents = [];
  List<ChartDataPoint> _classComparison = [];
  List<StudentAttendanceRecord> _consecutiveAbsent = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Filter options
  String? _selectedClass;
  String? _selectedSection;
  DateTime _selectedMonth = DateTime.now();
  String _selectedYear = DateTime.now().year.toString();

  final List<String> _academicYears = [
    '2023-2024',
    '2024-2025',
    '2025-2026',
    '2026-2027',
  ];

  final List<String> _classes = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
  final List<String> _sections = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    
    _analyticsService = AdvancedAnalyticsService();
    _reportService = AttendanceReportService();
    _attendanceService = AttendanceServiceEnhanced();

    // Initialize filter based on user role
    if (widget.userRole == 'class_teacher' && 
        widget.assignedClassId != null && 
        widget.assignedSectionId != null) {
      _selectedClass = widget.assignedClassId;
      _selectedSection = widget.assignedSectionId;
    }

    _currentFilter = AnalyticsFilter(
      academicYear: _selectedYear,
      month: _selectedMonth,
      classId: _selectedClass,
      sectionId: _selectedSection,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    if (_currentFilter.hasClassFilter) {
      _loadAnalytics();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    if (!_currentFilter.hasClassFilter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select class and section')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Load all analytics data
      final metrics = await _analyticsService.getComprehensiveMetrics(
        schoolId: AppConfig.schoolId,
        filter: _currentFilter,
      );

      final monthlyData = await _analyticsService.getMonthlyBarChartData(
        schoolId: AppConfig.schoolId,
        filter: _currentFilter,
      );

      final pieData = await _analyticsService.getAttendancePieChartData(
        schoolId: AppConfig.schoolId,
        filter: _currentFilter,
      );

      final lowestStudents = await _analyticsService.getLowestAttendanceStudents(
        schoolId: AppConfig.schoolId,
        filter: _currentFilter,
        limit: 5,
      );

      final consecutiveAbsent = await _analyticsService.getConsecutiveAbsentStudents(
        schoolId: AppConfig.schoolId,
        classId: _currentFilter.classId!,
        sectionId: _currentFilter.sectionId!,
        threshold: 3,
      );

      // Load class comparison only for admin
      List<ChartDataPoint> classComparison = [];
      if (widget.userRole == 'admin') {
        final classes = [
          for (var cls in _classes)
            for (var sec in _sections)
              {'classId': cls, 'sectionId': sec},
        ];

        classComparison = await _analyticsService.getClassComparisonData(
          schoolId: AppConfig.schoolId,
          classes: classes.take(6).toList(),
          month: _selectedMonth,
        );
      }

      setState(() {
        _metrics = metrics;
        _monthlyData = monthlyData;
        _pieData = pieData;
        _lowestStudents = lowestStudents;
        _consecutiveAbsent = consecutiveAbsent;
        _classComparison = classComparison;
        _loading = false;
      });

      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    setState(() {
      _currentFilter = AnalyticsFilter(
        academicYear: _selectedYear,
        month: _selectedMonth,
        classId: _selectedClass,
        sectionId: _selectedSection,
      );
    });
    _loadAnalytics();
  }

  Future<void> _exportExcel() async {
    if (!_currentFilter.hasClassFilter) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating Excel report...')),
      );

      final students = await _attendanceService
          .watchStudentsForClassSection(
            schoolId: AppConfig.schoolId,
            classId: _currentFilter.classId!,
            sectionId: _currentFilter.sectionId!,
          )
          .first;

      final reportTitle =
          'Attendance Report - Class ${_currentFilter.classId} ${_currentFilter.sectionId} '
          '(${DateFormat('MMM yyyy').format(_currentFilter.month)})';

      final filePath = await _reportService.generateExcelReport(
        schoolId: AppConfig.schoolId,
        classId: _currentFilter.classId!,
        sectionId: _currentFilter.sectionId!,
        startDate: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        endDate: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
        students: students,
        reportTitle: reportTitle,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel report exported: $filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    if (!_currentFilter.hasClassFilter) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF report...')),
      );

      final students = await _attendanceService
          .watchStudentsForClassSection(
            schoolId: AppConfig.schoolId,
            classId: _currentFilter.classId!,
            sectionId: _currentFilter.sectionId!,
          )
          .first;

      final reportTitle =
          'Attendance Report - Class ${_currentFilter.classId} ${_currentFilter.sectionId} '
          '(${DateFormat('MMM yyyy').format(_currentFilter.month)})';

      final filePath = await _reportService.generatePdfReport(
        schoolId: AppConfig.schoolId,
        classId: _currentFilter.classId!,
        sectionId: _currentFilter.sectionId!,
        startDate: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        endDate: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
        students: students,
        reportTitle: reportTitle,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF report exported: $filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [const Color(0xFF1A237E), const Color(0xFF0D47A1)]
                : [const Color(0xFF5E35B1), const Color(0xFF1E88E5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDarkMode),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF121212) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _metrics == null
                          ? _buildEmptyState()
                          : _buildDashboardContent(isDarkMode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Analytics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.userRole == 'admin' ? 'School Overview' : 'Class Dashboard',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              _buildExportButtons(),
            ],
          ),
          const SizedBox(height: 20),
          _buildFilterSection(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildFilterSection(bool isDarkMode) {
    final canChangeClass = widget.userRole != 'class_teacher';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _academicYears.map((year) {
                      return DropdownMenuItem(value: year, child: Text(year));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedYear = val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDatePickerMode: DatePickerMode.year,
                      );
                      if (picked != null) {
                        setState(() => _selectedMonth = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(DateFormat('MMM yyyy').format(_selectedMonth)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedClass,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _classes.map((cls) {
                      return DropdownMenuItem(value: cls, child: Text('Class $cls'));
                    }).toList(),
                    onChanged: canChangeClass
                        ? (val) => setState(() => _selectedClass = val)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSection,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _sections.map((sec) {
                      return DropdownMenuItem(value: sec, child: Text('Section $sec'));
                    }).toList(),
                    onChanged: canChangeClass
                        ? (val) => setState(() => _selectedSection = val)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _applyFilter,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButtons() {
    return Row(
      children: [
        IconButton(
          onPressed: _exportExcel,
          icon: const Icon(Icons.file_download, color: Colors.white),
          tooltip: 'Export Excel',
        ),
        IconButton(
          onPressed: _exportPdf,
          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
          tooltip: 'Export PDF',
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            'Select filters to view analytics',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metrics Cards
            _buildMetricsSection(),
            const SizedBox(height: 24),

            // Absent Alert Panel
            if (_consecutiveAbsent.isNotEmpty) ...[
              _buildAbsentAlertPanel(isDarkMode),
              const SizedBox(height: 24),
            ],

            // Monthly Bar Chart
            _buildSectionTitle('Monthly Attendance Trend'),
            const SizedBox(height: 12),
            _buildMonthlyBarChart(isDarkMode),
            const SizedBox(height: 24),

            // Pie Chart and Top 5
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Distribution'),
                      const SizedBox(height: 12),
                      _buildPieChart(isDarkMode),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Top 5 Lowest'),
                      const SizedBox(height: 12),
                      _buildLowestStudentsChart(isDarkMode),
                    ],
                  ),
                ),
              ],
            ),

            // Class Comparison (Admin only)
            if (widget.userRole == 'admin' && _classComparison.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionTitle('Class Comparison'),
              const SizedBox(height: 12),
              _buildClassComparisonChart(isDarkMode),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Students',
          _metrics!.totalStudents.toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildMetricCard(
          'Avg Attendance',
          '${_metrics!.averageAttendance.toStringAsFixed(1)}%',
          Icons.trending_up,
          Colors.green,
        ),
        _buildMetricCard(
          'Total Present',
          _metrics!.totalPresent.toString(),
          Icons.check_circle,
          Colors.teal,
        ),
        _buildMetricCard(
          'Total Absent',
          _metrics!.totalAbsent.toString(),
          Icons.cancel,
          Colors.red,
        ),
        _buildMetricCard(
          '3+ Consecutive',
          _metrics!.consecutiveAbsentCount.toString(),
          Icons.warning,
          Colors.orange,
        ),
        if (_metrics!.lowestAttendanceStudent != null)
          _buildMetricCard(
            'Lowest',
            '${_metrics!.lowestAttendanceStudent!.percentage.toStringAsFixed(1)}%',
            Icons.arrow_downward,
            Colors.deepOrange,
            subtitle: _metrics!.lowestAttendanceStudent!.studentName,
          ),
        if (_metrics!.highestAttendanceStudent != null)
          _buildMetricCard(
            'Highest',
            '${_metrics!.highestAttendanceStudent!.percentage.toStringAsFixed(1)}%',
            Icons.arrow_upward,
            Colors.purple,
            subtitle: _metrics!.highestAttendanceStudent!.studentName,
          ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsentAlertPanel(bool isDarkMode) {
    return Card(
      elevation: 4,
      color: Colors.red[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  'Consecutive Absent Alert',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_consecutiveAbsent.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _consecutiveAbsent.length,
              itemBuilder: (context, index) {
                final student = _consecutiveAbsent[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Text(
                        student.rollNumber,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text(student.studentName),
                    subtitle: Text('${student.consecutiveDays} consecutive days absent'),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        // Contact parent functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Contacting parent of ${student.studentName}')),
                        );
                      },
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMonthlyBarChart(bool isDarkMode) {
    if (_monthlyData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('No data available')),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final data = _monthlyData[groupIndex];
                    return BarTooltipItem(
                      '${data.label}\n${rod.toY.toStringAsFixed(1)}%',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < _monthlyData.length) {
                        return Text(_monthlyData[value.toInt()].label,
                            style: const TextStyle(fontSize: 10));
                      }
                      return const Text('');
                    },
                  ),
                ),
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
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _monthlyData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                Color barColor = Colors.green;
                
                if (data.value < 75) {
                  barColor = Colors.red;
                } else if (data.value < 85) {
                  barColor = Colors.orange;
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data.value,
                      color: barColor,
                      width: 16,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(bool isDarkMode) {
    if (_pieData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('No data')),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    final colors = [Colors.green, Colors.red, Colors.orange];
    var index = 0;

    _pieData.forEach((key, value) {
      sections.add(
        PieChartSectionData(
          color: colors[index % colors.length],
          value: value,
          title: '$key\n${value.toInt()}',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      index++;
    });

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLowestStudentsChart(bool isDarkMode) {
    if (_lowestStudents.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('No data')),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: _lowestStudents.map((student) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.studentName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: student.percentage / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            student.percentage >= 75 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${student.percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildClassComparisonChart(bool isDarkMode) {
    if (_classComparison.isEmpty) return const SizedBox();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < _classComparison.length) {
                        return Text(_classComparison[value.toInt()].label,
                            style: const TextStyle(fontSize: 10));
                      }
                      return const Text('');
                    },
                  ),
                ),
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
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _classComparison.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.value,
                      color: Colors.blue,
                      width: 20,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
