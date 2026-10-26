// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Sadece Web derlemesinde indirme için
// ignore: unused_import
import 'dart:html' as html;

class YedeklemeEkrani extends StatefulWidget {
  final String rol;
  const YedeklemeEkrani({super.key, this.rol = 'admin'});

  @override
  State<YedeklemeEkrani> createState() => _YedeklemeEkraniState();
}

class _YedeklemeEkraniState extends State<YedeklemeEkrani> {
  final _supabase = Supabase.instance.client;
  bool _islemSuruyor = false;
  String _durumMesaji = '';
  List<FileObject> _bulutYedekleri = [];

  bool get _isAdmin => widget.rol.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _bulutYedekleriniGetir();
  }

  Future<void> _bulutYedekleriniGetir() async {
    try {
      final list = await _supabase.storage.from('yedekler').list();
      if (mounted) {
        setState(() {
          _bulutYedekleri = list;
        });
      }
    } catch (_) {}
  }

  void _cihazaIndir(List<int> bytes, String dosyaAdi) {
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', dosyaAdi)
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<void> _yedekAl() async {
    if (!_isAdmin) return;

    setState(() {
      _islemSuruyor = true;
      _durumMesaji = 'Veritabanı tabloları taranıyor...';
    });

    try {
      // AKTİF TABLOLARIN YEDEĞİ ALINIYOR
      final reyonlar = await _supabase.from('reyonlar').select();
      final sktTakip = await _supabase.from('urun_skt_takip').select();
      final mikroStoklar =
          await _supabase.from('mikro_stok_bilgileri').select();
      final profiller = await _supabase.from('profiller').select();

      final Map<String, dynamic> yedekVerisi = {
        'olusturulma_tarihi': DateTime.now().toIso8601String(),
        'magaza': 'Adabağ Hipermarket ERP',
        'reyonlar': reyonlar,
        'urun_skt_takip': sktTakip,
        'mikro_stok_bilgileri': mikroStoklar,
        'profiller': profiller,
      };

      final jsonMetni = const JsonEncoder.withIndent('  ').convert(yedekVerisi);
      final bytes = utf8.encode(jsonMetni);

      final dosyaAdi =
          'adabag_yedek_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}_${DateTime.now().day.toString().padLeft(2, '0')}_${DateTime.now().hour}${DateTime.now().minute}.json';

      await _supabase.storage.from('yedekler').uploadBinary(
            dosyaAdi,
            bytes,
            fileOptions: const FileOptions(
                contentType: 'application/json', upsert: true),
          );

      _cihazaIndir(bytes, dosyaAdi);

      if (mounted) {
        setState(() {
          _durumMesaji = 'Yedekleme Başarılı!\n'
              '• Buluta yüklendi: $dosyaAdi\n'
              '• Bilgisayarınıza indirildi.\n'
              'Toplam ${sktTakip.length} SKT Girişi, ${mikroStoklar.length} Stok Kartı arşivlendi.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Yedek alındı, buluta kaydedildi ve cihazınıza indirildi.'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }

      _bulutYedekleriniGetir();
    } catch (e) {
      if (mounted) {
        setState(() => _durumMesaji = 'Yedekleme hatası: $e');
      }
    } finally {
      if (mounted) setState(() => _islemSuruyor = false);
    }
  }

  Future<void> _buluttanCihazaIndir(String dosyaAdi) async {
    setState(() {
      _islemSuruyor = true;
      _durumMesaji = '$dosyaAdi buluttan indiriliyor...';
    });

    try {
      final bytes = await _supabase.storage.from('yedekler').download(dosyaAdi);
      _cihazaIndir(bytes, dosyaAdi);

      if (mounted) {
        setState(() {
          _durumMesaji = '$dosyaAdi başarıyla bilgisayarınıza indirildi.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$dosyaAdi cihazınıza indirildi.'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _durumMesaji = 'İndirme hatası: $e');
      }
    } finally {
      if (mounted) setState(() => _islemSuruyor = false);
    }
  }

  Future<void> _buluttanGeriYukle(String dosyaAdi) async {
    if (!_isAdmin) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geri Yükleme Onayı'),
        content: Text(
          '$dosyaAdi yedeği geri yüklenecek. Mevcut ürünler ve SKT partileri güncellenecektir. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Geri Yükle'),
          ),
        ],
      ),
    );

    if (onay != true) return;

    setState(() {
      _islemSuruyor = true;
      _durumMesaji =
          'Bulut yedeği indiriliyor ve veritabanı geri yükleniyor...';
    });

    try {
      final bytes = await _supabase.storage.from('yedekler').download(dosyaAdi);
      final jsonStr = utf8.decode(bytes);
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      if (data['reyonlar'] is List) {
        for (var item in data['reyonlar']) {
          await _supabase.from('reyonlar').upsert(item);
        }
      }

      // Güncel SKT tablosuna geri yükleme
      if (data['urun_skt_takip'] is List) {
        for (var item in data['urun_skt_takip']) {
          await _supabase.from('urun_skt_takip').upsert(item);
        }
      } else if (data['skt_kayitlari'] is List) {
        // Eski yedek dosyalarıyla geriye dönük uyumluluk
        for (var item in data['skt_kayitlari']) {
          await _supabase.from('urun_skt_takip').upsert(item);
        }
      }

      // Stok Kartları geri yükleme
      if (data['mikro_stok_bilgileri'] is List) {
        for (var item in data['mikro_stok_bilgileri']) {
          await _supabase.from('mikro_stok_bilgileri').upsert(item);
        }
      }

      if (mounted) {
        setState(() {
          _durumMesaji =
              'Geri yükleme tamamlandı!\nTüm veriler başarıyla aktarıldı.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Veritabanı seçilen yedekten başarıyla geri yüklendi!'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _durumMesaji = 'Geri yükleme hatası: $e');
      }
    } finally {
      if (mounted) setState(() => _islemSuruyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulut Yedekleme & Geri Yükle'),
        backgroundColor: Colors.teal.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _bulutYedekleriniGetir),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_sync,
                          size: 36, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Market Veri Güvenlik Merkezi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blueGrey.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Stok kartları, parti SKT kayıtları ve reyonları bulutta saklayabilir, cihazınıza JSON olarak indirebilir veya tek tıkla geri döndürebilirsiniz.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Yeni Yedek Al & Dışa Aktar',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Verileri buluta arşivler ve anında bilgisayarınıza JSON dosyası olarak indirir.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E)),
                            onPressed: _islemSuruyor ? null : _yedekAl,
                            icon: const Icon(Icons.download_for_offline),
                            label: const Text('Yedek Al ve Cihaza İndir'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2. Bulut Arşivi (İndir & Geri Yükle)',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Buluttaki herhangi bir yedeği cihazınıza indirebilir veya veritabanına geri aktarabilirsiniz.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        if (_bulutYedekleri.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Henüz bulutta kayıtlı yedek bulunmuyor.',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _bulutYedekleri.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final dosya = _bulutYedekleri[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.insert_drive_file,
                                    color: Color(0xFF0F766E)),
                                title: Text(dosya.name,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.file_download,
                                          color: Color(0xFF0F766E), size: 20),
                                      tooltip: 'Cihaza İndir',
                                      onPressed: _islemSuruyor
                                          ? null
                                          : () =>
                                              _buluttanCihazaIndir(dosya.name),
                                    ),
                                    FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            Colors.deepOrange.shade50,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                      ),
                                      onPressed: _islemSuruyor
                                          ? null
                                          : () =>
                                              _buluttanGeriYukle(dosya.name),
                                      child: const Text('Geri Yükle',
                                          style: TextStyle(
                                              color: Colors.deepOrange,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_islemSuruyor)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator())),
                if (_durumMesaji.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(_durumMesaji,
                        style: const TextStyle(fontSize: 12, height: 1.4)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
