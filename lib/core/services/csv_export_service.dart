import 'package:flutter/material.dart';
import 'package:puantaj_x/core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/attendance/data/models/attendance_model.dart';
import 'package:intl/intl.dart';
import '../utils/file_download_helper.dart'; // Verified Import

// Using local stub instead of share_plus for web compatibility
import '../utils/share_stub.dart' if (dart.library.io) 'package:share_plus/share_plus.dart';

class CsvExportService {
  Future<void> exportAttendanceToCsv(BuildContext context, List<Attendance> list, String projectName) async {
    final buffer = StringBuffer();
    // Header
    buffer.writeln('Tarih,IsciID,Durum,Saat,Mesai,Not');

    // Rows
    for (final item in list) {
      final date = DateFormat('yyyy-MM-dd').format(item.date);
      buffer.writeln('$date,${item.workerId},${item.status.name},${item.hours},${item.overtimeHours},${item.note ?? ""}');
    }

    final csvString = buffer.toString();
    
    // Save to temp file or download directly
    if (kIsWeb) {
      // Web Download
      await FileDownloadHelper.saveAndNotify(context, csvString.codeUnits, 'puantaj_export.csv'); 
    } else {
       // Mobile Logic
       final directory = await getTemporaryDirectory();
       final path = '${directory.path}/puantaj_${DateTime.now().millisecondsSinceEpoch}.csv';
       final file = File(path);
       await file.writeAsString(csvString);
       
       // Share
       await Share.shareXFiles([XFile(path)], text: '$projectName - Puantaj CSV');
    }
  }
}
