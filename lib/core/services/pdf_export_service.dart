import 'package:puantaj_x/core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../features/report/data/models/daily_report_model.dart';
import '../../features/project/data/models/project_model.dart';
import '../providers/global_providers.dart';

class PdfExportService {
  Future<Uint8List> generateDailyReportPdf(DailyReport report, Project project, ExportSettings settings) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Pre-load images if needed
    final List<pw.ImageProvider> loadedImages = [];
    if (settings.includePhotos && report.attachments.isNotEmpty) {
      for (var att in report.attachments) {
        if (att.localPath != null) {
          if (!kIsWeb) {
             final file = File(att.localPath!);
             if (await file.exists()) {
                final bytes = await file.readAsBytes();
                loadedImages.add(pw.MemoryImage(bytes));
             }
          } else {
             // Web Logic: localPath is likely a blob URL or we need to fetch it if it's a network URL
             // If sync is active, maybe we have a signedUrl. 
             // For now, skipping local file read on web to prevent crash.
             // TODO: Implement Web Image fetching
          }
        }
      }
    }

    final pageFormat = settings.pdfOrientation == 'landscape' 
        ? PdfPageFormat.a4.landscape 
        : PdfPageFormat.a4;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
             if (settings.includeHeader) ...[
                _buildHeader(project, report),
                pw.SizedBox(height: 20),
             ],
            _buildInfoSection(report),
            pw.SizedBox(height: 20),
            if (settings.detailLevel == 'detailed')
              _buildItemsTable(report.items, settings.includeCosts)
            else
              _buildSummarySection(report.items, settings.includeCosts),
            
            pw.SizedBox(height: 30),
            
            if (settings.includePhotos && loadedImages.isNotEmpty) ...[
               pw.Text('FOTOĞRAFLAR', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
               pw.SizedBox(height: 10),
               _buildPhotosGrid(loadedImages, report.attachments),
               pw.SizedBox(height: 30),
            ],

            _buildFooter(),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<void> shareDailyReportPdf(DailyReport report, Project project, ExportSettings settings) async {
    final bytes = await generateDailyReportPdf(report, project, settings);
    await Printing.sharePdf(bytes: bytes, filename: 'rapor_${report.id}.pdf');
  }

  pw.Widget _buildHeader(Project project, DailyReport report) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('GÜNLÜK ŞANTİYE RAPORU', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text(project.name, style: pw.TextStyle(fontSize: 14)),
            if (project.location != null)
              pw.Text(project.location!, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(DateFormat('dd.MM.yyyy').format(report.date), style: pw.TextStyle(fontSize: 14)),
            pw.Text('Rapor No: #${report.id}', style: pw.TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInfoSection(DailyReport report) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoItem('Hava Durumu', report.weather ?? '-'),
          _buildInfoItem('Çalışma Şekli', report.shift ?? '-'),
          _buildInfoItem('Hazırlayan', report.createdBy ?? 'Admin'),
        ],
      ),
    );
  }

  pw.Widget _buildInfoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildItemsTable(List<ReportItem> items, bool includeCosts) {
    if (items.isEmpty) return pw.Text('Rapor içeriği boş.');

    final headers = ['Kategori', 'Açıklama', 'Miktar', 'Birim'];
    if (includeCosts) {
      headers.addAll(['Birim Fiyat', 'Tutar']);
    }

    return pw.Table.fromTextArray(
      headers: headers,
      data: items.map((item) {
        final row = [
          item.category ?? '-',
          item.description ?? '-',
          item.quantity?.toStringAsFixed(2) ?? '-',
          item.unit ?? '-',
        ];
        if (includeCosts) {
           row.addAll(['-', '-']); 
        }
        return row;
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        if (includeCosts) 4: pw.Alignment.centerRight,
        if (includeCosts) 5: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildSummarySection(List<ReportItem> items, bool includeCosts) {
    final Map<String, int> categoryCounts = {};
    for (var item in items) {
       final cat = item.category ?? 'Diğer';
       categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
           pw.Text('ÖZET RAPOR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
           pw.SizedBox(height: 10),
           ...categoryCounts.entries.map((e) => pw.Row(
             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
             children: [
               pw.Text(e.key),
               pw.Text('${e.value} Kalem'),
             ]
           )).toList(),
           pw.Divider(),
           pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
             pw.Text('Toplam Kalem Sayısı:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
             pw.Text('${items.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
           ]),
        ],
      )
    );
  }

  pw.Widget _buildPhotosGrid(List<pw.ImageProvider> images, List<Attachment> attachments) {
    if (images.isEmpty) return pw.Container();
    
    return pw.GridView(
      crossAxisCount: 2,
      childAspectRatio: 1.3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: List.generate(images.length, (index) {
         final image = images[index];
         final label = index < attachments.length ? (attachments[index].category ?? '-') : '-';

         return pw.Container(
           decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
           child: pw.Column(
             mainAxisAlignment: pw.MainAxisAlignment.center,
             children: [
               pw.Expanded(child: pw.Image(image, fit: pw.BoxFit.contain)),
               pw.Padding(
                 padding: pw.EdgeInsets.all(4),
                 child: pw.Text(label, style: pw.TextStyle(fontSize: 10)),
               ),
             ]
           ),
         );
      }),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('PuantajX ile oluşturuldu', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
        pw.Column(
          children: [
            pw.Container(height: 40, width: 100, decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
            pw.Text('Onay / İmza', style: pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
