import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

class HizliSorguEkrani extends StatefulWidget {
  final String? rol;

  const HizliSorguEkrani({super.key, this.rol});

  @override
  State<HizliSorguEkrani> createState() => _HizliSorguEkraniState();
}

class _HizliSorguEkraniState extends State<HizliSorguEkrani> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _aramaController = TextEditingController();
  final NumberFormat _paraFormat =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final NumberFormat _sayiFormat = NumberFormat.decimalPattern('tr_TR');

  List<Map<String, dynamic>> _sonuclar = [];
  bool _yukleniyor = false;
  String _bilgiMesaji =
      'Aramak istediğiniz stok kodunu veya barkodu girip Enter\'a basınız.';
  String _kullaniciRolu = 'reyoncu';

  @override
  void initState() {
    super.initState();
    _roluBelirle();
  }

  Future<void> _roluBelirle() async {
    if (widget.rol != null && widget.rol!.isNotEmpty) {
      setState(() => _kullaniciRolu = widget.rol!.trim().toLowerCase());
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profil = await _supabase
            .from('profiller')
            .select('rol')
            .eq('id', user.id)
            .maybeSingle();

        if (profil != null && profil['rol'] != null) {
          setState(() =>
              _kullaniciRolu = profil['rol'].toString().trim().toLowerCase());
        } else {
          final metaRol =
              user.userMetadata?['rol']?.toString().trim().toLowerCase();
          if (metaRol != null) setState(() => _kullaniciRolu = metaRol);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  String _turkceBuyuk(String text) {
    return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
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

  Future<void> _urunAra(String aranan) async {
    final girdi = aranan.trim();
    if (girdi.isEmpty) {
      setState(() {
        _sonuclar = [];
        _bilgiMesaji = 'Lütfen aranacak stok kodu veya barkod girin.';
      });
      return;
    }

    setState(() {
      _yukleniyor = true;
      _bilgiMesaji = '';
    });

    try {
      final tamKod = await _supabase
          .from('mikro_stok_bilgileri')
          .select()
          .eq('barkod', girdi)
          .limit(1);

      if (tamKod.isNotEmpty) {
        if (mounted) {
          setState(() {
            _sonuclar = List<Map<String, dynamic>>.from(tamKod as List);
            _yukleniyor = false;
          });
        }
        return;
      }

      if (int.tryParse(girdi) != null) {
        final intSayi = int.parse(girdi);
        final sifirVaryasyonlari = [
          intSayi.toString(),
          intSayi.toString().padLeft(2, '0'),
          intSayi.toString().padLeft(3, '0'),
          intSayi.toString().padLeft(4, '0'),
          intSayi.toString().padLeft(5, '0'),
          intSayi.toString().padLeft(6, '0'),
        ];

        final sifirliEslesme = await _supabase
            .from('mikro_stok_bilgileri')
            .select()
            .inFilter('barkod', sifirVaryasyonlari)
            .limit(1);

        if (sifirliEslesme.isNotEmpty) {
          if (mounted) {
            setState(() {
              _sonuclar =
                  List<Map<String, dynamic>>.from(sifirliEslesme as List);
              _yukleniyor = false;
            });
          }
          return;
        }

        final barkodArama = await _supabase
            .from('mikro_stok_bilgileri')
            .select()
            .ilike('stok_adi', '%| Barkod:%$girdi%')
            .limit(20);

        List<Map<String, dynamic>> eslesenBarkodlar = [];
        for (var row in (barkodArama as List)) {
          final tamAd = (row['stok_adi'] ?? '').toString();
          if (tamAd.contains('| Barkod:')) {
            final barkodlarMetni = tamAd.split('| Barkod:').last.trim();
            final barkodListesi =
                barkodlarMetni.split(',').map((e) => e.trim()).toList();
            if (barkodListesi.contains(girdi)) {
              eslesenBarkodlar.add(Map<String, dynamic>.from(row));
            }
          }
        }

        if (eslesenBarkodlar.isNotEmpty) {
          if (mounted) {
            setState(() {
              _sonuclar = eslesenBarkodlar;
              _yukleniyor = false;
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _sonuclar = [];
            _yukleniyor = false;
            _bilgiMesaji =
                'Stok kodu veya barkodu "$girdi" olan ürün bulunamadı.';
          });
        }
        return;
      }

      // Ürün İsmiyle Arama (Örn: İÇİM)
      final buyukGirdi = _turkceBuyuk(girdi);
      final isimSonuclari = await _supabase
          .from('mikro_stok_bilgileri')
          .select()
          .ilike('stok_adi', '%$buyukGirdi%')
          .limit(100);

      final List<Map<String, dynamic>> filtrelenmis = [];
      for (var row in (isimSonuclari as List)) {
        final tamAd = (row['stok_adi'] ?? '').toString();
        final urunAdi = _turkceBuyuk(_ayristirUrunAdi(tamAd));
        final kelimeler = urunAdi.split(RegExp(r'[\s\-_/]+'));
        if (kelimeler.any((k) => k.startsWith(buyukGirdi))) {
          filtrelenmis.add(Map<String, dynamic>.from(row));
        }
      }

      // Aktif harfle başlayanlar ÖNCE, pasifler EN SONA
      filtrelenmis.sort((a, b) {
        final adA = _ayristirUrunAdi(a['stok_adi']?.toString() ?? '');
        final adB = _ayristirUrunAdi(b['stok_adi']?.toString() ?? '');
        return _turkceKarsilastir(adA, adB);
      });

      if (mounted) {
        setState(() {
          _sonuclar = filtrelenmis;
          _yukleniyor = false;
          if (_sonuclar.isEmpty) {
            _bilgiMesaji = '"$girdi" isimli ürün bulunamadı.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _bilgiMesaji = 'Arama hatası: $e';
        });
      }
    }
  }

  String _ayristirUrunAdi(String tamMetin) {
    if (tamMetin.contains(']') && tamMetin.contains('| Barkod:')) {
      final bas = tamMetin.indexOf(']') + 1;
      final son = tamMetin.indexOf('| Barkod:');
      return tamMetin.substring(bas, son).trim();
    }
    return tamMetin;
  }

  String _ayristirBarkod(String tamMetin, String yedekKod) {
    if (tamMetin.contains('| Barkod:')) {
      return tamMetin.split('| Barkod:').last.trim();
    }
    return yedekKod;
  }

  @override
  Widget build(BuildContext context) {
    final bool reyoncuMu = _kullaniciRolu == 'reyoncu';

    return Scaffold(
      appBar: AppBar(
        title: const Text('FİYAT GÖR & HIZLI STOK SORGULA'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: TextField(
              controller: _aramaController,
              autofocus: true,
              keyboardType: TextInputType.text,
              inputFormatters: [TurkceBuyukHarfFormatter()],
              decoration: InputDecoration(
                hintText: 'Stok Kodu veya Barkod girip Enter\'a basın...',
                prefixIcon:
                    const Icon(Icons.qr_code_scanner, color: Colors.indigo),
                suffixIcon: _aramaController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _aramaController.clear();
                          setState(() {
                            _sonuclar = [];
                            _bilgiMesaji =
                                'Aramak istediğiniz stok kodunu veya barkodu giriniz.';
                          });
                        },
                      )
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (deger) => _urunAra(deger),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _sonuclar.isEmpty
                    ? Center(
                        child: Text(
                          _bilgiMesaji,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _sonuclar.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _sonuclar[index];
                          final stokKod = (item['barkod'] ?? '').toString();
                          final tamAd = (item['stok_adi'] ?? '').toString();
                          final urunAdi = _ayristirUrunAdi(tamAd);
                          final barkod = _ayristirBarkod(tamAd, stokKod);

                          final alis = (item['alis_fiyati'] ?? 0.0).toDouble();
                          final satis =
                              (item['satis_fiyati'] ?? 0.0).toDouble();
                          final stok =
                              (item['mikro_stok_miktari'] ?? 0.0).toDouble();
                          final s7 = (item['satis_7_gun'] ?? 0.0).toDouble();
                          final s15 =
                              (item['son_15_gun_hareket'] ?? 0.0).toDouble();
                          final s30 = (item['satis_30_gun'] ?? 0.0).toDouble();

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: Colors.indigo.shade200),
                                        ),
                                        child: Text(
                                          stokKod,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.indigo.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          urunAdi,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Barkod: $barkod',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (!reyoncuMu) ...[
                                            Text(
                                                'Alış Fiyatı: ${_paraFormat.format(alis)}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.grey.shade700)),
                                            const SizedBox(height: 2),
                                          ],
                                          Text(
                                            'Satış Fiyatı: ${_paraFormat.format(satis)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text('Merkez Stok',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                          Text(
                                            '${_sayiFormat.format(stok)} ad',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: stok > 0
                                                  ? Colors.blue.shade900
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (!reyoncuMu) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildSatisBadge('Son 7 Gün', s7),
                                          _buildSatisBadge('Son 15 Gün', s15),
                                          _buildSatisBadge('Son 30 Gün', s30),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
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

  Widget _buildSatisBadge(String baslik, double miktar) {
    return Column(
      children: [
        Text(baslik,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          '${_sayiFormat.format(miktar)} ad',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: miktar > 0 ? Colors.orange.shade900 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}
