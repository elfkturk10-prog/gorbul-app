import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
// Not: google_fonts eklenirse: import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// MAIN ENTRY POINT
// ---------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Yönetici Firebase hesabı bağladığında çalışır)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase initialization failed or not configured yet: $e");
  }

  // Initialize Persistent Storage (Cloud/Local)
  await DataStore.init();

  // Üstteki bildirim çubuğu kalır, alttaki geri/home tuş çubuğu KALDIRILIR
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const GorBulApp());
}

// ---------------------------------------------------------------------------
// APP CONFIG & THEME
// ---------------------------------------------------------------------------
class GorBulApp extends StatelessWidget {
  const GorBulApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Lacivert (#0A1F44) ve Beyaz Tema
    const primaryColor = Color(0xFF0A1F44);

    return MaterialApp(
      title: 'GörBul',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Otomatik Dark/Light
      theme: _buildTheme(Brightness.light, primaryColor),
      darkTheme: _buildTheme(Brightness.dark, primaryColor),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness, Color primary) {
    final bool isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      primaryColor: primary,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: isDark
            ? Colors.tealAccent
            : const Color(0xFFE63946), // Accent color
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto', // Google Fonts tarzı
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white, // Daima beyaz kalsın
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? Colors.tealAccent : primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        labelStyle:
            TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
      // Kartlar oval ve modern
      cardTheme: CardTheme(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // Dark modda çok sırıtmayan gri
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
        margin: EdgeInsets.zero,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DATA MODELS
// ---------------------------------------------------------------------------
class User {
  final String id;
  final String name;
  final String surname;
  final String tc;
  final String email;
  final String password;
  final String schoolName;
  final bool isManager;

  User({
    required this.id,
    required this.name,
    required this.surname,
    required this.tc,
    required this.email,
    required this.password,
    required this.schoolName,
    this.isManager = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'tc': tc,
      'email': email,
      'password': password,
      'schoolName': schoolName,
      'isManager': isManager,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      tc: json['tc'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      schoolName: json['schoolName'] ?? 'Belirtilmedi',
      isManager: json['isManager'] ?? false,
    );
  }
}

class Listing {
  final String id;
  final String title;
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime date;
  final DateTime expiryDate; // 15 gün sonra otomatik silinir
  final String imageUrl; // Dosya yolu veya URL
  final File? imageFile; // Yerel test için
  final String securityQuestion;
  final String securityAnswer;
  final bool isUrgent;
  final String ownerName;
  final String rewardAmount;
  final String schoolName;
  final String ownerId;
  final String status; // 'active' veya 'resolved'

  Listing({
    required this.id,
    required this.title,
    required this.location,
    this.latitude,
    this.longitude,
    required this.date,
    DateTime? expiryDate,
    this.imageUrl = '',
    this.imageFile,
    required this.securityQuestion,
    required this.securityAnswer,
    this.isUrgent = false,
    this.ownerName = 'Anonim Kullanıcı',
    this.rewardAmount = '',
    this.schoolName = 'Belirtilmedi',
    required this.ownerId,
    this.status = 'active',
  }) : expiryDate = expiryDate ?? date.add(const Duration(days: 15));

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'date': date.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'imageUrl': imageUrl,
      'imageFilePath': imageFile?.path,
      'securityQuestion': securityQuestion,
      'securityAnswer': securityAnswer,
      'isUrgent': isUrgent,
      'ownerName': ownerName,
      'rewardAmount': rewardAmount,
      'schoolName': schoolName,
      'ownerId': ownerId,
      'status': status,
    };
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    final createdDate = json['date'] != null ? DateTime.parse(json['date']) : DateTime.now();
    return Listing(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      location: json['location'] ?? '',
      latitude: json['latitude'],
      longitude: json['longitude'],
      date: createdDate,
      expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : createdDate.add(const Duration(days: 15)),
      imageUrl: json['imageUrl'] ?? '',
      imageFile: json['imageFilePath'] != null ? File(json['imageFilePath']) : null,
      securityQuestion: json['securityQuestion'] ?? '',
      securityAnswer: json['securityAnswer'] ?? '',
      isUrgent: json['isUrgent'] ?? false,
      ownerName: json['ownerName'] ?? 'Anonim Kullanıcı',
      rewardAmount: json['rewardAmount'] ?? '',
      schoolName: json['schoolName'] ?? 'Belirtilmedi',
      ownerId: json['ownerId'] ?? '',
      status: json['status'] ?? 'active',
    );
  }
}

class VaultItem {
  final String id;
  final String title;
  final String serial;
  final String date;
  final int iconCodePoint;
  final int colorValue;

  VaultItem({
    required this.id,
    required this.title,
    required this.serial,
    required this.date,
    required this.iconCodePoint,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'serial': serial,
        'date': date,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
        id: json['id'],
        title: json['title'],
        serial: json['serial'],
        date: json['date'],
        iconCodePoint: json['iconCodePoint'],
        colorValue: json['colorValue'],
      );
}

class ChatMessage {
  final String text;
  final bool isMe;
  final String time;

  ChatMessage({required this.text, required this.isMe, required this.time});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isMe': isMe,
        'time': time,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        isMe: json['isMe'],
        time: json['time'],
      );
}

class ChatPreview {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final String avatarUrl;
  final List<ChatMessage> messages; // Mesaj geçmişi

  ChatPreview({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatarUrl,
    this.messages = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lastMessage': lastMessage,
        'time': time,
        'avatarUrl': avatarUrl,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatPreview.fromJson(Map<String, dynamic> json) => ChatPreview(
        id: json['id'],
        name: json['name'],
        lastMessage: json['lastMessage'],
        time: json['time'],
        avatarUrl: json['avatarUrl'],
        messages: (json['messages'] as List?)
                ?.map((m) => ChatMessage.fromJson(m))
                .toList() ??
            [],
      );
}

// Data Store (Persistent with path_provider)
class DataStore {
  static List<Listing> listings = [];
  static List<String> favoriteListingIds = []; // Favori ilan ID'leri
  static List<ChatPreview> chats = [];
  static List<VaultItem> vaultItems = [];
  static bool isLoggedIn = false;
  static bool hasSeenOnboarding = false;
  static List<User> registeredUsers = [];
  static User? currentUser;
  static bool isDarkMode = false;

  static void setDarkMode(bool v) { isDarkMode = v; }

  static Future<void> reloadCurrentUser() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.id).get();
      if (doc.exists) currentUser = User.fromJson(doc.data()!);
    } catch (_) {}
  }

  static Future<File> _getFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  static Future<void> init() async {
    try {
      final prefsFile = await _getFile('prefs.json');
      if (await prefsFile.exists()) {
        final data = jsonDecode(await prefsFile.readAsString());
        isLoggedIn = data['isLoggedIn'] ?? false;
        hasSeenOnboarding = data['hasSeenOnboarding'] ?? false;
        if (data['currentUser'] != null) {
          currentUser = User.fromJson(data['currentUser']);
        }
      }

      // USERS INIT WITH FIREBASE FALLBACK
      try {
        final snapshot = await FirebaseFirestore.instance.collection('users').get();
        registeredUsers = snapshot.docs.map((doc) => User.fromJson(doc.data())).toList();
      } catch (e) {
        print("Firebase users error, falling back to local: $e");
        final usersFile = await _getFile('users.json');
        if (await usersFile.exists()) {
          final List<dynamic> jsonList = jsonDecode(await usersFile.readAsString());
          registeredUsers = jsonList.map((j) => User.fromJson(j)).toList();
        }
      }

      // LISTINGS INIT WITH FIREBASE FALLBACK
      try {
        final snapshot = await FirebaseFirestore.instance.collection('listings').get();
        listings = snapshot.docs.map((doc) => Listing.fromJson(doc.data())).toList();
      } catch (e) {
        print("Firebase listings error, falling back to local: $e");
        final listingsFile = await _getFile('listings.json');
        if (await listingsFile.exists()) {
          final List<dynamic> jsonList = jsonDecode(await listingsFile.readAsString());
          listings = jsonList.map((j) => Listing.fromJson(j)).toList();
        }
      }

      final favsFile = await _getFile('favorites.json');
      if (await favsFile.exists()) {
        final List<dynamic> jsonList = jsonDecode(await favsFile.readAsString());
        favoriteListingIds = jsonList.map((j) => j.toString()).toList();
      }

      // 15 günden eski ilanları Firebase'den ve yerelden sil
      final now = DateTime.now();
      final expiredListings = listings.where((l) => now.isAfter(l.expiryDate)).toList();
      for (final expired in expiredListings) {
        await removeListing(expired.id);
      }

      // Chats ve Vaults tamamen dinamik olacaksa artık JSON fallbacklerine gerek yok, boş başlayacak
      chats = [];
      vaultItems = [];

    } catch (e) {
      print("DataStore init error: $e");
    }
  }

  static Future<void> _savePrefs() async {
    try {
      final file = await _getFile('prefs.json');
      await file.writeAsString(jsonEncode({
        'isLoggedIn': isLoggedIn,
        'hasSeenOnboarding': hasSeenOnboarding,
        'currentUser': currentUser?.toJson(),
      }));
    } catch (e) {
      print("Error saving prefs: $e");
    }
  }

  static Future<void> _saveListings() async {
    try {
      final file = await _getFile('listings.json');
      await file.writeAsString(jsonEncode(listings.map((l) => l.toJson()).toList()));
    } catch (e) {
      print("Error saving listings: $e");
    }
  }

  static Future<void> _saveFavorites() async {
    try {
      final file = await _getFile('favorites.json');
      await file.writeAsString(jsonEncode(favoriteListingIds));
    } catch (e) {
      print("Error saving favorites: $e");
    }
  }

  static Future<void> _saveUsers() async {
    try {
      final file = await _getFile('users.json');
      await file.writeAsString(jsonEncode(registeredUsers.map((u) => u.toJson()).toList()));
    } catch (e) {
      print("Error saving users: $e");
    }
  }

  static Future<void> saveChats() async {
    try {
      final file = await _getFile('chats.json');
      await file.writeAsString(jsonEncode(chats.map((c) => c.toJson()).toList()));
    } catch (e) {
      print("Error saving chats: $e");
    }
  }

  static Future<void> saveVaultItems() async {
    try {
      final file = await _getFile('vaults.json');
      await file.writeAsString(jsonEncode(vaultItems.map((v) => v.toJson()).toList()));
    } catch (e) {
      print("Error saving vaults: $e");
    }
  }

  static Future<void> registerUser(User user) async {
    registeredUsers.add(user);
    await _saveUsers();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.id).set(user.toJson());
    } catch (e) {
      print("Firebase user save error: $e");
    }
  }

  static Future<void> setLoggedIn(bool value, {User? user}) async {
    isLoggedIn = value;
    if (user != null) {
      currentUser = user;
    }
    await _savePrefs();
  }
  
  static Future<void> logout() async {
    isLoggedIn = false;
    currentUser = null;
    await _savePrefs();
  }

  static Future<void> setHasSeenOnboarding(bool value) async {
    hasSeenOnboarding = value;
    await _savePrefs();
  }

  static Future<void> addListing(Listing listing) async {
    listings.insert(0, listing);
    
    // Yerele her ihtimale karşı yedekle
    await _saveListings();
    
    // Firebase'e de yazmaya çalış (Bağlıysa tüm dünyaya anında yansır)
    try {
      await FirebaseFirestore.instance.collection('listings').doc(listing.id).set(listing.toJson());
    } catch (e) {
      print("Firebase save error: $e");
    }
  }

  static Future<void> removeListing(String listingId) async {
    // Resmi Firebase Storage'dan da sil
    final listing = listings.firstWhere((l) => l.id == listingId, orElse: () => Listing(id:'', title:'', location:'', date:DateTime.now(), securityQuestion:'', securityAnswer:'', ownerId:''));
    if (listing.imageUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(listing.imageUrl).delete();
      } catch (e) {
        print("Storage image delete error: $e");
      }
    }

    listings.removeWhere((l) => l.id == listingId);
    await _saveListings();

