// Sprachen der Oberfläche: Deutsch ist die Quelle (Schlüssel), dazu Türkçe, English, العربية.
// Platzhalter wie bei String(format:): %@ für Text, %d für Zahlen, %1$@ für feste Reihenfolge.
import Foundation

enum AppLang: String, CaseIterable {
    case de, tr, en, ar

    /// Jede Sprache in sich selbst benannt
    var label: String { ["de": "Deutsch", "tr": "Türkçe", "en": "English", "ar": "العربية"][rawValue]! }
    var locale: Locale { Locale(identifier: ["de": "de_DE", "tr": "tr_TR", "en": "en_GB", "ar": "ar@numbers=latn"][rawValue]!) }
    var rtl: Bool { self == .ar }

    /// Systemsprache, falls unterstützt, sonst Deutsch
    static var system: AppLang {
        for id in Locale.preferredLanguages {
            if let l = AppLang(rawValue: String(id.prefix(2))) { return l }
        }
        return .de
    }
}

var appLang = AppLang(rawValue: UserDefaults.standard.string(forKey: "lang") ?? "") ?? AppLang.system

/// Übersetzt einen deutschen Text in die gewählte Sprache und setzt Werte ein.
func L(_ de: String, _ args: CVarArg...) -> String {
    let s = appLang == .de ? de : (translations[de]?[appLang.rawValue] ?? de)
    return args.isEmpty ? s : String(format: s, arguments: args)
}

