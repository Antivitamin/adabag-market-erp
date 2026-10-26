import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class PersonelEkrani extends StatefulWidget {
  const PersonelEkrani({super.key});

  @override
  State<PersonelEkrani> createState() => _PersonelEkraniState();
}

class _PersonelEkraniState extends State<PersonelEkrani> {
  final supabase = Supabase.instance.client;
  List<dynamic> _personeller = [];
  List<String> _tumReyonlar = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _ekranVerileriniYukle();
  }

  Future<void> _ekranVerileriniYukle() async {
    setState(() => _yukleniyor = true);
    await Future.wait([
      _personelleriGetir(),
      _tumReyonlariGetir(),
    ]);
    if (mounted) setState(() => _yukleniyor = false);
  }

  String _turkceBuyuk(String text) {
    return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase().trim();
  }

  int _turkceKarsilastir(String a, String b) {
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

  Future<void> _tumReyonlariGetir() async {
    try {
      final res = await supabase
          .from('mikro_stok_bilgileri')
          .select('stok_ana_grup')
          .limit(2000);

      Set<String> reyonSet = {};
      for (var r in (res as List)) {
        final g = r['stok_ana_grup']?.toString().trim();
        if (g != null && g.isNotEmpty && g != 'TANIMSIZ') {
          reyonSet.add(g);
        }
      }
      final sorted = reyonSet.toList()..sort(_turkceKarsilastir);
      if (mounted) setState(() => _tumReyonlar = sorted);
    } catch (_) {}
  }

  Future<void> _personelleriGetir() async {
    try {
      final res = await supabase.from('profiller').select().order('ad_soyad');
      if (mounted) {
        setState(() => _personeller = res);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Personel listesi yüklenemedi: $e')),
        );
      }
    }
  }

  List<String> _gruplariAyristir(dynamic rawGruplar) {
    if (rawGruplar == null) return [];
    if (rawGruplar is List) {
      return rawGruplar
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (rawGruplar is String && rawGruplar.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawGruplar);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return rawGruplar
            .replaceAll('{', '')
            .replaceAll('}', '')
            .replaceAll('"', '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  // REYON SEÇİM DİYALOGU (TÜRKÇE ALFABETİK SIRALI)
  Future<List<String>?> _reyonSecimDiyalogu(List<String> secililer) async {
    List<String> geciciSecililer = List.from(secililer);
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Atanacak Reyonları Seçin (Alfabetik)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: _tumReyonlar.isEmpty
                ? const Center(child: Text('Tanımlı reyon bulunamadı.'))
                : ListView.builder(
                    itemCount: _tumReyonlar.length,
                    itemBuilder: (c, idx) {
                      final reyon = _tumReyonlar[idx];
                      final bool isChecked = geciciSecililer.contains(reyon);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(reyon,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        value: isChecked,
                        onChanged: (val) {
                          setDState(() {
                            if (val == true) {
                              geciciSecililer.add(reyon);
                            } else {
                              geciciSecililer.remove(reyon);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, geciciSecililer),
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
  }

  void _yeniPersonelOlusturDiyalogu() {
    final adSoyadCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final sifreCtrl = TextEditingController(text: '123456');
    String seciliRol = 'reyoncu';
    List<String> atananGruplar = [];
    bool kaydediliyor = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Yeni Personel Tanımla'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: adSoyadCtrl,
                  inputFormatters: [TurkceBuyukHarfFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Personel Ad Soyad',
                    hintText: 'Ad Soyad giriniz',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Giriş E-Postası',
                    hintText: 'ornek@adabagmarket.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sifreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Geçici Şifre',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Atanacak Rol:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: seciliRol,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'reyoncu',
                      child: Text('Reyon Personeli (Kısıtlı Yetki)'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Mağaza Yöneticisi (Admin - Tam Yetki)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDState(() => seciliRol = val);
                    }
                  },
                ),
                if (seciliRol == 'reyoncu') ...[
                  const SizedBox(height: 14),
                  const Text('Atanan Reyonlar / Gruplar:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final secilenler =
                          await _reyonSecimDiyalogu(atananGruplar);
                      if (secilenler != null) {
                        setDState(() => atananGruplar = secilenler);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        border: Border.all(color: Colors.teal.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              atananGruplar.isEmpty
                                  ? 'Reyon Seçmek İçin Tıklayın'
                                  : atananGruplar.join(', '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: atananGruplar.isEmpty
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: atananGruplar.isEmpty
                                      ? Colors.grey.shade600
                                      : Colors.teal.shade900),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
                              color: Color(0xFF0F766E)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: kaydediliyor ? null : () => Navigator.pop(dialogCtx),
              child: const Text('İptal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E)),
              onPressed: kaydediliyor
                  ? null
                  : () async {
                      final adSoyad = adSoyadCtrl.text.trim();
                      final email = emailCtrl.text.trim().toLowerCase();
                      final sifre = sifreCtrl.text.trim();

                      if (adSoyad.isEmpty || email.isEmpty || sifre.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Lütfen tüm alanları doldurun!')),
                        );
                        return;
                      }

                      setDState(() => kaydediliyor = true);
                      try {
                        final dynamic res = await supabase.rpc(
                          'admin_personel_olustur',
                          params: {
                            'yeni_email': email,
                            'yeni_sifre': sifre,
                            'yeni_ad_soyad': adSoyad,
                            'yeni_rol': seciliRol,
                          },
                        );

                        if (res != null && res['success'] == true) {
                          final yeniId = res['user_id'];
                          if (yeniId != null) {
                            await supabase.from('profiller').update({
                              'atanan_gruplar':
                                  seciliRol == 'admin' ? [] : atananGruplar,
                            }).eq('id', yeniId);
                          }

                          if (!mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$adSoyad başarıyla oluşturuldu.'),
                              backgroundColor: const Color(0xFF0F766E),
                            ),
                          );
                          _personelleriGetir();
                        } else {
                          final msg = res?['message'] ?? 'İşlem başarısız.';
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(msg),
                                backgroundColor: Colors.redAccent),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Hata: $e'),
                                backgroundColor: Colors.redAccent),
                          );
                        }
                      } finally {
                        setDState(() => kaydediliyor = false);
                      }
                    },
              child: kaydediliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _rolDegistirDiyalogu(dynamic personel) {
    String seciliRol =
        (personel['rol'] ?? 'reyoncu').toString().toLowerCase().trim();
    if (seciliRol != 'admin' && seciliRol != 'reyoncu') seciliRol = 'reyoncu';

    final adSoyadCtrl = TextEditingController(text: personel['ad_soyad'] ?? '');
    List<String> atananGruplar = _gruplariAyristir(personel['atanan_gruplar']);

    bool kaydediliyor = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Personel Yetki & Reyon Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: adSoyadCtrl,
                  inputFormatters: [TurkceBuyukHarfFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Yetki Rolü:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: seciliRol,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Mağaza Yöneticisi (Admin)'),
                    ),
                    DropdownMenuItem(
                      value: 'reyoncu',
                      child: Text('Reyon Personeli'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDState(() => seciliRol = val);
                    }
                  },
                ),
                if (seciliRol == 'reyoncu') ...[
                  const SizedBox(height: 14),
                  const Text('Atanan Reyonlar / Gruplar:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final secilenler =
                          await _reyonSecimDiyalogu(atananGruplar);
                      if (secilenler != null) {
                        setDState(() => atananGruplar = secilenler);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        border: Border.all(color: Colors.teal.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              atananGruplar.isEmpty
                                  ? 'Reyon Seçmek İçin Tıklayın'
                                  : atananGruplar.join(', '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: atananGruplar.isEmpty
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: atananGruplar.isEmpty
                                      ? Colors.grey.shade600
                                      : Colors.teal.shade900),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
                              color: Color(0xFF0F766E)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: kaydediliyor ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E)),
              onPressed: kaydediliyor
                  ? null
                  : () async {
                      setDState(() => kaydediliyor = true);
                      try {
                        final sonGruplar =
                            seciliRol == 'admin' ? [] : atananGruplar;

                        try {
                          await supabase.rpc(
                            'admin_personel_guncelle',
                            params: {
                              'hedef_kullanici_id': personel['id'],
                              'yeni_ad_soyad': adSoyadCtrl.text.trim(),
                              'yeni_rol': seciliRol,
                              'yeni_atanan_gruplar': sonGruplar,
                            },
                          );
                        } catch (_) {}

                        await supabase.from('profiller').update({
                          'ad_soyad': adSoyadCtrl.text.trim(),
                          'rol': seciliRol,
                          'atanan_gruplar': sonGruplar,
                        }).eq('id', personel['id']);

                        if (!mounted) return;
                        Navigator.pop(dialogCtx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${adSoyadCtrl.text.trim()} bilgileri ve reyonları kaydedildi.'),
                            backgroundColor: const Color(0xFF0F766E),
                          ),
                        );
                        _personelleriGetir();
                      } catch (err) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Hata: $err'),
                                backgroundColor: Colors.redAccent),
                          );
                        }
                      } finally {
                        setDState(() => kaydediliyor = false);
                      }
                    },
              child: kaydediliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  void _personelSilDiyalogu(dynamic personel) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Personeli Sil'),
        content: Text(
            '${personel['ad_soyad']} personeli tamamen silinecektir. Emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                final dynamic res = await supabase.rpc(
                  'admin_personel_sil',
                  params: {'hedef_kullanici_id': personel['id']},
                );

                if (!mounted) return;
                Navigator.pop(dialogCtx);

                if (res != null && res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${personel['ad_soyad']} silindi.'),
                        backgroundColor: const Color(0xFF0F766E)),
                  );
                  _personelleriGetir();
                } else {
                  final msg = res?['message'] ?? 'Silinemedi';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(msg), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel & Reyon Yetki Yönetimi'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _ekranVerileriniYukle),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _yeniPersonelOlusturDiyalogu,
        icon: const Icon(Icons.person_add),
        label: const Text('Yeni Personel Ekle'),
        backgroundColor: Colors.purple,
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _personeller.isEmpty
              ? const Center(child: Text('Kayıtlı personel bulunamadı.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _personeller.length,
                  itemBuilder: (context, index) {
                    final p = _personeller[index];
                    final bool isAdmin =
                        (p['rol'] ?? '').toString().toLowerCase().trim() ==
                            'admin';
                    final List<String> atananlar =
                        _gruplariAyristir(p['atanan_gruplar']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAdmin
                              ? Colors.purple.shade100
                              : const Color(0xFF0F766E).withValues(alpha: 0.15),
                          child: Icon(
                            isAdmin
                                ? isAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.person
                                : Icons.person,
                            color: isAdmin
                                ? Colors.purple
                                : const Color(0xFF0F766E),
                          ),
                        ),
                        title: Text(
                          p['ad_soyad'] ?? 'İSİMSİZ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdmin
                                  ? 'Yetki: Mağaza Yöneticisi (Admin)'
                                  : 'Yetki: Reyon Personeli',
                              style: TextStyle(
                                color: isAdmin
                                    ? Colors.purple.shade700
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!isAdmin)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  atananlar.isEmpty
                                      ? 'Atanan Reyon: Yok'
                                      : 'Reyonlar: ${atananlar.join(', ')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: atananlar.isEmpty
                                        ? Colors.red.shade700
                                        : Colors.teal.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Color(0xFF0F766E)),
                              tooltip: 'Yetkiyi / Reyonları Düzenle',
                              onPressed: () => _rolDegistirDiyalogu(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              tooltip: 'Personeli Sil',
                              onPressed: () => _personelSilDiyalogu(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
