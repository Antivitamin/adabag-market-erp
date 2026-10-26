import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'giris_ekrani.dart';
import 'hizli_sorgu_ekrani.dart';
import 'urun_skt_ekrani.dart';
import 'hareketsiz_stok_ekrani.dart';
import 'stok_kartlari_ekrani.dart';
import 'reyonlar_ekrani.dart';
import 'yedekleme_ekrani.dart';
import 'personel_ekrani.dart';
import 'gun_sonu_ekrani.dart';

class AnaPanelEkrani extends StatefulWidget {
  final String? rol;
  final String? adSoyad;

  const AnaPanelEkrani({super.key, this.rol, this.adSoyad});

  @override
  State<AnaPanelEkrani> createState() => _AnaPanelEkraniState();
}

class _AnaPanelEkraniState extends State<AnaPanelEkrani> {
  final _supabase = Supabase.instance.client;
  String _kullaniciAdi = 'Kullanıcı';
  String _rol = 'reyoncu';
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _kullaniciBilgileriniHazirla();
  }

  Future<void> _kullaniciBilgileriniHazirla() async {
    if (widget.rol != null && widget.rol!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _rol = widget.rol!.trim().toLowerCase();
          _kullaniciAdi = widget.adSoyad ?? 'Kullanıcı';
          _yukleniyor = false;
        });
      }
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profil = await _supabase
            .from('profiller')
            .select('ad_soyad, rol')
            .eq('id', user.id)
            .maybeSingle();

        if (profil != null) {
          if (mounted) {
            setState(() {
              _kullaniciAdi = profil['ad_soyad']?.toString() ?? 'Kullanıcı';
              _rol =
                  (profil['rol']?.toString() ?? 'reyoncu').trim().toLowerCase();
              _yukleniyor = false;
            });
          }
          return;
        }

        final metaAd = user.userMetadata?['ad_soyad']?.toString();
        final metaRol = user.userMetadata?['rol']?.toString();

        if (mounted) {
          setState(() {
            _kullaniciAdi =
                metaAd ?? user.email?.split('@').first ?? 'Kullanıcı';
            _rol = (metaRol ?? 'reyoncu').trim().toLowerCase();
            _yukleniyor = false;
          });
        }
      } else {
        if (mounted) setState(() => _yukleniyor = false);
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // KULLANICI ŞİFRE DEĞİŞTİRME DİYALOGU
  void _sifreDegistirDiyalogu() {
    final yeniSifreCtrl = TextEditingController();
    final yeniSifreTekrarCtrl = TextEditingController();
    bool sifreGizli1 = true;
    bool sifreGizli2 = true;
    bool kaydediliyor = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Şifre Değiştir',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: yeniSifreCtrl,
                obscureText: sifreGizli1,
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                        sifreGizli1 ? Icons.visibility_off : Icons.visibility,
                        size: 20),
                    onPressed: () =>
                        setDState(() => sifreGizli1 = !sifreGizli1),
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yeniSifreTekrarCtrl,
                obscureText: sifreGizli2,
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre (Tekrar)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                        sifreGizli2 ? Icons.visibility_off : Icons.visibility,
                        size: 20),
                    onPressed: () =>
                        setDState(() => sifreGizli2 = !sifreGizli2),
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: kaydediliyor ? null : () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E)),
              onPressed: kaydediliyor
                  ? null
                  : () async {
                      final s1 = yeniSifreCtrl.text.trim();
                      final s2 = yeniSifreTekrarCtrl.text.trim();

                      if (s1.isEmpty || s2.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Lütfen şifre alanlarını doldurun!')),
                        );
                        return;
                      }
                      if (s1 != s2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Girdiğiniz şifreler birbiriyle uyuşmuyor!')),
                        );
                        return;
                      }
                      if (s1.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Şifre en az 6 karakter olmalıdır!')),
                        );
                        return;
                      }

                      setDState(() => kaydediliyor = true);
                      try {
                        await _supabase.auth.updateUser(
                          UserAttributes(password: s1),
                        );

                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Şifreniz başarıyla güncellendi.'),
                            backgroundColor: Color(0xFF0F766E),
                          ),
                        );
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
                  : const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cikisYap() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content:
            const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (onay == true) {
      try {
        await _supabase.auth.signOut();
      } catch (_) {}

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GirisEkrani()),
        (route) => false,
      );
    }
  }

  Widget _buildMenuKarti({
    required String baslik,
    required String altBaslik,
    required IconData icon,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: renk, size: 26),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    altBaslik,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool reyoncuMu = _rol == 'reyoncu';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Adabağ Market ERP Paneli',
            style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Çıkış Yap',
            onPressed: _cikisYap,
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HOŞ GELDİNİZ KARTI (LOGO + İSİM + ŞİFRE DEĞİŞTİR BUTONU)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade800,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        // LOGO ALANI
                        Container(
                          width: 46,
                          height: 46,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.storefront_rounded,
                                    color: Color(0xFF1E1B4B), size: 28);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // HOŞ GELDİNİZ METNİ
                        Expanded(
                          child: Text(
                            'Hoş Geldiniz, $_kullaniciAdi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ŞİFRE DEĞİŞTİR BUTONU
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _sifreDegistirDiyalogu,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.key_rounded,
                                    color: Colors.amberAccent, size: 15),
                                SizedBox(width: 4),
                                Text(
                                  'Şifre Değiştir',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Hızlı İşlemler & Modüller',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),

                  // MODÜL GRID LİSTESİ
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                    children: [
                      // 1. Fiyat Gör & Hızlı Stok
                      _buildMenuKarti(
                        baslik: 'Fiyat Gör & Hızlı Stok',
                        altBaslik: 'Barkod Okut ve Sorgula',
                        icon: Icons.qr_code_scanner,
                        renk: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HizliSorguEkrani()),
                          );
                        },
                      ),

                      // 2. STOK KARTLARI (Reyoncuya Gizli)
                      if (!reyoncuMu)
                        _buildMenuKarti(
                          baslik: 'Stok Kartları',
                          altBaslik: 'Tüm Liste, Alış & Satış',
                          icon: Icons.inventory,
                          renk: Colors.blue.shade700,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const StokKartlariEkrani()),
                            );
                          },
                        ),

                      // 3. Ürün & SKT Takip
                      _buildMenuKarti(
                        baslik: 'Ürün & SKT Takip',
                        altBaslik: 'Parti ve SKT Listesi',
                        icon: Icons.event_available,
                        renk: Colors.teal.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => UrunSktEkrani(rol: _rol)),
                          );
                        },
                      ),

                      // 4. Hareketsiz Stok
                      _buildMenuKarti(
                        baslik: 'Hareketsiz Stok',
                        altBaslik: 'Stok > 10 & 0 Satış',
                        icon: Icons.warning_amber_rounded,
                        renk: Colors.red.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    HareketsizStokEkrani(rol: _rol)),
                          );
                        },
                      ),

                      // 5. Reyonlar & Stok Grupları
                      _buildMenuKarti(
                        baslik: 'Reyonlar',
                        altBaslik: 'Reyon & Stok Grupları',
                        icon: Icons.grid_view_rounded,
                        renk: Colors.deepOrange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ReyonlarEkrani(rol: _rol)),
                          );
                        },
                      ),

                      // 6. GÜN SONU & KASA (Reyoncuya Gizli)
                      if (!reyoncuMu)
                        _buildMenuKarti(
                          baslik: 'Gün Sonu & Kasa',
                          altBaslik: 'Nakit, POS, İade & Ciro',
                          icon: Icons.point_of_sale_rounded,
                          renk: Colors.amber.shade900,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const GunSonuEkrani()),
                            );
                          },
                        ),

                      // 7. KULLANICI & YETKİ YÖNETİMİ (Reyoncuya Gizli)
                      if (!reyoncuMu)
                        _buildMenuKarti(
                          baslik: 'Kullanıcı Yetkileri',
                          altBaslik: 'Personel Ekle & Rol Tanımla',
                          icon: Icons.manage_accounts_rounded,
                          renk: Colors.blueGrey.shade800,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PersonelEkrani()),
                            );
                          },
                        ),

                      // 8. VERİ YEDEKLEME (Reyoncuya Gizli)
                      if (!reyoncuMu)
                        _buildMenuKarti(
                          baslik: 'Veri Yedekleme',
                          altBaslik: 'Supabase Depo & Geri Yükle',
                          icon: Icons.cloud_sync_rounded,
                          renk: Colors.purple.shade700,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const YedeklemeEkrani()),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