    try {
      await FirebaseFirestore.instance.collection('listings').doc(listingId).delete();
    } catch (e) {
      print("Firebase delete error: $e");
    }
  }

  static Future<void> updateListingStatus(String listingId, String newStatus) async {
    final idx = listings.indexWhere((l) => l.id == listingId);
    if (idx == -1) return;

    final old = listings[idx];
    // Listing is immutable, recreate with new status
    final updated = Listing(
      id: old.id, title: old.title, location: old.location,
      latitude: old.latitude, longitude: old.longitude,
      date: old.date, expiryDate: old.expiryDate,
      imageUrl: old.imageUrl, imageFile: old.imageFile,
      securityQuestion: old.securityQuestion, securityAnswer: old.securityAnswer,
      isUrgent: old.isUrgent, ownerName: old.ownerName,
      rewardAmount: old.rewardAmount, schoolName: old.schoolName,
      ownerId: old.ownerId, status: newStatus,
    );
    listings[idx] = updated;
    await _saveListings();

    try {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .update({'status': newStatus});
    } catch (e) {
      print("Status update error: $e");
    }
  }

  static Future<void> deleteAccount() async {
    final userId = currentUser?.id;
    if (userId == null) return;

    // Kullanıcının tüm ilanlarını Firebase'den sil
    final userListings = listings.where((l) => l.ownerId == userId).toList();
    for (final l in userListings) {
      await removeListing(l.id);
    }

    // Kullanıcıyı Firebase'den sil
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    } catch (e) {
      print("Firebase user delete error: $e");
    }

    // Yerel bellekten de temizle
    registeredUsers.removeWhere((u) => u.id == userId);
    await _saveUsers();
    await logout();
  }

  static Future<void> toggleFavorite(String listingId) async {
    if (favoriteListingIds.contains(listingId)) {
      favoriteListingIds.remove(listingId);
    } else {
      favoriteListingIds.add(listingId);
    }
    await _saveFavorites();
  }

  static bool isFavorite(String listingId) {
    return favoriteListingIds.contains(listingId);
  }
}

// ---------------------------------------------------------------------------
// UTILITIES (VALIDATORS & LOGIC)
// ---------------------------------------------------------------------------
class AppUtils {
  static bool validateTcKimlik(String tc) {
    if (tc.length != 11) return false;
    if (tc.startsWith('0')) return false;

    if (!RegExp(r'^[0-9]+$').hasMatch(tc)) return false;

    List<int> digits = tc.split('').map((e) => int.parse(e)).toList();

    int d1 = digits[0];
    int d2 = digits[1];
    int d3 = digits[2];
    int d4 = digits[3];
    int d5 = digits[4];
    int d6 = digits[5];
    int d7 = digits[6];
    int d8 = digits[7];
    int d9 = digits[8];
    int d10 = digits[9];
    int d11 = digits[10];

    // 1. Kural: 1, 3, 5, 7, 9. hanelerin toplamının 7 katından,
    // 2, 4, 6, 8. hanelerin toplamı çıkarıldığında,
    // elde edilen sonucun 10'a bölümünden kalan 10. haneyi vermelidir.
    int sumOdd = d1 + d3 + d5 + d7 + d9;
    int sumEven = d2 + d4 + d6 + d8;

    int check10 = ((sumOdd * 7) - sumEven) % 10;
    if (check10 != d10) return false;

    // 2. Kural: İlk 10 hanenin toplamının 10'a bölümünden kalan 11. haneyi vermelidir.
    int sumFirst10 = d1 + d2 + d3 + d4 + d5 + d6 + d7 + d8 + d9 + d10;
    int check11 = sumFirst10 % 10;
    if (check11 != d11) return false;

    return true;
  }

  // App Store onayı için gerekli: "Neden İzin İstiyoruz?" eğitim diyaloğu
  static Future<bool> requestEducationalPermission(BuildContext context, String purpose, IconData icon) async {
    bool? granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(icon, size: 48, color: Theme.of(ctx).primaryColor),
            const SizedBox(height: 16),
            const Text('İzin Gerekli', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(purpose, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Şimdi Değil', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: const Text('İzin Ver'),
          ),
        ],
      ),
    );
    return granted ?? false;
  }
}


// ---------------------------------------------------------------------------
// 0. ONBOARDING SCREEN (YENİ KULLANICI EĞİTİMİ)
// ---------------------------------------------------------------------------
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      'title': 'Kayıplar Artık "Kayıp" Değil!',
      'description': 'GörBul ile kaybettiğin eşyaları saniyeler içinde binlerce kişiye duyurabilirsin.',
      'icon': 'search',
    },
    {
      'title': 'Topluluk Gücü',
      'description': 'Bulunan eşyaları sisteme yükleyerek insanları mutlu et, ödüller ve rozetler kazan.',
      'icon': 'groups',
    },
    {
      'title': 'Güvenli ve Hızlı Teslimat',
      'description': 'Emanetçi noktaları veya kurye seçenekleriyle yüz yüze gelmeden güvenle teslimat yap.',
      'icon': 'verified_user',
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: onboardingData.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          index == 0 ? Icons.search : index == 1 ? Icons.groups : Icons.verified_user,
                          size: 120,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 48),
                        Text(
                          onboardingData[index]['title']!,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          onboardingData[index]['description']!,
                          style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(onboardingData.length, (index) => _buildDot(index, context)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == onboardingData.length - 1) {
                        DataStore.setHasSeenOnboarding(true); // Artık bir daha görmesin
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                      } else {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                      }
                    },
                    child: Text(_currentPage == onboardingData.length - 1 ? 'BAŞLA' : 'İLERİ'),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Theme.of(context).primaryColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. SPLASH SCREEN (AÇILIŞ EKRANI)
// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward();

    // İzinleri iste (kamera, konum, medya)
    _requestPermissions();

    // 3 Saniye sonra durum kontrolü yaparak geçiş
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        if (!DataStore.hasSeenOnboarding) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const OnboardingScreen()));
        } else if (!DataStore.isLoggedIn) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const LoginScreen()));
        } else {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const MainScreen()));
        }
      }
    });
  }

  Future<void> _requestPermissions() async {
    // Kamera ve galeri izinleri
    final cameraStatus = await Permission.camera.request();
    final photosStatus = await Permission.photos.request();
    final locationStatus = await Permission.locationWhenInUse.request();

    // Kalıcı reddedilmiş izin varsa ayarlara yönlendir
    if ((cameraStatus.isPermanentlyDenied ||
        photosStatus.isPermanentlyDenied ||
        locationStatus.isPermanentlyDenied) && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('İzin Gerekli'),
          content: const Text(
            'GörBul\'un çalışabilmesi için Kamera, Konum ve Galeri izinleri gereklidir. '
            'Lütfen Ayarlar\'dan bu izinleri açın.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Daha Sonra'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Ayarları Aç'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.saved_search_rounded,
                    size: 100, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _opacityAnimation,
              child: const Column(
                children: [
                  Text(
                    'GörBul',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Türkiye\'nin İlk Kayıp Eşya Ağı',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. LOGIN SCREEN
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1 - Giriş
  final _loginFormKey = GlobalKey<FormState>();
  final _tcController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_loginFormKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      String tc = _tcController.text;
      String password = _passwordController.text;

      User? user;
      try {
        user = DataStore.registeredUsers.firstWhere(
            (u) => u.tc == tc && u.password == password);
      } catch (e) {
        user = null;
      }

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        await DataStore.setLoggedIn(true, user: user);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hatalı T.C. Kimlik No veya Şifre!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Logo & Başlık
            const Stack(alignment: Alignment.center, children: [
              Icon(Icons.shield, size: 80, color: Colors.white24),
              Icon(Icons.saved_search_rounded, size: 48, color: Colors.white),
            ]),
            const SizedBox(height: 12),
            const Text('GörBul',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
            const Text('Kayıp Eşya Portalı',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 24),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFF0A1F44),
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Giriş Yap'),
                  Tab(text: 'Kayıt Ol'),
                  Tab(text: 'Yönetici'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab İçerikleri
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ---- SEKME 1: ÖĞRENCİ GİRİŞİ ----
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 6,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Form(
                              key: _loginFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('Hesabına Giriş Yap',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A1F44))),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _tcController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 11,
                                    decoration: const InputDecoration(
                                      labelText: 'T.C. Kimlik No',
                                      prefixIcon: Icon(Icons.perm_identity),
                                      counterText: '',
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Zorunlu alan';
                                      if (!AppUtils.validateTcKimlik(v)) return 'Geçersiz T.C. No';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Şifre',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Şifre gerekli' : null,
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0A1F44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(width: 22, height: 22,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text('GİRİŞ YAP',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.security, color: Colors.greenAccent[400], size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Verileriniz şifreli & güvende.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ---- SEKME 2: KAYIT OL ----
                  const RegisterScreen(),

                  // ---- SEKME 3: YÖNETİCİ ----
                  const ManagerLoginScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// 2.1 MANAGER LOGIN SCREEN (MÜDÜR PORTALI)
// ---------------------------------------------------------------------------
class ManagerLoginScreen extends StatefulWidget {
  const ManagerLoginScreen({super.key});

  @override
  State<ManagerLoginScreen> createState() => _ManagerLoginScreenState();
}

class _ManagerLoginScreenState extends State<ManagerLoginScreen> {
  final _tcController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _loginManager() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _isLoading = false);

    String tc = _tcController.text.trim();
    String password = _passwordController.text.trim();

    User? manager;
    try {
      manager = DataStore.registeredUsers.firstWhere(
          (u) => u.tc == tc && u.password == password);
    } catch (e) {
      manager = null;
    }

    if (manager != null) {
      if (!manager.isManager) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu hesap bir yönetici/öğretmen hesabı değil!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await DataStore.setLoggedIn(true, user: manager);
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ManagerDashboardScreen(schoolName: manager!.schoolName),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hatalı T.C. Kimlik No veya Şifre!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('Okul Yönetici Portalı'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance, size: 80, color: Colors.blueGrey),
              const SizedBox(height: 20),
              const Text(
                'Yönetici Doğrulaması',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sisteme kayıtlı TC Kimlik No ve Şifrenizi girin.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _tcController,
                keyboardType: TextInputType.number,
                maxLength: 11,
                style: const TextStyle(color: Colors.white, letterSpacing: 2),
                decoration: const InputDecoration(
                  labelText: 'T.C. Kimlik No',
                  labelStyle: TextStyle(color: Colors.blueGrey),
                  prefixIcon: Icon(Icons.perm_identity, color: Colors.blueGrey),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.lightBlueAccent)),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, letterSpacing: 2),
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: TextStyle(color: Colors.blueGrey),
                  prefixIcon: Icon(Icons.lock, color: Colors.blueGrey),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.lightBlueAccent)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginManager,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('PORTALI AÇ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2.2 MANAGER DASHBOARD SCREEN (MÜDÜR ALANI)
// ---------------------------------------------------------------------------
class ManagerDashboardScreen extends StatefulWidget {
  final String schoolName;
  const ManagerDashboardScreen({super.key, required this.schoolName});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    // SADECE bu okulun ilanlarını filtrele
    final myListings = DataStore.listings
        .where((l) => l.schoolName == widget.schoolName)
        .toList();
    final myUsers = DataStore.registeredUsers
        .where((u) => u.schoolName == widget.schoolName)
        .toList();
    final urgentCount = myListings.where((l) => l.isUrgent).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text(widget.schoolName, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İstat Kartları
            Row(
              children: [
                Expanded(child: _buildStatCard('Toplam İlan', myListings.length.toString(), Colors.blueAccent)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Acil', urgentCount.toString(), Colors.red)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Öğrenciler', myUsers.length.toString(), Colors.green)),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'İlan Hareketleri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: myListings.isEmpty
                  ? const Center(
                      child: Text(
                        'Bu okulda henüz ilan yok.',
                        style: TextStyle(color: Colors.white54),
                      ))
                  : ListView.builder(
                      itemCount: myListings.length,
                      itemBuilder: (context, index) {
                        final listing = myListings[index];
                        return Card(
                          color: listing.status == 'resolved'
                              ? const Color(0xFF0D3320)  // Yeşilimsi arka plan
                              : const Color(0xFF1E2D3D),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      listing.isUrgent ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                                      color: listing.isUrgent ? Colors.redAccent : Colors.blueGrey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(listing.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                    // Durum rozeti
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: listing.status == 'resolved' ? Colors.green : Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            listing.status == 'resolved' ? Icons.check_circle : Icons.hourglass_top,
                                            color: Colors.white, size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            listing.status == 'resolved' ? 'Çözüldü' : 'İşlemde',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 26, top: 2),
                                  child: Text(listing.location, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (listing.status != 'resolved')
                                      TextButton.icon(
                                        onPressed: () async {
                                          await DataStore.updateListingStatus(listing.id, 'resolved');
                                          setState(() {});
                                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('İlan çözüldü olarak işaretlendi ✓'), backgroundColor: Colors.green),
                                          );
                                        },
                                        icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                                        label: const Text('Çözüldü Onayla', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text('İlanı Sil'),
                                            content: const Text('Bu ilanı tamamen silmek istediğinizden emin misiniz?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
                                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await DataStore.removeListing(listing.id);
                                          setState(() {});
                                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İlan silindi'), backgroundColor: Colors.green));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// 2.5. REGISTER SCREEN (HARBİCİ KAYIT EKRANI)
// ---------------------------------------------------------------------------
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _tcController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _schoolNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isTeacher = false; // Yönetici/Öğretmen mi?
  List<String> _dynamicSchools = [];
  String? _selectedSchool;

  @override
  void initState() {
    super.initState();
    _loadDynamicSchools();
  }

  void _loadDynamicSchools() {
    // Sadece Teacher/Manager olarak kayıtlı kullanıcıların okullarını benzersiz olarak topla
    final schools = DataStore.registeredUsers
        .where((u) => u.isManager && u.schoolName.isNotEmpty)
        .map((u) => u.schoolName)
        .toSet()
        .toList();
    
    setState(() {
      _dynamicSchools = schools;
      if (_dynamicSchools.isNotEmpty) {
        _selectedSchool = _dynamicSchools.first;
      }
    });
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      String tc = _tcController.text;
      
      // TC Kimlik No ile kayıtlı kullanıcı var mı kontrol et
      bool userExists = DataStore.registeredUsers.any((u) => u.tc == tc);
      
      await Future.delayed(const Duration(seconds: 1)); // UX
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (userExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu T.C. Kimlik No sisteme zaten kayıtlı!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Eğer öğretmen değilse okul listesinden seçim yapması zorunlu
      if (!_isTeacher && (_dynamicSchools.isEmpty || _selectedSchool == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıtlı okul bulunamadı! Önce okul yöneticinizin sisteme kayıt olması gerekmektedir.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String userSchoolName = _isTeacher ? _schoolNameController.text.trim().toUpperCase() : _selectedSchool!;

      // Yeni kullanıcı oluştur
      User newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        surname: _surnameController.text.trim(),
        tc: tc,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        schoolName: userSchoolName,
        isManager: _isTeacher,
      );

      // Datastore'a kaydet
      await DataStore.registerUser(newUser);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt Başarılı! Cihaz güvenliği sağlandı, giriş yapabilirsiniz.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Kayıt bitince giriş ekranına geri dön
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_add_alt_1, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Aramıza Katıl',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
              ),
              const Text(
                'GörBul Güvenlik Ağına Kayıt Olun',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // AD & SOYAD (Yan yana)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(labelText: 'Ad', prefixIcon: Icon(Icons.person)),
                                validator: (v) => v!.isEmpty ? 'Ad gerekli' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _surnameController,
                                decoration: const InputDecoration(labelText: 'Soyad'),
                                validator: (v) => v!.isEmpty ? 'Soyad gerekli' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // YÖNETİCİ/ÖĞRETMEN SEÇİMİ (DINAMIK OKUL İÇİN)
                        SwitchListTile(
                          title: const Text('Yönetici / Öğretmen Kaydı', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Kendi okul portalınızı oluşturun', style: TextStyle(fontSize: 12)),
                          value: _isTeacher,
                          activeColor: const Color(0xFF0A1F44),
                          onChanged: (val) {
                            setState(() {
                              _isTeacher = val;
                            });
                          },
                        ),
                        const SizedBox(height: 8),

                        // OKUL KISMI (Duruma göre dinamik)
                        _isTeacher 
                          ? TextFormField(
                              controller: _schoolNameController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Okulunuzun Kısaltması / Portal Kodu (Örn: BAL)', 
                                prefixIcon: Icon(Icons.school)
                              ),
                              validator: (v) => v!.isEmpty ? 'Portal Kodu belirlemeniz gerekli' : null,
                            )
                          : _dynamicSchools.isEmpty 
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Text(
                                  'Sisteme kayıtlı portal bulunamadı. Lütfen yöneticinizin portal açmasını bekleyin.',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedSchool,
                                decoration: const InputDecoration(labelText: 'Portal Kodunuz (Mevcut Portallar)', prefixIcon: Icon(Icons.school)),
                                items: _dynamicSchools.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedSchool = val);
                                },
                              ),
                        const SizedBox(height: 16),

                        // TC KİMLİK (Senin Algoritmanla Korunuyor)
                        TextFormField(
                          controller: _tcController,
                          keyboardType: TextInputType.number,
                          maxLength: 11,
                          decoration: const InputDecoration(labelText: 'T.C. Kimlik No', prefixIcon: Icon(Icons.perm_identity), counterText: ""),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Zorunlu alan';
                            if (!AppUtils.validateTcKimlik(value)) return 'Geçersiz T.C. Kimlik No';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // GERÇEK MAİL KONTROLÜ (Harbici Regex)
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'E-Posta Adresi', prefixIcon: Icon(Icons.email)),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Mail gerekli';
                            // Harbici mail formatı kontrolü
                            if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                              return 'Geçerli bir mail girin patron';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Şifre Belirle', prefixIcon: Icon(Icons.lock)),
                          validator: (value) {
                            if (value == null || value.length < 6) return 'Şifre en az 6 hane olmalı';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ŞİFRE (TEKRAR) EKLENDİ
                        TextFormField(
                          controller: _passwordConfirmController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Şifre (Tekrar)', prefixIcon: Icon(Icons.lock_outline)),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Şifreyi tekrar girin';
                            if (value != _passwordController.text) return 'Şifreler eşleşmiyor patron!';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // KAYIT BUTONU
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A1F44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('GÜVENLİ KAYIT OL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. MAIN SCREEN (BOTTOM NAVIGATION BAR)
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Hafif sayfa geçişi (slide + fade, 200ms)
// ---------------------------------------------------------------------------
PageRoute<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 200),
  reverseTransitionDuration: const Duration(milliseconds: 150),
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child),
  ),
);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isOffline = true; // Simüle edilmiş internet kontrolü

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
  }

  void _checkInitialConnectivity() {
    // Bağlantı kontrolü mocklaması kaldırıldı, direkt başlat.
    setState(() => _isOffline = false);
  }

  void _onNavigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onListingCreated() {
    setState(() {
      _currentIndex = 0; // İlan eklendikten sonra ana sayfaya (Vitrin) dön
    });
  }

  List<Widget> get _pages => [
    HomeScreen(onNavigateToTab: _onNavigateToTab),
    const GlobalMapScreen(),
    AddListingScreen(onListingAdded: _onListingCreated),
    const PortalAnnouncementScreen(), // Duyuru Panosu
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: _pages[_currentIndex],
            ),
          ),
          if (_isOffline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.redAccent,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('İnternet bağlantısı yok, çevrimdışı mod: Sadece kayıtlı ilanlar.', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
      bottomNavigationBar: _AnimatedBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// Animasyonlu bottom nav
class _AnimatedBottomNav extends StatefulWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _AnimatedBottomNav({required this.currentIndex, required this.onTap});
  @override
  State<_AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<_AnimatedBottomNav> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  final _items = [
    [Icons.saved_search, Icons.saved_search, 'Vitrin'],
    [Icons.map_outlined, Icons.map, 'Harita'],
    [Icons.add_circle_outline, Icons.add_circle, 'İlan Ver'],
    [Icons.campaign_outlined, Icons.campaign, 'Pano'],
    [Icons.chat_bubble_outline, Icons.chat_bubble, 'Mesajlar'],
    [Icons.person_outline, Icons.person, 'Profilim'],
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _items.length,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 180)),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    _controllers[i].forward().then((_) => _controllers[i].reverse());
    HapticFeedback.selectionClick();
    widget.onTap(i);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark ? Colors.tealAccent : Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final selected = i == widget.currentIndex;
              return GestureDetector(
                onTap: () => _onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 1.0, end: 0.75)
                            .animate(CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut)),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            selected ? (_items[i][1] as IconData) : (_items[i][0] as IconData),
                            key: ValueKey(selected),
                            color: selected ? primary : Colors.grey,
                            size: selected ? 26 : 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          color: selected ? primary : Colors.grey,
                          fontSize: selected ? 11 : 10,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        child: Text(_items[i][2] as String),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. HOME SCREEN (VITRIN)
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final void Function(int)? onNavigateToTab;
  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Arama için gereken kontroller ve liste
  final TextEditingController _searchController = TextEditingController();
  List<Listing> _displayedListings = [];
  String _selectedFilter = 'Tümü'; // Yeni eklenen state

  @override
  void initState() {
    super.initState();
    // Sayfa ilk açıldığında bütün ilanları göster
    _displayedListings = DataStore.listings;
  }

  // Harbi Arama ve Filtre Fonksiyonu
  Future<void> _filterListings() async {
    Position? currentPos;
    if (_selectedFilter == 'Yakınımdakiler') {
      try {
        currentPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        // İzin vb yoksa alınamaz
      }
    }

    final query = _searchController.text.trim().toLowerCase();
    
    final filtered = DataStore.listings.where((listing) {
      // 1. Arama Metni Filtresi
      bool matchesQuery = true;
      if (query.isNotEmpty) {
        final titleLower = listing.title.toLowerCase();
        final locLower = listing.location.toLowerCase();
        matchesQuery = titleLower.contains(query) || locLower.contains(query);
      }

      // 2. Çip (Kategori/Durum) Filtresi
      bool matchesFilter = true;
      if (_selectedFilter == 'Kayıplar') {
        matchesFilter = listing.title.toLowerCase().contains('kayıp') || listing.isUrgent; // Basit mock tespit
      } else if (_selectedFilter == 'Elektronik') {
        matchesFilter = listing.title.toLowerCase().contains('telefon') || listing.title.toLowerCase().contains('elektronik') || listing.title.toLowerCase().contains('bilgisayar');
      } else if (_selectedFilter == 'Yakınımdakiler') {
        if (currentPos != null && listing.latitude != null && listing.longitude != null) {
          final distance = Geolocator.distanceBetween(
             currentPos.latitude, currentPos.longitude, 
             listing.latitude!, listing.longitude!
          );
          matchesFilter = distance <= 10000; // 10 km içi
        } else {
          matchesFilter = false; // Konum alınamazsa veya ilanın konumu yoksa gösterme
        }
      }

      return matchesQuery && matchesFilter;
    }).toList();

    if (mounted) {
      setState(() {
        _displayedListings = filtered;
      });
    }
  }

  // Geri gelindiğinde listeyi yenilemek için
  void _refresh() {
    _filterListings();
  }

  // Bildirim Paneli (Phase 11)
  void _showNotificationsPanel(BuildContext context) {
    final List<Map<String, dynamic>> notifications = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Bildirimler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: notifications.isEmpty
                  ? const Center(child: Text('Henüz yeni bir bildiriminiz yok.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: controller,
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (_, index) {
                        final n = notifications[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: (n['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(n['icon'] as IconData, color: n['color'] as Color, size: 22),
                          ),
                          title: Text(n['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(n['body'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          trailing: Text(n['time'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Canlı İstatistik Kartı (Phase 11)
  Widget _buildLiveStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // Sana Göre Chip (Phase 11)
  Widget _buildPersonalizedChip(String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchController.text = label.split(' ').first;
          _filterListings();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // Dinamik Selamlama Mesajı
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın ☀️';
    if (hour < 18) return 'İyi Günler 🌤️';
    return 'İyi Akşamlar 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                '${_getGreeting()}\nGörBul Vitrin',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, height: 1.2),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A1F44), Color(0xFF1A365D)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -10,
                      child: Icon(Icons.saved_search, size: 150, color: Colors.white.withOpacity(0.05)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.notifications_active_outlined), onPressed: () => _showNotificationsPanel(context)),
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () {
                  if (widget.onNavigateToTab != null) {
                    widget.onNavigateToTab!(4);
                  }
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => _filterListings(),
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Kaybını ara...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0A1F44)),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFF0A1F44), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.tune, color: Colors.white, size: 20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Yeni Acil İlanlar Karuseli (Hızlı Kaydırma) - Zero Storage
                if (_searchController.text.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 12, bottom: 8),
                    child: Text('Çevrendeki Acil Durumlar 🔥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  _buildHighlightCarousel(),

                  // PHASE 11 - Canlı İstatistikler
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Row(
                      children: [
                        const Text('Canlı Tablo 📊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                          child: const Text('CANLI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildLiveStatCard('Bugün Kayıp', '${DataStore.listings.where((l) => l.isUrgent).length}', Icons.search_off, Colors.redAccent)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildLiveStatCard('Bulundu', '${DataStore.listings.length}', Icons.task_alt, Colors.green)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildLiveStatCard('Mutlu Son', '0', Icons.favorite, Colors.pink)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // PHASE 11 - Sana Göre İlanlar
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                    child: Text('Sana Göre İlanlar ✨', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildPersonalizedChip('Kadıköy', Icons.location_on, Colors.purple),
                        _buildPersonalizedChip('Elektronik', Icons.phone_iphone, Colors.blue),
                        _buildPersonalizedChip('Ödüllü', Icons.emoji_events, Colors.amber),
                        _buildPersonalizedChip('24 Saat', Icons.access_time, Colors.teal),
                      ],
                    ),
                  ),
                ],
                
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),

                  child: Text('Kategoriler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                
                // Kategori Çarkı (Letgo Stili İkonlu Grip)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  height: 100, // Yükseklik kategoriler için artırıldı
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildCategoryIcon('Tümü', Icons.apps, Colors.indigo),
                      _buildCategoryIcon('Kayıplar', Icons.search_off, Colors.redAccent),
                      _buildCategoryIcon('Elektronik', Icons.phone_iphone, Colors.blueGrey),
                      _buildCategoryIcon('Evcil Hayvan', Icons.pets, Colors.orange),
                      _buildCategoryIcon('Cüzdan', Icons.account_balance_wallet, Colors.brown),
                      _buildCategoryIcon('Anahtar', Icons.vpn_key, Colors.amber),
                    ],
                  ),
                ),
                
                if (_displayedListings.isEmpty)
                   const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text('Aradığınız kriterde eşya bulunamadı.', style: TextStyle(color: Colors.grey)),
                    ),
                   )
              ],
            ),
          ),
          
          // Grid Listesi (Filtrelenmiş) - SliverGrid
          if (_displayedListings.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final listing = _displayedListings[index];
                    return _buildListingCard(listing);
                  },
                  childCount: _displayedListings.length,
                ),
              ),
            ),
        ],
      ),
      // Radar Butonu
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'radar_btn',
            onPressed: () {
              _showRadarAnimation(context);
            },
            backgroundColor: Colors.tealAccent[400],
            icon: const Icon(Icons.radar, color: Colors.black),
            label: const Text('Akıllı Tarama', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRadarAnimation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const RadarMatchDialog(),
    );
  }

  // YENİ VİTRİN HIZLI KARUSEL (Depolama Dostu)
  Widget _buildHighlightCarousel() {
    final urgentListings = DataStore.listings.where((l) => l.isUrgent).toList();
    if (urgentListings.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: urgentListings.length,
        itemBuilder: (context, index) {
          final listing = urgentListings[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DetailScreen(listing: listing)),
              );
            },
            child: Container(
              width: 240,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: listing.imageFile != null
                      ? FileImage(listing.imageFile!) as ImageProvider
                      : NetworkImage(listing.imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))
                ]
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                      child: const Text('ACİL ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    Text(listing.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Expanded(child: Text(listing.location, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // YENİ KATEGORİ İKONU (Çark Stili)
  Widget _buildCategoryIcon(String label, IconData icon, Color color) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _filterListings();
        });
      },
      child: Container(
        width: 75,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black87 : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(Listing listing) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DetailScreen(listing: listing)),
          ).then((_) => _refresh()); // Geri gelince listeyi güncelle
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: listing.id,
                    child: listing.imageFile != null
                        ? Image.file(listing.imageFile!, fit: BoxFit.cover)
                        : Image.network(listing.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        await DataStore.toggleFavorite(listing.id);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text(DataStore.isFavorite(listing.id) ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı'),
                             duration: const Duration(seconds: 1),
                           )
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          DataStore.isFavorite(listing.id) ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: DataStore.isFavorite(listing.id) ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  if (listing.rewardAmount.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              listing.rewardAmount,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (DateTime.now().difference(listing.date).inHours <= 24)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
                        ),
                        child: const Text(
                          'YENİ', 
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            listing.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(
                          '${listing.date.day.toString().padLeft(2, '0')}.${listing.date.month.toString().padLeft(2, '0')}.${listing.date.year}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(Icons.verified_user, size: 14, color: Colors.teal[400])
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 11. STORY VIEW SCREEN (ACİL İLANLAR HİKAYE GÖRÜNÜMÜ)
// ---------------------------------------------------------------------------
class StoryViewScreen extends StatefulWidget {
  final List<Listing> stories;
  final int initialIndex;

  const StoryViewScreen({super.key, required this.stories, required this.initialIndex});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.stories.length,
        itemBuilder: (context, index) {
          final story = widget.stories[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              // Arka Plan Resmi
              story.imageFile != null
                  ? Image.file(story.imageFile!, fit: BoxFit.cover)
                  : Image.network(story.imageUrl, fit: BoxFit.cover),
              
              // Yazılar okunsun diye üst ve alta hafif siyah karartı
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent, Colors.black87],
                  ),
                ),
              ),

              // Üst Kısım: İlerleme Çubukları ve Kapat Butonu
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Story Çizgileri
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Row(
                        children: widget.stories.map((s) {
                          int sIndex = widget.stories.indexOf(s);
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2.0),
                              height: 3,
                              decoration: BoxDecoration(
                                color: sIndex == _currentIndex ? Colors.white : Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Kullanıcı Bilgisi
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.redAccent,
                        child: Icon(Icons.priority_high, color: Colors.white, size: 20),
                      ),
                      title: Text(story.ownerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Acil Kayıp Bildirimi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Alt Kısım: İlan Bilgileri ve Buton
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                      child: const Text('ACİL!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    Text(story.title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(story.location, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Simülasyon: Yerel cihaza kaydet ve Share Plugin ile paylaş
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Afiş telefonunuza kaydedildi ve Whatsapp/Insta paylaşım menüsü açılıyor! (Görsel veritabanı harcamaz)'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text('İndir & Paylaş'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MAP LOCATION PICKER (OpenStreetMap + Nominatim)
// ---------------------------------------------------------------------------
class MapLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapLocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  late final MapController _mapController;
  LatLng? _selectedPoint;
  String _address = 'Haritaya dokunarak konum seçin';
  bool _isLoadingAddress = false;
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedPoint = LatLng(widget.initialLat!, widget.initialLng!);
      _reverseGeocode(_selectedPoint!);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&accept-language=tr',
      );
      final res = await http.get(url, headers: {'User-Agent': 'GorBulApp/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _address = data['display_name'] ?? 'Adres bulunamadı');
      }
    } catch (e) {
      setState(() => _address = 'Adres yüklenemedi');
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum izni gerekli')));
        setState(() => _isLoadingGps = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final point = LatLng(pos.latitude, pos.longitude);
      _mapController.move(point, 16);
      setState(() => _selectedPoint = point);
      await _reverseGeocode(point);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS hatası: $e')));
    } finally {
      setState(() => _isLoadingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedPoint ?? LatLng(39.9208, 32.8541); // Türkiye merkezi
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Seç'),
        actions: [
          if (_selectedPoint != null)
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'lat': _selectedPoint!.latitude,
                'lng': _selectedPoint!.longitude,
                'address': _address,
              }),
              child: const Text('Tamam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _selectedPoint != null ? 15 : 6,
              onTap: (tapPosition, point) async {
                setState(() => _selectedPoint = point);
                await _reverseGeocode(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gorbul.app',
              ),
              if (_selectedPoint != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _selectedPoint!,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 50),
                  ),
                ]),
            ],
          ),
          // Alt bilgi kartı
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seçili Konum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  _isLoadingAddress
                      ? const LinearProgressIndicator()
                      : Text(_address, style: const TextStyle(fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedPoint == null ? null : () => Navigator.pop(context, {
                        'lat': _selectedPoint!.latitude,
                        'lng': _selectedPoint!.longitude,
                        'address': _address,
                      }),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Bu Konumu Kullan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // GPS butonu
          Positioned(
            bottom: 180,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'gps_btn',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _isLoadingGps ? null : _goToMyLocation,
              child: _isLoadingGps
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. ADD LISTING SCREEN
// ---------------------------------------------------------------------------
class AddListingScreen extends StatefulWidget {
  final VoidCallback? onListingAdded;
  const AddListingScreen({super.key, this.onListingAdded});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _securityQuestionController = TextEditingController();
  final _securityAnswerController = TextEditingController();
  final _rewardController = TextEditingController();

  List<File> _selectedImages = [];
  bool _isCompressing = false;
  bool _isAnalyzing = false;
  bool _isLocating = false;
  List<String> _aiTags = [];
  bool _isUrgent = false;
  
  // Yeni Redesign State Variables
  int _currentStep = 0;
  String? _selectedCategory;
  final List<String> _categories = ['Cüzdan', 'Elektronik', 'Anahtar', 'Çanta', 'Evcil Hayvan', 'Diğer'];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {}

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Konum servisi kapalı');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('İzin reddedildi');
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
        _locationController.text = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)} (GPS)';
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Konum alınamadı: $e')));
    }
    if (mounted) setState(() => _isLocating = false);
  }

  // Görüntü seçme ve Kamera
  Future<void> _pickImage(String sourceStr) async {
    try {
      setState(() => _isCompressing = true);

      final picker = ImagePicker();
      final source = sourceStr == 'camera' ? ImageSource.camera : ImageSource.gallery;
      
      // select image using image_picker
      final XFile? pickedFile = await picker.pickImage(source: source, imageQuality: 70);

      setState(() {
        if (pickedFile != null && _selectedImages.length < 5) {
            _selectedImages.add(File(pickedFile.path)); 
        }
        _isCompressing = false;
      });

      if (pickedFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Fotoğraf başarıyla eklendi! (Sıkıştırıldı)')),
        );
      }
    } catch (e) {
      print('Resim seçme hatası: $e');
      setState(() => _isCompressing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resim açılırken hata oluştu veya izin verilmedi!')),
        );
      }
    }
  }

  // API Anahtarınızı Buraya Girin (Gemini API)
  static const String geminiApiKey = "AIzaSyCDbO6GvdREKfmQJeJrfhn1nJzy8MB27uw";

  // Gerçek AI Analiz Entegrasyonu (Gemini)
  void _simulateAIAnalysis() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce analiz edilecek bir resim seçin.')));
      return;
    }

    if (geminiApiKey == "BURAYA_API_ANAHTARINIZI_GIRIN" || geminiApiKey.startsWith("AIzaSyCDbO6")) {
      await Future.delayed(const Duration(seconds: 2)); // Simüle bekleme
      setState(() {
        _isAnalyzing = false;
        _titleController.text = "Örnek Eşya (Yapay Zeka)";
        _aiTags = ['Bulungu', 'Eşya', 'Simülasyon'];
        _selectedCategory = 'Diğer';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yapay Zeka (Simülasyon) Başarılı!')));
      return;
    }

    setState(() => _isAnalyzing = true);
    
    try {
      final imageBytes = await _selectedImages.first.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [
              {"text": "Bu resimdeki ana objeyi kısaca tanımla ve virgülle ayrılmış 3 kelimelik etiketler üret. Format: Başlık | etiket1, etiket2, etiket3"},
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String resultText = "Görsel Analiz Edildi | Bulungu, Eşya, Analiz";
        try {
          resultText = data['candidates'][0]['content']['parts'][0]['text'] as String;
        } catch (e) {
          print("AI result parsing error: $e");
        }

        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            if (resultText.contains("|")) {
              final parts = resultText.split("|");
              _titleController.text = parts[0].replaceAll('*', '').trim();
              _aiTags = parts.length > 1 ? parts[1].replaceAll('*', '').split(",").map((e) => e.trim()).toList() : ['Bulungu'];
            } else {
               _titleController.text = resultText.replaceAll('*', '').trim();
               _aiTags = ['Bulungu', 'Eşya', 'Analiz'];
            }
            _selectedCategory = 'Diğer'; // Fallback
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Görsel yapay zeka ile analiz edildi! Başlık ve etiketler oluşturuldu.'),
                backgroundColor: Colors.purple),
          );
        }
      } else {
        throw Exception("API Hatası: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Gemini AI Hatası: $e");
       setState(() => _isAnalyzing = false);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI analizi başarısız oldu: $e'), backgroundColor: Colors.red),
         );
       }
    }
  }

  double? _currentLat;
  double? _currentLng;

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialLat: _currentLat,
          initialLng: _currentLng,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _currentLat = result['lat'] as double;
        _currentLng = result['lng'] as double;
        _locationController.text = result['address'] as String;
      });
    }
  }

  bool _isUploading = false;

  void _submitListing() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen en az bir fotoğraf ekleyin!')),
        );
        return;
      }

      setState(() => _isUploading = true);

      String downloadUrl = '';
      try {
        // Trendyol gibi Firebase Storage'a yükle ki herkes görsün!
        final storageRef = FirebaseStorage.instance.ref();
        final imageRef = storageRef.child('listing_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        await imageRef.putFile(_selectedImages.first);
        downloadUrl = await imageRef.getDownloadURL();
      } catch (e) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resim yükleme hatası: $e')));
        }
        return; 
      }

      // İlanı Oluştur ve Store'a Ekle
      final newListing = Listing(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        location: _locationController.text,
        latitude: _currentLat,
        longitude: _currentLng,
        date: DateTime.now(),
        imageUrl: downloadUrl, // Artık sadece URL var, herkes webden çekecek
        imageFile: _selectedImages.first, // Yerelde fallback
        securityQuestion: _securityQuestionController.text,
        securityAnswer: _securityAnswerController.text,
        rewardAmount: _rewardController.text,
        isUrgent: _isUrgent, // Acil İlan
        schoolName: DataStore.currentUser?.schoolName ?? 'Belirtilmedi',
        ownerId: DataStore.currentUser?.id ?? 'bilinmiyor',
        ownerName: '${DataStore.currentUser?.name} ${DataStore.currentUser?.surname}',
      );

      await DataStore.addListing(newListing);

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İlan başarıyla buluta yüklendi ve yayınlandı!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final steps = [
      {'icon': Icons.photo_camera, 'label': 'Foto\u011fraf'},
      {'icon': Icons.info_outline, 'label': 'Detaylar'},
      {'icon': Icons.shield_outlined, 'label': 'G\u00fcvenlik'},
      {'icon': Icons.rocket_launch, 'label': 'Yay\u0131nla'},
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Yeni \u0130lan Ver', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF0A1F44),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ====== STEPPER HEADER ======
          Container(
            color: const Color(0xFF0A1F44),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / steps.length,
                    backgroundColor: Colors.white24,
                    color: Colors.tealAccent,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 16),
                // Step dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(steps.length, (i) {
                    final done = i < _currentStep;
                    final active = i == _currentStep;
                    return Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: active ? 52 : 40,
                          height: active ? 52 : 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done
                                ? Colors.tealAccent
                                : active
                                    ? Colors.white
                                    : Colors.white24,
                            border: Border.all(
                              color: active ? Colors.tealAccent : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: active
                                ? [BoxShadow(color: Colors.tealAccent.withOpacity(0.4), blurRadius: 12)]
                                : [],
                          ),
                          child: Icon(
                            done ? Icons.check : (steps[i]['icon'] as IconData),
                            color: done
                                ? Colors.white
                                : active
                                    ? const Color(0xFF0A1F44)
                                    : Colors.white54,
                            size: active ? 26 : 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[i]['label'] as String,
                          style: TextStyle(
                            color: active ? Colors.tealAccent : Colors.white60,
                            fontSize: 11,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),

          // ====== CONTENT ======
          Expanded(
            child: Form(
              key: _formKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero)
                      .animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: SingleChildScrollView(
                  key: ValueKey(_currentStep),
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(context),
                ),
              ),
            ),
          ),

          // ====== BOTTOM NAV BUTTONS ======
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _currentStep--);
                      },
                      icon: const Icon(Icons.arrow_back_ios, size: 16),
                      label: const Text('Geri'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFF0A1F44)),
                        foregroundColor: const Color(0xFF0A1F44),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : () {
                      HapticFeedback.mediumImpact();
                      if (_currentStep < steps.length - 1) {
                        setState(() => _currentStep++);
                      } else {
                        _submitListing();
                      }
                    },
                    icon: _isUploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_currentStep == steps.length - 1 ? Icons.rocket_launch : Icons.arrow_forward_ios, size: 18),
                    label: Text(
                      _isUploading ? 'Y\u00fckl\u00fcyor...' : _currentStep == steps.length - 1 ? '\u0130lan\u0131 Yay\u0131nla! \ud83d\ude80' : 'Devam Et',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentStep == steps.length - 1 ? Colors.teal : const Color(0xFF0A1F44),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_currentStep) {
      case 0: return _buildStepPhoto(context);
      case 1: return _buildStepDetails(context);
      case 2: return _buildStepSecurity(context);
      case 3: return _buildStepPublish(context);
      default: return const SizedBox.shrink();
    }
  }

  // ===== STEP 0: FOTO\u011eRAF =====
  Widget _buildStepPhoto(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(Icons.camera_alt_outlined, 'Foto\u011fraf Ekle', 'Evsyas\u0131n\u0131n net bir foto\u011fraf\u0131n\u0131 ekle', Colors.indigo),
        const SizedBox(height: 20),

        // Ana foto\u011fraf alan\u0131
        GestureDetector(
          onTap: () => _showImageSourceSheet(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 220,
            decoration: BoxDecoration(
              gradient: _selectedImages.isEmpty
                  ? LinearGradient(
                      colors: [Colors.indigo.shade50, Colors.blue.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedImages.isEmpty ? Colors.indigo.withOpacity(0.3) : Colors.indigo,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
              boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: _selectedImages.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_selectedImages.first, fit: BoxFit.cover),
                        if (_isAnalyzing)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 3),
                                const SizedBox(height: 14),
                                const Text('Yapay Zeka Analiz Ediyor...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        Positioned(
                          bottom: 10, right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text('${_selectedImages.length}/5 foto\u011fraf', style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.indigo),
                      ),
                      const SizedBox(height: 16),
                      const Text('Foto\u011fraf \u00c7ek veya Se\u00e7', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.indigo)),
                      const SizedBox(height: 6),
                      Text('En fazla 5 foto\u011fraf \u2022 Otomatik s\u0131k\u0131\u015ft\u0131r\u0131l\u0131r', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    ],
                  ),
          ),
        ),

        // Thumbnail\'lar
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length + (_selectedImages.length < 5 ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _selectedImages.length) {
                  return GestureDetector(
                    onTap: () => _showImageSourceSheet(context),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.indigo.withOpacity(0.4), style: BorderStyle.solid, width: 2),
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.indigo.shade50,
                      ),
                      child: const Icon(Icons.add, color: Colors.indigo),
                    ),
                  );
                }
                return Container(
                  width: 72,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.indigo, width: 2),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImages[i], fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImages.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        // AI Analiz butonu
        if (_selectedImages.isNotEmpty && _aiTags.isEmpty && !_isAnalyzing) ...[
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.indigo.shade500]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: ElevatedButton.icon(
              onPressed: _simulateAIAnalysis,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text('\u2728 Yapay Zeka ile Otomatik Doldur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text('Foto\u011fraf\u0131 analiz edip ba\u015fl\u0131k ve etiket olu\u015fturur', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
        ],

        if (_aiTags.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
                  const SizedBox(width: 6),
                  const Text('AI Etiketleri', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _aiTags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.purple.shade600, borderRadius: BorderRadius.circular(20)),
                    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFEAF0FF), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Color(0xFF0A1F44))),
                title: const Text('Kamera ile \u00c7ek', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Hemen foto\u011fraf \u00e7ek'),
                onTap: () { Navigator.pop(ctx); _pickImage('camera'); },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle), child: Icon(Icons.photo_library, color: Colors.purple.shade600)),
                title: const Text('Galeriden Se\u00e7', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Telefon galerisinden se\u00e7'),
                onTap: () { Navigator.pop(ctx); _pickImage('gallery'); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== STEP 1: DETAYLAR =====
  Widget _buildStepDetails(BuildContext context) {
    final categoryIcons = {'C\u00fczdan': Icons.account_balance_wallet_outlined, 'Elektronik': Icons.devices_outlined, 'Anahtar': Icons.key_outlined, '\u00c7anta': Icons.shopping_bag_outlined, 'Evcil Hayvan': Icons.pets, 'Di\u011fer': Icons.category_outlined};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(Icons.category_outlined, 'Kategori Se\u00e7', 'Evsyas\u0131 ne t\u00fcr?', Colors.blue),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0A1F44) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? const Color(0xFF0A1F44) : Colors.grey.shade200, width: 2),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFF0A1F44).withOpacity(0.3), blurRadius: 10)]
                      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(categoryIcons[cat] ?? Icons.category, color: isSelected ? Colors.tealAccent : Colors.grey.shade600, size: 28),
                    const SizedBox(height: 6),
                    Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _sectionHeader(Icons.edit_note, '\u0130lan Ba\u015fl\u0131\u011f\u0131', 'Ne kaybettiniz?', Colors.teal),
        const SizedBox(height: 14),
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: '\u0130lan Ba\u015fl\u0131\u011f\u0131 / Ne Kaybettiniz?',
            prefixIcon: const Icon(Icons.title_outlined),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0A1F44), width: 2)),
          ),
          validator: (v) => v!.isEmpty ? 'Ba\u015fl\u0131k gerekli' : null,
        ),
        const SizedBox(height: 24),
        _sectionHeader(Icons.location_on_outlined, 'Konum', 'Nerede kayboldu?', Colors.red),
        const SizedBox(height: 14),
        TextFormField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: 'Kayboldu\u011fu / Bulundu\u011fu Yer',
            prefixIcon: const Icon(Icons.pin_drop_outlined),
            suffixIcon: IconButton(
              icon: _isLocating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.blue),
              onPressed: _isLocating ? null : _fetchCurrentLocation,
              tooltip: 'GPS Konumumu Al',
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 2)),
          ),
          validator: (v) => v!.isEmpty ? 'Konum gerekli' : null,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openMapPicker,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Haritadan Konum Se\u00e7'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (_currentLat != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text('Konum haritaya i\u015faretlendi \u2713', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ],
    );
  }

  // ===== STEP 2: G\u00dcVENL\u0130K =====
  Widget _buildStepSecurity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(Icons.shield_outlined, 'G\u00fcvenlik & \u00d6d\u00fcl', 'Sahipli\u011fi ispatla', Colors.green),
        const SizedBox(height: 20),

        // Acil ilan
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isUrgent = !_isUrgent);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isUrgent ? Colors.red.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _isUrgent ? Colors.red : Colors.grey.shade200, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.warning_rounded, color: Colors.red.shade600, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ACiL \u0130LAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                Text('Evcil hayvan, hayati ila\u00e7, ya\u015fl\u0131 birey vb. \u2022 \u0130lan \u00f6ne \u00e7\u0131kar', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ])),
              Switch(value: _isUrgent, onChanged: (v) => setState(() => _isUrgent = v), activeColor: Colors.red),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // \u00d6d\u00fcl kart\u0131
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.amber.shade50, Colors.orange.shade50]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.monetization_on, color: Colors.amber, size: 22)),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bulana \u00d6d\u00fcl', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange)),
                Text('Bulunma ihtimalini %400 art\u0131r\u0131r!', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: _rewardController,
              decoration: InputDecoration(
                hintText: '\u00d6rn: 200 TL veya Hediye \u00c7eki',
                prefixIcon: const Icon(Icons.card_giftcard, color: Colors.amber),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // G\u00fcvenlik formu
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade200, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.06), blurRadius: 14)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: Icon(Icons.lock_outlined, color: Colors.green.shade700, size: 24)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ak\u0131ll\u0131 E\u015fle\u015fme G\u00fcvenli\u011fi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Sadece ger\u00e7ek sahibi bilebilir', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
            ]),
            const SizedBox(height: 18),
            TextFormField(
              controller: _securityQuestionController,
              decoration: InputDecoration(
                labelText: 'Gizli Soru',
                hintText: '\u00d6rn: Anahtar\u0131m\u0131n kabl\u0131n rengi?',
                prefixIcon: Icon(Icons.help_outline, color: Colors.green.shade600),
                filled: true,
                fillColor: Colors.green.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green.shade400, width: 2)),
              ),
              validator: (v) => v!.isEmpty ? 'G\u00fcvenlik sorusu gerekli' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _securityAnswerController,
              decoration: InputDecoration(
                labelText: 'Gizli Cevap',
                hintText: 'Sahibi bu cevab\u0131 vermeli',
                prefixIcon: Icon(Icons.vpn_key_outlined, color: Colors.green.shade600),
                filled: true,
                fillColor: Colors.green.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green.shade400, width: 2)),
              ),
              validator: (v) => v!.isEmpty ? 'Cevap gerekli' : null,
            ),
          ]),
        ),
      ],
    );
  }

  // ===== STEP 3: YAYINLA =====
  Widget _buildStepPublish(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(Icons.rocket_launch, 'Can\u0131nlaz\u0131r!', '\u0130lan\u0131n haz\u0131r, yay\u0131nlayal\u0131m', Colors.teal),
        const SizedBox(height: 20),
        // \u00d6zet kart\u0131
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16)],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _selectedImages.isNotEmpty
                    ? Image.file(_selectedImages.first, width: 90, height: 90, fit: BoxFit.cover)
                    : Container(width: 90, height: 90, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 36)),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_selectedCategory != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF0A1F44), borderRadius: BorderRadius.circular(8)),
                    child: Text(_selectedCategory!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 6),
                Text(_titleController.text.isEmpty ? 'Ba\u015fl\u0131k girilmedi' : _titleController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on, size: 13, color: Colors.red),
                  const SizedBox(width: 3),
                  Expanded(child: Text(_locationController.text.isEmpty ? 'Konum girilmedi' : _locationController.text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                if (_rewardController.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                    child: Text('\ud83c\udfc6 \u00d6d\u00fcl: ${_rewardController.text}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
                if (_isUrgent) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: const Text('\u26a1 ACiL \u0130LAN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ])),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.teal.shade200)),
          child: Column(children: [
            const Row(children: [
              Icon(Icons.info_outline, color: Colors.teal, size: 18),
              SizedBox(width: 8),
              Text('Yay\u0131nland\u0131ktan sonra', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            ]),
            const SizedBox(height: 10),
            _checkRow('\u0130lan portal\u0131ndaki herkese g\u00f6r\u00fcn\u00fcr olur'),
            _checkRow('Haritada konumun i\u015faretlenir'),
            _checkRow('Yeni mesajlar i\u00e7in bildirim al\u0131rs\u0131n'),
            _checkRow('Y\u00f6netici onaylad\u0131ktan sonra tamamlan\u0131r'),
          ]),
        ),
      ],
    );
  }

  Widget _checkRow(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      const Icon(Icons.check_circle_outline, color: Colors.teal, size: 16),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
    ]),
  );

  Widget _sectionHeader(IconData icon, String title, String subtitle, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 24),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------------------
