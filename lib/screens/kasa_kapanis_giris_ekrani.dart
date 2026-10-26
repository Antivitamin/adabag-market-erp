import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TurkceBuyukHarfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text) return newValue;
    final metin =
        newValue.text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
    return newValue.copyWith(
      text: metin,
      selection: TextSelection.collapsed(offset: metin.length),
    );
  }
}

class DinamikKalemSatiri {
  TextEditingController isimCtrl;
  TextEditingController k1Ctrl;
  TextEditingController k2Ctrl;
  TextEditingController k3Ctrl;

  late FocusNode isimFocus;
  late FocusNode k1Focus;
  late FocusNode k2Focus;
  late FocusNode k3Focus;

  DinamikKalemSatiri({
    String isim = '',
    String k1 = '',
    String k2 = '',
    String k3 = '',
  })  : isimCtrl = TextEditingController(text: isim),
        k1Ctrl = TextEditingController(text: k1),
        k2Ctrl = TextEditingController(text: k2),
        k3Ctrl = TextEditingController(text: k3);

  void initFocus(
    KeyEventResult Function(FocusNode, KeyEvent) onKeyIsim,
    KeyEventResult Function(FocusNode, KeyEvent) onKeyK1,
    KeyEventResult Function(FocusNode, KeyEvent) onKeyK2,
    KeyEventResult Function(FocusNode, KeyEvent) onKeyK3,
  ) {
    isimFocus = FocusNode(onKeyEvent: onKeyIsim);
    k1Focus = FocusNode(onKeyEvent: onKeyK1);
    k2Focus = FocusNode(onKeyEvent: onKeyK2);
    k3Focus = FocusNode(onKeyEvent: onKeyK3);
  }

  void dispose() {
    isimCtrl.dispose();
    k1Ctrl.dispose();
    k2Ctrl.dispose();
    k3Ctrl.dispose();
    isimFocus.dispose();
    k1Focus.dispose();
    k2Focus.dispose();
    k3Focus.dispose();
  }
}

class KasaKapanisGirisEkrani extends StatefulWidget {
  final String? initialDate;

  const KasaKapanisGirisEkrani({super.key, this.initialDate});

  @override
  State<KasaKapanisGirisEkrani> createState() => _KasaKapanisGirisEkraniState();
}

class _KasaKapanisGirisEkraniState extends State<KasaKapanisGirisEkrani> {
  final supabase = Supabase.instance.client;
  final DateFormat _tarihFormatGoster = DateFormat('dd.MM.yyyy');

  late DateTime secilenTarihDt;
  bool yukleniyor = false;
  bool kilitliMi = false;

  final TextEditingController veresiyeDevirCtrl =
      TextEditingController(text: '0,00');

  final List<TextEditingController> nakitCtrl =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> isbankCtrl =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> ziraatCtrl =
      List.generate(3, (_) => TextEditingController());

  final TextEditingController digerBankaAdiCtrl =
      TextEditingController(text: '');
  late FocusNode digerBankaAdiFocus;
  final List<TextEditingController> digerBankaCtrl =
      List.generate(3, (_) => TextEditingController());
  late List<FocusNode> digerBankaFocus;

  final List<TextEditingController> bozukCtrl =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> posetCtrl =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> iadeCtrl =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> yardimCtrl =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> iskontoCtrl =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> eldenCtrl =
      List.generate(3, (_) => TextEditingController());

  late List<FocusNode> nakitFocus;
  late List<FocusNode> isbankFocus;
  late List<FocusNode> ziraatFocus;
  late List<FocusNode> bozukFocus;
  late List<FocusNode> posetFocus;
  late List<FocusNode> iadeFocus;
  late List<FocusNode> yardimFocus;
  late List<FocusNode> iskontoFocus;
  late List<FocusNode> eldenFocus;

  List<double> zRaporuSistem = [0.0, 0.0, 0.0];

  List<DinamikKalemSatiri> veresiyeListesi = [];
  List<DinamikKalemSatiri> gelenVeresiyeListesi = [];
  List<DinamikKalemSatiri> giderListesi = [];

  String get secilenTarihIso => DateFormat('yyyy-MM-dd').format(secilenTarihDt);

  @override
  void initState() {
    super.initState();
    secilenTarihDt = widget.initialDate != null
        ? DateTime.tryParse(widget.initialDate!) ?? DateTime.now()
        : DateTime.now();

    _focusNodeBaglantilariniKur();
    verileriGetir();
  }

