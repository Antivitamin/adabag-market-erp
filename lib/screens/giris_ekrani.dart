import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ana_panel_ekrani.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _emailController = TextEditingController();
  final _sifreController = TextEditingController();
  bool _yukleniyor = false;
  bool _sifreGizli = true;

  @override
  void dispose() {
    _emailController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    final email = _emailController.text.trim();
    final sifre = _sifreController.text.trim();

    if (email.isEmpty || sifre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta ve şifrenizi girin!')),
      );
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: sifre,
      );

      final user = res.user;
      if (user == null) throw 'Giriş yapılamadı.';

      String rol = 'reyoncu';
      String adSoyad = email;

      try {
        final profil = await Supabase.instance.client
            .from('profiller')
            .select('ad_soyad, rol')
            .eq('id', user.id)
            .maybeSingle();

        if (profil != null) {
          rol = (profil['rol'] ?? 'reyoncu').toString().trim();
          adSoyad = (profil['ad_soyad'] ?? email).toString().trim();
        }
      } catch (_) {
        rol = user.userMetadata?['rol']?.toString() ?? 'reyoncu';
        adSoyad = user.userMetadata?['ad_soyad']?.toString() ?? email;
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => AnaPanelEkrani(
              rol: rol,
              adSoyad: adSoyad,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Giriş başarısız: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LOGO ALANI
                    Container(
                      constraints:
                          const BoxConstraints(maxHeight: 140, maxWidth: 260),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Logo dosyası bulunamazsa gösterilecek şık yedek ikon
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.storefront,
                                size: 54, color: Colors.indigo.shade900),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MARKET ERP YÖNETİMİ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mikro v17 & Supabase Entegre Portal',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 28),
                    // FORM ALANLARI
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-Posta',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _sifreController,
                      obscureText: _sifreGizli,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_sifreGizli
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _sifreGizli = !_sifreGizli),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _girisYap(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.indigo.shade900,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _yukleniyor ? null : _girisYap,
                        child: _yukleniyor
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'GİRİŞ YAP',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