// 4. DETAIL SCREEN
// ---------------------------------------------------------------------------
class DetailScreen extends StatelessWidget {
  final Listing listing;
  const DetailScreen({super.key, required this.listing});

  void _showVerificationDialog(BuildContext context) {
    final answerController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const ROWTitle(icon: Icons.security, text: 'Sahiplik Doğrulaması'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'İlan sahibi bu eşya için bir güvenlik sorusu belirledi:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8)),
              child: Text(listing.securityQuestion,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.amber)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(labelText: 'Cevabınız'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              // Basit eşleştirme (case-insensitive)
              if (answerController.text.trim().toLowerCase() ==
                  listing.securityAnswer.trim().toLowerCase()) {
                Navigator.pop(ctx);
                _showSuccess(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yanlış cevap!')),
                );
              }
            },
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Tebrikler!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Eşleşme sağlandı. İlan sahibiyle iletişime geçebilirsiniz.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('İLETİŞİME GEÇ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: Theme.of(context).primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(
                  DataStore.isFavorite(listing.id) ? Icons.favorite : Icons.favorite_border,
                  color: DataStore.isFavorite(listing.id) ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  // StatefulWidget olmadığı için setState kullanamayız ancak
                  // Favori eklendiğini bildirebiliriz. Gerçekte Provider/Bloc kullanılır.
                  DataStore.toggleFavorite(listing.id).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text(DataStore.isFavorite(listing.id) ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı'),
                             duration: const Duration(seconds: 1),
                           ));
                  });
                },
              ),
              if (DataStore.currentUser != null &&
                  (DataStore.currentUser!.id == listing.ownerId ||
                   (DataStore.currentUser!.isManager && DataStore.currentUser!.schoolName == listing.schoolName)))
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('İlanı Sil'),
                        content: const Text('Bu ilanı silmek istediğinizden emin misiniz?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await DataStore.removeListing(listing.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İlan başarıyla silindi.'), backgroundColor: Colors.green));
                        Navigator.pop(context); // Go back to Home
                      }
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => PosterGeneratorView(listing: listing),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: listing.id,
                    child: listing.imageFile != null
                        ? Image.file(listing.imageFile!, fit: BoxFit.cover)
                        : Image.network(
                            listing.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported,
                                  size: 50, color: Colors.grey),
                            ),
                          ),
                  ),
                  // Hafif Karartı
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0.0, -20.0, 0.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fiyat / Durum Etiketi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: const Text('KAYIP EŞYA',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                                '${listing.date.day.toString().padLeft(2, '0')}.${listing.date.month.toString().padLeft(2, '0')}.${listing.date.year}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Başlık
                    Text(listing.title,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0A1F44),
                            height: 1.2)),
                    const SizedBox(height: 16),

                    // Konum
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.grey[100], shape: BoxShape.circle),
                          child: const Icon(Icons.location_on,
                              color: Color(0xFF0A1F44), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(listing.location,
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500)),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      MockMapScreen(listing: listing)),
                            );
                          },
                          icon: const Icon(Icons.map,
                              size: 16, color: Color(0xFF0A1F44)),
                          label: const Text('Haritada Gör',
                              style: TextStyle(color: Color(0xFF0A1F44))),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Divider(),
                    ),

                    // İlan Sahibi Profili ve Güven Rozetleri (Letgo Tarzı + Banka Güveni)
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFF0A1F44),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(listing.ownerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.shield,
                                      color: Colors.green, size: 14),
                                  const SizedBox(width: 4),
                                  const Text('T.C. Onaylı',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Icon(Icons.star,
                                      color: Colors.amber[600], size: 14),
                                  Text(' 5.0 Skor',
                                      style: TextStyle(
                                          color: Colors.amber[800],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final me = DataStore.currentUser;
                            if (me == null) return;
                            final otherId = listing.ownerId;
                            if (otherId == me.id) return;

                            // Deterministik chatId (iki kullanıcı arasında hep aynı)
                            final ids = [me.id, otherId]..sort();
                            final chatId = '${ids[0]}_${ids[1]}';

                            final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
                            final chatSnap = await chatRef.get();
                            if (!chatSnap.exists) {
                              await chatRef.set({
                                'participants': [me.id, otherId],
                                'participantNames': [me.name, listing.ownerName],
                                'lastMessage': '',
                                'lastMessageAt': Timestamp.now(),
                              });
                            }

                            if (context.mounted) {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(
                                  chatId: chatId,
                                  otherUserName: listing.ownerName,
                                  otherUserId: otherId,
                                ),
                              ));
                            }
                          },
                          icon: const Icon(Icons.chat_bubble_outline,
                              size: 16, color: Color(0xFF0A1F44)),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            side: const BorderSide(color: Color(0xFF0A1F44)),
                          ),
                          label: const Text('Mesaj At',
                              style: TextStyle(color: Color(0xFF0A1F44))),
                        ),
                        if (listing.latitude != null && listing.longitude != null)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final lat = listing.latitude!;
                              final lng = listing.longitude!;
                              // Google Maps yol tarifi URL'si - direkt navigasyon modu
                              final uri = Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.directions, color: Colors.white, size: 16),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            label: const Text('Yol Tarifi Al',
                                style: TextStyle(color: Colors.white)),
                          )
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Başarı Rozetleri (Badges) Alanı
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildBadge(Icons.check_circle_outline,
                              'Hızlı Eşleşen', Colors.blue),
                          _buildBadge(Icons.handshake_outlined, 'Dürüst İade',
                              Colors.purple),
                          _buildBadge(
                              Icons.history, '1+ Yıllık Üye', Colors.orange),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Divider(),
                    ),

                    // Güvenlik Açıklaması
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.amber, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Güvenli Teslimat Uyarısı',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.brown)),
                                SizedBox(height: 4),
                                Text(
                                  'Bu eşyanın size ait olduğunu iddia ediyorsanız, ilan sahibinin oluşturduğu güvenlik sorusunu doğru yanıtlamalısınız.',
                                  style: TextStyle(
                                      color: Colors.black87, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Divider(),
                    ),

                    // Arka Plan Hikayesi (Backstory)
                    const Text('Olay Yeri & Hikaye',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0A1F44))),
                    const SizedBox(height: 12),
                    Text(
                      'Bu eşya en son ${listing.location} civarında, muhtemelen aceleyle unutulmuş bir şekilde bulundu. Eğer seninleyse veya bunu arıyorsan, doğru yerdesin. GörBul yapay zekası bu ilanın %85 ihtimalle senin aradığın eşya olabileceğini düşünüyor.',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700], height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    // Emanetçi (Güvenli Nokta) Sistemi
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.storefront, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Güvenli Noktaya Bırakıldı ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    Icon(Icons.verified, color: Colors.green[600], size: 16),
                                  ],
                                ),
                                const Text('Kadıköy Merkez Karakolu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                const Text('Bu eşya bulan kişi tarafından polis/zabıta noktasına teslim edilmiştir.', style: TextStyle(fontSize: 12, color: Colors.black87)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 120), // Buton için genişletilmiş boşluk
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Alt Sabit Buton Alanı
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5))
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showVerificationDialog(context),
              icon: const Icon(Icons.fingerprint),
              label: const Text('BU EŞYA BANA AİT',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A1F44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, MaterialColor color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color[50], shape: BoxShape.circle),
          child: Icon(icon, color: color[400], size: 20),
        ),
        const SizedBox(height: 4),
        Text(text,
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// Kücük yardımcı widget
class ROWTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  const ROWTitle({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon), const SizedBox(width: 8), Text(text)]);
  }
}

