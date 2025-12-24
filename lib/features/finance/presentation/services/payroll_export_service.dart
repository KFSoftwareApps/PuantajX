import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../payment_summary_screen.dart'; // For PaymentSummaryItem and PayType

class PayrollExportService {
  
  // --- PDF EXPORT ---
  
  static Future<Uint8List> generatePdf({
    required List<PaymentSummaryItem> items,
    required DateTime startDate,
    required DateTime endDate,
    required String projectName,
    bool watermark = false,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(projectName, style: pw.TextStyle(font: boldFont, fontSize: 24)),
                    pw.Text('Hakediş Özeti', style: pw.TextStyle(font: font, fontSize: 20)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Tarih: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}',
                style: pw.TextStyle(font: font, fontSize: 14),
              ),
              if (watermark)
                 pw.Watermark(
                   child: pw.Text('DEMO / FREE PLAN', style: pw.TextStyle(color: PdfColors.grey300, fontSize: 60, font: boldFont)),
                 ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(font: boldFont),
                cellStyle: pw.TextStyle(font: font),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                headers: ['Çalışan', 'Gün', 'Saat', 'Tutar'],
                data: items.map((item) => [
                      item.workerName,
                      item.daysWorked.toString(),
                      item.hoursWorked.toStringAsFixed(1),
                      '${item.totalAmount.toStringAsFixed(2)} TL',
                    ]).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                   pw.Container(
                     padding: const pw.EdgeInsets.all(8),
                     decoration: pw.BoxDecoration(border: pw.Border.all()),
                     child: pw.Text(
                      'TOPLAM: ${items.fold<double>(0, (sum, item) => sum + item.totalAmount).toStringAsFixed(2)} TL',
                      style: pw.TextStyle(font: boldFont, fontSize: 16),
                    ),
                   )
                ],
              ),
              pw.SizedBox(height: 40),
               pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Teslim Eden', style: pw.TextStyle(font: boldFont)),
                      pw.SizedBox(height: 40),
                      pw.Container(height: 1, width: 120, color: PdfColors.black),
                    ]
                  ),
                   pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Teslim Alan', style: pw.TextStyle(font: boldFont)),
                      pw.SizedBox(height: 40),
                      pw.Container(height: 1, width: 120, color: PdfColors.black),
                    ]
                  )
                ]
              )
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  // --- EXCEL EXPORT ---

  static Future<List<int>> generateExcel({
    required List<PaymentSummaryItem> items,
    required DateTime startDate,
    required DateTime endDate,
    required String projectName,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Hakediş'];
    
    // Delete default sheet if exists
    if(excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
    );
    
    // Title
    sheet.appendRow([TextCellValue('HAKEDİŞ ÖZETİ - $projectName')]);
    sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("D1"));
    sheet.cell(CellIndex.indexByString("A1")).cellStyle = CellStyle(bold: true, fontSize: 16, horizontalAlign: HorizontalAlign.Center);
    
    sheet.appendRow([TextCellValue('Dönem: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}')]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    final headers = ['Çalışan', 'Gün', 'Saat', 'Tutar (TL)'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    
    // Apply Header Style
    for(int i=0; i<headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3)).cellStyle = headerStyle;
    }

    // Data
    double total = 0;
    for (final item in items) {
      total += item.totalAmount;
      sheet.appendRow([
        TextCellValue(item.workerName),
        IntCellValue(item.daysWorked),
        DoubleCellValue(item.hoursWorked),
        DoubleCellValue(item.totalAmount),
      ]);
    }

    sheet.appendRow([TextCellValue('')]);
    
    // Total Row
    final totalRowIdx = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('TOPLAM'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(total),
    ]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRowIdx)).cellStyle = CellStyle(bold: true);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRowIdx)).cellStyle = CellStyle(bold: true);

    return excel.save() ?? [];
  }
}
