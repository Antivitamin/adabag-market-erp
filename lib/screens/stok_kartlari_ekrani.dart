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

class StokKartlariEkrani extends StatefulWidget {
  final String? seciliGrup;
  final String? rol;

  const StokKartlariEkrani({super.key, this.seciliGrup, this.rol});

  @override
  State<StokKartlariEkrani> createState() => _StokKartlariEkraniState();
}

class _StokKartlariEkraniState extends State<StokKartlariEkrani> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _aramaController = TextEditingController();
  final NumberFormat _paraFormat =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final NumberFormat _sayiFormat = NumberFormat.decimalPattern('tr_TR');

  List<Map<String, dynamic>> _sayfaUrunleri = [];
  bool _yukleniyor = true;
  String _aramaKelimesi = '';
  String _kullaniciRolu = 'admin';

  String _siralamaKriteri = 'stok_adi';
  bool _artanSiralama = true;
  bool _sifirStoklariGizle = false;

  static const int _sayfaBoyutu = 100;
  int _mevcutSayfa = 1;
  int _toplamUrunSayisi = 0;

  double _genelStokAdedi = 0.0;
  double _genelAlisMaliyeti = 0.0;
  double _genelSatisDegeri = 0.0;
  double _genelNetKar = 0.0;
  double _genelKarMarji = 0.0;

  @override
  void initState() {
    super.initState();
    _roluBelirle();
    _ekranVerileriniYukle();
  }

  Future<void> _roluBelirle() async {
    if (widget.rol != null && widget.rol!.isNotEmpty) {
      _kullaniciRolu = widget.rol!.trim().toLowerCase();
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
          setState(() {
            _kullaniciRolu = profil['rol'].toString().trim().toLowerCase();
          });
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
        _mevcutSayfa = 1;
      });
      _ekranVerileriniYukle();
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

  String _ayristirBarkod(String tamMetin, String yedekKod) {
    if (tamMetin.contains('| Barkod:')) {
      return tamMetin.split('| Barkod:').last.trim();
    }
    return yedekKod;
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

  Future<void> _ekranVerileriniYukle() async {
    setState(() => _yukleniyor = true);
    await Future.wait([
      _genelOzetleriGetir(),
      _sayfaListesiniGetir(),
    ]);
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _genelOzetleriGetir() async {
    try {
      final res = await _supabase.rpc('get_stok_ozet_verileri', params: {
        'p_grup': widget.seciliGrup,
        'p_arama': _aramaKelimesi.isEmpty ? null : _turkceBuyuk(_aramaKelimesi),
        'p_sifir_gizle': _sifirStoklariGizle,
      });

      if (res != null && (res as List).isNotEmpty) {
        final ozet = res[0];
        final toplamCesit = (ozet['toplam_cesit'] ?? 0) as int;
        final toplamStok = (ozet['toplam_stok'] ?? 0.0).toDouble();
        final toplamAlis = (ozet['toplam_alis_maliyet'] ?? 0.0).toDouble();
        final toplamSatis = (ozet['toplam_satis_deger'] ?? 0.0).toDouble();
        final toplamKar = (ozet['toplam_net_kar'] ?? 0.0).toDouble();
        final marj = toplamAlis > 0 ? ((toplamKar / toplamAlis) * 100) : 0.0;

        if (mounted) {
          setState(() {
            _toplamUrunSayisi = toplamCesit;
            _genelStokAdedi = toplamStok;
            _genelAlisMaliyeti = toplamAlis;
            _genelSatisDegeri = toplamSatis;
            _genelNetKar = toplamKar;
            _genelKarMarji = marj;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _sayfaListesiniGetir() async {
    try {
      dynamic sorgu = _supabase.from('mikro_stok_bilgileri').select(
            'barkod, stok_adi, stok_ana_grup, alis_fiyati, satis_fiyati, mikro_stok_miktari, son_15_gun_hareket',
          );

      if (widget.seciliGrup != null && widget.seciliGrup!.isNotEmpty) {
        if (widget.seciliGrup == 'TANIMSIZ') {
          sorgu = sorgu.or('stok_ana_grup.eq.TANIMSIZ,stok_ana_grup.is.null');
        } else {
          sorgu = sorgu.eq('stok_ana_grup', widget.seciliGrup!);
        }
      }

      if (_sifirStoklariGizle) {
        sorgu = sorgu.gt('mikro_stok_miktari', 0);
      }

      final bool sayiMi = int.tryParse(_aramaKelimesi) != null;

      if (_aramaKelimesi.isNotEmpty) {
        if (sayiMi) {
          sorgu = sorgu.or(
              'barkod.ilike.%$_aramaKelimesi\%,stok_adi.ilike.\%\vert{} Barkod:\%$_aramaKelimesi%%');
          sorgu = sorgu.order(_siralamaKriteri, ascending: _artanSiralama);
        } else {
          final buyukKelime = _turkceBuyuk(_aramaKelimesi);
          sorgu = sorgu.ilike('stok_adi', '%$buyukKelime%');
        }
      } else {
        sorgu = sorgu.order(_siralamaKriteri, ascending: _artanSiralama);
      }

      final int baslangic = (_mevcutSayfa - 1) * _sayfaBoyutu;
      final int bitis = baslangic + _sayfaBoyutu - 1;

      final res = await sorgu.range(baslangic, bitis);
      List<Map<String, dynamic>> gelenler =
          List<Map<String, dynamic>>.from(res as List);

      if (_aramaKelimesi.isNotEmpty && !sayiMi) {
        final arananKelime = _turkceBuyuk(_aramaKelimesi);
        gelenler = gelenler.where((item) {
          final urunAdi = _turkceBuyuk(
              _ayristirUrunAdi(item['stok_adi']?.toString() ?? ''));
          final kelimeler = urunAdi.split(RegExp(r'[\s\-_/]+'));
          return kelimeler.any((k) => k.startsWith(arananKelime));
        }).toList();

        gelenler.sort((a, b) {
          final adA = _ayristirUrunAdi(a['stok_adi']?.toString() ?? '');
          final adB = _ayristirUrunAdi(b['stok_adi']?.toString() ?? '');
          final comp = _turkceKarsilastir(adA, adB);
          return _artanSiralama ? comp : -comp;
        });
      } else if (_siralamaKriteri == 'stok_adi') {
        gelenler.sort((a, b) {
          final adA = _ayristirUrunAdi(a['stok_adi']?.toString() ?? '');
          final adB = _ayristirUrunAdi(b['stok_adi']?.toString() ?? '');
          final comp = _turkceKarsilastir(adA, adB);
          return _artanSiralama ? comp : -comp;
        });
      }

      if (mounted) {
        setState(() {
          _sayfaUrunleri = gelenler;
        });
      }
    } catch (e) {
      if (mounted) {
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
                        _sayfaListesiniGetir();
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

  Widget _buildOzetKarti(bool reyoncuMu) {
    if (reyoncuMu) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.indigo.shade900,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildOzetItem('TOPLAM ÇEŞİT', '$_toplamUrunSayisi Kalem',
                Colors.white70, Colors.white),
            _buildOzetItem(
                'TOPLAM STOK',
                '${_sayiFormat.format(_genelStokAdedi)} ad',
                Colors.white70,
                Colors.cyanAccent),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOzetItem('TOPLAM ÇEŞİT', '$_toplamUrunSayisi Kalem',
                  Colors.white70, Colors.white),
              _buildOzetItem(
                  'TOPLAM STOK',
                  '${_sayiFormat.format(_genelStokAdedi)} ad',
                  Colors.white70,
                  Colors.cyanAccent),
              _buildOzetItem(
                  'ALIŞ MALİYETİ',
                  _paraFormat.format(_genelAlisMaliyeti),
                  Colors.white70,
                  Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOzetItem(
                  'SATIŞ DEĞERİ',
                  _paraFormat.format(_genelSatisDegeri),
                  Colors.white70,
                  Colors.white),
              _buildOzetItem('NET KÂR', _paraFormat.format(_genelNetKar),
                  Colors.white70, Colors.lightGreenAccent),
              _buildOzetItem(
                  'KÂR MARJI',
                  '%${_genelKarMarji.toStringAsFixed(1)}',
                  Colors.white70,
                  Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOzetItem(
      String baslik, String deger, Color baslikRenk, Color degerRenk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          baslik,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold, color: baslikRenk),
        ),
        const SizedBox(height: 2),
        Text(
          deger,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: degerRenk),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool reyoncuMu = _kullaniciRolu == 'reyoncu';

    String baslik = 'STOK KARTLARI LİSTESİ';
    if (widget.seciliGrup != null) {
      baslik = widget.seciliGrup == 'TANIMSIZ'
          ? 'Grubu Olmayan Ürünler'
          : '${widget.seciliGrup} Grubu';
    }

    final int toplamSayfa = (_toplamUrunSayisi / _sayfaBoyutu).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text(baslik, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _ekranVerileriniYukle,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _aramaController,
                  inputFormatters: [TurkceBuyukHarfFormatter()],
                  decoration: InputDecoration(
                    hintText: 'Stok kodu, ürün adı veya barkod ile ara...',
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
                              _mevcutSayfa = 1;
                              _ekranVerileriniYukle();
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
                    _mevcutSayfa = 1;
                    _ekranVerileriniYukle();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(
                            () => _sifirStoklariGizle = !_sifirStoklariGizle);
                        _mevcutSayfa = 1;
                        _ekranVerileriniYukle();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: _sifirStoklariGizle
                              ? Colors.red.shade800
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _sifirStoklariGizle
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 14,
                              color: _sifirStoklariGizle
                                  ? Colors.white
                                  : Colors.red.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sifirStoklariGizle
                                  ? '0 Stok: Gizli'
                                  : '0 Stok: Açık',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _sifirStoklariGizle
                                    ? Colors.white
                                    : Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _siralamaKriteri,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold),
                            items: const [
                              DropdownMenuItem(
                                  value: 'stok_adi', child: Text('Ürün Adı')),
                              DropdownMenuItem(
                                  value: 'son_15_gun_hareket',
                                  child: Text('En Çok Satan')),
                              DropdownMenuItem(
                                  value: 'barkod', child: Text('Stok Kodu')),
                            ],
                            onChanged: (val) {
                              if (val != null && val != _siralamaKriteri) {
                                setState(() {
                                  _siralamaKriteri = val;
                                  _artanSiralama = val == 'son_15_gun_hareket'
                                      ? false
                                      : true;
                                });
                                _mevcutSayfa = 1;
                                _sayfaListesiniGetir();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() => _artanSiralama = !_artanSiralama);
                        _mevcutSayfa = 1;
                        _sayfaListesiniGetir();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade900,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _siralamaKriteri == 'son_15_gun_hareket'
                                  ? (_artanSiralama ? 'Az ➔ Çok' : 'Çok ➔ Az')
                                  : (_artanSiralama ? 'A ➔ Z' : 'Z ➔ A'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _artanSiralama
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
              ],
            ),
          ),
          _buildOzetKarti(reyoncuMu),
          const Divider(height: 1),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _sayfaUrunleri.isEmpty
                    ? const Center(
                        child: Text('Kriterlere uygun stok kartı bulunamadı.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _sayfaUrunleri.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = _sayfaUrunleri[index];
                          final stokKod = (item['barkod'] ?? '').toString();
                          final tamAd = (item['stok_adi'] ?? '').toString();
                          final urunAdi = _ayristirUrunAdi(tamAd);
                          final barkod = _ayristirBarkod(tamAd, stokKod);

                          final alis = (item['alis_fiyati'] ?? 0.0).toDouble();
                          final satis =
                              (item['satis_fiyati'] ?? 0.0).toDouble();
                          final stok =
                              (item['mikro_stok_miktari'] ?? 0.0).toDouble();
                          final s15 =
                              (item['son_15_gun_hareket'] ?? 0.0).toDouble();

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: Colors.indigo.shade200),
                                        ),
                                        child: Text(
                                          stokKod,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.indigo.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          urunAdi,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Barkod: $barkod',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Divider(height: 14),
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
                                                'Alış: ${_paraFormat.format(alis)}',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.grey.shade700)),
                                          ],
                                          Text(
                                              'Satış: ${_paraFormat.format(satis)}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const Text('Merkez Stok',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey)),
                                          Text(
                                            '${_sayiFormat.format(stok)} ad',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: stok > 0
                                                  ? Colors.blue.shade900
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text('15G Satış',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey)),
                                          Text(
                                            '${_sayiFormat.format(s15)} ad',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: s15 > 0
                                                  ? Colors.orange.shade900
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
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
          if (!_yukleniyor && _toplamUrunSayisi > 0)
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
                    'Toplam $_toplamUrunSayisi Kalem',
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
                                _sayfaListesiniGetir();
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
                                _sayfaListesiniGetir();
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
                            ? () {
                                setState(() => _mevcutSayfa++);
                                _sayfaListesiniGetir();
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
                                _sayfaListesiniGetir();
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