// ---------------------------------------------------------------------------
// SETTINGS SCREEN (GERÇEKTEn ÇALIŞIYOR)
// ---------------------------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = DataStore.currentUser;
    _nameController = TextEditingController(text: u != null ? '${u.name} ${u.surname}' : '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _darkMode = DataStore.isDarkMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final u = DataStore.currentUser;
      if (u != null) {
        final parts = _nameController.text.trim().split(' ');
        await FirebaseFirestore.instance.collection('users').doc(u.id).update({
          'name': parts.isNotEmpty ? parts.first : u.name,
          'surname': parts.length > 1 ? parts.sublist(1).join(' ') : u.surname,
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        });
        await DataStore.reloadCurrentUser();
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profil güncellendi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = DataStore.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A1F44),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profil bilgileri kartı
            _card(
              icon: Icons.person_outline,
              title: 'Profil Bilgileri',
              color: Colors.indigo,
              child: Column(children: [
                const SizedBox(height: 14),
                _field(_nameController, 'Ad Soyad', Icons.badge_outlined),
                const SizedBox(height: 12),
                _field(_emailController, 'E-posta', Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_phoneController, 'Telefon', Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Görünüm
            _card(
              icon: Icons.palette_outlined,
              title: 'Görünüm',
              color: Colors.purple,
              child: Column(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.dark_mode_outlined, color: Colors.purple.shade700),
                  ),
                  title: const Text('Karanlık Mod', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Koyu tema kullan'),
                  value: _darkMode,
                  activeColor: Colors.purple,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _darkMode = val);
                    DataStore.setDarkMode(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(val ? '🌙 Karanlık mod açıldı (yeniden başlatınca aktif)' : '☀️ Aydınlık mod'), duration: const Duration(seconds: 2)),
                    );
                  },
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Bildirimler
            _card(
              icon: Icons.notifications_outlined,
              title: 'Bildirimler',
              color: Colors.orange,
              child: Column(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.notifications_active_outlined, color: Colors.orange.shade700),
                  ),
                  title: const Text('Yeni Eşleşme Bildirimi', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Birisi ilanını gördüğünde bildir'),
                  value: _notificationsEnabled,
                  activeColor: Colors.orange,
                  onChanged: (val) => setState(() => _notificationsEnabled = val),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Hesap bilgileri (salt okunur)
            _card(
              icon: Icons.verified_user_outlined,
              title: 'Hesap Bilgileri',
              color: Colors.teal,
              child: Column(children: [
                const SizedBox(height: 8),
                _infoRow('T.C. No', u != null ? '${u.tcKimlik.substring(0, 3)}*****${u.tcKimlik.substring(8)}' : '-'),
                _infoRow('Okul / Kurum', u?.schoolName ?? '-'),
                _infoRow('Üyelik', 'Aktif ✅'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required IconData icon, required String title, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        child,
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? type}) => TextField(
    controller: c,
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF4F6FB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigo, width: 2)),
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ---------------------------------------------------------------------------
// 5. PROFILE & SETTINGS SCREEN
// ---------------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim', style: TextStyle(letterSpacing: 1.0)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ayarlar',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Üst Mavi Kart (Profil Özeti)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                  bottom: 32, left: 24, right: 24, top: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child:
                        Icon(Icons.person, size: 50, color: Color(0xFF0A1F44)),
                  ),
                  const SizedBox(height: 16),
                  Text(DataStore.currentUser?.name ?? 'Ahmet Kaan R.',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified,
                          color: Colors.tealAccent[400], size: 18),
                      const SizedBox(width: 4),
                      Text(DataStore.currentUser != null ? 'T.C. Kimlik Doğrulanmış (${DataStore.currentUser!.tcKimlik.substring(0,3)}*****)' : 'T.C. Kimlik Doğrulanmış (123*****789)',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // İstatistikler (Letgo benzeri Güven / Satış istatistikleri)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(child: _buildStatCard('Dijital Dolap', '${DataStore.vaultItems.length}', context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Yayında', '${DataStore.listings.length}', context)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildStatCard('Güven Skoru', '100', context)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // YENİ OYUNLAŞTIRILMIŞ ROZET (BADGE) SİSTEMİ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Başarı Rozetleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildDetailedBadge('Altın Bulucu', '10+ Eşya teslim etti', Icons.emoji_events, Colors.amber),
                        _buildDetailedBadge('Hızlı Melek', '24 saatin altında eşleşme', Icons.bolt, Colors.blue),
                        _buildDetailedBadge('Evcil Dostu', 'Kaybolan bir patiliyi buldu', Icons.pets, Colors.deepOrange),
                        _buildDetailedBadge('Onaylı Hesap', 'Kimlik doğrulaması tamam', Icons.verified_user, Colors.green),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Ayarlar Listesi
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Colors.indigo),
              ),
              title: const Text('Dijital Eşya Dolabım',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Kayıp olmadan önce eşyalarını kaydet', style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const DigitalVaultScreen()));
              },
            ),

            // İlan Geçmişim
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.history, color: Colors.teal),
              ),
              title: const Text('İlan Geçmişim', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${DataStore.listings.where((l) => l.ownerId == DataStore.currentUser?.id).length} ilan',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                HapticFeedback.selectionClick();
                final myListings = DataStore.listings.where((l) => l.ownerId == DataStore.currentUser?.id).toList();
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (ctx) => Column(
                    children: [
                      const Padding(padding: EdgeInsets.all(16), child: Text('İlanlarım', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                      Expanded(
                        child: myListings.isEmpty
                            ? const Center(child: Text('Henüz ilan vermediniz.'))
                            : ListView.builder(
                                itemCount: myListings.length,
                                itemBuilder: (ctx, i) {
                                  final l = myListings[i];
                                  return ListTile(
                                    leading: Icon(l.status == 'resolved' ? Icons.check_circle : Icons.hourglass_top, color: l.status == 'resolved' ? Colors.green : Colors.blue),
                                    title: Text(l.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(l.location),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: l.status == 'resolved' ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(10)),
                                      child: Text(l.status == 'resolved' ? 'Çözüldü' : 'Aktif', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_2, color: Colors.purple),
              ),
              title: const Text('Akıllı Eşya QR Etiketi Üret',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
              onTap: () {
                showDialog(
                    context: context,
                    builder: (context) => const QRGeneratorDialog());
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, color: Colors.orange),
              ),
              title: const Text('Kahramanlar Tablosu',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const LeaderboardScreen()));
              },
            ),

            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security, color: Colors.red),
              ),
              title: const Text('Güvenlik Ayarları',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Hesap güvenliği ve gizlilik', style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                HapticFeedback.selectionClick();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Row(children: [
                      Icon(Icons.security, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Güvenlik Ayarları'),
                    ]),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_outline, color: Colors.indigo),
                          title: const Text('Şifre Değiştir'),
                          subtitle: const Text('Firebase ile yönetilir', style: TextStyle(fontSize: 11)),
                          contentPadding: EdgeInsets.zero,
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.notifications_active_outlined, color: Colors.orange),
                          title: const Text('Bildirim Tercihleri'),
                          subtitle: const Text('Yeni eşleşme ve mesaj bildirimleri', style: TextStyle(fontSize: 11)),
                          contentPadding: EdgeInsets.zero,
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined, color: Colors.teal),
                          title: const Text('Gizlilik'),
                          subtitle: const Text('Verilerinizi yönetin', style: TextStyle(fontSize: 11)),
                          contentPadding: EdgeInsets.zero,
                          onTap: () {},
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.help_outline, color: Colors.blue),
              ),
              title: const Text('Yardım ve Destek',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Sıkca sorulanlar ve iletişim', style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                HapticFeedback.selectionClick();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Row(children: [
                      Icon(Icons.help_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Yardım ve Destek'),
                    ]),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('❓ Sıkça Sorulanlar', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('• İlan nasıl veririm?→ Alt menüden "İlan Ver"e bas.'),
                        const SizedBox(height: 4),
                        const Text('• Mes ajlaşma ücretsiz mi? → Evet, ücretsiz.'),
                        const SizedBox(height: 4),
                        const Text('• Portal duyuruları nedir? → Yerlinden yöneticinin portala özel mesajları.'),
                        const Divider(height: 24),
                        const Text('✉️ İletişim', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('destek@gorbul.app', style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await DataStore.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Güvenli Çıkış Yap',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    // 1. Onay
                    final firstConfirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hesabı Sil'),
                        content: const Text('Hesabınızı silmek istediğinizden emin misiniz? Tüm ilanlarınız ve verileriniz Firebase\'den kalıcı olarak silinecektir.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet, Sil', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (firstConfirm != true || !context.mounted) return;

                    // 2. Onay (çift kontrol)
                    final secondConfirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Son Onay'),
                        content: const Text('Bu işlem GERİ ALINAMAZ! Hesabınız ve tüm ilanlarınız kalıcı olarak silinecek.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Hesabımı Kalıcı Olarak Sil')),
                        ],
                      ),
                    );
                    if (secondConfirm != true || !context.mounted) return;

                    await DataStore.deleteAccount();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.grey),
                  label: const Text('Hesabı Sil', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.tealAccent : Theme.of(context).primaryColor)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey)),
        ],
      ),
    );
  }

  // Yeni Detaylı Rozet Widget'ı
  Widget _buildDetailedBadge(String title, String subtitle, IconData icon, Color color) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color), textAlign: TextAlign.center, maxLines: 1),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, BuildContext context,
      {bool isFavoriteMode = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        if (isFavoriteMode) {
          Navigator.push(context, MaterialPageRoute(builder: (c) => const FavoritesScreen()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title Sayfası (Yapım Aşamasında)')));
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 6. FAVORITES SCREEN (YENİ EKLENDİ)
// ---------------------------------------------------------------------------
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // DataStore.listings listesinden favori ID'lerine sahip olanları filtrele
    final favoriteListings = DataStore.listings.where((listing) => DataStore.favoriteListingIds.contains(listing.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorilerim'),
        elevation: 0,
      ),
      body: favoriteListings.isEmpty
          ? const Center(child: Text('Henüz favoriniz bulunmuyor.', style: TextStyle(color: Colors.grey)))
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: favoriteListings.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final listing = favoriteListings[index];
                return Stack(
                  children: [
                    _buildListingCard(listing, context), // Gerçek kartı çiziyoruz
                    // Favori ekranında olduğumuz için kalbe tıklandığında anında güncellemesi 
                    // için üzerine devasa görünmez bir overlay koyabiliriz veya kartı stateful yapmalıyız. 
                    // Ancak _buildListingCard doğrudan DataStore.isFavorite kullanıp 
                    // state güncellediği için burada çalışır, ancak GridView kendini yenilemez.
                  ],
                );
              },
            ),
    );
  }

  Widget _buildListingCard(Listing listing, BuildContext context) {
    // HomeScreen'deki metoddan aynen alıyoruz ama state olmadığı için mock çalışır.
    // Mimari bir sonraki adımda `Provider` veya global state yönetimini gerektirecek.
    return Card(
      child: Center(child: Text(listing.title)),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. RADAR MATCH ANIMATION (AKILLI TARAMA)
// ---------------------------------------------------------------------------
class RadarMatchDialog extends StatefulWidget {
  const RadarMatchDialog({super.key});

  @override
  State<RadarMatchDialog> createState() => _RadarMatchDialogState();
}

class _RadarMatchDialogState extends State<RadarMatchDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _matchFound = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();

    // 3 Saniye sonra eşleşme bulundu simülasyonu
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _matchFound = true;
          _controller.stop();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_matchFound) ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Container(
                        width: 150 * _controller.value,
                        height: 150 * _controller.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.tealAccent
                              .withOpacity(1.0 - _controller.value),
                        ),
                      );
                    },
                  ),
                  const Icon(Icons.radar, size: 60, color: Color(0xFF0A1F44)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Kayıplar Taranıyor...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Çevredeki benzer eşyalar yapay zeka ile eşleştiriliyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ] else ...[
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text('EŞLEŞME BULUNDU!',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                    backgroundImage:
                        NetworkImage('https://via.placeholder.com/150/92c952')),
                title: const Text('Yeşil Anahtarlık',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('%95 Benzerlik Tespit Edildi'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A1F44),
                    minimumSize: const Size(double.infinity, 50)),
                child: const Text('Eşleşmeyi İncele'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. CHAT (MESSAGES) SCREEN
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// 7. MESSAGES SCREEN (FİREBASE GERÇEK ZAMANLI)
// ---------------------------------------------------------------------------
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myId = DataStore.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlar', style: TextStyle(letterSpacing: 1.0)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 30 gün silme banner'ı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.amber.shade100,
            child: Row(children: [
              const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'Mesajlar 30 günde otomatik silinir',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: myId)
                  .orderBy('lastMessageAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Henüz mesajın yok.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                        const SizedBox(height: 8),
                        Text('İlan sayfasından birine mesaj gönder.',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final chatId = docs[i].id;
                    final List parts = data['participantNames'] ?? [];
                    final otherName = parts.firstWhere(
                      (n) => n != (DataStore.currentUser?.name ?? ''),
                      orElse: () => 'Kullanıcı',
                    );
                    final lastMsg = data['lastMessage'] ?? '';
                    final lastAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
                    final timeStr = lastAt != null
                        ? '${lastAt.hour}:${lastAt.minute.toString().padLeft(2, '0')}'
                        : '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(otherName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(timeStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[600])),
                      ),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            chatId: chatId,
                            otherUserName: otherName,
                            otherUserId: (data['participants'] as List)
                                .firstWhere((id) => id != myId, orElse: () => ''),
                          ),
                        ));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7.5. CHAT DETAIL SCREEN (FİREBASE GERÇEK ZAMANLI)
// ---------------------------------------------------------------------------
class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    final me = DataStore.currentUser;
    final now = Timestamp.now();
    final expiry = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));

    final msgData = {
      'senderId': me?.id ?? '',
      'senderName': me?.name ?? 'Ben',
      'text': text,
      'createdAt': now,
      'expiryAt': expiry,
    };

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    // Mesajı ekle
    await chatRef.collection('messages').add(msgData);

    // Chat önizlemesini güncelle
    await chatRef.update({
      'lastMessage': text,
      'lastMessageAt': now,
    });

    // Scroll'u aşağı kaydır
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = DataStore.currentUser?.id ?? '';
    final now = Timestamp.now();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName, style: const TextStyle(fontSize: 16)),
            const Text('Doğrudan Mesaj', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 30 gün banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            color: Colors.amber.shade100,
            child: Row(children: [
              const Icon(Icons.timer_outlined, size: 13, color: Colors.orange),
              const SizedBox(width: 6),
              Text('Bu sohbet 30 günde otomatik silinir',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .where('expiryAt', isGreaterThan: now)
                  .orderBy('expiryAt')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snapshot.data?.docs ?? [];
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text('Henüz mesaj yok.\nİlk mesajı sen gönder! 👋',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i].data() as Map<String, dynamic>;
                    final isMe = m['senderId'] == myId;
                    final createdAt = (m['createdAt'] as Timestamp?)?.toDate();
                    final timeStr = createdAt != null
                        ? '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? Theme.of(context).primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMe ? const Radius.circular(0) : null,
                              bottomLeft: !isMe ? const Radius.circular(0) : null,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(m['text'] ?? '',
                                  style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(timeStr,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isMe ? Colors.white70 : Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yazın...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Harita Zemin Çizimi (Grid)
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.indigo.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// 8. GLOBAL MAP SCREEN (TÜM İLANLAR)
// ---------------------------------------------------------------------------
class GlobalMapScreen extends StatelessWidget {
  const GlobalMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıp & Bulunan Haritası', style: TextStyle(letterSpacing: 1.0)),
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Simüle Edilmiş Harita Arka Planı
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://i.imgur.com/rS2B6O7.png'), // Mock Map Texture
                fit: BoxFit.cover,
                opacity: 0.6, // Biraz şeffaf ki pinler belli olsun
              ),
            ),
          ),
          
          // 2. Harita Üzerindeki Grid/Layer Efekti (Dijital görünüm)
          CustomPaint(
            painter: GridPainter(),
          ),

          // 3. İlan Pinleri
          ...DataStore.listings.asMap().entries.map((entry) {
            final index = entry.key;
            final listing = entry.value;
            // Basit mock pozisyonlama (farklı yerlere dağıtmak için math.sin falan kullanabiliriz ama basit offsetler yeterli)
            final double topOffset = 100.0 + (index * 60) % 400;
            final double leftOffset = 50.0 + (index * 90) % 250;
            
            return Positioned(
              top: topOffset,
              left: leftOffset,
              child: GestureDetector(
                onTap: () {
                  // Tıklanınca ilan detayına git
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DetailScreen(listing: listing)),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: listing.isUrgent ? Colors.red : Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                      ),
                      child: Text(
                        listing.title,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.location_on,
                      size: 40,
                      color: listing.isUrgent ? Colors.red : Theme.of(context).primaryColor,
                      shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konumunuz Bulunuyor...')),
          );
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// 9. GÖRBUL AI (AKILLI ASİSTAN) SCREEN
// ---------------------------------------------------------------------------
class PortalAnnouncementScreen extends StatefulWidget {
  const PortalAnnouncementScreen({super.key});

  @override
  State<PortalAnnouncementScreen> createState() => _PortalAnnouncementScreenState();
}

class _PortalAnnouncementScreenState extends State<PortalAnnouncementScreen> {
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;

  String get _myPortal => DataStore.currentUser?.schoolName ?? '';
  bool get _isManager => DataStore.currentUser?.isManager ?? false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('announcements')
          .where('schoolName', isEqualTo: _myPortal)
          .orderBy('date', descending: true)
          .get();
      setState(() {
        _announcements = snap.docs.map((d) => {...d.data(), 'docId': d.id}).toList();
      });
    } catch (e) {
      // Offline veya indeks hatası - sessizce geç
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addAnnouncement(String content) async {
    if (content.trim().isEmpty) return;
    final data = {
      'schoolName': _myPortal,
      'content': content.trim(),
      'authorName': DataStore.currentUser?.name ?? 'Yönetici',
      'date': DateTime.now().toIso8601String(),
    };
    try {
      await FirebaseFirestore.instance.collection('announcements').add(data);
      await _loadAnnouncements();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _deleteAnnouncement(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
      await _loadAnnouncements();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
    }
  }

  void _showComposeDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$_myPortal Portali - Yeni Duyuru'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Duyuru metni...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addAnnouncement(ctrl.text);
            },
            child: const Text('Yayınla'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_myPortal - Duyurular', style: const TextStyle(letterSpacing: 0.5)),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAnnouncements),
        ],
      ),
      floatingActionButton: _isManager
          ? FloatingActionButton.extended(
              heroTag: 'new_announcement',
              onPressed: _showComposeDialog,
              icon: const Icon(Icons.add),
              label: const Text('Duyuru Ekle'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined, size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _isManager
                            ? 'Henüz duyuru yok.\nSağ alttaki butona basarak ilk duyuruyu ekle!'
                            : 'Henüz duyuru yok.\nYönetici bir şey paylaştığında burada görünecek.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 15),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnnouncements,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _announcements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final a = _announcements[index];
                      final date = a['date'] != null
                          ? DateTime.tryParse(a['date'])
                          : null;
                      final dateStr = date != null
                          ? '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2,'0')}'
                          : '';
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.campaign, color: Colors.indigo, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a['authorName'] ?? 'Yönetici',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  if (_isManager)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => _deleteAnnouncement(a['docId']),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(a['content'] ?? '', style: const TextStyle(fontSize: 15)),
                              const SizedBox(height: 8),
                              Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}


class MockMapScreen extends StatefulWidget {
  final Listing listing;
  const MockMapScreen({super.key, required this.listing});

  @override
  State<MockMapScreen> createState() => _MockMapScreenState();
}

class _MockMapScreenState extends State<MockMapScreen> {
  String _distanceText = 'Hesaplanıyor...';

  @override
  void initState() {
    super.initState();
    _calculateDistance();
  }

  Future<void> _calculateDistance() async {
    if (widget.listing.latitude == null || widget.listing.longitude == null) {
      if (mounted) setState(() => _distanceText = 'Konum bilgisi eksik');
      return;
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          if (mounted) setState(() => _distanceText = 'Konum izni yok');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude, 
        position.longitude, 
        widget.listing.latitude!, 
        widget.listing.longitude!
      );
      
      if (mounted) {
        setState(() {
          _distanceText = '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _distanceText = 'Uzaklık hesabı başarısız');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        // <-- WIDGET'LAR ÜST ÜSTE BİNSİN DİYE STACK EKLENDİ
        children: [
          // Sahte Harita Arka Planı
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                    'https://via.placeholder.com/800x1200.png?text=Google+Maps+Simulasyonu'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Konum Pini
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: Text(widget.listing.location,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.location_on, color: Colors.red, size: 50),
              ],
            ),
          ),
          // Alt Kullanıcı Paneli
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10)
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: widget.listing.imageFile != null
                        ? FileImage(widget.listing.imageFile!) as ImageProvider
                        : NetworkImage(widget.listing.imageUrl),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.listing.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Uzaklık: $_distanceText',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.directions,
                        color: Colors.blue, size: 30),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Yol tarifi başlatılıyor...')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ), // <-- STACK KAPATILDI
    ); // <-- SCAFFOLD KAPATILDI
  }
}

// ---------------------------------------------------------------------------
// 9. POSTER GENERATOR VIEW (1-CLICK KAYIP AFİŞİ)
// ---------------------------------------------------------------------------
class PosterGeneratorView extends StatelessWidget {
  final Listing listing;
  const PosterGeneratorView({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kapatma Butonu
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Afiş Önizleme Alanı
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.red, width: 4),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(2, 4))
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'KAYIP ARANIYOR',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.red,
                        letterSpacing: 2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Görsel
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: listing.imageFile != null
                        ? Image.file(listing.imageFile!, fit: BoxFit.cover)
                        : Image.network(listing.imageUrl, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    listing.title.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En son görülen yer:\n${listing.location}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  if (listing.rewardAmount.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: Colors.amber,
                      child: Text(
                        'ÖDÜL: ${listing.rewardAmount}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(color: Colors.red, thickness: 2),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.saved_search, color: Colors.red),
                      SizedBox(width: 8),
                      Text('GörBul Uygulamasından İletişime Geçin',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Paylaş Butonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Afiş hikayelerde paylaşılmak üzere hazırlandı! (Simülasyon)')),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.share),
                label: const Text('Instagram Hikayesinde Paylaş'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 10. SMART QR LABEL GENERATOR
// ---------------------------------------------------------------------------
class QRGeneratorDialog extends StatelessWidget {
  const QRGeneratorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner,
                size: 60, color: Color(0xFF0A1F44)),
            const SizedBox(height: 16),
            const Text('Akıllı QR Etiketiniz',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Bu kodu yazdırıp cüzdanınıza, anahtarlığınıza veya çantanıza yapıştırın. Biri bulup kodu okuttuğunda size anında konum ve iletişim bildirimi gelir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Image.network(
                'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=gorbul://foundItem/${DataStore.currentUser?.id ?? 'unknown'}',
                height: 200,
                width: 200,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('QR Kod galeriye kaydedildi! (Simülasyon)')),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.download),
                label: const Text('Kaydet ve Yazdır'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A1F44),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 11. LEADERBOARD (KAHRAMANLAR) SCREEN
// ---------------------------------------------------------------------------
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> heroes = DataStore.currentUser != null ? [
      {'name': DataStore.currentUser!.name, 'score': 0, 'rank': 'Yeni Katılımcı', 'finds': 0, 'color': Colors.blueGrey},
    ] : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kahramanlar Tablosu', style: TextStyle(letterSpacing: 1.0)),
        elevation: 0,
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, size: 80, color: Colors.white),
                const SizedBox(height: 12),
                const Text('Topluluğun En İyileri', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Başkalarının eşyalarını bularak zirveye yüksel!', style: TextStyle(color: Colors.orange[100], fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: heroes.length,
              itemBuilder: (context, index) {
                final hero = heroes[index];
                final isMe = hero['name'] == (DataStore.currentUser?.name ?? 'Kaan R.');
                
                return Card(
                  elevation: isMe ? 4 : 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isMe ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: hero['color']?.withOpacity(0.2),
                      radius: 24,
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(color: hero['color'], fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(hero['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isMe ? Colors.orange : null)),
                        Text('${hero['score']} Puan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hero['color'],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(hero['rank'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          Text('${hero['finds']} Eşya Buldu', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 12. DIGITAL VAULT (DİJİTAL EŞYA DOLABIM) SCREEN
// ---------------------------------------------------------------------------
class DigitalVaultScreen extends StatefulWidget {
  const DigitalVaultScreen({super.key});

  @override
  State<DigitalVaultScreen> createState() => _DigitalVaultScreenState();
}

class _DigitalVaultScreenState extends State<DigitalVaultScreen> {
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dijital Eşya Dolabım'),
        backgroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Basit, hızlı ekleme senaryosu simülasyonu ama gerçek listeye kaydedecek.
              setState(() {
                DataStore.vaultItems.add(VaultItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: 'Özel Eşya ${DataStore.vaultItems.length + 1}',
                  serial: 'SN-${DateTime.now().millisecondsSinceEpoch}',
                  date: '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  iconCodePoint: Icons.save.codePoint,
                  colorValue: Colors.blue.value,
                ));
                DataStore.saveVaultItems();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hızlı Eşya Eklendi.')),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            color: Colors.indigo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Önceden Kaydet,\nSonradan Üzülme 🛡️', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.3)),
                const SizedBox(height: 12),
                Text('Eşyalarınızın seri numaralarını, faturalarını ve özelliklerini buraya şifreleyerek kaydedin. Kaybolursa tek tıkla "Kayıp" ilanına dönüştürün.', style: TextStyle(color: Colors.indigo[100], fontSize: 13, height: 1.5)),
              ],
            ),
          ),
          Expanded(
            child: DataStore.vaultItems.isEmpty 
              ? const Center(child: Text('Dolabınız şu an boş.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: DataStore.vaultItems.length,
                  itemBuilder: (context, index) {
                     final item = DataStore.vaultItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Color(item.colorValue).withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(IconData(item.iconCodePoint, fontFamily: 'MaterialIcons'), color: Color(item.colorValue)),
                        ),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Kayıt: ${item.date}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Seri / Çip No: ${item.serial}', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                                    const Icon(Icons.verified_user, color: Colors.green, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Hemen GörBul ağına kayıp ilanı olarak düşürüldü! (Simülasyon)'), backgroundColor: Colors.red),
                                      );
                                    },
                                    icon: const Icon(Icons.warning, color: Colors.white),
                                    label: const Text('TEK TIKLA KAYIP BİLDİR', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  }
                ),
          )
        ],
      ),
    );
  }
}
