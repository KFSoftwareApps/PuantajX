import '../../features/project/data/models/worker_model.dart';
import '../../features/attendance/data/models/attendance_model.dart';
import '../../features/project/data/models/project_model.dart';
import '../types/app_types.dart';

class CostCalculator {
  /// Calculates the total cost for a specific attendance entry.
  static double calculateDailyCost({
    required Worker worker,
    required Attendance attendance,
    required Project project,
  }) {
    // 1. Determine Status Rules
    if (attendance.status == AttendanceStatus.absent ||
        attendance.status == AttendanceStatus.unpaidLeave) {
      return 0.0;
    }

    // 2. Determine Base Hourly Rate
    double hourlyRate = 0.0;

    if (worker.payType == PayType.monthly) {
      // Monthly Salary Calculation
      // Rate = Salary / (Days * Hours)
      final salary = worker.monthlySalary ?? 0;
      final days = project.monthlyWorkDays > 0 ? project.monthlyWorkDays : 26;
      final hours = project.hoursPerDay > 0 ? project.hoursPerDay : 8.0;
      hourlyRate = salary / (days * hours);
    } else if (worker.payType == PayType.daily) {
      // Daily Rate Calculation
      final daily = worker.dailyRate ?? 0;
      final hours = project.hoursPerDay > 0 ? project.hoursPerDay : 8.0;
      hourlyRate = daily / hours;
    } else {
      // Hourly Rate
      hourlyRate = worker.hourlyRate ?? 0;
    }

    // 3. Determine Day Multiplier
    double dayMultiplier = 1.0;
    switch (attendance.dayType) {
      case DayType.weekend:
        dayMultiplier = project.weekendMultiplier;
        break;
      case DayType.holiday:
        dayMultiplier = project.holidayMultiplier;
        break;
      case DayType.normal:
      default:
        dayMultiplier = 1.0;
        break;
    }

    // 4. Calculate Normal Hours Cost
    // If paid leave, we treat it as working normal hours (usually)
    // or we use the hours recorded in attendance.
    // For now, let's use the hours recorded. 
    // If it's a full day leave, system should record normal hours (e.g. 8).
    double normalCost = attendance.hours * hourlyRate * dayMultiplier;

    // 5. Calculate Overtime Cost (if any)
    double overtimeCost =
        attendance.overtimeHours * hourlyRate * project.overtimeMultiplier;

    return normalCost + overtimeCost;
  }
}