  void _focusNodeBaglantilariniKur() {
    KeyEventResult tusYoneticisi(FocusNode node, KeyEvent event,
        {int? kasaIdx, bool isIsim = false, TextEditingController? ctrl}) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          if (ctrl != null) _sayiyiYuvarlaVeFormatla(ctrl);
          _asagiAkit(node, kasaIdx: kasaIdx, isIsim: isIsim);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (ctrl != null) _sayiyiYuvarlaVeFormatla(ctrl);
          _yukariAkit(node, kasaIdx: kasaIdx, isIsim: isIsim);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    nakitFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: nakitCtrl[i])));
    isbankFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: isbankCtrl[i])));
    ziraatFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: ziraatCtrl[i])));
    digerBankaFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: digerBankaCtrl[i])));
    digerBankaAdiFocus =
        FocusNode(onKeyEvent: (n, e) => tusYoneticisi(n, e, isIsim: true));

    bozukFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: bozukCtrl[i])));
    posetFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: posetCtrl[i])));
    iadeFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: iadeCtrl[i])));
    yardimFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: yardimCtrl[i])));
    iskontoFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: iskontoCtrl[i])));
    eldenFocus = List.generate(
        3,
        (i) => FocusNode(
            onKeyEvent: (n, e) =>
                tusYoneticisi(n, e, kasaIdx: i, ctrl: eldenCtrl[i])));

    // VERESİYE SATIŞ 15 SATIRA ÇIKARILDI (+2 SATIR DAHA)
    final vIsimler = [
      'BİTLİS SPOR',
      'ÇEVRE YOLU',
      'TÜNEL',
      'VERGİ DAİRESİ',
      'ŞANTİYE',
      'MUTFAK',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      ''
    ];
    veresiyeListesi = vIsimler.map((isim) {
      final s = DinamikKalemSatiri(isim: isim);
      s.initFocus(
        (n, e) => tusYoneticisi(n, e, isIsim: true),
        (n, e) => tusYoneticisi(n, e, kasaIdx: 0, ctrl: s.k1Ctrl),
        (n, e) => tusYoneticisi(n, e, kasaIdx: 1, ctrl: s.k2Ctrl),
        (n, e) => tusYoneticisi(n, e, kasaIdx: 2, ctrl: s.k3Ctrl),
      );
      return s;
    }).toList();

    // 6 SATIR
    final gvIsimler = ['NEVZAT IŞIK', '', '', '', '', ''];
    gelenVeresiyeListesi = gvIsimler.map((isim) {
      final s = DinamikKalemSatiri(isim: isim);
      s.initFocus(
        (n, e) => tusYoneticisi(n, e, isIsim: true),
        (n, e) => tusYoneticisi(n, e, kasaIdx: 0, ctrl: s.k1Ctrl),
        (n, e) => tusYoneticisi(n, e, kasaIdx: 1, ctrl: s.k2Ctrl),
        (n, e) => tusYoneticisi(n, e, kasaIdx: 2, ctrl: s.k3Ctrl),
      );
      return s;
    }).toList();

    // 6 SATIR
    final gidIsimler = ['', '', '', '', '', ''];
    giderListesi = gidIsimler.map((isim) {
      final s = DinamikKalemSatiri(isim: isim);
      s.initFocus(
        (n, e) => tusYoneticisi(n, e, isIsim: true),
        (n, e) => tusYoneticisi(n, e, kasaIdx: 0, ctrl: s.k1Ctrl),
        (n, e) => tusYoneticisi(n, e, kasaIdx: 1, ctrl: s.k2Ctrl),
        (n, e) => tusYoneticisi(n, e, kasaIdx: 2, ctrl: s.k3Ctrl),
      );
      return s;
    }).toList();
  }

  @override
  void dispose() {
    veresiyeDevirCtrl.dispose();
    digerBankaAdiCtrl.dispose();
    digerBankaAdiFocus.dispose();
    for (int i = 0; i < 3; i++) {
      nakitCtrl[i].dispose();
      isbankCtrl[i].dispose();
      ziraatCtrl[i].dispose();
      digerBankaCtrl[i].dispose();
      bozukCtrl[i].dispose();
      posetCtrl[i].dispose();
      iadeCtrl[i].dispose();
      yardimCtrl[i].dispose();
      iskontoCtrl[i].dispose();
      eldenCtrl[i].dispose();

      nakitFocus[i].dispose();
      isbankFocus[i].dispose();
      ziraatFocus[i].dispose();
      digerBankaFocus[i].dispose();
      bozukFocus[i].dispose();
      posetFocus[i].dispose();
      iadeFocus[i].dispose();
      yardimFocus[i].dispose();
      iskontoFocus[i].dispose();
      eldenFocus[i].dispose();
    }
    for (var s in veresiyeListesi) {
      s.dispose();
    }
    for (var s in gelenVeresiyeListesi) {
      s.dispose();
    }
    for (var s in giderListesi) {
      s.dispose();
    }
    super.dispose();
  }

  List<FocusNode> _kasaSutunFocusZinciri(int kasaIdx) {
    List<FocusNode> chain = [];
    chain.add(nakitFocus[kasaIdx]);
    chain.add(isbankFocus[kasaIdx]);
    chain.add(ziraatFocus[kasaIdx]);
    chain.add(digerBankaFocus[kasaIdx]);
    chain.add(bozukFocus[kasaIdx]);

    for (var s in veresiyeListesi) {
      chain.add(
          kasaIdx == 0 ? s.k1Focus : (kasaIdx == 1 ? s.k2Focus : s.k3Focus));
    }

    chain.add(posetFocus[kasaIdx]);
    chain.add(iadeFocus[kasaIdx]);
    chain.add(yardimFocus[kasaIdx]);
    chain.add(iskontoFocus[kasaIdx]);

    for (var s in gelenVeresiyeListesi) {
      chain.add(
          kasaIdx == 0 ? s.k1Focus : (kasaIdx == 1 ? s.k2Focus : s.k3Focus));
    }

    for (var s in giderListesi) {
      chain.add(
          kasaIdx == 0 ? s.k1Focus : (kasaIdx == 1 ? s.k2Focus : s.k3Focus));
    }

    chain.add(eldenFocus[kasaIdx]);
    return chain;
  }

  List<FocusNode> _isimSutunFocusZinciri() {
    List<FocusNode> chain = [];
    chain.add(digerBankaAdiFocus);
    for (var s in veresiyeListesi) {
      chain.add(s.isimFocus);
    }
    for (var s in gelenVeresiyeListesi) {
      chain.add(s.isimFocus);
    }
    for (var s in giderListesi) {
      chain.add(s.isimFocus);
    }
    return chain;
  }

  void _asagiAkit(FocusNode currentFocus, {int? kasaIdx, bool isIsim = false}) {
    List<FocusNode> chain = isIsim
        ? _isimSutunFocusZinciri()
        : _kasaSutunFocusZinciri(kasaIdx ?? 0);
    int index = chain.indexOf(currentFocus);
    if (index != -1 && index + 1 < chain.length) {
      chain[index + 1].requestFocus();
    }
  }

  void _yukariAkit(FocusNode currentFocus,
      {int? kasaIdx, bool isIsim = false}) {
    List<FocusNode> chain = isIsim
        ? _isimSutunFocusZinciri()
        : _kasaSutunFocusZinciri(kasaIdx ?? 0);
    int index = chain.indexOf(currentFocus);
    if (index > 0) {
      chain[index - 1].requestFocus();
    }
  }

  void _sayiyiYuvarlaVeFormatla(TextEditingController ctrl) {
    String text = ctrl.text.trim();
    if (text.isEmpty) return;
    String temiz = text.replaceAll('.', '').replaceAll(',', '.');
    double? val = double.tryParse(temiz);
    if (val != null) {
      int yuvarlanmis = val.round();
      ctrl.text = '${NumberFormat("#,##0", "tr_TR").format(yuvarlanmis)},00';
      setState(() {});
    }
  }

  double _parse(String text) {
    if (text.isEmpty) return 0.0;
    String temiz = text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(temiz) ?? 0.0;
  }

  double _kasaDinamikToplam(List<DinamikKalemSatiri> liste, int kasaIndex) {
    double top = 0.0;
    for (var item in liste) {
      if (kasaIndex == 0) top += _parse(item.k1Ctrl.text);
      if (kasaIndex == 1) top += _parse(item.k2Ctrl.text);
      if (kasaIndex == 2) top += _parse(item.k3Ctrl.text);
    }
    return top;
  }

  double kasaFarkiHesapla(int i) {
    final z = zRaporuSistem[i];
    final n = _parse(nakitCtrl[i].text);
    final isb = _parse(isbankCtrl[i].text);
    final zir = _parse(ziraatCtrl[i].text);
    final digerPos = _parse(digerBankaCtrl[i].text);
    final bz = _parse(bozukCtrl[i].text);
    final pos = _parse(posetCtrl[i].text);
    final iad = _parse(iadeCtrl[i].text);
    final yrd = _parse(yardimCtrl[i].text);
    final isk = _parse(iskontoCtrl[i].text);
    final eld = _parse(eldenCtrl[i].text);

    final verTop = _kasaDinamikToplam(veresiyeListesi, i);
    final gvTop = _kasaDinamikToplam(gelenVeresiyeListesi, i);
    final gidTop = _kasaDinamikToplam(giderListesi, i);

    return z -
        (n + isb + zir + digerPos + bz + verTop + pos + iad + yrd + isk) +
        gvTop -
        (gidTop + eld);
  }

  double get bugunkuNetVeresiyeDegisimi {
    double vTop = 0.0;
    double gvTop = 0.0;
    for (int i = 0; i < 3; i++) {
      vTop += _kasaDinamikToplam(veresiyeListesi, i);
      gvTop += _kasaDinamikToplam(gelenVeresiyeListesi, i);
    }
    return vTop - gvTop;
  }

  double get genelKumulatifVeresiyeToplam {
    double dundenDevir = _parse(veresiyeDevirCtrl.text);
    return dundenDevir + bugunkuNetVeresiyeDegisimi;
  }

  double get genelNakitToplam {
    return _parse(nakitCtrl[0].text) +
        _parse(nakitCtrl[1].text) +
        _parse(nakitCtrl[2].text);
  }

  double get genelNakitArtiBozukToplam {
    double bozukTop = _parse(bozukCtrl[0].text) +
        _parse(bozukCtrl[1].text) +
        _parse(bozukCtrl[2].text);
    double eldenTop = _parse(eldenCtrl[0].text) +
        _parse(eldenCtrl[1].text) +
        _parse(eldenCtrl[2].text);
    return genelNakitToplam + bozukTop + eldenTop;
  }

  double get genelCiroToplam =>
      zRaporuSistem[0] + zRaporuSistem[1] + zRaporuSistem[2];

  String get pdfDosyaAdi {
    const aylar = [
      '',
      'OCAK',
      'ŞUBAT',
      'MART',
      'NİSAN',
      'MAYIS',
      'HAZİRAN',
      'TEMMUZ',
      'AĞUSTOS',
      'EYLÜL',
      'EKİM',
      'KASIM',
      'ARALIK'
    ];
    return '${secilenTarihDt.day} ${aylar[secilenTarihDt.month]} ${secilenTarihDt.year}';
  }

  Future<void> verileriGetir() async {
    setState(() => yukleniyor = true);
    try {
      final posRes = await supabase
          .from('mikro_kasa_detaylari')
          .select()
          .eq('tarih', secilenTarihIso);

      final posList = posRes as List;
      for (int k = 1; k <= 3; k++) {
        Map<String, dynamic>? posKasa;
        for (var item in posList) {
          if (item['kasa_adi'] == 'Kasa $k') {
            posKasa = item;
            break;
          }
        }
        zRaporuSistem[k - 1] =
            (posKasa?['net_tutar'] as num?)?.toDouble() ?? 0.0;
      }

      final manRes = await supabase
          .from('kasa_kapanis_manuel')
          .select()
          .eq('tarih', secilenTarihIso);

      for (int i = 0; i < 3; i++) {
        nakitCtrl[i].clear();
        isbankCtrl[i].clear();
        ziraatCtrl[i].clear();
        digerBankaCtrl[i].clear();
        bozukCtrl[i].clear();
        posetCtrl[i].clear();
        iadeCtrl[i].clear();
        yardimCtrl[i].clear();
        iskontoCtrl[i].clear();
        eldenCtrl[i].clear();
      }
      digerBankaAdiCtrl.clear();

      final kayitListesi = manRes as List;
      if (kayitListesi.isNotEmpty) {
        kilitliMi = true;
        for (var row in kayitListesi) {
          final kNo = (row['kasa_no'] as int?) ?? 1;
          if (kNo >= 1 && kNo <= 3) {
            final idx = kNo - 1;
            nakitCtrl[idx].text = _sayiFormatla(row['nakit']);
            isbankCtrl[idx].text = _sayiFormatla(row['isbank_pos']);
            ziraatCtrl[idx].text = _sayiFormatla(row['ziraat_pos']);
            bozukCtrl[idx].text = _sayiFormatla(row['bozuk_para']);
            posetCtrl[idx].text = _sayiFormatla(row['poset_bedeli']);
            iadeCtrl[idx].text = _sayiFormatla(row['iade']);
            yardimCtrl[idx].text = _sayiFormatla(row['yardim_ceki']);
            iskontoCtrl[idx].text = _sayiFormatla(row['iskonto']);
            eldenCtrl[idx].text = _sayiFormatla(row['elden_verilen_nakit']);

            try {
              if (row['diger_banka_adi'] != null) {
                digerBankaAdiCtrl.text = row['diger_banka_adi'].toString();
              }
              if (row['diger_banka_pos'] != null) {
                digerBankaCtrl[idx].text =
                    _sayiFormatla(row['diger_banka_pos']);
              }
            } catch (_) {}

            _kalemleriListeyeDoldur(
                row['veresiye_kalemleri'], veresiyeListesi, idx);
            _kalemleriListeyeDoldur(
                row['gelen_veresiye_kalemleri'], gelenVeresiyeListesi, idx);
            _kalemleriListeyeDoldur(row['gider_kalemleri'], giderListesi, idx);
          }
        }
      } else {
        kilitliMi = false;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => yukleniyor = false);
    }
  }

  void _kalemleriListeyeDoldur(
      dynamic data, List<DinamikKalemSatiri> hedefListe, int kasaIdx) {
    if (data == null || data is! List) return;
    for (var item in data) {
      final isim = item['isim']?.toString().trim() ?? '';
      final tutar = _sayiFormatla(item['tutar']);
      if (isim.isEmpty && tutar == '0,00') continue;

      DinamikKalemSatiri? mevcut;
      for (var s in hedefListe) {
        if (s.isimCtrl.text.trim().toUpperCase() == isim.toUpperCase()) {
          mevcut = s;
          break;
        }
      }
      if (mevcut == null) {
        for (var s in hedefListe) {
          if (s.isimCtrl.text.trim().isEmpty) {
            mevcut = s;
            mevcut.isimCtrl.text = isim;
            break;
          }
        }
      }
      if (mevcut == null) {
        mevcut = DinamikKalemSatiri(isim: isim);
        hedefListe.add(mevcut);
      }
      if (kasaIdx == 0) mevcut.k1Ctrl.text = tutar;
      if (kasaIdx == 1) mevcut.k2Ctrl.text = tutar;
      if (kasaIdx == 2) mevcut.k3Ctrl.text = tutar;
    }
  }

  String _sayiFormatla(dynamic val) {
    if (val == null || val == 0 || val == 0.0) return '0,00';
    double d = (val as num).toDouble();
    return '${NumberFormat("#,##0", "tr_TR").format(d.round())},00';
  }

  Future<void> kaydet() async {
    setState(() => yukleniyor = true);
    try {
      for (int k = 1; k <= 3; k++) {
        final idx = k - 1;
        List<Map<String, dynamic>> vKalem = [];
        for (var s in veresiyeListesi) {
          final t = _parse(idx == 0
              ? s.k1Ctrl.text
              : (idx == 1 ? s.k2Ctrl.text : s.k3Ctrl.text));
          final isim = s.isimCtrl.text.trim().toUpperCase();
          if (t > 0 || isim.isNotEmpty) {
            vKalem.add({'isim': isim, 'tutar': t});
          }
        }

        List<Map<String, dynamic>> gvKalem = [];
        for (var s in gelenVeresiyeListesi) {
          final t = _parse(idx == 0
              ? s.k1Ctrl.text
              : (idx == 1 ? s.k2Ctrl.text : s.k3Ctrl.text));
          final isim = s.isimCtrl.text.trim().toUpperCase();
          if (t > 0 || isim.isNotEmpty) {
            gvKalem.add({'isim': isim, 'tutar': t});
          }
        }

        List<Map<String, dynamic>> gidKalem = [];
        for (var s in giderListesi) {
          final t = _parse(idx == 0
              ? s.k1Ctrl.text
              : (idx == 1 ? s.k2Ctrl.text : s.k3Ctrl.text));
          final isim = s.isimCtrl.text.trim().toUpperCase();
          if (t > 0 || isim.isNotEmpty) {
            gidKalem.add({'isim': isim, 'tutar': t});
          }
        }

        final Map<String, dynamic> upsertData = {
          'tarih': secilenTarihIso,
          'kasa_no': k,
          'nakit': _parse(nakitCtrl[idx].text),
          'isbank_pos': _parse(isbankCtrl[idx].text),
          'ziraat_pos': _parse(ziraatCtrl[idx].text),
          'bozuk_para': _parse(bozukCtrl[idx].text),
          'poset_bedeli': _parse(posetCtrl[idx].text),
          'iade': _parse(iadeCtrl[idx].text),
          'yardim_ceki': _parse(yardimCtrl[idx].text),
          'iskonto': _parse(iskontoCtrl[idx].text),
          'elden_verilen_nakit': _parse(eldenCtrl[idx].text),
          'z_raporu': zRaporuSistem[idx],
          'veresiye_toplam': _kasaDinamikToplam(veresiyeListesi, idx),
          'veresiye_kalemleri': vKalem,
          'gelen_veresiye_kalemleri': gvKalem,
          'gider_kalemleri': gidKalem,
          'guncellenme_tarihi': DateTime.now().toIso8601String(),
        };

        if (digerBankaAdiCtrl.text.trim().isNotEmpty ||
            _parse(digerBankaCtrl[idx].text) > 0) {
          upsertData['diger_banka_adi'] =
              digerBankaAdiCtrl.text.trim().toUpperCase();
          upsertData['diger_banka_pos'] = _parse(digerBankaCtrl[idx].text);
        }

        await supabase.from('kasa_kapanis_manuel').upsert(
              upsertData,
              onConflict: 'tarih,kasa_no',
            );
      }
      setState(() => kilitliMi = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm kasalar kaydedildi ve kilitlendi!'),
            backgroundColor: Color(0xFF0369A1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => yukleniyor = false);
    }
  }

  // --- 26 EKİM.XLSX BİREBİR A4 PORTRAIT TEK SAYFA BASKI ÖNİZLEMESİ (15 SATIR VERESİYE) ---
  void _excelGorunumuYazdir() {
    final tarihStr = _tarihFormatGoster.format(secilenTarihDt);
    final dosyaAdi = pdfDosyaAdi;
    final digerBankaAdi = digerBankaAdiCtrl.text.trim().toUpperCase();

    String fPara(double val) {
      if (val == 0.0) return '';
      return NumberFormat("#,##0", "tr_TR").format(val);
    }

    String fStr(String val) {
      final d = _parse(val);
      if (d == 0.0) return '';
      return NumberFormat("#,##0", "tr_TR").format(d);
    }

    final htmlIcerik = '''
    <!DOCTYPE html>
    <html lang="tr">
    <head>
      <meta charset="UTF-8">
      <title>$dosyaAdi</title>
      <style>
        @page { 
          size: A4 portrait; 
          margin: 4mm 10mm 2mm 10mm; 
        }
        * { 
          box-sizing: border-box; 
          -webkit-print-color-adjust: exact !important; 
          print-color-adjust: exact !important; 
        }
        html, body { 
          width: 100%;
          margin: 0; 
          padding: 0; 
          font-family: 'Calibri', Arial, sans-serif; 
          color: #000;
          background: #fff;
        }
        .excel-sheet {
          width: 190mm;
          margin: 0 auto;
        }
        table.excel-table { 
          border-collapse: collapse; 
          width: 100%; 
          table-layout: fixed;
          border: none;
        }
        table.excel-table td { 
          border: 1px solid #000; 
          padding: 0 4px; 
          font-size: 10pt; 
          height: 22.2px; 
          overflow: hidden;
          vertical-align: middle;
        }
        .mavi { 
          background-color: #8DF5F5 !important; 
          font-weight: bold; 
          text-align: center; 
          font-size: 10.5pt; 
        }
        .kasa-baslik { 
          background-color: #8DF5F5 !important; 
          font-weight: bold; 
          text-align: center; 
          font-size: 11pt; 
        }
        .tarih-kutusu { 
          font-size: 12pt; 
          font-weight: bold; 
          text-align: center; 
        }

        td.dikey-bosluk {
          width: 5px !important;
          max-width: 5px !important;
          padding: 0 !important;
          border: none !important;
          background-color: transparent !important;
        }

        tr.bosluk-satir td { 
          height: 3.5px !important; 
          line-height: 3.5px !important;
          padding: 0 !important; 
          border: none !important;
          background-color: transparent !important; 
        }

        .dikey-baslik {
          background-color: #8DF5F5 !important;
          font-weight: bold; 
          text-align: center; 
          vertical-align: middle !important;
          width: 36px !important;
          padding: 0 !important;
        }
        .dikey-yazi {
          writing-mode: vertical-rl;
          transform: rotate(180deg);
          white-space: nowrap;
          font-size: 10pt; 
          font-weight: bold; 
          letter-spacing: 1.2px;
          margin: auto;
        }
        .kalem-adi { 
          font-weight: bold; 
          font-size: 9.5pt; 
          padding-left: 6px !important; 
        }
        .sayi { 
          text-align: right; 
          font-size: 10pt; 
          font-weight: normal; 
          padding-right: 6px !important; 
        }
        .fark-hucre { 
          text-align: right; 
          font-size: 10.5pt; 
          font-weight: normal; 
          padding-right: 6px !important; 
        }

        td.alt-bos-alan {
          border: none !important;
          background: transparent !important;
        }
        .alt-baslik {
          background-color: #8DF5F5 !important;
          font-weight: bold;
          font-size: 10.5pt;
          text-align: left;
          padding-left: 6px !important;
        }
      </style>
    </head>
    <body>
      <div class="excel-sheet">
        <table class="excel-table">
          <colgroup>
            <col style="width: 36px;">
            <col style="width: 254px;">
            <col style="width: 5px;">
            <col style="width: 130px;">
            <col style="width: 5px;">
            <col style="width: 130px;">
            <col style="width: 5px;">
            <col style="width: 130px;">
          </colgroup>

          <!-- Satır 1: Tarih ve Kasa Başlıkları -->
          <tr style="height: 24px;">
            <td colspan="2" class="tarih-kutusu">$tarihStr</td>
            <td class="dikey-bosluk"></td>
            <td class="kasa-baslik">KASA-1</td>
            <td class="dikey-bosluk"></td>
            <td class="kasa-baslik">KASA-2</td>
            <td class="dikey-bosluk"></td>
            <td class="kasa-baslik">KASA-3</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 3: NAKİT -->
          <tr>
            <td colspan="2" class="mavi">NAKİT</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(nakitCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(nakitCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(nakitCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 5: İŞBANK POS -->
          <tr>
            <td colspan="2" class="mavi">İŞBANK POS</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(isbankCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(isbankCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(isbankCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 7: ZİRAAT POS -->
          <tr>
            <td colspan="2" class="mavi">ZİRAAT POS</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(ziraatCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(ziraatCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(ziraatCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 9: Diğer Banka POS -->
          <tr>
            <td colspan="2" class="mavi">${digerBankaAdi.isEmpty ? '' : digerBankaAdi}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(digerBankaCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(digerBankaCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(digerBankaCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 11: BOZUK PARA -->
          <tr>
            <td colspan="2" class="mavi">BOZUK PARA</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(bozukCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(bozukCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(bozukCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 13-27: VERESİYE SATIŞ (15 Satır) -->
          ${List.generate(veresiyeListesi.length, (i) {
      final item = veresiyeListesi[i];
      String sol = i == 0
          ? '<td rowspan="${veresiyeListesi.length}" class="dikey-baslik"><div class="dikey-yazi">VERESİYE SATIŞ</div></td>'
          : '';
      return '<tr>$sol<td class="kalem-adi">${item.isimCtrl.text.toUpperCase()}</td><td class="dikey-bosluk"></td><td class="sayi">${fStr(item.k1Ctrl.text)}</td><td class="dikey-bosluk"></td><td class="sayi">${fStr(item.k2Ctrl.text)}</td><td class="dikey-bosluk"></td><td class="sayi">${fStr(item.k3Ctrl.text)}</td></tr>';
    }).join('')}
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 29: POŞET -->
          <tr>
            <td colspan="2" class="mavi">POŞET</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(posetCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(posetCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(posetCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 31: İADE -->
          <tr>
            <td colspan="2" class="mavi">İADE</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(iadeCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(iadeCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(iadeCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 33: YARDIM ÇEKİ -->
          <tr>
            <td colspan="2" class="mavi">YARDIM ÇEKİ</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(yardimCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(yardimCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(yardimCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 35: İSKONTO -->
          <tr>
            <td colspan="2" class="mavi">İSKONTO</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(iskontoCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(iskontoCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(iskontoCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 37-42: GELEN VERESİYE (6 Satır) -->
          ${List.generate(gelenVeresiyeListesi.length, (i) {
      final item = gelenVeresiyeListesi[i];
      String sol = i == 0
          ? '<td rowspan="${gelenVeresiyeListesi.length}" class="dikey-baslik"><div class="dikey-yazi">GELEN VERESİYE</div></td>'
          : '';
      return '<tr>$sol<td class="kalem-adi">${item.isimCtrl.text.toUpperCase()}</td><td class="dikey-bosluk"></td><td class="sayi">${fStr(item.k1Ctrl.text)}</td><td class="dikey-bosluk"></td><td class="sayi">${fStr(item.k2Ctrl.text)}</td><td class="dikey-bosluk"></td><td class="sayi">${fStr(item.k3Ctrl.text)}</td></tr>';
    }).join('')}
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 44-49: GİDER (6 Satır) -->
          ${List.generate(giderListesi.length, (i) {
      final item = giderListesi[i];
      String sol = i == 0
          ? '<td rowspan="${giderListesi.length}" class="dikey-baslik"><div class="dikey-yazi">GİDER</div></td>'
          : '';
      return '<tr>$sol<td class="kalem-adi">${item.isimCtrl.text.toUpperCase()}</td><td class="dikey-bosluk"></td><td class="sayi">${fStr(item.k1Ctrl.text)}</td><td class="dikey-bosluk"></td><td class="sayi">${fStr(item.k2Ctrl.text)}</td><td class="dikey-bosluk"></td><td class="sayi">${fStr(item.k3Ctrl.text)}</td></tr>';
    }).join('')}

          <!-- Satır 50: ELDEN VERİLEN NAKİT -->
          <tr>
            <td colspan="2" class="mavi">ELDEN VERİLEN NAKİT</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(eldenCtrl[0].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(eldenCtrl[1].text)}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fStr(eldenCtrl[2].text)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 52: Z RAPORU -->
          <tr>
            <td colspan="2" class="mavi">Z RAPORU</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi" style="font-weight:bold;">${fPara(zRaporuSistem[0])}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi" style="font-weight:bold;">${fPara(zRaporuSistem[1])}</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi" style="font-weight:bold;">${fPara(zRaporuSistem[2])}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 54: FARK -->
          <tr>
            <td colspan="2" class="mavi">FARK</td>
            <td class="dikey-bosluk"></td>
            <td class="fark-hucre">${fPara(kasaFarkiHesapla(0))}</td>
            <td class="dikey-bosluk"></td>
            <td class="fark-hucre">${fPara(kasaFarkiHesapla(1))}</td>
            <td class="dikey-bosluk"></td>
            <td class="fark-hucre">${fPara(kasaFarkiHesapla(2))}</td>
          </tr>
          <tr class="bosluk-satir" style="height: 4px !important;"><td colspan="8"></td></tr>

          <!-- Satır 56: VERESİYE -->
          <tr>
            <td colspan="4" class="alt-bos-alan"></td>
            <td class="alt-bos-alan"></td>
            <td class="alt-baslik">VERESİYE</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fPara(genelKumulatifVeresiyeToplam)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 58: NAKİT -->
          <tr>
            <td colspan="4" class="alt-bos-alan"></td>
            <td class="alt-bos-alan"></td>
            <td class="alt-baslik">NAKİT</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fPara(genelNakitToplam)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 60: NAKİT+BOZUK PARA -->
          <tr>
            <td colspan="4" class="alt-bos-alan"></td>
            <td class="alt-bos-alan"></td>
            <td class="alt-baslik">NAKİT+BOZUK PARA</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fPara(genelNakitArtiBozukToplam)}</td>
          </tr>
          <tr class="bosluk-satir"><td colspan="8"></td></tr>

          <!-- Satır 62: CİRO -->
          <tr>
            <td colspan="4" class="alt-bos-alan"></td>
            <td class="alt-bos-alan"></td>
            <td class="alt-baslik">CİRO</td>
            <td class="dikey-bosluk"></td>
            <td class="sayi">${fPara(genelCiroToplam)}</td>
          </tr>
        </table>
      </div>

      <script>
        document.title = '$dosyaAdi';
        window.print();
      </script>
    </body>
    </html>
    ''';

    final blob = html.Blob([htmlIcerik], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Üst Yönetim Barı
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(
                    bottom: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'KASA KAPANIŞ MUTABAKATI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (kilitliMi)
                        SizedBox(
                          height: 30,
                          child: ElevatedButton.icon(
                            onPressed: () => setState(() => kilitliMi = false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade500,
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.lock_open, size: 14),
                            label: const Text('DÜZENLE',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                        )
                      else
                        SizedBox(
                          height: 30,
                          child: ElevatedButton.icon(
                            onPressed: kaydet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.save, size: 14),
                            label: const Text('KAYDET',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.print,
                            color: Color(0xFF8DF5F5), size: 20),
                        tooltip: 'Yazdır / PDF',
                        onPressed: _excelGorunumuYazdir,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left,
                                  color: Colors.white70, size: 18),
                              tooltip: 'Önceki Gün',
                              onPressed: () {
                                setState(() => secilenTarihDt = secilenTarihDt
                                    .subtract(const Duration(days: 1)));
                                verileriGetir();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26),
                            ),
                            InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: secilenTarihDt,
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) {
                                  setState(() => secilenTarihDt = d);
                                  verileriGetir();
                                }
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month,
                                        color: Color(0xFF8DF5F5), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _tarihFormatGoster.format(secilenTarihDt),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right,
                                  color: Colors.white70, size: 18),
                              tooltip: 'Sonraki Gün',
                              onPressed: () {
                                setState(() => secilenTarihDt = secilenTarihDt
                                    .add(const Duration(days: 1)));
                                verileriGetir();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: kilitliMi
                              ? Colors.amber.withValues(alpha: 0.15)
                              : const Color(0xFF0284C7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: kilitliMi
                                ? Colors.amber.shade400
                                : const Color(0xFF38BDF8),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          kilitliMi ? 'KİLİTLİ' : 'DÜZENLENEBİLİR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: kilitliMi
                                ? Colors.amber.shade300
                                : const Color(0xFFBAE6FD),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Veresiye Devir / Veresiye Toplam İkiz Kartları & Tablo
            Expanded(
              child: yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.blueGrey.shade300,
                                          width: 1.2),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Veresiye Devir:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Focus(
                                            onFocusChange: (hasFocus) {
                                              if (!hasFocus) {
                                                _sayiyiYuvarlaVeFormatla(
                                                    veresiyeDevirCtrl);
                                              }
                                            },
                                            child: TextField(
                                              controller: veresiyeDevirCtrl,
                                              readOnly: kilitliMi,
                                              textAlign: TextAlign.right,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              onSubmitted: (_) =>
                                                  _sayiyiYuvarlaVeFormatla(
                                                      veresiyeDevirCtrl),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                  color: Color(0xFF0F172A)),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.blueGrey.shade300,
                                          width: 1.2),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Veresiye Toplam:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              color: Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          '${NumberFormat("#,##0", "tr_TR").format(genelKumulatifVeresiyeToplam.round())},00 TL',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0369A1),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Tablo
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: Colors.black, width: 1.5),
                            ),
                            child: Column(
                              children: [
                                _satirBandi(
                                    'TARİH / KALEMLER',
                                    [
                                      'KASA-1 (TL)',
                                      'KASA-2 (TL)',
                                      'KASA-3 (TL)',
                                    ],
                                    isHeader: true),
                                _inputSatir('NAKİT', nakitCtrl, nakitFocus),
                                _inceBosluk(),
                                _inputSatir(
                                    'İŞBANK POS', isbankCtrl, isbankFocus),
                                _inceBosluk(),
                                _inputSatir(
                                    'ZİRAAT POS', ziraatCtrl, ziraatFocus),
                                _inceBosluk(),
                                _yedekBankaSatiri(),
                                _inceBosluk(),
                                _inputSatir(
                                    'BOZUK PARA', bozukCtrl, bozukFocus),
                                _inceBosluk(),
                                _blokBaslik('VERESİYE SATIŞ (15 SATIR)'),
                                ...veresiyeListesi
                                    .map((e) => _dinamikInputSatir(e)),
                                _inceBosluk(),
                                _inputSatir('POŞET', posetCtrl, posetFocus),
                                _inceBosluk(),
                                _inputSatir('İADE', iadeCtrl, iadeFocus),
                                _inceBosluk(),
                                _inputSatir(
                                    'YARDIM ÇEKİ', yardimCtrl, yardimFocus),
                                _inceBosluk(),
                                _inputSatir(
                                    'İSKONTO', iskontoCtrl, iskontoFocus),
                                _inceBosluk(),
                                _blokBaslik('GELEN VERESİYE (6 SATIR)'),
                                ...gelenVeresiyeListesi
                                    .map((e) => _dinamikInputSatir(e)),
                                _inceBosluk(),
                                _blokBaslik('GİDER (6 SATIR)'),
                                ...giderListesi
                                    .map((e) => _dinamikInputSatir(e)),
                                _inputSatir('ELDEN VERİLEN NAKİT', eldenCtrl,
                                    eldenFocus),
                                _inceBosluk(),
                                _saltOkunurSatir(
                                    'Z RAPORU (DYNMASTER)',
                                    [
                                      NumberFormat("#,##0", "tr_TR")
                                          .format(zRaporuSistem[0]),
                                      NumberFormat("#,##0", "tr_TR")
                                          .format(zRaporuSistem[1]),
                                      NumberFormat("#,##0", "tr_TR")
                                          .format(zRaporuSistem[2]),
                                    ],
                                    renk: const Color(0xFFF0FDF4)),
                                _inceBosluk(),
                                _saltOkunurSatir(
                                    'FARK (KASA AÇIĞI / FAZLASI)',
                                    [
                                      NumberFormat("#,##0", "tr_TR")
                                          .format(kasaFarkiHesapla(0)),
                                      NumberFormat("#,##0", "tr_TR")
                                          .format(kasaFarkiHesapla(1)),
                                      NumberFormat("#,##0", "tr_TR")
                                          .format(kasaFarkiHesapla(2)),
                                    ],
                                    renk: const Color(0xFFFEF08A),
                                    isBold: true),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Sağ Alt Özet Tablosu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 280,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: Colors.black, width: 1.5),
                                ),
                                child: Column(
                                  children: [
                                    _altOzetSatir('VERESİYE',
                                        genelKumulatifVeresiyeToplam),
                                    _altOzetSatir('NAKİT', genelNakitToplam),
                                    _altOzetSatir('NAKİT+BOZUK PARA',
                                        genelNakitArtiBozukToplam),
                                    _altOzetSatir('CİRO', genelCiroToplam,
                                        isLast: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inceBosluk() => Container(height: 4, color: const Color(0xFFE2E8F0));

  Widget _blokBaslik(String baslik) {
    return Container(
      color: const Color(0xFF8DF5F5).withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      alignment: Alignment.centerLeft,
      child: Text(baslik,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF0F172A))),
    );
  }

  Widget _satirBandi(String baslik, List<String> kolonlar,
      {bool isHeader = false}) {
    return Container(
      color: const Color(0xFF8DF5F5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
              flex: 5,
              child: Text(baslik,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13))),
          ...kolonlar.map((k) => Expanded(
                flex: 3,
                child: Text(k,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight:
                            isHeader ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13)),
              )),
        ],
      ),
    );
  }

  Widget _yedekBankaSatiri() {
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: digerBankaAdiCtrl,
              focusNode: digerBankaAdiFocus,
              readOnly: kilitliMi,
              inputFormatters: [TurkceBuyukHarfFormatter()],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _asagiAkit(digerBankaAdiFocus, isIsim: true),
              style: TextStyle(
                  color: kilitliMi ? Colors.grey.shade700 : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
              decoration: InputDecoration(
                hintText: 'DİĞER BANKA POS',
                hintStyle: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey.shade300,
                    fontWeight: FontWeight.normal),
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              ),
            ),
          ),
          ...List.generate(
            3,
            (i) => Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _sayiyiYuvarlaVeFormatla(digerBankaCtrl[i]);
                  },
                  child: TextField(
                    controller: digerBankaCtrl[i],
                    focusNode: digerBankaFocus[i],
                    readOnly: kilitliMi,
                    textAlign: TextAlign.right,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      _sayiyiYuvarlaVeFormatla(digerBankaCtrl[i]);
                      _asagiAkit(digerBankaFocus[i], kasaIdx: i);
                    },
                    style: TextStyle(
                        color: kilitliMi ? Colors.grey.shade700 : Colors.black,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0,00',
                      fillColor:
                          kilitliMi ? Colors.grey.shade100 : Colors.white,
                      filled: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputSatir(String baslik, List<TextEditingController> ctrls,
      List<FocusNode> focusNodes) {
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        children: [
          Expanded(
              flex: 5,
              child: Text(baslik,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12))),
          ...List.generate(
            3,
            (i) => Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _sayiyiYuvarlaVeFormatla(ctrls[i]);
                  },
                  child: TextField(
                    controller: ctrls[i],
                    focusNode: focusNodes[i],
                    readOnly: kilitliMi,
                    textAlign: TextAlign.right,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      _sayiyiYuvarlaVeFormatla(ctrls[i]);
                      _asagiAkit(focusNodes[i], kasaIdx: i);
                    },
                    style: TextStyle(
                        color: kilitliMi ? Colors.grey.shade700 : Colors.black,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0,00',
                      fillColor:
                          kilitliMi ? Colors.grey.shade100 : Colors.white,
                      filled: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dinamikInputSatir(DinamikKalemSatiri item) {
    final kasaFocusNodes = [item.k1Focus, item.k2Focus, item.k3Focus];
    final kasaCtrls = [item.k1Ctrl, item.k2Ctrl, item.k3Ctrl];

    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: item.isimCtrl,
              focusNode: item.isimFocus,
              readOnly: kilitliMi,
              inputFormatters: [TurkceBuyukHarfFormatter()],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _asagiAkit(item.isimFocus, isIsim: true),
              style: TextStyle(
                  color: kilitliMi ? Colors.grey.shade700 : Colors.black,
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'AÇIKLAMA / KİŞİ',
                isDense: true,
                fillColor: kilitliMi ? Colors.grey.shade100 : Colors.white,
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
            ),
          ),
          ...List.generate(
            3,
            (i) => Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _sayiyiYuvarlaVeFormatla(kasaCtrls[i]);
                  },
                  child: TextField(
                    controller: kasaCtrls[i],
                    focusNode: kasaFocusNodes[i],
                    readOnly: kilitliMi,
                    textAlign: TextAlign.right,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      _sayiyiYuvarlaVeFormatla(kasaCtrls[i]);
                      _asagiAkit(kasaFocusNodes[i], kasaIdx: i);
                    },
                    style: TextStyle(
                        color: kilitliMi ? Colors.grey.shade700 : Colors.black,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0,00',
                      fillColor:
                          kilitliMi ? Colors.grey.shade100 : Colors.white,
                      filled: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saltOkunurSatir(String baslik, List<String> degerler,
      {Color? renk, bool isBold = false}) {
    return Container(
      color: renk ?? Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Expanded(
              flex: 5,
              child: Text(baslik,
                  style: TextStyle(
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12))),
          ...degerler.map((d) => Expanded(
                flex: 3,
                child: Text(d,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                        fontSize: 13)),
              )),
        ],
      ),
    );
  }

  Widget _altOzetSatir(String baslik, double deger, {bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: Colors.grey.shade400))),
      child: Row(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF8DF5F5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(baslik,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(NumberFormat("#,##0", "tr_TR").format(deger.round()),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
