import 'kasa_kapanis_giris_ekrani.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class GunSonuEkrani extends StatefulWidget {
  const GunSonuEkrani({super.key});

  @override
  State<GunSonuEkrani> createState() => _GunSonuEkraniState();
}

class _GunSonuEkraniState extends State<GunSonuEkrani> {
  final _supabase = Supabase.instance.client;
  final NumberFormat _paraFormat =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final DateFormat _tarihFormat = DateFormat('dd.MM.yyyy');

  late DateTime _baslangicTarihi;
  late DateTime _bitisTarihi;

  List<Map<String, dynamic>> _gunSonuListesi = [];
  Map<String, List<Map<String, dynamic>>> _kasaDetaylariMap = {};
  bool _yukleniyor = true;

  // Bugünün Canlı Satış Verileri
  Map<String, dynamic>? _bugunGenel;
  List<Map<String, dynamic>> _bugunKasalar = [];

  double _filtreSatis = 0.0;
  double _filtreIade = 0.0;
  double _filtreNetCiro = 0.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _bitisTarihi = DateTime(now.year, now.month, now.day);
    _baslangicTarihi = _bitisTarihi.subtract(const Duration(days: 30));

    _verileriGetir();
  }

  Future<void> _verileriGetir() async {
    setState(() => _yukleniyor = true);
    try {
      final bas = DateFormat('yyyy-MM-dd').format(_baslangicTarihi);
      final bit = DateFormat('yyyy-MM-dd').format(_bitisTarihi);
      final bugunStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. Genel Gün Sonu
      final resGenel = await _supabase
          .from('mikro_kasa_gun_sonu')
          .select()
          .gte('tarih', bas)
          .lte('tarih', bit)
          .order('tarih', ascending: false);

      // 2. Kasa Bazlı Kırılımlar
      final resDetay = await _supabase
          .from('mikro_kasa_detaylari')
          .select()
          .gte('tarih', bas)
          .lte('tarih', bit)
          .order('kasa_adi', ascending: true);

      final genelListe = List<Map<String, dynamic>>.from(resGenel as List);
      final detayListe = List<Map<String, dynamic>>.from(resDetay as List);

      Map<String, List<Map<String, dynamic>>> detayMap = {};
      for (var d in detayListe) {
        final t = d['tarih'].toString();
        detayMap.putIfAbsent(t, () => []).add(d);
      }

      double tSatis = 0.0;
      double tIade = 0.0;
      double tCiro = 0.0;

      Map<String, dynamic>? bugunG;
      List<Map<String, dynamic>> bugunK = [];

      for (var r in genelListe) {
        final t = r['tarih'].toString();
        if (t == bugunStr) {
          bugunG = r;
          bugunK = detayMap[t] ?? [];
        } else {
          tSatis += (r['toplam_nakit'] ?? 0.0).toDouble();
          tIade += (r['toplam_iade'] ?? 0.0).toDouble();
          tCiro += (r['toplam_net_ciro'] ?? 0.0).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _gunSonuListesi = genelListe
              .where((e) => e['tarih'].toString() != bugunStr)
              .toList();
          _kasaDetaylariMap = detayMap;
          _bugunGenel = bugunG;
          _bugunKasalar = bugunK;
          _filtreSatis = tSatis;
          _filtreIade = tIade;
          _filtreNetCiro = tCiro;
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

  Future<void> _tarihAraligiSec() async {
    final secilen = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange:
          DateTimeRange(start: _baslangicTarihi, end: _bitisTarihi),
    );

    if (secilen != null) {
      setState(() {
        _baslangicTarihi = secilen.start;
        _bitisTarihi = secilen.end;
      });
      _verileriGetir();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('GÜN SONU & CANLI KASA RAPORU'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          // Kasa Kapanış & Mutabakat Girişi Butonu
          IconButton(
            icon: const Icon(Icons.edit_note, size: 28),
            tooltip: 'Kasa Kapanış & Mutabakat Girişi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => KasaKapanisGirisEkrani(
                    initialDate:
                        DateTime.now().toIso8601String().substring(0, 10),
                  ),
                ),
              );
            },
          ),
          // Tarih Seçici Butonu
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Tarih Aralığı Seç',
            onPressed: _tarihAraligiSec,
          ),
          // Yenile Butonu
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _verileriGetir,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _verileriGetir,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  // 1. CANLI BUGÜN KASA RAPORU KARTI
                  _buildCanliKasaBandi(),

                  const SizedBox(height: 12),

                  // 2. GEÇMİŞ DÖNEM ÖZET PANELİ
                  _buildGecmisOzetPaneli(),

                  const SizedBox(height: 14),

                  // 3. GEÇMİŞ GÜNLER LİSTESİ BAŞLIĞI
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      'GEÇMİŞ GÜN KAPANIPLARI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),

                  // Geçmiş Günlerin Listesi
                  if (_gunSonuListesi.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text('Bu aralıkta kapanış kaydı bulunamadı.',
                          style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    ..._gunSonuListesi
                        .map((item) => _buildGecmisGunKarti(item)),
                ],
              ),
            ),
    );
  }

  // --- BUGÜNÜN ANLIK CANLI SATIŞ KARTI ---
  Widget _buildCanliKasaBandi() {
    final bugunNet = (_bugunGenel?['toplam_net_ciro'] ?? 0.0).toDouble();
    final bugunNakit = (_bugunGenel?['toplam_nakit'] ?? 0.0).toDouble();
    final bugunPos = (_bugunGenel?['toplam_kredi_karti'] ?? 0.0).toDouble();
    final bugunIade = (_bugunGenel?['toplam_iade'] ?? 0.0).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canlı Başlık Bandı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0284C7),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'BUGÜN CANLI KASA DURUMU',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  _tarihFormat.format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Canlı Genel Toplamlar
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniOzet(
                        'ANLIK CİRO',
                        _paraFormat.format(bugunNet),
                        const Color(0xFF0369A1),
                        const Color(0xFFE0F2FE),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniOzet(
                        'NAKİT',
                        _paraFormat.format(bugunNakit),
                        const Color(0xFF15803D),
                        const Color(0xFFDCFCE7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniOzet(
                        'KREDİ KARTI',
                        _paraFormat.format(bugunPos),
                        const Color(0xFF4338CA),
                        const Color(0xFFEEF2FF),
                      ),
                    ),
                    if (bugunIade > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniOzet(
                          'İADE',
                          '-${_paraFormat.format(bugunIade)}',
                          const Color(0xFFB91C1C),
                          const Color(0xFFFEE2E2),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),

                const Text(
                  'Kasaların Canlı Dağılımı:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),

                // Kasa 1, 2, 3 Kartları
                if (_bugunKasalar.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Bugün henüz fiş satışı bulunmuyor.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic)),
                  )
                else
                  ..._bugunKasalar
                      .map((k) => _buildTekKasaKarti(k, canli: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- GEÇMİŞ DÖNEM FİLTRE ÖZETİ ---
  Widget _buildGecmisOzetPaneli() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aralık: ${_tarihFormat.format(_baslangicTarihi)} - ${_tarihFormat.format(_bitisTarihi)}',
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              InkWell(
                onTap: _tarihAraligiSec,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_calendar, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Tarihi Değiştir',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOPLAM SATIŞ',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      _paraFormat.format(_filtreSatis),
                      style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Container(height: 30, width: 1, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOPLAM İADE',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFFCA5A5),
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      '-${_paraFormat.format(_filtreIade)}',
                      style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFF87171),
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Container(height: 30, width: 1, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NET CİRO',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF86EFAC),
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      _paraFormat.format(_filtreNetCiro),
                      style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4ADE80),
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- GEÇMİŞ GÜN KARTI ---
  Widget _buildGecmisGunKarti(Map<String, dynamic> item) {
    final isoTarih = item['tarih'].toString();
    final dt = DateTime.tryParse(isoTarih) ?? DateTime.now();
    final netCiro = (item['toplam_net_ciro'] ?? 0.0).toDouble();
    final iade = (item['toplam_iade'] ?? 0.0).toDouble();
    final kasalar = _kasaDetaylariMap[isoTarih] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarih ve Net Ciro Başlığı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      size: 18, color: Color(0xFF0F172A)),
                  const SizedBox(width: 6),
                  Text(
                    _tarihFormat.format(dt),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      '${kasalar.length} Kasa',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  'Net: ${_paraFormat.format(netCiro)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),

          if (iade > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Toplam İade: -${_paraFormat.format(iade)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDC2626),
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Kasaların Listesi
          ...kasalar.map((k) => _buildTekKasaKarti(k, canli: false)),
        ],
      ),
    );
  }

  // --- TEK BİR KASA SATIRI BİLEŞENİ (SABİT 3 SÜTUNLU MİMARİ - ASLA KAYMAZ) ---
  Widget _buildTekKasaKarti(Map<String, dynamic> k, {required bool canli}) {
    final kAdi = k['kasa_adi'].toString();
    final n = (k['nakit'] ?? 0.0).toDouble();
    final pos = (k['kredi_karti'] ?? 0.0).toDouble();
    final i = (k['iade'] ?? 0.0).toDouble();
    final net = (k['net_tutar'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: canli ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canli ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.point_of_sale_rounded,
                    size: 16,
                    color: canli
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    kAdi,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                'Toplam: ${_paraFormat.format(net)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 3 SABİT SÜTUN (NAKİT - POS - İADE)
          Row(
            children: [
              // 1. Sütun: NAKİT (Sola Hizalı)
              Expanded(
                child: Row(
                  children: [
                    const Text('Nakit: ',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600)),
                    Flexible(
                      child: Text(
                        _paraFormat.format(n),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Sütun: POS (Ortaya Hizalı - Yeri Asla Kaymaz)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('POS: ',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600)),
                    Flexible(
                      child: Text(
                        _paraFormat.format(pos),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Sütun: İADE (Sağa Hizalı - İade Olmasa Bile Hizayı Korur)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'İade: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: i > 0
                            ? const Color(0xFF64748B)
                            : const Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        i > 0 ? '-${_paraFormat.format(i)}' : '₺0,00',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: i > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MİNİ ÖZET KUTUCUĞU ---
  Widget _buildMiniOzet(
      String baslik, String deger, Color yaziRenk, Color bgRenk) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: bgRenk,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            baslik,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: yaziRenk.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              deger,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: yaziRenk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
