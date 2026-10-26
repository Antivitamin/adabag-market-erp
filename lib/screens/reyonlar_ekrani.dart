import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'stok_kartlari_ekrani.dart';

class ReyonlarEkrani extends StatefulWidget {
  final String? rol;

  const ReyonlarEkrani({super.key, this.rol});

  @override
  State<ReyonlarEkrani> createState() => _ReyonlarEkraniState();
}

class _ReyonlarEkraniState extends State<ReyonlarEkrani> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _aramaController = TextEditingController();
  final NumberFormat _sayiFormat = NumberFormat.decimalPattern('tr_TR');

  List<Map<String, dynamic>> _reyonGruplari = [];
  bool _yukleniyor = true;
  String _aramaKelimesi = '';
  bool _stokSifirGizle = false;

  String _kullaniciRolu = 'reyoncu';
  List<String> _kullaniciAtananGruplari = [];

  @override
  void initState() {
    super.initState();
    _rolVeGruplariYukle();
  }

  String _turkceBuyuk(String text) {
    return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase().trim();
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

  // TÜRKÇE ALFABETİK SIRALAMA (Özel karakterleri ve pasifleri sona atar)
  int _turkceKarsilastir(String a, String b) {
    final bool aOzel = _ozelKarakterliMi(a);
    final bool bOzel = _ozelKarakterliMi(b);

    if (aOzel != bOzel) {
      return aOzel ? 1 : -1;
    }

    const trAlfabe = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ0123456789';
    final sA = _turkceBuyuk(a);
    final sB = _turkceBuyuk(b);
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
    _reyonlariGetir();
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
                  'Ürün barkodunu okutarak ait olduğu reyonu bulun.',
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
      _aramaController.text = okunan;
      _aramaKelimesi = okunan.trim();
      _reyonlariGetir();
    }
  }

  Future<void> _reyonlariGetir() async {
    setState(() => _yukleniyor = true);
    try {
      String? filtrelenecekReyonAdi;
      if (_aramaKelimesi.isNotEmpty) {
        final aramaSonucu = await _supabase
            .from('mikro_stok_bilgileri')
            .select('stok_ana_grup')
            .or('barkod.eq.$_aramaKelimesi,stok_adi.ilike.%$_aramaKelimesi%')
            .limit(1)
            .maybeSingle();

        if (aramaSonucu != null && aramaSonucu['stok_ana_grup'] != null) {
          filtrelenecekReyonAdi = aramaSonucu['stok_ana_grup'].toString();
        }
      }

      List<Map<String, dynamic>> tumStoklar = [];
      int baslangic = 0;
      const int adim = 1000;
      bool devam = true;

      while (devam) {
        final res = await _supabase
            .from('mikro_stok_bilgileri')
            .select('stok_ana_grup, mikro_stok_miktari')
            .range(baslangic, baslangic + adim - 1);

        final parca = List<Map<String, dynamic>>.from(res as List);
        tumStoklar.addAll(parca);

        if (parca.length < adim) {
          devam = false;
        } else {
          baslangic += adim;
        }
      }

      Map<String, Map<String, dynamic>> reyonIstatistik = {};

      for (var row in tumStoklar) {
        String reyon = (row['stok_ana_grup'] ?? 'TANIMSIZ').toString().trim();
        if (reyon.isEmpty) reyon = 'TANIMSIZ';

        final String buyukReyon = _turkceBuyuk(reyon);

        if (_kullaniciRolu == 'reyoncu') {
          if (!_kullaniciAtananGruplari.contains(buyukReyon)) {
            continue;
          }
        }

        final stokMiktar = (row['mikro_stok_miktari'] ?? 0.0).toDouble();

        if (!reyonIstatistik.containsKey(reyon)) {
          reyonIstatistik[reyon] = {
            'reyon_adi': reyon,
            'cesit_sayisi': 0,
            'toplam_adet': 0.0,
            'sifir_stok_sayisi': 0,
          };
        }

        reyonIstatistik[reyon]!['cesit_sayisi'] =
            (reyonIstatistik[reyon]!['cesit_sayisi'] as int) + 1;
        reyonIstatistik[reyon]!['toplam_adet'] =
            (reyonIstatistik[reyon]!['toplam_adet'] as double) + stokMiktar;

        if (stokMiktar <= 0) {
          reyonIstatistik[reyon]!['sifir_stok_sayisi'] =
              (reyonIstatistik[reyon]!['sifir_stok_sayisi'] as int) + 1;
        }
      }

      List<Map<String, dynamic>> liste = reyonIstatistik.values.toList();

      if (filtrelenecekReyonAdi != null) {
        liste = liste
            .where((r) => r['reyon_adi'] == filtrelenecekReyonAdi)
            .toList();
      } else if (_aramaKelimesi.isNotEmpty) {
        liste = liste
            .where((r) => r['reyon_adi']
                .toString()
                .toLowerCase()
                .contains(_aramaKelimesi.toLowerCase()))
            .toList();
      }

      // TÜRKÇE ALFABETİK SIRALAMA UYGULANDI
      liste.sort((a, b) => _turkceKarsilastir(
            a['reyon_adi'].toString(),
            b['reyon_adi'].toString(),
          ));

      if (mounted) {
        setState(() {
          _reyonGruplari = liste;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('REYONLAR & STOK GRUPLARI',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _reyonlariGetir,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aramaController,
                    decoration: InputDecoration(
                      hintText: 'Reyon adı yazın veya barkod okutun...',
                      hintStyle: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: Color(0xFF64748B)),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner,
                                color: Color(0xFF2563EB), size: 20),
                            tooltip: 'Kamera ile Barkod Oku',
                            onPressed: _kameraIleBarkodOku,
                          ),
                          if (_aramaController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18, color: Color(0xFF64748B)),
                              onPressed: () {
                                _aramaController.clear();
                                _aramaKelimesi = '';
                                _reyonlariGetir();
                              },
                            ),
                        ],
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 9, horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                    onSubmitted: (val) {
                      _aramaKelimesi = val.trim();
                      _reyonlariGetir();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(
                    _stokSifirGizle ? 'Sıfır Stok: Gizli' : 'Sıfır Stok: Açık',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _stokSifirGizle
                          ? Colors.white
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  selected: _stokSifirGizle,
                  selectedColor: const Color(0xFFDC2626),
                  backgroundColor: const Color(0xFFFEF2F2),
                  side: BorderSide(
                    color: _stokSifirGizle
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFFECACA),
                  ),
                  showCheckmark: false,
                  avatar: Icon(
                    _stokSifirGizle
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 14,
                    color: _stokSifirGizle
                        ? Colors.white
                        : const Color(0xFFDC2626),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  onSelected: (val) {
                    setState(() {
                      _stokSifirGizle = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // REYON LİSTE ALANI
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _reyonGruplari.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_person_rounded,
                                size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _kullaniciRolu == 'reyoncu' &&
                                      _kullaniciAtananGruplari.isEmpty
                                  ? 'Hesabınıza henüz atanmış bir reyon bulunmuyor.\nLütfen yöneticinizle iletişime geçiniz.'
                                  : 'Yetkili olduğunuz reyonlarda eşleşen kayıt bulunamadı.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: _reyonGruplari.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = _reyonGruplari[index];
                          final reyonAdi = item['reyon_adi'].toString();
                          final cesit = (item['cesit_sayisi'] ?? 0) as int;
                          final toplamAdet =
                              (item['toplam_adet'] ?? 0.0) as double;
                          final sifirStok =
                              (item['sifir_stok_sayisi'] ?? 0) as int;

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StokKartlariEkrani(
                                      seciliGrup: reyonAdi,
                                      rol: _kullaniciRolu,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(7),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFEFF6FF),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFDBEAFE)),
                                                ),
                                                child: const Icon(
                                                    Icons.grid_view_rounded,
                                                    color: Color(0xFF2563EB),
                                                    size: 18),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  reyonAdi,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13.5,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 28),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF1F5F9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFFE2E8F0)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .inventory_2_outlined,
                                                          size: 12,
                                                          color: Color(
                                                              0xFF475569)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$cesit Kalem Ürün',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              Color(0xFF1E293B),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: toplamAdet > 0
                                                        ? const Color(
                                                            0xFFEFF6FF)
                                                        : const Color(
                                                            0xFFFEF2F2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                      color: toplamAdet > 0
                                                          ? const Color(
                                                              0xFFBFDBFE)
                                                          : const Color(
                                                              0xFFFECACA),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.layers_outlined,
                                                        size: 12,
                                                        color: toplamAdet > 0
                                                            ? const Color(
                                                                0xFF1D4ED8)
                                                            : const Color(
                                                                0xFFDC2626),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Stok: ${_sayiFormat.format(toplamAdet)} Ad',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: toplamAdet > 0
                                                              ? const Color(
                                                                  0xFF1D4ED8)
                                                              : const Color(
                                                                  0xFFDC2626),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (!_stokSifirGizle)
                                                  if (sifirStok > 0)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFFFFBEB),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                            color: const Color(
                                                                0xFFFDE68A)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                              Icons
                                                                  .warning_amber_rounded,
                                                              size: 12,
                                                              color: Color(
                                                                  0xFFD97706)),
                                                          const SizedBox(
                                                              width: 3),
                                                          Text(
                                                            '$sifirStok Kalem Stok Sıfır',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: Color(
                                                                  0xFFB45309),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFECFDF5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                            color: const Color(
                                                                0xFFA7F3D0)),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .check_circle_outline,
                                                              size: 11,
                                                              color: Color(
                                                                  0xFF059669)),
                                                          SizedBox(width: 3),
                                                          Text(
                                                            'Tam Dolu',
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: Color(
                                                                  0xFF047857),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Align(
                                      alignment: Alignment.center,
                                      child: Icon(Icons.chevron_right_rounded,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ],
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
  }
}
