import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

class HareketsizStokEkrani extends StatefulWidget {
  final String? rol;

  const HareketsizStokEkrani({super.key, this.rol});

  @override
  State<HareketsizStokEkrani> createState() => _HareketsizStokEkraniState();
}

class _HareketsizStokEkraniState extends State<HareketsizStokEkrani> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _aramaController = TextEditingController();
  final NumberFormat _paraFormat =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final NumberFormat _sayiFormat = NumberFormat.decimalPattern('tr_TR');

  List<Map<String, dynamic>> _hareketsizUrunler = [];
  bool _yukleniyor = true;
  String _aramaKelimesi = '';
  String _kullaniciRolu = 'reyoncu';
  List<String> _kullaniciAtananGruplari = [];

  int _seciliGun = 15;
  double _minStok = 10.0;
  bool _sifirStokGizle = true;
  bool _stokCoktanAza = true;

  static const int _sayfaBoyutu = 100;
  int _mevcutSayfa = 1;

  int _toplamCesit = 0;
  double _toplamStokMiktari = 0.0;
  double _toplamTutar = 0.0;

  @override
  void initState() {
    super.initState();
    _rolVeGruplariYukle();
  }

  String _turkceBuyuk(String text) {
    return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase().trim();
  }

  Future<void> _rolVeGruplariYukle() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profil = await _supabase
            .from('profiller')
            .select('rol, atanan_gruplar')
            .eq('id', user.id)
            .maybeSingle();

        if (profil != null) {
          _kullaniciRolu =
              (profil['rol'] ?? 'reyoncu').toString().trim().toLowerCase();

          final dynamic rawGruplar = profil['atanan_gruplar'];
          List<dynamic> parsedList = [];

          if (rawGruplar is List) {
            parsedList = rawGruplar;
          } else if (rawGruplar is String && rawGruplar.trim().isNotEmpty) {
            try {
              final decoded = jsonDecode(rawGruplar);
              if (decoded is List) parsedList = decoded;
            } catch (_) {
              parsedList =
                  rawGruplar.replaceAll('{', '').replaceAll('}', '').split(',');
            }
          }

          _kullaniciAtananGruplari = parsedList
              .map((e) => _turkceBuyuk(e.toString()))
              .where((e) => e.isNotEmpty)
              .toList();
        } else if (widget.rol != null) {
          _kullaniciRolu = widget.rol!.trim().toLowerCase();
        }
      }
    } catch (_) {}
    _hareketsizStoklariGetir();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  bool _ozelKarakterliMi(String s) {
    final temiz = s.trim();
    if (temiz.isEmpty) return true;
    final upper = _turkceBuyuk(temiz);
    if (upper.startsWith('X/') ||
        upper.startsWith('X//') ||
        upper.startsWith('X///')) {
      return true;
    }
    const trHarfler = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ0123456789';
    return !trHarfler.contains(upper[0]);
  }

  int _turkceKarsilastir(String a, String b) {
    final bool aOzel = _ozelKarakterliMi(a);
    final bool bOzel = _ozelKarakterliMi(b);

    if (aOzel != bOzel) {
      return aOzel ? 1 : -1;
    }

    const trAlfabe = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ0123456789';
    final sA = _turkceBuyuk(a.trim());
    final sB = _turkceBuyuk(b.trim());
    final minLen = sA.length < sB.length ? sA.length : sB.length;

    for (int i = 0; i < minLen; i++) {
      final charA = sA[i];
      final charB = sB[i];
      if (charA != charB) {
        final idxA = trAlfabe.indexOf(charA);
        final idxB = trAlfabe.indexOf(charB);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        return charA.compareTo(charB);
      }
    }
    return sA.length.compareTo(sB.length);
  }

  Future<void> _kameraIleBarkodOku() async {
    final okunan = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title:
                    const Text('Barkod Okutun', style: TextStyle(fontSize: 16)),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty &&
                        barcodes.first.rawValue != null) {
                      final String kod = barcodes.first.rawValue!.trim();
                      Navigator.pop(ctx, kod);
                    }
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black87,
                child: const Text(
                  'Barkodu ekrandaki çerçeveye hizalayınız.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (okunan != null && okunan.isNotEmpty) {
      setState(() {
        _aramaController.text = _turkceBuyuk(okunan);
        _aramaKelimesi = _turkceBuyuk(okunan);
      });
      _hareketsizStoklariGetir();
    }
  }

  String _ayristirUrunAdi(String tamMetin) {
    if (tamMetin.contains(']') && tamMetin.contains('| Barkod:')) {
      final bas = tamMetin.indexOf(']') + 1;
      final son = tamMetin.indexOf('| Barkod:');
      return tamMetin.substring(bas, son).trim();
    } else if (tamMetin.contains(']')) {
      return tamMetin.substring(tamMetin.indexOf(']') + 1).trim();
    }
    return tamMetin.trim();
  }

  String _ayristirBarkod(String tamMetin) {
    if (tamMetin.contains('| Barkod:')) {
      return tamMetin.split('| Barkod:').last.trim();
    }
    return '';
  }

  bool _teraziBarkoduMu(String barkodStr) {
    if (barkodStr.isEmpty) return false;
    final parcalar = barkodStr.split(',');
    for (var b in parcalar) {
      final temizBarkod = b.trim();
      if (temizBarkod.startsWith('27')) {
        return true;
      }
    }
    return false;
  }

  void _sirala(List<Map<String, dynamic>> liste) {
    liste.sort((a, b) {
      final stokA = (a['mikro_stok_miktari'] ?? 0.0).toDouble();
      final stokB = (b['mikro_stok_miktari'] ?? 0.0).toDouble();
      return _stokCoktanAza ? stokB.compareTo(stokA) : stokA.compareTo(stokB);
    });
  }

  Future<void> _hareketsizStoklariGetir() async {
    setState(() => _yukleniyor = true);
    try {
      String satisKolonu = 'son_15_gun_hareket';
      if (_seciliGun == 7) satisKolonu = 'satis_7_gun';
      if (_seciliGun == 30) satisKolonu = 'satis_30_gun';
      if (_seciliGun == 60) satisKolonu = 'satis_60_gun';

      double tabanStok = _minStok;
      if (_sifirStokGizle && tabanStok <= 0) {
        tabanStok = 0.0001;
      }

      List<Map<String, dynamic>> tumHareketsizler = [];
      int baslangic = 0;
      const int adim = 1000;
      bool devam = true;

      final bool sayiMi = int.tryParse(_aramaKelimesi) != null;

      while (devam) {
        dynamic sorgu = _supabase
            .from('mikro_stok_bilgileri')
            .select(
                'barkod, stok_adi, satis_fiyati, alis_fiyati, mikro_stok_miktari, stok_ana_grup, $satisKolonu')
            .eq(satisKolonu, 0);

        if (_sifirStokGizle || tabanStok > 0) {
          sorgu = sorgu.gt('mikro_stok_miktari', tabanStok);
        }

        if (_aramaKelimesi.isNotEmpty) {
          if (sayiMi) {
            sorgu = sorgu.or(
                'barkod.ilike.%$_aramaKelimesi\%,stok_adi.ilike.\%\vert{} Barkod:\%$_aramaKelimesi%%');
          } else {
            final buyukKelime = _turkceBuyuk(_aramaKelimesi);
            sorgu = sorgu.ilike('stok_adi', '%$buyukKelime%');
          }
        }

        final res = await sorgu.range(baslangic, baslangic + adim - 1);
        final parca = List<Map<String, dynamic>>.from(res as List);
        tumHareketsizler.addAll(parca);

        if (parca.length < adim) {
          devam = false;
        } else {
          baslangic += adim;
        }
      }

      final List<Map<String, dynamic>> filtrelenmisListe = [];
      double tStok = 0.0;
      double tTutar = 0.0;

      for (var r in tumHareketsizler) {
        final tamAd = (r['stok_adi'] ?? '').toString();
        final barkodStr = _ayristirBarkod(tamAd);

        if (_teraziBarkoduMu(barkodStr)) {
          continue;
        }

        if (_kullaniciRolu == 'reyoncu') {
          final urunReyonu =
              _turkceBuyuk((r['stok_ana_grup'] ?? 'TANIMSIZ').toString());
          if (!_kullaniciAtananGruplari.contains(urunReyonu)) {
            continue;
          }
        }

        if (_aramaKelimesi.isNotEmpty && !sayiMi) {
          final urunAdi = _turkceBuyuk(_ayristirUrunAdi(tamAd));
          final kelimeler = urunAdi.split(RegExp(r'[\s\-_/]+'));
          if (!kelimeler
              .any((k) => k.startsWith(_turkceBuyuk(_aramaKelimesi)))) {
            continue;
          }
        }

        final stok = (r['mikro_stok_miktari'] ?? 0.0).toDouble();
        final satisFiyat = (r['satis_fiyati'] ?? 0.0).toDouble();
        tStok += stok;
        tTutar += (stok * satisFiyat);

        filtrelenmisListe.add(r);
      }

      if (_aramaKelimesi.isNotEmpty && !sayiMi) {
        filtrelenmisListe.sort((a, b) {
          final adA = _ayristirUrunAdi(a['stok_adi']?.toString() ?? '');
          final adB = _ayristirUrunAdi(b['stok_adi']?.toString() ?? '');
          return _turkceKarsilastir(adA, adB);
        });
      } else {
        _sirala(filtrelenmisListe);
      }

      if (mounted) {
        setState(() {
          _hareketsizUrunler = filtrelenmisListe;
          _toplamCesit = filtrelenmisListe.length;
          _toplamStokMiktari = tStok;
          _toplamTutar = tTutar;
          _mevcutSayfa = 1;
          _yukleniyor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _yukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  // MODERN SAYFA SEÇİM BOTTOM SHEET (Şık ve akıcı)
  void _sayfaSecimPenceresi(int toplamSayfa) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gitmek İstediğiniz Sayfayı Seçin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: toplamSayfa,
                  itemBuilder: (c, idx) {
                    final sayfaNo = idx + 1;
                    final seciliMi = sayfaNo == _mevcutSayfa;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() => _mevcutSayfa = sayfaNo);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: seciliMi
                              ? Colors.indigo.shade900
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: seciliMi
                                ? Colors.indigo.shade900
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          '$sayfaNo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: seciliMi ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool reyoncuMu = _kullaniciRolu == 'reyoncu';

    final int toplamSayfa = (_hareketsizUrunler.length / _sayfaBoyutu).ceil();
    final int baslangicIdx = (_mevcutSayfa - 1) * _sayfaBoyutu;
    final int bitisIdx =
        (baslangicIdx + _sayfaBoyutu > _hareketsizUrunler.length)
            ? _hareketsizUrunler.length
            : baslangicIdx + _sayfaBoyutu;

    final gosterilenler = _hareketsizUrunler.isEmpty
        ? <Map<String, dynamic>>[]
        : _hareketsizUrunler.sublist(baslangicIdx, bitisIdx);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('HAREKETSİZ STOK RAPORU',
            style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _hareketsizStoklariGetir,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _seciliGun,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.red, size: 20),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900),
                            items: const [
                              DropdownMenuItem(
                                  value: 7, child: Text('Son 7 Gün')),
                              DropdownMenuItem(
                                  value: 15, child: Text('Son 15 Gün')),
                              DropdownMenuItem(
                                  value: 30, child: Text('Son 30 Gün')),
                              DropdownMenuItem(
                                  value: 60, child: Text('Son 60 Gün')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                _seciliGun = val;
                                _hareketsizStoklariGetir();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            value: _minStok,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                            items: const [
                              DropdownMenuItem(
                                  value: 0.0, child: Text('Tüm Stoklar')),
                              DropdownMenuItem(
                                  value: 10.0, child: Text('10+ Adet')),
                              DropdownMenuItem(
                                  value: 50.0, child: Text('50+ Adet')),
                              DropdownMenuItem(
                                  value: 100.0, child: Text('100+ Adet')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                _minStok = val;
                                _hareketsizStoklariGetir();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() => _sifirStokGizle = !_sifirStokGizle);
                          _hareketsizStoklariGetir();
                        },
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: _sifirStokGizle
                                ? Colors.red.shade800
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sifirStokGizle
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 15,
                                color: _sifirStokGizle
                                    ? Colors.white
                                    : Colors.red.shade900,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sifirStokGizle
                                    ? '0 Stok: Gizli'
                                    : '0 Stok: Açık',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _sifirStokGizle
                                      ? Colors.white
                                      : Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() {
                            _stokCoktanAza = !_stokCoktanAza;
                            _sirala(_hareketsizUrunler);
                            _mevcutSayfa = 1;
                          });
                        },
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade900,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _stokCoktanAza
                                    ? 'Stok: Çok ➔ Az'
                                    : 'Stok: Az ➔ Çok',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _stokCoktanAza
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: Colors.white,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _aramaController,
                  inputFormatters: [TurkceBuyukHarfFormatter()],
                  decoration: InputDecoration(
                    hintText: 'Ürün adı veya barkod ile ara...',
                    hintStyle:
                        TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: Colors.indigo),
                          tooltip: 'Kamera ile Barkod Oku',
                          onPressed: _kameraIleBarkodOku,
                        ),
                        if (_aramaController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _aramaController.clear();
                              _aramaKelimesi = '';
                              _hareketsizStoklariGetir();
                            },
                          ),
                      ],
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  ),
                  onSubmitted: (val) {
                    _aramaKelimesi = _turkceBuyuk(val.trim());
                    _hareketsizStoklariGetir();
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hareketsiz: $_toplamCesit Çeşit',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                if (!reyoncuMu)
                  Text(
                    'Bağlı Stok: ${_sayiFormat.format(_toplamStokMiktari)} Ad • ${_paraFormat.format(_toplamTutar)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _hareketsizUrunler.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _kullaniciRolu == 'reyoncu' &&
                                        _kullaniciAtananGruplari.isEmpty
                                    ? 'Hesabınıza henüz atanmış bir reyon bulunmuyor.'
                                    : 'Yetkili olduğunuz reyonlarda hareketsiz stok kaydı bulunamadı.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: gosterilenler.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = gosterilenler[index];
                          final stokKod = (item['barkod'] ?? '').toString();
                          final tamAd = (item['stok_adi'] ?? '').toString();
                          final urunAdi = _ayristirUrunAdi(tamAd);
                          final barkod = _ayristirBarkod(tamAd);
                          final reyon =
                              (item['stok_ana_grup'] ?? '').toString();

                          final satis =
                              (item['satis_fiyati'] ?? 0.0).toDouble();
                          final stok =
                              (item['mikro_stok_miktari'] ?? 0.0).toDouble();

                          final siraNo = baslangicIdx + index + 1;

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#$siraNo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '[$stokKod]$urunAdi',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Barkod: ${barkod.isEmpty ? stokKod : barkod}',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.grey.shade600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (reyon.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                      color:
                                                          Colors.grey.shade300),
                                                ),
                                                child: Text(
                                                  reyon,
                                                  style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.grey.shade800),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fiyat: ${_paraFormat.format(satis)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${_sayiFormat.format(stok)} ad',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '0 Satış ($_seciliGun Gün)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // MODERN SAYFALAMA ÇUBUĞU (Kaba diyalog kutusu yerine şık grid açılır menü)
          if (!_yukleniyor && _hareketsizUrunler.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kayıt: ${baslangicIdx + 1} - $bitisIdx / $_toplamCesit',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.first_page, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28),
                        tooltip: 'İlk Sayfa',
                        onPressed: _mevcutSayfa > 1
                            ? () => setState(() => _mevcutSayfa = 1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28),
                        tooltip: 'Önceki Sayfa',
                        onPressed: _mevcutSayfa > 1
                            ? () => setState(() => _mevcutSayfa--)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _sayfaSecimPenceresi(toplamSayfa),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.indigo.shade200),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Sayfa $_mevcutSayfa / ${toplamSayfa == 0 ? 1 : toplamSayfa}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.indigo.shade900),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.arrow_drop_down,
                                  size: 16, color: Colors.indigo.shade900),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28),
                        tooltip: 'Sonraki Sayfa',
                        onPressed: _mevcutSayfa < toplamSayfa
                            ? () => setState(() => _mevcutSayfa++)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.last_page, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28),
                        tooltip: 'Son Sayfa',
                        onPressed: _mevcutSayfa < toplamSayfa
                            ? () => setState(() => _mevcutSayfa = toplamSayfa)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
