import 'package:puantaj_x/core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart'; // For BuildContext
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../features/report/data/models/daily_report_model.dart';
import '../../features/project/data/models/project_model.dart';
import '../utils/file_download_helper.dart'; // Verified Import

// Using local stub instead of share_plus for web compatibility
import '../utils/share_stub.dart' if (dart.library.io) 'package:share_plus/share_plus.dart';

class ExcelExportService {
  static Future<List<int>> generateDailyReportExcel(DailyReport report, Project project) async {
    final excel = Excel.createExcel();
    final sheet = excel['Günlük Rapor'];
    excel.delete('Sheet1'); // Remove default sheet

    // Styles
    final headerStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Arial),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // --- Header Section ---
    sheet.appendRow([TextCellValue('GÜNLÜK ŞANTİYE RAPORU')]);
    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("E1"));
    sheet.cell(CellIndex.indexByString("A1")).cellStyle = headerStyle;

    sheet.appendRow([TextCellValue('Proje:'), TextCellValue(project.name)]);
    sheet.appendRow([TextCellValue('Tarih:'), TextCellValue(DateFormat('dd.MM.yyyy').format(report.date))]);
    sheet.appendRow([TextCellValue('Rapor No:'), IntCellValue(report.id)]);
    sheet.appendRow([TextCellValue('Vardiya:'), TextCellValue(report.shift ?? '-')]);
    sheet.appendRow([TextCellValue('Hava Durumu:'), TextCellValue(report.weather ?? '-')]);
    sheet.appendRow([TextCellValue('')]); 

    // --- Notes ---
    sheet.appendRow([TextCellValue('Genel Açıklama')]);
    sheet.cell(CellIndex.indexByString("A8")).cellStyle = headerStyle;
    sheet.appendRow([TextCellValue(report.generalNote ?? '-')]);
    sheet.appendRow([TextCellValue('')]);

    // --- Detailed Items ---
    sheet.appendRow([
      TextCellValue('Kategori'),
      TextCellValue('Açıklama'),
      TextCellValue('Miktar'),
    ]);
    
    // Header Style for Table
    // The previous row was appended, so it's likely row 0-indexed: 0..7(note)..9(headers)
    // We can rely on automatic appending.
    
    for (var item in report.items) {
      sheet.appendRow([
        TextCellValue(item.category == 'crew' ? 'Personel/Ekip' : 'Malzeme/İş'),
        TextCellValue(item.description ?? ''),
        DoubleCellValue(item.quantity ?? 0),
      ]);
    }

    final bytes = excel.save();
    return bytes ?? [];
  }

  /// Export payment summary to Excel
  static Future<void> exportPaymentSummary(BuildContext context, {
    required String projectName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> summaryData,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Ödeme Özeti'];

    // Header
    sheet.appendRow([
      TextCellValue('Proje: $projectName'),
    ]);
    sheet.appendRow([
      TextCellValue('Dönem: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}'),
    ]);
    sheet.appendRow([TextCellValue('')]); // Empty row

    // Column headers
    sheet.appendRow([
      TextCellValue('Çalışan Adı'),
      TextCellValue('Toplam Saat'),
      TextCellValue('Normal Saat'),
      TextCellValue('Mesai Saati'),
      TextCellValue('Saatlik Ücret'),
      TextCellValue('Toplam Tutar'),
    ]);

    // Data rows
    for (final item in summaryData) {
      sheet.appendRow([
        TextCellValue(item['workerName'] ?? ''),
        DoubleCellValue(((item['totalHours'] as num?)?.toDouble() ?? 0)),
        DoubleCellValue(((item['normalHours'] as num?)?.toDouble() ?? 0)),
        DoubleCellValue(((item['overtimeHours'] as num?)?.toDouble() ?? 0)),
        DoubleCellValue(((item['hourlyRate'] as num?)?.toDouble() ?? 0)),
        DoubleCellValue(((item['totalAmount'] as num?)?.toDouble() ?? 0)),
      ]);
    }

    // Summary row
    final totalAmount = summaryData.fold<double>(
      0,
      (sum, item) => sum + ((item['totalAmount'] as num?)?.toDouble() ?? 0),
    );
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('TOPLAM'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalAmount),
    ]);
    
    // Auto-fit columns (Basic approximation)


    // Save and share
    final fileBytes = excel.save();
    if (fileBytes != null) {
      if (kIsWeb) {
         await FileDownloadHelper.saveAndNotify(context, fileBytes, 'odeme_ozeti_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/odeme_ozeti_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Ödeme Özeti - $projectName',
        );
      }
    }
  }

  /// Export to CSV
  static Future<void> exportToCSV(BuildContext context, {
    required String projectName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> summaryData,
  }) async {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Proje: $projectName');
    buffer.writeln('Dönem: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}');
    buffer.writeln();
    
    // Column headers
    buffer.writeln('Çalışan Adı,Toplam Saat,Normal Saat,Mesai Saati,Saatlik Ücret,Toplam Tutar');
    
    // Data rows
    for (final item in summaryData) {
      buffer.writeln([
        item['workerName'] ?? '',
        item['totalHours'] ?? 0,
        item['normalHours'] ?? 0,
        item['overtimeHours'] ?? 0,
        item['hourlyRate'] ?? 0,
        item['totalAmount'] ?? 0,
      ].join(','));
    }
    
    // Summary
    final totalAmount = summaryData.fold<double>(
      0,
      (sum, item) => sum + ((item['totalAmount'] as num?)?.toDouble() ?? 0),
    );
    buffer.writeln();
    buffer.writeln('TOPLAM,,,,,${totalAmount}');
    
    // Save and share
    final bytes = List<int>.from(buffer.toString().codeUnits);
    if (kIsWeb) {
       await FileDownloadHelper.saveAndNotify(context, bytes, 'odeme_ozeti_${DateTime.now().millisecondsSinceEpoch}.csv');
    } else {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/odeme_ozeti_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      final file = File(filePath);
      await file.writeAsString(buffer.toString());
      
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Ödeme Özeti - $projectName',
      );
    }
  }
}
