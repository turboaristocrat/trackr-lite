import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/block_entry.dart';
import '../models/movement_entry.dart';
import '../models/shift_log.dart';
import 'web_launcher_stub.dart'
    if (dart.library.js_interop) 'web_launcher_web.dart';

class MovementService {
  /// Converts "09:16" or "9:16" to "09.16" (railway dot time notation).
  /// If empty or already containing blank placeholder, returns "_____".
  static String formatTimeDot(String time) {
    final trimmed = time.trim();
    if (trimmed.isEmpty || trimmed.contains('_')) {
      return '_____';
    }
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      final hh = parts[0].padLeft(2, '0');
      final mm = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
      return '$hh.$mm';
    }
    if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      final hh = parts[0].padLeft(2, '0');
      final mm = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
      return '$hh.$mm';
    }
    return trimmed;
  }

  /// Formats DateTime to "01.10.26"
  static String formatDateDot(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    return '$dd.$mm.$yy';
  }

  /// Formats dual night date e.g. "06/07.10.26"
  static String formatDualDateDot(DateTime d1, DateTime d2) {
    final dd1 = d1.day.toString().padLeft(2, '0');
    final dd2 = d2.day.toString().padLeft(2, '0');
    final mm = d1.month.toString().padLeft(2, '0');
    final yy = (d1.year % 100).toString().padLeft(2, '0');
    if (d1.month == d2.month) {
      return '$dd1/$dd2.$mm.$yy';
    } else {
      final mm2 = d2.month.toString().padLeft(2, '0');
      return '$dd1.$mm/$dd2.$mm2.$yy';
    }
  }

  /// Checks if departure -> arrival crosses midnight
  static bool isOvernightTime(String dep, String arr) {
    final d = dep.replaceAll('.', ':').trim();
    final a = arr.replaceAll('.', ':').trim();
    if (d.contains(':') && a.contains(':')) {
      final depHour = int.tryParse(d.split(':')[0]) ?? 0;
      final arrHour = int.tryParse(a.split(':')[0]) ?? 0;
      final depMin = int.tryParse(d.split(':')[1]) ?? 0;
      final arrMin = int.tryParse(a.split(':')[1]) ?? 0;
      if (depHour > arrHour) return true;
      if (depHour == arrHour && depMin > arrMin) return true;
    }
    return false;
  }

  /// Compares two time strings ("HH:mm" or "HH.mm") within a day context or shift context.
  /// Returns negative if t1 < t2, positive if t1 > t2, 0 if equal.
  static int compareShiftTimes(String t1, String t2, {bool isNightShift = false}) {
    final c1 = t1.replaceAll('.', ':').trim();
    final c2 = t2.replaceAll('.', ':').trim();
    if (!c1.contains(':') || !c2.contains(':')) return 0;
    final h1 = int.tryParse(c1.split(':')[0]) ?? 0;
    final m1 = int.tryParse(c1.split(':')[1]) ?? 0;
    final h2 = int.tryParse(c2.split(':')[0]) ?? 0;
    final m2 = int.tryParse(c2.split(':')[1]) ?? 0;

    int totalMins1 = h1 * 60 + m1;
    int totalMins2 = h2 * 60 + m2;

    if (isNightShift) {
      // For night shifts starting in afternoon/evening and ending next morning,
      // map morning hours (< 12:00) to next day (+ 24*60 mins)
      if (h1 < 12) totalMins1 += 24 * 60;
      if (h2 < 12) totalMins2 += 24 * 60;
    }

    return totalMins1.compareTo(totalMins2);
  }

  /// Checks whether a block entry represents movement between two different stations,
  /// rather than work within the same station or yard.
  static bool isInterStationMovement(BlockEntry b) {
    final from = b.stationFrom.trim().toUpperCase();
    final to = b.stationTo.trim().toUpperCase();
    if (from.isEmpty) return false;
    if (to.isEmpty || to == '_____') return false;
    if (b.line.trim().toUpperCase() == 'YARD' || to.startsWith('ROAD')) return false;
    return from != to;
  }

  /// Compiles day-by-day items for an entire month from shifts and overrides
  static List<MovementDayItem> generateMonthDays({
    required int year,
    required int month,
    required List<ShiftLog> historyShifts,
    ShiftLog? activeShift,
    Map<String, MovementDayItem> overrides = const {},
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final List<MovementDayItem> result = [];

    // Combine history and active shift for lookup
    final allShifts = List<ShiftLog>.from(historyShifts);
    if (activeShift != null) {
      final idx = allShifts.indexWhere((s) => s.date == activeShift.date && s.isNightShift == activeShift.isNightShift);
      if (idx != -1) {
        allShifts[idx] = activeShift;
      } else {
        allShifts.add(activeShift);
      }
    }

    String lastKnownStabled = '';
    // Look up last known stabled station from previous month if possible
    final priorShifts = allShifts.where((s) {
      try {
        final d = DateTime.parse(s.date);
        return d.isBefore(DateTime(year, month, 1));
      } catch (_) {
        return false;
      }
    }).toList();
    if (priorShifts.isNotEmpty) {
      priorShifts.sort((a, b) => b.date.compareTo(a.date));
      for (final s in priorShifts) {
        if (s.stabledStation.trim().isNotEmpty) {
          lastKnownStabled = s.stabledStation.trim().toUpperCase();
          break;
        }
      }
    }

    // Temporary storage for overnight or carryover runs carried into the next day
    final List<MovementRun> pendingNextDayRuns = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final currentDt = DateTime(year, month, day);
      final dateKey = DateFormat('yyyy-MM-dd').format(currentDt);

      // 1. Check for manual override first
      if (overrides.containsKey(dateKey)) {
        final override = overrides[dateKey]!;
        result.add(override);
        if (override.type == MovementItemType.stay && override.stayStation.isNotEmpty) {
          lastKnownStabled = override.stayStation.toUpperCase();
        } else if (override.type == MovementItemType.transit && override.runs.isNotEmpty) {
          final lastRun = override.runs.last;
          if (lastRun.toStation.isNotEmpty && !lastRun.toStation.contains('_')) {
            lastKnownStabled = lastRun.toStation.toUpperCase();
          }
        }
        pendingNextDayRuns.clear();
        continue;
      }

      // 2. Check for shifts on this day
      final dayShifts = allShifts.where((s) => s.date == dateKey).toList();

      // Collect any incoming runs carried from yesterday
      final List<MovementRun> dayRuns = [];
      if (pendingNextDayRuns.isNotEmpty) {
        dayRuns.addAll(pendingNextDayRuns);
        for (final p in pendingNextDayRuns) {
          if (p.toStation.isNotEmpty && !p.toStation.contains('_')) {
            lastKnownStabled = p.toStation.toUpperCase();
          }
        }
        pendingNextDayRuns.clear();
      }

      if (dayShifts.isNotEmpty) {
        // Collect movement runs from all shifts on this day
        for (final shift in dayShifts) {
          if (shift.stabledStation.trim().isNotEmpty) {
            lastKnownStabled = shift.stabledStation.trim().toUpperCase();
          }

          // 1. Identify inter-station movements
          final transits = shift.blocks.where((b) => b.isTransit).toList();
          final explicitInterStation = transits.where(isInterStationMovement).toList();
          final blockInterStation = shift.blocks.where(isInterStationMovement).toList();

          final interStationRuns = explicitInterStation.isNotEmpty
              ? explicitInterStation
              : blockInterStation;

          if (interStationRuns.isEmpty) {
            // Machine worked inside yard or remained stationary throughout this shift
            final stayAt = shift.stabledStation.trim().isNotEmpty
                ? shift.stabledStation.trim().toUpperCase()
                : (shift.readyStation.trim().isNotEmpty
                    ? shift.readyStation.trim().toUpperCase()
                    : (shift.blocks.isNotEmpty ? shift.blocks.first.stationFrom.trim().toUpperCase() : lastKnownStabled));
            if (stayAt.isNotEmpty) lastKnownStabled = stayAt;
            continue;
          }

          // 2. Inter-station movement exists: departure station and start time
          final firstMove = interStationRuns.first;
          final fromStation = firstMove.stationFrom.trim().toUpperCase();
          final depTime = firstMove.startTime.trim();

          // 3. Determine arrival station and arrival time
          String toStation;
          String arrTime;

          if (shift.stabledTime.trim().isNotEmpty) {
            // If machine stable has a time logged with it then that is the movement end for that day
            arrTime = shift.stabledTime.trim();
            toStation = shift.stabledStation.trim().isNotEmpty
                ? shift.stabledStation.trim().toUpperCase()
                : interStationRuns.last.stationTo.trim().toUpperCase();
          } else {
            // Or else it should be the last block end station and time
            final lastBlock = shift.blocks.isNotEmpty ? shift.blocks.last : interStationRuns.last;
            final isYard = lastBlock.line.trim().toUpperCase() == 'YARD' || lastBlock.stationTo.toUpperCase().startsWith('ROAD');
            toStation = isYard
                ? (lastBlock.stationFrom.trim().isNotEmpty
                    ? lastBlock.stationFrom.trim().toUpperCase()
                    : (shift.stabledStation.trim().isNotEmpty ? shift.stabledStation.trim().toUpperCase() : '_____'))
                : (lastBlock.stationTo.trim().isNotEmpty
                    ? lastBlock.stationTo.trim().toUpperCase()
                    : (shift.stabledStation.trim().isNotEmpty ? shift.stabledStation.trim().toUpperCase() : '_____'));
            arrTime = lastBlock.endTime.trim().isNotEmpty
                ? lastBlock.endTime.trim()
                : interStationRuns.last.endTime.trim();
          }

          if ((toStation.isEmpty || toStation == '_____') && shift.stabledStation.trim().isNotEmpty) {
            toStation = shift.stabledStation.trim().toUpperCase();
          }

          // 4. Handle Night Shift vs Day Shift
          final depHour = int.tryParse(depTime.replaceAll('.', ':').split(':')[0]) ?? 0;
          final isNight = shift.isNightShift || isOvernightTime(depTime, arrTime);

          if (isNight) {
            if (depHour >= 12) {
              // Movement started BEFORE 12:00 AM on Day 1 (e.g. 20:21)
              // Day 1 (Night Departure): AFK - _____ (20.21 - _____ hrs)
              dayRuns.add(MovementRun(
                fromStation: fromStation,
                toStation: '_____',
                departureTime: depTime,
                arrivalTime: '_____',
                isOvernight: true,
                isDepartureLeg: true,
              ));

              // Day 2 (Morning Arrival): _____ - WKI (_____ - 07.14 hrs)
              pendingNextDayRuns.add(MovementRun(
                fromStation: '_____',
                toStation: toStation,
                departureTime: '_____',
                arrivalTime: arrTime,
                isOvernight: true,
                isArrivalLeg: true,
              ));
            } else {
              // Machine got ready before 12:00 AM, but did NOT start moving until AFTER 12:00 AM
              // Day 1 gets no departure leg (records Stay at station if dayRuns is empty).
              // Day 2 carries the full single-day movement run
              pendingNextDayRuns.add(MovementRun(
                fromStation: fromStation,
                toStation: toStation,
                departureTime: depTime,
                arrivalTime: arrTime,
                isOvernight: false,
              ));
              if (toStation.isNotEmpty && toStation != '_____') {
                lastKnownStabled = toStation;
              }
            }
          } else {
            // Daytime Shift (Same day): KTYM - CGY (09.16 - 16.36 hrs)
            dayRuns.add(MovementRun(
              fromStation: fromStation,
              toStation: toStation,
              departureTime: depTime,
              arrivalTime: arrTime,
              isOvernight: false,
            ));
            if (toStation.isNotEmpty && toStation != '_____') {
              lastKnownStabled = toStation;
            }
          }
        }

        if (dayRuns.isNotEmpty) {
          result.add(MovementDayItem(
            date: dateKey,
            type: MovementItemType.transit,
            runs: dayRuns,
          ));
        } else {
          // No movement runs on this day (e.g. machine worked only inside yard): mark Stay at station
          final stayAt = dayShifts.first.stabledStation.trim().isNotEmpty
              ? dayShifts.first.stabledStation.trim().toUpperCase()
              : (dayShifts.first.readyStation.trim().isNotEmpty
                  ? dayShifts.first.readyStation.trim().toUpperCase()
                  : (dayShifts.first.blocks.isNotEmpty ? dayShifts.first.blocks.first.stationFrom.trim().toUpperCase() : lastKnownStabled));
          if (stayAt.isNotEmpty) lastKnownStabled = stayAt;
          result.add(MovementDayItem(
            date: dateKey,
            type: MovementItemType.stay,
            stayStation: stayAt,
          ));
        }
      } else {
        // No shift logged for this day
        if (dayRuns.isNotEmpty) {
          result.add(MovementDayItem(
            date: dateKey,
            type: MovementItemType.transit,
            runs: dayRuns,
          ));
        } else {
          // Do not prefill future dates with anything
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final isFuture = currentDt.isAfter(today);

          result.add(MovementDayItem(
            date: dateKey,
            type: MovementItemType.stay,
            stayStation: isFuture ? '' : lastKnownStabled,
          ));
        }
      }
    }

    return result;
  }

  /// Builds the complete formatted text string matching Image 2
  /// Builds the complete formatted text string matching Image 2
  static String formatMovementReport({
    int? year,
    int? month,
    List<MovementDayItem>? items,
    DateTime? selectedMonth,
    List<MovementDayItem>? monthDays,
    String? machineName,
    String? division,
    MovementFormatStyle style = MovementFormatStyle.register,
  }) {
    final effectiveYear = year ?? selectedMonth?.year ?? DateTime.now().year;
    final effectiveMonth = month ?? selectedMonth?.month ?? DateTime.now().month;
    final effectiveItems = items ?? monthDays ?? const [];
    final monthDate = DateTime(effectiveYear, effectiveMonth, 1);
    final monthName = DateFormat('MMMM yyyy').format(monthDate).toUpperCase();
    final buffer = StringBuffer();

    // Header exactly as handwritten
    buffer.writeln('* MACHINE MOVEMENT – $monthName *');
    buffer.writeln();

    for (int i = 0; i < effectiveItems.length; i++) {
      final item = effectiveItems[i];
      DateTime dt;
      try {
        dt = DateTime.parse(item.date);
      } catch (_) {
        dt = DateTime(effectiveYear, effectiveMonth, i + 1);
      }
      final dateDot = formatDateDot(dt);

      if (item.type == MovementItemType.custom) {
        buffer.writeln('$dateDot :- ${item.customText.trim()}');
        continue;
      }

      if (item.type == MovementItemType.stay) {
        final station = item.stayStation.trim().toUpperCase();
        if (station.isNotEmpty) {
          buffer.writeln('$dateDot :- Stay at $station');
        }
        continue;
      }

      // Transit items
      if (item.runs.isEmpty) {
        final station = item.stayStation.trim().toUpperCase();
        if (station.isNotEmpty) {
          buffer.writeln('$dateDot :- Stay at $station');
        }
        continue;
      }

      if (style == MovementFormatStyle.dualDate) {
        // Dual date style: combine overnight runs into single continuous line
        for (final run in item.runs) {
          if (run.isArrivalLeg) {
            // Already reported or stand-alone morning leg
            final to = run.toStation.trim().isEmpty ? '_____' : run.toStation.trim().toUpperCase();
            final arr = formatTimeDot(run.arrivalTime);
            buffer.writeln('$dateDot :- _____ – $to (_____ – $arr hrs)');
          } else if (run.isDepartureLeg) {
            final from = run.fromStation.trim().isEmpty ? '_____' : run.fromStation.trim().toUpperCase();
            final to = run.toStation.trim().isEmpty ? '_____' : run.toStation.trim().toUpperCase();
            final dep = formatTimeDot(run.departureTime);
            final nextDay = dt.add(const Duration(days: 1));
            final dualDate = formatDualDateDot(dt, nextDay);
            // Look ahead for next day arrival time if available
            String arr = '_____';
            if (i + 1 < effectiveItems.length && effectiveItems[i + 1].runs.isNotEmpty) {
              final nextArrival = effectiveItems[i + 1].runs.firstWhere(
                (r) => r.isArrivalLeg,
                orElse: () => const MovementRun(fromStation: '', toStation: '', departureTime: '', arrivalTime: ''),
              );
              if (nextArrival.arrivalTime.isNotEmpty) {
                arr = formatTimeDot(nextArrival.arrivalTime);
              }
            }
            buffer.writeln('$dualDate :- $from – $to ($dep – $arr hrs)');
          } else {
            // Standard single day transit
            final from = run.fromStation.trim().isEmpty ? '_____' : run.fromStation.trim().toUpperCase();
            final to = run.toStation.trim().isEmpty ? '_____' : run.toStation.trim().toUpperCase();
            final dep = formatTimeDot(run.departureTime);
            final arr = formatTimeDot(run.arrivalTime);
            buffer.writeln('$dateDot :- $from – $to ($dep – $arr hrs)');
          }
        }
      } else {
        // Register style (Image 2 exact replica)
        if (item.runs.length == 1) {
          final run = item.runs.first;
          final from = run.fromStation.trim().isEmpty ? '_____' : run.fromStation.trim().toUpperCase();
          final to = run.toStation.trim().isEmpty ? '_____' : run.toStation.trim().toUpperCase();
          final dep = formatTimeDot(run.departureTime);
          final arr = formatTimeDot(run.arrivalTime);

          if (run.isDepartureLeg) {
            buffer.writeln('$dateDot :- $from – _____ ($dep – _____ hrs)');
          } else if (run.isArrivalLeg) {
            buffer.writeln('$dateDot :- _____ – $to (_____ – $arr hrs)');
          } else {
            buffer.writeln('$dateDot :- $from – $to ($dep – $arr hrs)');
          }
        } else {
          // Multiple runs on same date: group with curly bracket { as in handwritten note
          for (int rIdx = 0; rIdx < item.runs.length; rIdx++) {
            final run = item.runs[rIdx];
            final from = run.fromStation.trim().isEmpty ? '_____' : run.fromStation.trim().toUpperCase();
            final to = run.toStation.trim().isEmpty ? '_____' : run.toStation.trim().toUpperCase();
            final dep = formatTimeDot(run.departureTime);
            final arr = formatTimeDot(run.arrivalTime);

            String runStr;
            if (run.isDepartureLeg) {
              runStr = '$from – _____ ($dep – _____ hrs)';
            } else if (run.isArrivalLeg) {
              runStr = '_____ – $to (_____ – $arr hrs)';
            } else {
              runStr = '$from – $to ($dep – $arr hrs)';
            }

            if (rIdx == 0) {
              buffer.writeln('$dateDot :- $runStr');
            } else {
              buffer.writeln('            $runStr');
            }
          }
        }
      }
    }

    return buffer.toString().trim();
  }

  // --- Sharing Helpers ---
  static Future<void> copyToClipboard(String reportText) async {
    await Clipboard.setData(ClipboardData(text: reportText));
  }

  static Future<void> shareToTelegram(String reportText, String title) async {
    try {
      await Clipboard.setData(ClipboardData(text: reportText));
    } catch (_) {}

    if (kIsWeb && canWebShare()) {
      try {
        final shared = await triggerWebShare(title, reportText);
        if (shared) return;
      } catch (_) {}
    }

    final encoded = Uri.encodeComponent(reportText);
    final tgDirectUri = 'tg://msg_url?url=&text=$encoded';
    final tgWebUri = 'https://t.me/share/url?url=&text=$encoded';

    if (kIsWeb) {
      try {
        openExternalUriDirect(tgDirectUri);
        return;
      } catch (_) {}
    }

    try {
      final ok = await launchUrl(Uri.parse(tgWebUri), mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}

    try {
      // ignore: deprecated_member_use
      await Share.share(reportText, subject: title);
    } catch (_) {}
  }

  static Future<void> shareToWhatsApp(String reportText) async {
    try {
      await Clipboard.setData(ClipboardData(text: reportText));
    } catch (_) {}

    final encoded = Uri.encodeComponent(reportText);
    final waUri = 'https://api.whatsapp.com/send?text=$encoded';
    try {
      await launchUrl(Uri.parse(waUri), mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore: deprecated_member_use
      await Share.share(reportText);
    }
  }
}
