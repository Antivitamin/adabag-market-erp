// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'screens/ana_panel_ekrani.dart';
import 'screens/giris_ekrani.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase kalıcı oturum yönetimiyle başlatılıyor
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const AdabagErpApp());
}

class AdabagErpApp extends StatelessWidget {
  const AdabagErpApp({super.key});

  Future<Map<String, String>?> _oturumKontrolEt() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final res = await supabase
          .from('profiller')
          .select('ad_soyad, rol')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        return {
          'adSoyad': res['ad_soyad'] ?? 'Personel',
          'rol': res['rol'] ?? 'reyoncu',
        };
      }
    } catch (_) {}

    return {'adSoyad': 'Kullanıcı', 'rol': 'reyoncu'};
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adabağ Hipermarket ERP',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR')],
      locale: const Locale('tr', 'TR'),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          primary: const Color(0xFF0F766E),
        ),
      ),
      home: FutureBuilder<Map<String, String>?>(
        future: _oturumKontrolEt(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF0F766E)),
              ),
            );
          }

          // Oturum varsa doğrudan ana panele, yoksa giriş ekranına yönlendir
          if (snapshot.hasData && snapshot.data != null) {
            return AnaPanelEkrani(
              rol: snapshot.data!['rol']!,
              adSoyad: snapshot.data!['adSoyad']!,
            );
          }

          return const GirisEkrani();
        },
      ),
    );
  }
}
