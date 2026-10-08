import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shift_log.dart';

class WhatsAppService {
  static String formatReport(ShiftLog log) {
    String formattedDate;
    try {
      final parsed = DateTime.parse(log.date);
      formattedDate = DateFormat('dd-MM-yyyy').format(parsed);
    } catch (_) {
      formattedDate = log.date;
    }

    final buffer = StringBuffer();
    buffer.writeln('*TRACKR LITE SHIFT REPORT*');
    buffer.writeln('--------------------------------');
    buffer.writeln('📅 *Date:* $formattedDate');
    buffer.writeln('🚜 *Machine:* ${log.machineType} ${log.machineNo}');
    buffer.writeln('📍 *Div / Sec:* ${log.division} / ${log.section}');
    if (log.stabledStation.isNotEmpty) {
      buffer.writeln('🏠 *Stabled At:* ${log.stabledStation}');
    }
    buffer.writeln('--------------------------------');

    if (log.blocks.isEmpty) {
      buffer.writeln('No blocks recorded for this shift.');
    } else {
      buffer.writeln('*LOGGED ENTRIES:*');
      int blockIdx = 1;
      for (final b in log.blocks) {
        if (b.isTransit) {
          buffer.writeln('$blockIdx️⃣ *[TRANSIT]* ${b.startTime} - ${b.endTime}');
          buffer.writeln('   • *Route:* ${b.stationFrom} ➔ ${b.stationTo}');
          buffer.writeln('   • *Run:* ${b.output} Km');
        } else {
          buffer.writeln('$blockIdx️⃣ *[BLOCK]* ${b.startTime} - ${b.endTime}');
          buffer.writeln('   • *Section:* ${b.stationFrom} - ${b.stationTo} (${b.line} Line)');
          buffer.writeln('   • *Output:* ${b.output.toStringAsFixed(b.output.truncateToDouble() == b.output ? 0 : 2)} ${b.outputUnit}');
        }
        if (b.remarks.trim().isNotEmpty) {
          buffer.writeln('   • *Remarks:* ${b.remarks.trim()}');
        }
        buffer.writeln();
        blockIdx++;
      }
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('📊 *SUMMARY:*');
    buffer.writeln('• *Total Blocks:* ${log.blockCount}');
    if (log.totalBlockOutput > 0) {
      buffer.writeln('• *Total Block Output:* ${log.totalBlockOutput.toStringAsFixed(log.totalBlockOutput.truncateToDouble() == log.totalBlockOutput ? 0 : 2)}');
    }
    if (log.totalTransitKm > 0) {
      buffer.writeln('• *Total Transit Run:* ${log.totalTransitKm} Km');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('_Generated via TRACKR Lite_');

    return buffer.toString();
  }

  static Future<void> shareToWhatsApp(ShiftLog log) async {
    final text = formatReport(log);
    final encoded = Uri.encodeComponent(text);
    final whatsappUrl = Uri.parse('https://wa.me/?text=$encoded');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback to standard system share sheet
    // ignore: deprecated_member_use
    await Share.share(text, subject: 'TRACKR Shift Report ${log.date}');
  }

  static Future<void> copyToClipboard(ShiftLog log) async {
    final text = formatReport(log);
    await Clipboard.setData(ClipboardData(text: text));
  }
}
