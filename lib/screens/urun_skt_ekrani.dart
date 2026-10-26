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

class UrunSktEkrani extends StatefulWidget {
  final String? rol;

  const UrunSktEkrani({super.key, this.rol});

  @override
  State<UrunSktEkrani> createState() => _UrunSktEkraniState();
}

class _UrunSktEkraniState extends State<UrunSktEkrani> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _aramaController = TextEditingController();
  final NumberFormat _sayiFormat = NumberFormat.decimalPattern('tr_TR');

  List<Map<String, dynamic>> _sktListesi = [];
  bool _yukleniyor = true;
  String _aramaKelimesi = '';
  String _kullaniciRolu = 'reyoncu';
  List<String> _kullaniciAtananGruplari = [];

  static const int _sayfaBoyutu = 100;
  int _mevcutSayfa = 1;
  int _toplamKayitSayisi = 0;

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
    _sktVerileriniGetir();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
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
                  'Ürün barkodunu okutarak SKT sorgulayın.',
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
        _mevcutSayfa = 1;
      });
      _sktVerileriniGetir();
    }
  }

  Future<void> _sktVerileriniGetir() async {
    setState(() => _yukleniyor = true);
    try {
      dynamic sorgu = _supabase.from('vw_urun_skt_mikro').select();

      final bool sayiMi = int.tryParse(_aramaKelimesi) != null;

      if (_aramaKelimesi.isNotEmpty) {
        if (sayiMi) {
          sorgu = sorgu.or(
              'barkod.ilike.%$_aramaKelimesi%,stok_adi.ilike.%$_aramaKelimesi%');
        } else {
          final buyukKelime = _turkceBuyuk(_aramaKelimesi);
          sorgu = sorgu.ilike('stok_adi', '%$buyukKelime%');
        }
      }

      final res = await sorgu;
      List<Map<String, dynamic>> gelenListe =
          List<Map<String, dynamic>>.from(res as List);

      // Reyoncu kontrolü
      if (_kullaniciRolu == 'reyoncu') {
        gelenListe = gelenListe.where((item) {
          final reyon =
              _turkceBuyuk((item['stok_ana_grup'] ?? 'TANIMSIZ').toString());
          return _kullaniciAtananGruplari.contains(reyon);
        }).toList();
      }

      if (_aramaKelimesi.isNotEmpty && !sayiMi) {
        final arananKelime = _turkceBuyuk(_aramaKelimesi);
        gelenListe = gelenListe.where((item) {
          final urunAdi = _turkceBuyuk(item['stok_adi']?.toString() ?? '');
          final kelimeler = urunAdi.split(RegExp(r'[\s\-_/]+'));
          return kelimeler.any((k) => k.startsWith(arananKelime));
        }).toList();
      }

      gelenListe.sort((a, b) {
        final tarihA = a['skt']?.toString() ?? '9999-12-31';
        final tarihB = b['skt']?.toString() ?? '9999-12-31';
        return tarihA.compareTo(tarihB);
      });

      final int toplam = gelenListe.length;
      final int baslangic = (_mevcutSayfa - 1) * _sayfaBoyutu;
      final int bitis =
          baslangic + _sayfaBoyutu > toplam ? toplam : baslangic + _sayfaBoyutu;

      final sayfaVerisi = baslangic > toplam
          ? <Map<String, dynamic>>[]
          : gelenListe.sublist(baslangic, bitis);

      if (mounted) {
        setState(() {
          _sktListesi = sayfaVerisi;
          _toplamKayitSayisi = toplam;
          _yukleniyor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _yukleniyor = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

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
                        _sktVerileriniGetir();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: seciliMi
                              ? Colors.teal.shade800
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: seciliMi
                                ? Colors.teal.shade800
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
    final int toplamSayfa = (_toplamKayitSayisi / _sayfaBoyutu).ceil();
    final int baslangicIdx = (_mevcutSayfa - 1) * _sayfaBoyutu;
    final int bitisIdx = (baslangicIdx + _sayfaBoyutu > _toplamKayitSayisi)
        ? _toplamKayitSayisi
        : baslangicIdx + _sayfaBoyutu;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('ÜRÜN & SKT TAKİP', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.teal.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _sktVerileriniGetir,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: TextField(
              controller: _aramaController,
              inputFormatters: [TurkceBuyukHarfFormatter()],
              decoration: InputDecoration(
                hintText: 'Ürün adı veya barkod ile ara...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.qr_code_scanner, color: Colors.teal),
                      tooltip: 'Kamera ile Barkod Oku',
                      onPressed: _kameraIleBarkodOku,
                    ),
                    if (_aramaController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _aramaController.clear();
                          _aramaKelimesi = '';
                          _mevcutSayfa = 1;
                          _sktVerileriniGetir();
                        },
                      ),
                  ],
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              ),
              onSubmitted: (val) {
                _aramaKelimesi = _turkceBuyuk(val.trim());
                _mevcutSayfa = 1;
                _sktVerileriniGetir();
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toplam Kayıt: $_toplamKayitSayisi',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                Text(
                  'SKT Yaklaşanlar Öncelikli',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _sktListesi.isEmpty
                    ? const Center(
                        child: Text('Kriterlere uygun SKT kaydı bulunamadı.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _sktListesi.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = _sktListesi[index];
                          final barkod = (item['barkod'] ?? '').toString();
                          final urunAdi = (item['stok_adi'] ?? '').toString();
                          final reyon =
                              (item['stok_ana_grup'] ?? '').toString();
                          final miktar =
                              (item['mikro_stok_miktari'] ?? 0.0).toDouble();
                          final sktStr = item['skt']?.toString();

                          Color sktRenk = Colors.green.shade700;
                          String sktDurum = 'SKT Uygun';
                          if (sktStr != null) {
                            final sktTarih = DateTime.tryParse(sktStr);
                            if (sktTarih != null) {
                              final kalanGun =
                                  sktTarih.difference(DateTime.now()).inDays;
                              if (kalanGun < 0) {
                                sktRenk = Colors.red.shade800;
                                sktDurum = 'SKT GEÇMİŞ!';
                              } else if (kalanGun <= 30) {
                                sktRenk = Colors.orange.shade800;
                                sktDurum = '$kalanGun Gün Kaldı';
                              } else {
                                sktDurum =
                                    '${DateFormat('dd.MM.yyyy').format(sktTarih)}';
                              }
                            }
                          } else {
                            sktDurum = 'Belirtilmemiş';
                            sktRenk = Colors.grey;
                          }

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          urunAdi,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Barkod: $barkod',
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
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${_sayiFormat.format(miktar)} ad',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: sktRenk.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: sktRenk.withValues(
                                                  alpha: 0.4)),
                                        ),
                                        child: Text(
                                          sktDurum,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: sktRenk,
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
          if (!_yukleniyor && _toplamKayitSayisi > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kayıt: ${baslangicIdx + 1} - $bitisIdx / $_toplamKayitSayisi',
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
                            ? () {
                                setState(() => _mevcutSayfa = 1);
                                _sktVerileriniGetir();
                              }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28),
                        tooltip: 'Önceki Sayfa',
                        onPressed: _mevcutSayfa > 1
                            ? () {
                                setState(() => _mevcutSayfa--);
                                _sktVerileriniGetir();
                              }
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
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Sayfa $_mevcutSayfa / ${toplamSayfa == 0 ? 1 : toplamSayfa}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.teal.shade900),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.arrow_drop_down,
                                  size: 16, color: Colors.teal.shade900),
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
                            ? () {
                                setState(() => _mevcutSayfa++);
                                _sktVerileriniGetir();
                              }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.last_page, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28),
                        tooltip: 'Son Sayfa',
                        onPressed: _mevcutSayfa < toplamSayfa
                            ? () {
                                setState(() => _mevcutSayfa = toplamSayfa);
                                _sktVerileriniGetir();
                              }
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
