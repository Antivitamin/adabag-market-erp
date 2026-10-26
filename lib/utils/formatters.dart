import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TurkceBuyukHarfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buyukYazi =
        newValue.text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
    return TextEditingValue(text: buyukYazi, selection: newValue.selection);
  }
}

class TarihGirisFormatlayici extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('.', '');
    if (text.length > 8) text = text.substring(0, 8);

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 || nonZeroIndex == 4) {
        if (nonZeroIndex != text.length) buffer.write('.');
      }
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.toString().length),
    );
  }
}

class SktRenkYardimcisi {
  // GG.AA.YYYY formatındaki tarihin geçerli ve bugünden ileri olup olmadığını denetler
  static String? tarihGecerlilikKontrolu(String girilenTarih) {
    if (girilenTarih.trim().length != 10) {
      return 'Lütfen tarihi tam girin (GG.AA.YYYY)';
    }

    final parcalar = girilenTarih.split('.');
    if (parcalar.length != 3) {
      return 'Geçersiz tarih formatı!';
    }

    final int? gun = int.tryParse(parcalar[0]);
    final int? ay = int.tryParse(parcalar[1]);
    final int? yil = int.tryParse(parcalar[2]);

    if (gun == null || ay == null || yil == null) {
      return 'Tarih sadece sayılardan oluşmalıdır!';
    }

    if (ay < 1 || ay > 12 || gun < 1 || gun > 31 || yil < 2024) {
      return 'Geçersiz takvim tarihi!';
    }

    try {
      final hedefTarih = DateTime(yil, ay, gun);
      final bugun = DateTime.now();
      final sadeceBugun = DateTime(bugun.year, bugun.month, bugun.day);

      if (hedefTarih.isBefore(sadeceBugun)) {
        return 'Hata: SKT geçmiş bir tarih olamaz!';
      }
    } catch (_) {
      return 'Geçersiz gün/ay kombinasyonu!';
    }

    return null; // Tarih geçerli ve bugünden ileri
  }

  static Map<String, dynamic> analizEt(String sktTarihMetni) {
    try {
      final parcalar = sktTarihMetni.split('-');
      if (parcalar.length != 3) {
        return {
          'arkaRenk': Colors.grey.shade100,
          'yaziRenk': Colors.black87,
          'ikon': Icons.help_outline,
          'metin': sktTarihMetni,
        };
      }

      final hedefTarih = DateTime(
        int.parse(parcalar[0]),
        int.parse(parcalar[1]),
        int.parse(parcalar[2]),
      );
      final bugun = DateTime.now();
      final sadeceBugun = DateTime(bugun.year, bugun.month, bugun.day);
      final kalanGun = hedefTarih.difference(sadeceBugun).inDays;
      final formatliGosterim = '${parcalar[2]}.${parcalar[1]}.${parcalar[0]}';

      if (kalanGun < 0) {
        return {
          'arkaRenk': Colors.red.shade100,
          'yaziRenk': Colors.red.shade900,
          'ikon': Icons.error,
          'metin': '$formatliGosterim (${-kalanGun} Gün Geçmiş!)',
        };
      } else if (kalanGun <= 7) {
        return {
          'arkaRenk': Colors.red.shade50,
          'yaziRenk': Colors.red.shade800,
          'ikon': Icons.warning_amber_rounded,
          'metin': '$formatliGosterim ($kalanGun Gün Kaldı - Acil İndirim)',
        };
      } else if (kalanGun <= 30) {
        return {
          'arkaRenk': Colors.amber.shade50,
          'yaziRenk': Colors.orange.shade900,
          'ikon': Icons.access_time_filled,
          'metin': '$formatliGosterim ($kalanGun Gün Kaldı - Öne Çek)',
        };
      } else {
        return {
          'arkaRenk': Colors.green.shade50,
          'yaziRenk': Colors.green.shade800,
          'ikon': Icons.check_circle_outline,
          'metin': '$formatliGosterim ($kalanGun Gün - Güvenli)',
        };
      }
    } catch (_) {
      return {
        'arkaRenk': Colors.grey.shade100,
        'yaziRenk': Colors.black87,
        'ikon': Icons.help_outline,
        'metin': sktTarihMetni,
      };
    }
  }
}
