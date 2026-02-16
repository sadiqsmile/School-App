import 'student_base.dart';
import 'student_year.dart';

class ParentStudent {
  ParentStudent({
    required this.base,
    required this.year,
  });

  final StudentBase base;
  final StudentYear year;
}
