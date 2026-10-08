import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackr_lite/models/block_entry.dart';
import 'package:trackr_lite/models/shift_log.dart';
import 'package:trackr_lite/services/station_service.dart';
import 'package:trackr_lite/services/storage_service.dart';
import 'package:trackr_lite/services/whatsapp_service.dart';

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

  group('WhatsAppService', () {
    test('Formats shift report accurately for blocks and transit', () {
      final log = ShiftLog(
        date: '2026-10-08',
        machineType: 'CSM',
        machineNo: '952',
        division: 'TVC',
        section: 'KTYM',
        stabledStation: 'CGY',
        blocks: [
          const BlockEntry(
            id: 'b1',
            startTime: '01:15',
            endTime: '03:45',
            stationFrom: 'HAD',
            stationTo: 'CGY',
            line: 'DN',
            output: 1240,
            outputUnit: 'Sleepers',
            remarks: 'Tamping done',
          ),
          const BlockEntry(
            id: 'b2',
            startTime: '04:00',
            endTime: '05:10',
            stationFrom: 'CGY',
            stationTo: 'TRVL',
            line: 'Transit',
            output: 18.5,
            outputUnit: 'Km',
            isTransit: true,
          ),
        ],
      );

      final report = WhatsAppService.formatReport(log);

      expect(report, contains('TRACKR LITE SHIFT REPORT'));
      expect(report, contains('CSM 952'));
      expect(report, contains('TVC / KTYM'));
      expect(report, contains('1240 Sleepers'));
      expect(report, contains('18.5 Km'));
      expect(report, contains('*Total Blocks:* 1'));
      expect(report, contains('*Total Block Output:* 1240'));
      expect(report, contains('*Total Transit Run:* 18.5 Km'));
    });
  });

  group('StorageService', () {
    test('Saves and retrieves active shift and history', () async {
      final initial = await StorageService.getActiveShift();
      expect(initial.machineType, 'CSM');

      final updated = initial.copyWith(
        machineType: 'DUOMAT',
        machineNo: '814',
        blocks: [
          const BlockEntry(
            id: 't1',
            startTime: '02:00',
            endTime: '04:00',
            stationFrom: 'TCR',
            stationTo: 'OLR',
            output: 1500,
          ),
        ],
      );

      await StorageService.saveActiveShift(updated);
      final fetched = await StorageService.getActiveShift();
      expect(fetched.machineType, 'DUOMAT');
      expect(fetched.machineNo, '814');
      expect(fetched.blocks.length, 1);

      // Complete & Archive
      await StorageService.completeAndArchiveShift(updated);
      final history = await StorageService.getHistory();
      expect(history.length, 1);
      expect(history.first.machineType, 'DUOMAT');
    });

    test('Export and import backup JSON', () async {
      final exportJson = await StorageService.exportBackupJson();
      expect(exportJson, contains('TRACKR_Lite'));

      final success = await StorageService.importBackupJson(exportJson);
      expect(success, isTrue);
    });
  });
}