let translations: [String: [String: String]] = [
    // Zeiten und Countdown
    "min": ["tr": "dk", "en": "min", "ar": "د"],
    "h": ["tr": "sa", "en": "h", "ar": "س"],
    "%@ bis %@": ["tr": "%@ ile %@", "en": "%@ to %@", "ar": "%@ إلى %@"],
    "um %@": ["tr": "%@", "en": "at %@", "ar": "الساعة %@"],
    "%@ um %@": ["tr": "%@ %@", "en": "%@ at %@", "ar": "%@ الساعة %@"],
    "%@, %@ um %@": ["tr": "%@, %@ %@", "en": "%@, %@ at %@", "ar": "%@، %@ الساعة %@"],
    "%@, endet um %@": ["tr": "%@, bitiş %@", "en": "%@, ends at %@", "ar": "%@، ينتهي الساعة %@"],
    "%@-Zeit endet um %@": ["tr": "%@ vakti bitişi: %@", "en": "%@ time ends at %@", "ar": "ينتهي وقت %@ الساعة %@"],
    "Endet um %@": ["tr": "Bitiş: %@", "en": "Ends at %@", "ar": "ينتهي الساعة %@"],
    "Bis %@": ["tr": "%@ vaktine kadar", "en": "Until %@", "ar": "حتى %@"],
    "%@ in": ["tr": "%@'e kalan", "en": "%@ in", "ar": "%@ بعد"],
    "Lade…": ["tr": "Yükleniyor…", "en": "Loading…", "ar": "جارٍ التحميل…"],
    "Keine Daten": ["tr": "Veri yok", "en": "No data", "ar": "لا بيانات"],
    "Lade Gebetszeiten…": ["tr": "Namaz vakitleri yükleniyor…", "en": "Loading prayer times…", "ar": "جارٍ تحميل مواقيت الصلاة…"],
    "Keine Gebetszeiten vorhanden": ["tr": "Namaz vakti bulunamadı", "en": "No prayer times available", "ar": "لا توجد مواقيت صلاة"],

    // Kerahat
    "nach Sonnenaufgang": ["tr": "güneş doğduktan sonra", "en": "after sunrise", "ar": "بعد الشروق"],
    "vor %@ (Istiwa)": ["tr": "%@ öncesi (istiva)", "en": "before %@ (zenith)", "ar": "قبل %@ (الاستواء)"],
    "vor Sonnenuntergang": ["tr": "güneş batmadan önce", "en": "before sunset", "ar": "قبل الغروب"],
    "%@ nach Sonnenaufgang: %d min": ["tr": "Güneşten sonra %@: %d dk", "en": "%@ after sunrise: %d min", "ar": "%@ بعد الشروق: %d دقيقة"],
    "%@ vor %@: %d min": ["tr": "%2$@ öncesi %1$@: %3$d dk", "en": "%@ before %@: %d min", "ar": "%@ قبل %@: %d دقيقة"],

    // Stadt und Standort
    "Stadt wählen": ["tr": "Şehir seç", "en": "Choose city", "ar": "اختر المدينة"],
    "Automatisch per Standort": ["tr": "Konuma göre otomatik", "en": "Automatic by location", "ar": "تلقائي حسب الموقع"],
    "Stadt suchen, z. B. Berlin": ["tr": "Şehir ara, ör. Berlin", "en": "Search city, e.g. Berlin", "ar": "ابحث عن مدينة، مثل برلين"],
    "Standort: %@": ["tr": "Konum: %@", "en": "Location: %@", "ar": "الموقع: %@"],
    "Standort: %@, %d km entfernt": ["tr": "Konum: %@, %d km uzakta", "en": "Location: %@, %d km away", "ar": "الموقع: %@، على بعد %d كم"],
    "Standort gerade nicht bestimmbar, es bleibt %@.": ["tr": "Konum şu an belirlenemiyor, %@ kalıyor.", "en": "Location unavailable right now, staying with %@.", "ar": "تعذر تحديد الموقع حاليًا، تبقى %@."],
    "Standortzugriff ist aus. Freigeben unter Systemeinstellungen > Datenschutz & Sicherheit > Ortungsdienste.": [
        "tr": "Konum erişimi kapalı. Sistem Ayarları > Gizlilik ve Güvenlik > Konum Servisleri'nden izin ver.",
        "en": "Location access is off. Allow it in System Settings > Privacy & Security > Location Services.",
        "ar": "الوصول إلى الموقع متوقف. فعّله من إعدادات النظام > الخصوصية والأمن > خدمات الموقع."],
    "IGMG nicht erreichbar, keine Zeiten für heute.": ["tr": "IGMG'ye ulaşılamıyor, bugün için vakit yok.", "en": "IGMG unreachable, no times for today.", "ar": "تعذر الاتصال بـ IGMG، لا توجد مواقيت لليوم."],
    "IGMG nicht erreichbar, zeige gespeicherte Zeiten.": ["tr": "IGMG'ye ulaşılamıyor, kayıtlı vakitler gösteriliyor.", "en": "IGMG unreachable, showing saved times.", "ar": "تعذر الاتصال بـ IGMG، تُعرض المواقيت المحفوظة."],

    // Einstellungen und Fußleiste
    "Sprache": ["tr": "Dil", "en": "Language", "ar": "اللغة"],
    "Namen": ["tr": "Vakit adları", "en": "Prayer names", "ar": "أسماء الصلوات"],
    "Sekunden in der Menüleiste": ["tr": "Menü çubuğunda saniye", "en": "Seconds in menu bar", "ar": "الثواني في شريط القوائم"],
    "Bei Anmeldung starten": ["tr": "Oturum açıldığında başlat", "en": "Open at login", "ar": "التشغيل عند تسجيل الدخول"],
    "Updates automatisch installieren": ["tr": "Güncellemeleri otomatik yükle", "en": "Install updates automatically", "ar": "تثبيت التحديثات تلقائيًا"],
    "Version %@": ["tr": "Sürüm %@", "en": "Version %@", "ar": "الإصدار %@"],
    "Nach Updates suchen": ["tr": "Güncellemeleri denetle", "en": "Check for updates", "ar": "البحث عن تحديثات"],
    "Fertig": ["tr": "Bitti", "en": "Done", "ar": "تم"],
    "Einstellungen": ["tr": "Ayarlar", "en": "Settings", "ar": "الإعدادات"],
    "Neu von IGMG laden": ["tr": "IGMG'den yeniden yükle", "en": "Reload from IGMG", "ar": "إعادة التحميل من IGMG"],
    "Beenden": ["tr": "Çıkış", "en": "Quit", "ar": "إنهاء"],
    "Quelle IGMG": ["tr": "Kaynak: IGMG", "en": "Source: IGMG", "ar": "المصدر: IGMG"],
    ", Stand %@": ["tr": ", güncelleme %@", "en": ", updated %@", "ar": "، آخر تحديث %@"],

    // Namen-Auswahl
    "Türkisch (Akşam)": ["tr": "Türkçe (Akşam)", "en": "Turkish (Akşam)", "ar": "التركية (Akşam)"],
    "Arabisch, Umschrift (Maghrib)": ["tr": "Arapça, Latin harfli (Maghrib)", "en": "Arabic, transliterated (Maghrib)", "ar": "العربية بحروف لاتينية (Maghrib)"],
    "Arabisch, Schrift (المغرب)": ["tr": "Arapça, Arap harfli (المغرب)", "en": "Arabic script (المغرب)", "ar": "العربية (المغرب)"],
    "Deutsch (Abend)": ["tr": "Almanca (Abend)", "en": "German (Abend)", "ar": "الألمانية (Abend)"],
    "Englisch (Sunset)": ["tr": "İngilizce (Sunset)", "en": "English (Sunset)", "ar": "الإنجليزية (Sunset)"],

    // Updates
    "Version %@ ist da": ["tr": "Sürüm %@ hazır", "en": "Version %@ available", "ar": "الإصدار %@ متاح"],
    "Neue Version installieren": ["tr": "Yeni sürümü yükle", "en": "Install new version", "ar": "تثبيت الإصدار الجديد"],
    "Installieren": ["tr": "Yükle", "en": "Install", "ar": "تثبيت"],
    "Suche nach Updates…": ["tr": "Güncellemeler denetleniyor…", "en": "Checking for updates…", "ar": "جارٍ البحث عن تحديثات…"],
    "Du hast die neueste Version (%@).": ["tr": "En güncel sürüm kurulu (%@).", "en": "You're up to date (%@).", "ar": "لديك أحدث إصدار (%@)."],
    "Update-Prüfung fehlgeschlagen.": ["tr": "Güncelleme denetimi başarısız.", "en": "Update check failed.", "ar": "فشل البحث عن تحديثات."],
    "Lade Version %@…": ["tr": "Sürüm %@ indiriliyor…", "en": "Downloading version %@…", "ar": "جارٍ تنزيل الإصدار %@…"],
    "Starte neu…": ["tr": "Yeniden başlatılıyor…", "en": "Restarting…", "ar": "جارٍ إعادة التشغيل…"],
    "Update fehlgeschlagen: %@": ["tr": "Güncelleme başarısız: %@", "en": "Update failed: %@", "ar": "فشل التحديث: %@"],
    "Prüfsumme stimmt nicht": ["tr": "Sağlama toplamı uyuşmuyor", "en": "Checksum mismatch", "ar": "المجموع الاختباري غير مطابق"],
    "Paket unvollständig": ["tr": "Paket eksik", "en": "Package incomplete", "ar": "الحزمة غير مكتملة"],
    "Keine Schreibrechte für %@": ["tr": "%@ için yazma izni yok", "en": "No write permission for %@", "ar": "لا توجد صلاحية كتابة لـ %@"],
    "Entpacken fehlgeschlagen": ["tr": "Arşiv açılamadı", "en": "Unpacking failed", "ar": "فشل فك الضغط"],
]
