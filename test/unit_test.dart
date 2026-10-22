import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackr_lite/models/block_entry.dart';
import 'package:trackr_lite/models/movement_entry.dart';
import 'package:trackr_lite/models/shift_log.dart';
import 'package:trackr_lite/services/movement_service.dart';
import 'package:trackr_lite/services/report_service.dart';
import 'package:trackr_lite/services/station_service.dart';
import 'package:trackr_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StationService', () {
    test('Station search finds matches by code and name', () {
      final results = StationService.search('HAD');
      expect(results.any((s) => s.code == 'HAD'), isTrue);
      expect(results.first.name, contains('Harippad'));
    });
  });

  group('ReportService', () {
    test('Matches official Southern Railway UTV format exactly', () {
      const log = ShiftLog(
        date: '2026-09-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        readyStation: 'CGY',
        readyTime: '09:25',
        stabledStation: 'KTYM',
        blocks: [
          BlockEntry(
            id: 'b1',
            startTime: '10:35',
            endTime: '11:20',
            stationFrom: 'CGY',
            stationTo: 'CGV',
            line: 'UP',
            items: [
              WorkItem(activity: 'Sleepers unloaded', output: 16, outputUnit: 'Nos'),
            ],
          ),
          BlockEntry(
            id: 'b2',
            startTime: '12:05',
            endTime: '13:30',
            stationFrom: 'CGY',
            stationTo: 'TRVL',
            line: 'DN',
            items: [
              WorkItem(activity: 'Sleepers loaded', output: 64, outputUnit: 'Nos'),
            ],
          ),
          BlockEntry(
            id: 'b3',
            startTime: '14:55',
            endTime: '15:50',
            stationFrom: 'CGY',
            stationTo: 'CGV',
            line: 'UP',
            items: [
              WorkItem(activity: 'Sleepers unloaded', output: 24, outputUnit: 'Nos'),
            ],
          ),
          BlockEntry(
            id: 'b4',
            startTime: '16:38',
            endTime: '16:53',
            stationFrom: 'CGV',
            stationTo: 'KTYM',
            isTransit: true,
          ),
        ],
      );

      final report = ReportService.formatReport(log);

      expect(report, contains('Progress of UTV005H on 12.09.2026'));
      expect(report, contains('Division: TVC'));
      expect(report, contains('Section: KTYM'));
      expect(report, contains('Machine ready at CGY – 09:25 hrs.'));
      expect(report, contains('Block – 1'));
      expect(report, contains('BT: 10:35 – 11:20 hrs'));
      expect(report, contains('CGY – CGV (UP)'));
      expect(report, contains('Sleepers unloaded: 16 Nos'));
      expect(report, contains('CGY – TRVL (DN)'));
      expect(report, contains('Sleepers loaded: 64 Nos'));
      expect(report, contains('CGV – KTYM : 16:38 – 16:53 hrs'));
      expect(report, contains('Total:'));
      expect(report, contains('Sleepers loaded: 64 Nos'));
      expect(report, contains('Sleepers unloaded: 40 Nos'));
      expect(report, contains('= 104 nos'));
      expect(report, contains('Machine stabled at KTYM.'));
    });

    test('Formats multiple work items within a single block', () {
      const log = ShiftLog(
        date: '2026-09-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        blocks: [
          BlockEntry(
            id: 'm1',
            startTime: '10:00',
            endTime: '11:00',
            stationFrom: 'CGY',
            stationTo: 'CGV',
            line: 'Both',
            items: [
              WorkItem(activity: 'Sleepers unloaded', output: 20, outputUnit: 'Nos'),
              WorkItem(activity: 'Rails loaded', output: 5, outputUnit: 'Nos'),
            ],
          ),
        ],
      );

      final report = ReportService.formatReport(log);
      expect(report, contains('CGY – CGV (Both)'));
      expect(report, contains('Sleepers unloaded: 20 Nos'));
      expect(report, contains('Rails loaded: 5 Nos'));
      expect(report, contains('Total:'));
      expect(report, contains('Sleepers unloaded: 20 Nos'));
      expect(report, contains('Rails loaded: 5 Nos'));
      expect(report, contains('= 25 nos'));
    });

    test('Includes shift remarks after machine stabled section', () {
      const log = ShiftLog(
        date: '2026-09-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        stabledStation: 'KTYM',
        stabledTime: '17:30',
        remarks: 'Heavy rain delayed work. Machine in working condition.',
        blocks: [],
      );

      final report = ReportService.formatReport(log);
      expect(report, contains('Remarks: Heavy rain delayed work. Machine in working condition.'));
      expect(report, contains('Machine stabled at KTYM – 17:30 hrs.'));
      final remarksPos = report.indexOf('Remarks:');
      final stabledPos = report.indexOf('Machine stabled');
      expect(stabledPos, lessThan(remarksPos));

      // Test JSON roundtrip
      final json = log.toJson();
      expect(json['remarks'], 'Heavy rain delayed work. Machine in working condition.');
      final restored = ShiftLog.fromJson(json);
      expect(restored.remarks, log.remarks);
    });

    test('Formats night shift date as dual dates (e.g. 12/13.10.2026)', () {
      const dayLog = ShiftLog(
        date: '2026-10-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        isNightShift: false,
        blocks: [],
      );
      expect(dayLog.formattedDate, '12.10.2026');

      const nightLog = ShiftLog(
        date: '2026-10-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        isNightShift: true,
        blocks: [],
      );
      expect(nightLog.formattedDate, '12/13.10.2026');

      final report = ReportService.formatReport(nightLog);
      expect(report, contains('Progress of UTV005H on 12/13.10.2026'));

      // Month crossing check (e.g. Oct 31 to Nov 01)
      const monthEndLog = ShiftLog(
        date: '2026-10-31',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        isNightShift: true,
        blocks: [],
      );
      expect(monthEndLog.formattedDate, '31.10/01.11.2026');
    });

    test('Formats yard block with Road and UP/DN M/L correctly in report', () {
      const yardLog = ShiftLog(
        date: '2026-10-18',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'TCR',
        blocks: [
          BlockEntry(
            id: 'y1',
            startTime: '10:00',
            endTime: '11:30',
            stationFrom: 'WKI',
            stationTo: 'Road 3, UP M/L',
            line: 'Yard',
            items: [
              WorkItem(activity: 'Sleepers unloaded', output: 25, outputUnit: 'Nos'),
            ],
          ),
          BlockEntry(
            id: 'y2',
            startTime: '12:00',
            endTime: '13:00',
            stationFrom: 'WKI',
            stationTo: 'Road 1, DN M/L',
            line: 'Yard',
            items: [
              WorkItem(activity: 'Sleepers loaded', output: 30, outputUnit: 'Nos'),
            ],
          ),
        ],
      );

      final report = ReportService.formatReport(yardLog);
      expect(report, contains('WKI (Yard – Road 3, UP M/L)'));
      expect(report, contains('WKI (Yard – Road 1, DN M/L)'));
    });
  });

  group('StorageService', () {
    test('Saves and retrieves active shift and history', () async {
      final initial = await StorageService.getActiveShift();
      expect(initial.machineName, 'UTV005H');

      final updated = initial.copyWith(
        machineName: 'DUOMAT 814',
        blocks: [
          const BlockEntry(
            id: 't1',
            startTime: '02:00',
            endTime: '04:00',
            stationFrom: 'TCR',
            stationTo: 'OLR',
            items: [
              WorkItem(activity: 'Tamping done', output: 1500, outputUnit: 'Meters'),
            ],
          ),
        ],
      );

      await StorageService.saveActiveShift(updated);
      final fetched = await StorageService.getActiveShift();
      expect(fetched.machineName, 'DUOMAT 814');
      expect(fetched.blocks.length, 1);

      // Test saveOrUpdateHistoryShift
      // 1. Initial save
      final res1 = await StorageService.saveOrUpdateHistoryShift(updated);
      expect(res1, SaveHistoryResult.savedNew);
      var history = await StorageService.getHistory();
      expect(history.length, 1);
      expect(history.first.machineName, 'DUOMAT 814');

      // 2. Press again without change
      final res2 = await StorageService.saveOrUpdateHistoryShift(updated);
      expect(res2, SaveHistoryResult.noChanges);
      history = await StorageService.getHistory();
      expect(history.length, 1);

      // 3. Press again with change
      final modified = updated.copyWith(section: 'ALLP');
      final res3 = await StorageService.saveOrUpdateHistoryShift(modified);
      expect(res3, SaveHistoryResult.updated);
      history = await StorageService.getHistory();
      expect(history.length, 1);
      expect(history.first.section, 'ALLP');
    });

    test('Export and import backup JSON', () async {
      final exportJson = await StorageService.exportBackupJson();
      expect(exportJson, contains('TRACKR_Lite'));

      final success = await StorageService.importBackupJson(exportJson);
      expect(success, isTrue);
    });

    test('resetAllData resets active shift, history, and notes to 0', () async {
      await StorageService.resetAllData();
      final fresh = await StorageService.getActiveShift();
      final history = await StorageService.getHistory();
      final notes = await StorageService.getNotes();

      expect(fresh.blocks, isEmpty);
      expect(fresh.blockCount, 0);
      expect(fresh.totalBlockOutput, 0.0);
      expect(history, isEmpty);
      expect(notes, isEmpty);
    });

    test('Saves, loads, edits, and fully deletes remark templates', () async {
      final initial = await StorageService.getRemarkTemplates();
      expect(initial, contains('Kindly arrange one barrel diesel'));
      expect(initial, isNot(contains('Diesel filled: ___ Ltrs at ___')));

      // Test adding
      await StorageService.addRemarkTemplate('Custom Track Template #1');
      var updated = await StorageService.getRemarkTemplates();
      expect(updated, contains('Custom Track Template #1'));

      // Test editing
      final idx = updated.indexOf('Custom Track Template #1');
      await StorageService.updateRemarkTemplate(idx, 'Modified Track Template #1');
      updated = await StorageService.getRemarkTemplates();
      expect(updated, contains('Modified Track Template #1'));
      expect(updated, isNot(contains('Custom Track Template #1')));

      // Test deleting all templates fully to empty list
      while (updated.isNotEmpty) {
        await StorageService.deleteRemarkTemplate(0);
        updated = await StorageService.getRemarkTemplates();
      }
      expect(updated, isEmpty);

      // Verify that after deletion, getRemarkTemplates still returns [] and does NOT restore defaults
      final afterEmpty = await StorageService.getRemarkTemplates();
      expect(afterEmpty, isEmpty);
    });

    test('Preserves user active shift across date changes and app updates if work is logged', () async {
      final pastDateShift = ShiftLog(
        date: '2026-10-10', // Past date
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        remarks: 'Night work in progress',
        isNightShift: true,
        blocks: [
          const BlockEntry(
            id: 'p1',
            startTime: '22:00',
            endTime: '02:00',
            stationFrom: 'KTYM',
            stationTo: 'CGY',
            items: [
              WorkItem(activity: 'Sleepers unloaded', output: 120, outputUnit: 'Nos'),
            ],
          ),
        ],
      );

      await StorageService.saveActiveShift(pastDateShift);

      // Fetching active shift on a different day must preserve user's data and auto-save it to history
      final retrieved = await StorageService.getActiveShift();
      expect(retrieved.blocks.length, 1);
      expect(retrieved.remarks, 'Night work in progress');
      expect(retrieved.blocks.first.items.first.output, 120);
      expect(retrieved.isNightShift, isTrue);

      // Verify it was auto-saved to history datewise
      final savedHistory = await StorageService.getHistory();
      expect(savedHistory.any((h) => h.date == '2026-10-10'), isTrue);
    });

    test('Sorts history datewise and looks up by date and night shift', () async {
      await StorageService.resetAllData();

      const shiftOct10 = ShiftLog(
        date: '2026-10-10',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        blocks: [],
      );
      const shiftOct12 = ShiftLog(
        date: '2026-10-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        blocks: [],
      );
      const shiftOct11 = ShiftLog(
        date: '2026-10-11',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        blocks: [],
      );
      const shiftOct12Night = ShiftLog(
        date: '2026-10-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'KTYM',
        isNightShift: true,
        blocks: [],
      );

      await StorageService.saveOrUpdateHistoryShift(shiftOct10);
      await StorageService.saveOrUpdateHistoryShift(shiftOct12);
      await StorageService.saveOrUpdateHistoryShift(shiftOct11);
      await StorageService.saveOrUpdateHistoryShift(shiftOct12Night);

      final history = await StorageService.getHistory();
      expect(history.length, 4);
      // Datewise order: 2026-10-12 (night), 2026-10-12 (day), 2026-10-11, 2026-10-10
      expect(history[0].date, '2026-10-12');
      expect(history[0].isNightShift, isTrue);
      expect(history[1].date, '2026-10-12');
      expect(history[1].isNightShift, isFalse);
      expect(history[2].date, '2026-10-11');
      expect(history[3].date, '2026-10-10');

      // Test getHistoryShiftForDate
      final foundOct11 = await StorageService.getHistoryShiftForDate('2026-10-11');
      expect(foundOct11, isNotNull);
      expect(foundOct11!.date, '2026-10-11');

      final foundNight = await StorageService.getHistoryShiftForDate('2026-10-12', isNightShift: true);
      expect(foundNight, isNotNull);
      expect(foundNight!.isNightShift, isTrue);
    });

    test('Movement overrides can be saved, retrieved, and deleted', () async {
      const override = MovementDayItem(
        date: '2026-10-05',
        type: MovementItemType.stay,
        stayStation: 'AWY',
        isManualOverride: true,
      );

      await StorageService.saveMovementOverride(override);
      var overrides = await StorageService.getMovementOverrides();
      expect(overrides.containsKey('2026-10-05'), isTrue);
      expect(overrides['2026-10-05']!.stayStation, 'AWY');
      expect(overrides['2026-10-05']!.isManualOverride, isTrue);

      await StorageService.deleteMovementOverride('2026-10-05');
      overrides = await StorageService.getMovementOverrides();
      expect(overrides.containsKey('2026-10-05'), isFalse);
    });

    test('StorageService saves and retrieves auto backup configuration and persists in export/import', () async {
      expect(await StorageService.isAutoBackupEnabled(), isFalse);
      expect(await StorageService.getAutoBackupTime(), '20:00');

      await StorageService.setAutoBackupEnabled(true);
      await StorageService.setAutoBackupTime('21:30');
      await StorageService.setLastAutoBackupCompleted(date: '2026-10-15', time: '21:30');

      expect(await StorageService.isAutoBackupEnabled(), isTrue);
      expect(await StorageService.getAutoBackupTime(), '21:30');
      expect(await StorageService.getLastAutoBackupDate(), '2026-10-15');
      expect(await StorageService.getLastAutoBackupTime(), '21:30');

      final jsonBackup = await StorageService.exportBackupJson();
      expect(jsonBackup, contains('"autoBackup"'));
      expect(jsonBackup, contains('"21:30"'));

      await StorageService.setAutoBackupEnabled(false);
      await StorageService.setAutoBackupTime('08:00');
      expect(await StorageService.isAutoBackupEnabled(), isFalse);

      final ok = await StorageService.importBackupJson(jsonBackup);
      expect(ok, isTrue);
      expect(await StorageService.isAutoBackupEnabled(), isTrue);
      expect(await StorageService.getAutoBackupTime(), '21:30');
    });
  });

  group('MovementService', () {
    test('formatTimeDot formats military and dotted time notation correctly', () {
      expect(MovementService.formatTimeDot('09:16'), '09.16');
      expect(MovementService.formatTimeDot('9:16'), '09.16');
      expect(MovementService.formatTimeDot('16:36'), '16.36');
      expect(MovementService.formatTimeDot('09.16'), '09.16');
      expect(MovementService.formatTimeDot(''), '_____');
      expect(MovementService.formatTimeDot('_____'), '_____');
    });

    test('formatDateDot formats DateTime correctly', () {
      expect(MovementService.formatDateDot(DateTime(2026, 10, 1)), '01.10.26');
      expect(MovementService.formatDateDot(DateTime(2026, 10, 15)), '15.10.26');
    });

    test('formatDualDateDot formats cross-day and cross-month night dates', () {
      expect(MovementService.formatDualDateDot(DateTime(2026, 10, 6), DateTime(2026, 10, 7)), '06/07.10.26');
      expect(MovementService.formatDualDateDot(DateTime(2026, 10, 31), DateTime(2026, 11, 1)), '31.10/01.11.26');
    });

    test('Generates Register and Dual Date movement report strings according to reference sheet', () {
      final days = [
        const MovementDayItem(
          date: '2026-10-01',
          type: MovementItemType.transit,
          runs: [
            MovementRun(
              fromStation: 'KTYM',
              toStation: 'CGY',
              departureTime: '09:16',
              arrivalTime: '16:36',
            ),
          ],
        ),
        const MovementDayItem(
          date: '2026-10-02',
          type: MovementItemType.stay,
          stayStation: 'CGY',
        ),
        const MovementDayItem(
          date: '2026-10-06',
          type: MovementItemType.transit,
          runs: [
            MovementRun(
              fromStation: 'AFK',
              toStation: 'AWY',
              departureTime: '21:57',
              arrivalTime: '04:20',
              isOvernight: true,
              isDepartureLeg: true,
            ),
          ],
        ),
        const MovementDayItem(
          date: '2026-10-07',
          type: MovementItemType.transit,
          runs: [
            MovementRun(
              fromStation: 'AFK',
              toStation: 'AWY',
              departureTime: '21:57',
              arrivalTime: '04:20',
              isOvernight: true,
              isArrivalLeg: true,
            ),
            MovementRun(
              fromStation: 'AWY',
              toStation: 'TCR',
              departureTime: '15:53',
              arrivalTime: '',
              isOvernight: false,
            ),
          ],
        ),
      ];

      // 1. Register style
      final registerReport = MovementService.formatMovementReport(
        monthDays: days,
        selectedMonth: DateTime(2026, 10, 1),
        machineName: 'UTV005H',
        division: 'TVC',
        style: MovementFormatStyle.register,
      );

      expect(registerReport, contains('* MACHINE MOVEMENT – OCTOBER 2026 *'));
      expect(registerReport, contains('01.10.26 :- KTYM – CGY (09.16 – 16.36 hrs)'));
      expect(registerReport, contains('02.10.26 :- Stay at CGY'));
      expect(registerReport, contains('06.10.26 :- AFK – _____ (21.57 – _____ hrs)'));
      expect(registerReport, contains('07.10.26 :- _____ – AWY (_____ – 04.20 hrs)'));
      expect(registerReport, contains('            AWY – TCR (15.53 – _____ hrs)'));

      // 2. Dual date style
      final dualDateReport = MovementService.formatMovementReport(
        monthDays: days,
        selectedMonth: DateTime(2026, 10, 1),
        machineName: 'UTV005H',
        division: 'TVC',
        style: MovementFormatStyle.dualDate,
      );

      expect(dualDateReport, contains('01.10.26 :- KTYM – CGY (09.16 – 16.36 hrs)'));
      expect(dualDateReport, contains('02.10.26 :- Stay at CGY'));
      expect(dualDateReport, contains('06/07.10.26 :- AFK – AWY (21.57 – 04.20 hrs)'));
    });

    test('generateMonthDays auto-generates overall shift movement matching user screenshot (AFK 20.21 to WKI 07.14)', () {
      // User's exact shift log from image 1:
      // Ready at AFK 19:05
      // 1st transit: AFK - WKI (20:21 - 21:50)
      // Intermediate blocks and transits: MGK - TCR (05:39 - 05:58)
      // Final transit: PNQ - WKI (06:40 - 07:14)
      // Stabled at WKI
      const sampleNightShift = ShiftLog(
        date: '2026-10-12',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'TCR',
        readyStation: 'AFK',
        readyTime: '19:05',
        stabledStation: 'WKI',
        isNightShift: true,
        blocks: [
          BlockEntry(
            id: 't1',
            startTime: '20:21',
            endTime: '21:50',
            stationFrom: 'AFK',
            stationTo: 'WKI',
            isTransit: true,
          ),
          BlockEntry(
            id: 'b1',
            startTime: '23:50',
            endTime: '00:20',
            stationFrom: 'WKI',
            stationTo: 'WKI',
            line: 'Yard',
            items: [WorkItem(activity: 'Rail Loaded', output: 6)],
          ),
          BlockEntry(
            id: 't2',
            startTime: '05:39',
            endTime: '05:58',
            stationFrom: 'MGK',
            stationTo: 'TCR',
            isTransit: true,
          ),
          BlockEntry(
            id: 't3',
            startTime: '06:40',
            endTime: '07:14',
            stationFrom: 'PNQ',
            stationTo: 'WKI',
            isTransit: true,
          ),
        ],
      );

      final monthDays = MovementService.generateMonthDays(
        year: 2026,
        month: 10,
        historyShifts: [sampleNightShift],
      );

      // Day 12 item (Departure leg): AFK - _____ (20.21 - _____ hrs)
      // Departure taken from first transit run (20:21)
      final day12 = monthDays.firstWhere((d) => d.date == '2026-10-12');
      expect(day12.type, MovementItemType.transit);
      expect(day12.runs.length, 1);
      expect(day12.runs.first.fromStation, 'AFK');
      expect(day12.runs.first.departureTime, '20:21');
      expect(day12.runs.first.isDepartureLeg, isTrue);

      // Day 13 item (Arrival leg): _____ - WKI (_____ - 07.14 hrs)
      // Arrival taken from last transit run (07:14)
      final day13 = monthDays.firstWhere((d) => d.date == '2026-10-13');
      expect(day13.type, MovementItemType.transit);
      expect(day13.runs.length, 1);
      expect(day13.runs.first.toStation, 'WKI');
      expect(day13.runs.first.arrivalTime, '07:14');
      expect(day13.runs.first.isArrivalLeg, isTrue);

      // Verify generated report strings for day 12 and 13
      final report = MovementService.formatMovementReport(
        year: 2026,
        month: 10,
        items: monthDays,
        style: MovementFormatStyle.register,
      );

      expect(report, contains('12.10.26 :- AFK – _____ (20.21 – _____ hrs)'));
      expect(report, contains('13.10.26 :- _____ – WKI (_____ – 07.14 hrs)'));
    });

    test('StationService contains Guruvayur (GUV)', () {
      final results = StationService.search('GUV');
      expect(results, isNotEmpty);
      expect(results.first.code, 'GUV');
      expect(results.first.name, 'Guruvayur');
    });

    test('MovementService calculates movement start from inter-station block and end from stabled time', () {
      const shiftWithBlocksOnly = ShiftLog(
        date: '2026-10-15',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'TCR',
        readyStation: 'GUV',
        readyTime: '10:00',
        stabledStation: 'TCR',
        stabledTime: '18:30',
        isNightShift: false,
        blocks: [
          BlockEntry(
            id: 'b1',
            startTime: '11:00',
            endTime: '17:45',
            stationFrom: 'GUV',
            stationTo: 'PNQ',
            isTransit: false,
          ),
        ],
      );

      final monthDays = MovementService.generateMonthDays(
        year: 2026,
        month: 10,
        historyShifts: [shiftWithBlocksOnly],
      );

      final day15 = monthDays.firstWhere((d) => d.date == '2026-10-15');
      expect(day15.type, MovementItemType.transit);
      expect(day15.runs.length, 1);
      // Dep taken from first inter-station movement (11:00)
      expect(day15.runs.first.fromStation, 'GUV');
      expect(day15.runs.first.departureTime, '11:00');
      // Arr taken from stabledStation/stabledTime (18:30 at TCR)
      expect(day15.runs.first.toStation, 'TCR');
      expect(day15.runs.first.arrivalTime, '18:30');
    });

    test('Night shift ready before midnight but moving after midnight records Stay on Day 1 and Movement on Day 2', () {
      const nightShiftAfterMidnight = ShiftLog(
        date: '2026-10-15',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'TCR',
        readyStation: 'WKI',
        readyTime: '22:00',
        isNightShift: true,
        blocks: [
          // Yard work inside WKI before 12:00 AM
          BlockEntry(
            id: 'b1',
            startTime: '22:30',
            endTime: '00:45',
            stationFrom: 'WKI',
            stationTo: 'Road 3',
            line: 'Yard',
            isTransit: false,
          ),
          // First inter-station movement starts after 12:00 AM at 03:00
          BlockEntry(
            id: 'b2',
            startTime: '03:00',
            endTime: '03:24',
            stationFrom: 'WKI',
            stationTo: 'MGK',
            isTransit: true,
          ),
          // Last movement ends at 07:14
          BlockEntry(
            id: 'b3',
            startTime: '06:40',
            endTime: '07:14',
            stationFrom: 'PNQ',
            stationTo: 'TCR',
            isTransit: true,
          ),
        ],
      );

      final monthDays = MovementService.generateMonthDays(
        year: 2026,
        month: 10,
        historyShifts: [nightShiftAfterMidnight],
      );

      // Day 15 (Day 1): No station-to-station movement occurred before midnight -> Stay at WKI
      final day15 = monthDays.firstWhere((d) => d.date == '2026-10-15');
      expect(day15.type, MovementItemType.stay);
      expect(day15.stayStation, 'WKI');

      // Day 16 (Day 2): Movement started at 03:00 and ended at 07:14 at TCR
      final day16 = monthDays.firstWhere((d) => d.date == '2026-10-16');
      expect(day16.type, MovementItemType.transit);
      expect(day16.runs.length, 1);
      expect(day16.runs.first.fromStation, 'WKI');
      expect(day16.runs.first.toStation, 'TCR');
      expect(day16.runs.first.departureTime, '03:00');
      expect(day16.runs.first.arrivalTime, '07:14');
      expect(day16.runs.first.isOvernight, isFalse);

      final report = MovementService.formatMovementReport(
        year: 2026,
        month: 10,
        items: monthDays,
      );
      expect(report, contains('15.10.26 :- Stay at WKI'));
      expect(report, contains('16.10.26 :- WKI – TCR (03.00 – 07.14 hrs)'));
    });

    test('Shift with only yard work records Stay at station', () {
      const yardOnlyShift = ShiftLog(
        date: '2026-10-15',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'TCR',
        readyStation: 'TCR',
        readyTime: '09:00',
        stabledStation: 'TCR',
        blocks: [
          BlockEntry(
            id: 'b1',
            startTime: '10:00',
            endTime: '12:00',
            stationFrom: 'TCR',
            stationTo: 'Road 2',
            line: 'Yard',
            isTransit: false,
          ),
        ],
      );

      final monthDays = MovementService.generateMonthDays(
        year: 2026,
        month: 10,
        historyShifts: [yardOnlyShift],
      );

      final day15 = monthDays.firstWhere((d) => d.date == '2026-10-15');
      expect(day15.type, MovementItemType.stay);
      expect(day15.stayStation, 'TCR');
    });

    test('MovementService does not prefill future dates with anything', () {
      final now = DateTime.now();
      final futureYear = now.year + 1;
      final shift = ShiftLog(
        date: '$futureYear-01-01',
        machineName: 'UTV005H',
        division: 'TVC',
        section: 'TCR',
        readyStation: 'WKI',
        stabledStation: 'WKI',
        blocks: const [],
      );

      final monthDays = MovementService.generateMonthDays(
        year: futureYear,
        month: 1,
        historyShifts: [shift],
      );

      // Future date January 5 has no shifts and no runs
      final futureDay = monthDays.firstWhere((d) => d.date == '$futureYear-01-05');
      expect(futureDay.type, MovementItemType.stay);
      expect(futureDay.stayStation, isEmpty, reason: 'Future dates should not be prefilled with any station');

      final report = MovementService.formatMovementReport(
        year: futureYear,
        month: 1,
        items: monthDays,
      );
      expect(report, isNot(contains('05.01.${futureYear % 100} :- Stay at')));
    });
  });
}
