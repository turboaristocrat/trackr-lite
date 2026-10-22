import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shift_log.dart';

import 'web_launcher_stub.dart'
    if (dart.library.js_interop) 'web_launcher_web.dart';

class ReportService {
  static String formatYardLocation(String stationFrom, String stationTo) {
    String stn = stationFrom.trim().toUpperCase();
    stn = stn.replaceAll(RegExp(r'\s+(YARD|YD)$', caseSensitive: false), '').trim();

    String to = stationTo.trim();
    final roadMatch = RegExp(r'^(?:Road|Rd)\s*([1-7])', caseSensitive: false).firstMatch(to);
    if (roadMatch != null) {
      to = 'Rd ${roadMatch.group(1)}';
    } else if (to.toUpperCase().contains('DN M/L') || to.toUpperCase() == 'DN') {
      to = 'DN M/L';
    } else if (to.toUpperCase().contains('UP M/L') || to.toUpperCase() == 'UP') {
      to = 'UP M/L';
    }

    return '$stn Yd $to';
  }

  static String formatReport(ShiftLog log) {
    final formattedDate = log.formattedDate;

    final machineTitle = log.machineName.replaceAll(' ', '').trim();

    final buffer = StringBuffer();
    buffer.writeln('Progress of $machineTitle on $formattedDate');
    buffer.writeln('Division: ${log.division}');
    buffer.writeln('Section: ${log.section}');
    buffer.writeln();

    if (log.readyStation.isNotEmpty && log.readyTime.isNotEmpty) {
      buffer.writeln('Machine ready at ${log.readyStation} – ${log.readyTime} hrs.');
      buffer.writeln();
    }

    int blockIndex = 1;
    for (final b in log.blocks) {
      if (b.isTransit) {
        buffer.writeln('${b.stationFrom} – ${b.stationTo} : ${b.startTime} – ${b.endTime} hrs');
        if (b.output > 0) {
          buffer.writeln('Run: ${b.output} Km');
        }
        if (b.remarks.trim().isNotEmpty) {
          buffer.writeln('Remarks: ${b.remarks.trim()}');
        }
      } else {
        buffer.writeln('Block – $blockIndex');
        buffer.writeln('BT: ${b.startTime} – ${b.endTime} hrs');
        if (b.line == 'Yard') {
          buffer.writeln(formatYardLocation(b.stationFrom, b.stationTo));
        } else {
          buffer.writeln('${b.stationFrom} – ${b.stationTo} (${b.line})');
        }

        if (b.items.isNotEmpty) {
          for (final item in b.items) {
            final outputStr = item.output.truncateToDouble() == item.output
                ? item.output.toInt().toString()
                : item.output.toString();
            buffer.writeln('${item.activity}: $outputStr ${item.outputUnit}');
          }
        } else if (b.output > 0 || b.activity.isNotEmpty) {
          final outputStr = b.output.truncateToDouble() == b.output
              ? b.output.toInt().toString()
              : b.output.toString();
          buffer.writeln('${b.activity}: $outputStr ${b.outputUnit}');
        }

        if (b.remarks.trim().isNotEmpty) {
          buffer.writeln('Remarks: ${b.remarks.trim()}');
        }
        blockIndex++;
      }
      buffer.writeln();
    }

    // Totals section
    final activityTotals = log.outputByActivity;
    if (activityTotals.isNotEmpty) {
      buffer.writeln('Total:');
      double grandTotal = 0;
      activityTotals.forEach((activity, totalVal) {
        grandTotal += totalVal;
        final totalStr = totalVal.truncateToDouble() == totalVal
            ? totalVal.toInt().toString()
            : totalVal.toString();
        buffer.writeln('$activity: $totalStr Nos');
      });

      final grandTotalStr = grandTotal.truncateToDouble() == grandTotal
          ? grandTotal.toInt().toString()
          : grandTotal.toString();
      buffer.writeln('= $grandTotalStr nos');
      buffer.writeln();
    }

    // Stabled line
    if (log.stabledStation.isNotEmpty) {
      if (log.stabledTime.isNotEmpty) {
        buffer.writeln('Machine stabled at ${log.stabledStation} – ${log.stabledTime} hrs.');
      } else {
        buffer.writeln('Machine stabled at ${log.stabledStation}.');
      }
    }

    // Remarks line (after machine stabled)
    if (log.remarks.trim().isNotEmpty) {
      if (log.stabledStation.isNotEmpty) {
        buffer.writeln();
      }
      buffer.writeln('Remarks: ${log.remarks.trim()}');
    }

    return buffer.toString().trim();
  }

  // --- Telegram Primary Sharing ---
  static Future<void> shareToTelegram(ShiftLog log) async {
    final text = formatReport(log);

    // Safeguard: Always copy formatted report to clipboard first so user can also paste anytime
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}

    final subject = 'Progress of ${log.machineName} on ${log.formattedDate}';

    // 1. On Web: Use native navigator.share if available.
    // This allows the user to select Telegram from the OS share list,
    // and passes the complete text message cleanly into Telegram's composer!
    if (kIsWeb && canWebShare()) {
      try {
        final shared = await triggerWebShare(subject, text);
        if (shared) return;
      } catch (_) {}
    }

    final encoded = Uri.encodeComponent(text);
    final tgDirectAppUri = 'tg://msg_url?url=&text=$encoded';
    final tgUniversalHttps = 'https://t.me/share/url?url=&text=$encoded';

    // 2. Direct deep-link via url_launcher or browser navigation
    if (kIsWeb) {
      try {
        openExternalUriDirect(tgDirectAppUri);
        return;
      } catch (_) {}
    }

    // 3. Try launching via url_launcher
    try {
      final launched = await launchUrl(
        Uri.parse(tgUniversalHttps),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (launched) return;
    } catch (_) {}

    // 4. Fallback to package:share_plus
    try {
      // ignore: deprecated_member_use
      await Share.share(text, subject: subject);
    } catch (_) {}
  }

  // --- WhatsApp Secondary Sharing ---
  static Future<void> shareToWhatsApp(ShiftLog log) async {
    final text = formatReport(log);

    // Safeguard: Always copy formatted report to clipboard
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}

    final encoded = Uri.encodeComponent(text);
    final whatsappUrl = Uri.parse('https://wa.me/?text=$encoded');

    try {
      final launched = await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (launched) return;
    } catch (_) {}

    // Fallback to standard system share
    try {
      // ignore: deprecated_member_use
      await Share.share(text, subject: 'Progress of ${log.machineName} on ${log.formattedDate}');
    } catch (_) {}
  }

  // --- Copy to Clipboard ---
  static Future<void> copyToClipboard(ShiftLog log) async {
    final text = formatReport(log);
    await Clipboard.setData(ClipboardData(text: text));
  }
}
