import '../models/station.dart';

class StationService {
  // Pre-loaded Southern Railway TVC & PGT Stations
  static const List<Station> defaultStations = [
    // TVC - TCR Section
    Station(code: 'SRRB', name: "Shoranur 'B' Cabin", section: 'TCR', division: 'TVC'),
    Station(code: 'VTK', name: 'Vallathol Nagar', section: 'TCR', division: 'TVC'),
    Station(code: 'MUC', name: 'Mullurkara', section: 'TCR', division: 'TVC'),
    Station(code: 'WKI', name: 'Wadakancheri', section: 'TCR', division: 'TVC'),
    Station(code: 'MGK', name: 'Mulagunnathukavu', section: 'TCR', division: 'TVC'),
    Station(code: 'PNQ', name: 'Thrissur Punkunnam', section: 'TCR', division: 'TVC'),
    Station(code: 'TCR', name: 'Thrissur', section: 'TCR', division: 'TVC'),
    Station(code: 'OLR', name: 'Ollur', section: 'TCR', division: 'TVC'),
    Station(code: 'PUK', name: 'Pudukad', section: 'TCR', division: 'TVC'),
    Station(code: 'NYI', name: 'Nellayi', section: 'TCR', division: 'TVC'),
    Station(code: 'IJK', name: 'Irinjalakuda', section: 'TCR', division: 'TVC'),
    Station(code: 'CKI', name: 'Chalakudi', section: 'TCR', division: 'TVC'),
    Station(code: 'DINR', name: 'Divine Nagar', section: 'TCR', division: 'TVC'),
    Station(code: 'KRAN', name: 'Koratty Angadi', section: 'TCR', division: 'TVC'),
    Station(code: 'KUC', name: 'Karukutty', section: 'TCR', division: 'TVC'),
    Station(code: 'AFK', name: 'Angamaly for Kalady', section: 'TCR', division: 'TVC'),
    Station(code: 'CWR', name: 'Chowwara', section: 'TCR', division: 'TVC'),
    Station(code: 'AWY', name: 'Aluva', section: 'TCR', division: 'TVC'),
    Station(code: 'KLMR', name: 'Kalamassery', section: 'TCR', division: 'TVC'),
    Station(code: 'IPL', name: 'Idappally', section: 'TCR', division: 'TVC'),
    Station(code: 'ERDY', name: 'Ernakulam Marshalling Yard', section: 'TCR', division: 'TVC'),
    Station(code: 'ERN', name: 'Ernakulam Town (North)', section: 'TCR', division: 'TVC'),
    Station(code: 'ERS', name: 'Ernakulam Junction (South)', section: 'TCR', division: 'TVC'),

    // TVC - KTYM Section
    Station(code: 'TRTR', name: 'Tripunithura', section: 'KTYM', division: 'TVC'),
    Station(code: 'KFE', name: 'Chottanikkara Road', section: 'KTYM', division: 'TVC'),
    Station(code: 'MNTT', name: 'Mulanturutti', section: 'KTYM', division: 'TVC'),
    Station(code: 'KPTM', name: 'Kanjiramittam', section: 'KTYM', division: 'TVC'),
    Station(code: 'PVRD', name: 'Piravom Road', section: 'KTYM', division: 'TVC'),
    Station(code: 'VARD', name: 'Vaikom Road', section: 'KTYM', division: 'TVC'),
    Station(code: 'KRPP', name: 'Kuruppanthara', section: 'KTYM', division: 'TVC'),
    Station(code: 'KDTU', name: 'Kaduturutti Halt', section: 'KTYM', division: 'TVC'),
    Station(code: 'ETM', name: 'Ettumanur', section: 'KTYM', division: 'TVC'),
    Station(code: 'KFQ', name: 'Kumaranallur', section: 'KTYM', division: 'TVC'),
    Station(code: 'KTYM', name: 'Kottayam', section: 'KTYM', division: 'TVC'),
    Station(code: 'CGV', name: 'Chingavanam', section: 'KTYM', division: 'TVC'),
    Station(code: 'CGY', name: 'Changanassery', section: 'KTYM', division: 'TVC'),
    Station(code: 'TRVL', name: 'Tiruvalla', section: 'KTYM', division: 'TVC'),
    Station(code: 'CNGR', name: 'Chengannur', section: 'KTYM', division: 'TVC'),
    Station(code: 'CYN', name: 'Cheriyanad', section: 'KTYM', division: 'TVC'),
    Station(code: 'MVLK', name: 'Mavelikara', section: 'KTYM', division: 'TVC'),
    Station(code: 'KYJ', name: 'Kayamkulam Junction', section: 'KTYM', division: 'TVC'),

    // TVC - ALLP Section
    Station(code: 'KUMM', name: 'Kumbalam', section: 'ALLP', division: 'TVC'),
    Station(code: 'AROR', name: 'Aroor Halt', section: 'ALLP', division: 'TVC'),
    Station(code: 'EZP', name: 'Ezhuppunna', section: 'ALLP', division: 'TVC'),
    Station(code: 'TUVR', name: 'Turavur', section: 'ALLP', division: 'TVC'),
    Station(code: 'VAY', name: 'Vayalar', section: 'ALLP', division: 'TVC'),
    Station(code: 'SRTL', name: 'Cherthala', section: 'ALLP', division: 'TVC'),
    Station(code: 'TRBZ', name: 'Tirizhappally', section: 'ALLP', division: 'TVC'),
    Station(code: 'MAKM', name: 'Mararikulam', section: 'ALLP', division: 'TVC'),
    Station(code: 'KAVR', name: 'Kalavoor Halt', section: 'ALLP', division: 'TVC'),
    Station(code: 'ALLP', name: 'Alappuzha', section: 'ALLP', division: 'TVC'),
    Station(code: 'PNPR', name: 'Punnapra', section: 'ALLP', division: 'TVC'),
    Station(code: 'AMPA', name: 'Ambalappuzha', section: 'ALLP', division: 'TVC'),
    Station(code: 'TZH', name: 'Takazhi', section: 'ALLP', division: 'TVC'),
    Station(code: 'KVTA', name: 'Karuvatta Halt', section: 'ALLP', division: 'TVC'),
    Station(code: 'HAD', name: 'Harippad', section: 'ALLP', division: 'TVC'),
    Station(code: 'CHPD', name: 'Cheppad Halt', section: 'ALLP', division: 'TVC'),

    // TVC - QLN Section
    Station(code: 'OCR', name: 'Ochira', section: 'QLN', division: 'TVC'),
    Station(code: 'KPY', name: 'Karunagappalli', section: 'QLN', division: 'TVC'),
    Station(code: 'STKT', name: 'Sasthankotta', section: 'QLN', division: 'TVC'),
    Station(code: 'MQO', name: 'Munroturuttu', section: 'QLN', division: 'TVC'),
    Station(code: 'PRND', name: 'Perinad', section: 'QLN', division: 'TVC'),
    Station(code: 'QLN', name: 'Kollam Junction', section: 'QLN', division: 'TVC'),
    Station(code: 'MYY', name: 'Mayyanad', section: 'QLN', division: 'TVC'),
    Station(code: 'PVU', name: 'Paravur', section: 'QLN', division: 'TVC'),
    Station(code: 'KFI', name: 'Kappil', section: 'QLN', division: 'TVC'),
    Station(code: 'EVA', name: 'Edava', section: 'QLN', division: 'TVC'),
    Station(code: 'VAK', name: 'Varkala Sivagiri', section: 'QLN', division: 'TVC'),
    Station(code: 'AMY', name: 'Akathumuri', section: 'QLN', division: 'TVC'),
    Station(code: 'KVU', name: 'Kadakkavur', section: 'QLN', division: 'TVC'),
    Station(code: 'CRY', name: 'Chirayinkeezhu', section: 'QLN', division: 'TVC'),
    Station(code: 'PGZ', name: 'Perunguzhi', section: 'QLN', division: 'TVC'),
    Station(code: 'MQU', name: 'Murukkampuzha', section: 'QLN', division: 'TVC'),
    Station(code: 'KXP', name: 'Kaniyapuram', section: 'QLN', division: 'TVC'),
    Station(code: 'KZK', name: 'Kazhakuttam', section: 'QLN', division: 'TVC'),
    Station(code: 'KCVL', name: 'Kochuveli', section: 'QLN', division: 'TVC'),
    Station(code: 'TVP', name: 'Thiruvananthapuram Pettah', section: 'QLN', division: 'TVC'),
    Station(code: 'TVC', name: 'Thiruvananthapuram Central', section: 'QLN', division: 'TVC'),

    // TVC - NCJ Section
    Station(code: 'NEM', name: 'Nemom', section: 'NCJ', division: 'TVC'),
    Station(code: 'BRAM', name: 'Balaramapuram', section: 'NCJ', division: 'TVC'),
    Station(code: 'NYY', name: 'Neyyattinkara', section: 'NCJ', division: 'TVC'),
    Station(code: 'AMVA', name: 'Amaravila Halt', section: 'NCJ', division: 'TVC'),
    Station(code: 'DAVM', name: 'Dhanuvachapuram', section: 'NCJ', division: 'TVC'),
    Station(code: 'PASA', name: 'Parassala', section: 'NCJ', division: 'TVC'),
    Station(code: 'KZTW', name: 'Kulitturai West', section: 'NCJ', division: 'TVC'),
    Station(code: 'KZT', name: 'Kulitturai', section: 'NCJ', division: 'TVC'),
    Station(code: 'PYD', name: 'Palliyadi', section: 'NCJ', division: 'TVC'),
    Station(code: 'ERL', name: 'Eraniel', section: 'NCJ', division: 'TVC'),
    Station(code: 'VRLI', name: 'Virani Aloor', section: 'NCJ', division: 'TVC'),
    Station(code: 'NJT', name: 'Nagercoil Town', section: 'NCJ', division: 'TVC'),
    Station(code: 'NCJ', name: 'Nagercoil Junction', section: 'NCJ', division: 'TVC'),
    Station(code: 'CAPE', name: 'Kanniyakumari', section: 'NCJ', division: 'TVC'),
  ];

  static List<Station> search(String query) {
    if (query.trim().isEmpty) return defaultStations;
    final q = query.trim().toUpperCase();
    return defaultStations
        .where((s) => s.code.toUpperCase().contains(q) || s.name.toUpperCase().contains(q))
        .toList();
  }

  static String getStationName(String code) {
    final match = defaultStations.firstWhere(
      (s) => s.code.toUpperCase() == code.toUpperCase(),
      orElse: () => Station(code: code, name: code, section: '', division: ''),
    );
    return match.name;
  }
}
