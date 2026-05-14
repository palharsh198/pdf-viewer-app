import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { user, admin }

enum AppThemeMode { system, light, dark }

enum AppLanguage { english, hindi }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    UserRole? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
    );
  }
}

class PdfModel {
  final String id;
  final String title;
  final String category;
  final String description;
  final String fileName;
  final List<int>? bytes;
  final String? url;
  final DateTime createdAt;
  final String ownerId;
  final String? filePath;
 final bool isBookmarked;

  const PdfModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.fileName,
    required this.createdAt,
    required this.ownerId,
    this.bytes,
    this.url,
    this.filePath,
    this.isBookmarked = false,
  });

  factory PdfModel.fromJson(Map<String, dynamic> json) {
    return PdfModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      isBookmarked: json['isBookmarked'] ?? false,
      fileName: json['fileName'] ?? '',
      bytes: null,
      url: json['url'] ?? json['fileUrl'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      ownerId: json['ownerId'] ?? '',
      filePath: json['filePath'],
    );
  }

  PdfModel copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    String? fileName,
    List<int>? bytes,
    String? url,
    DateTime? createdAt,
    String? ownerId,
    String? filePath,
    bool? isBookmarked,
  }) {
    return PdfModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      fileName: fileName ?? this.fileName,
      bytes: bytes ?? this.bytes,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      ownerId: ownerId ?? this.ownerId,
      filePath: filePath ?? this.filePath,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "category": category,
      "description": description,
      "fileName": fileName,
      "url": url,
      "ownerId": ownerId,
      "filePath": filePath,
      "createdAt": createdAt.toIso8601String(),
      "isBookmarked": isBookmarked,
    };
  }
}


class AppStore extends ChangeNotifier {
  AppStore._();

  static final AppStore instance = AppStore._();

  AppUser? currentUser;

  AppThemeMode themeMode = AppThemeMode.system;
  AppLanguage language = AppLanguage.english;

  final List<AppUser> users = [
    const AppUser(
      id: 'admin-1',
      name: 'Admin',
      email: 'admin@gmail.com',
      password: '123456',
      role: UserRole.admin,
    ),
    const AppUser(
      id: 'user-1',
      name: 'Harshit',
      email: 'user@gmail.com',
      password: '123456',
      role: UserRole.user,
    ),
  ];

  final List<String> categories = [
    'Programming',
    'Database',
    'Education',
    'Artificial Intelligence',
    'General',
  ];

  final List<PdfModel> pdfs = [
    PdfModel(
      id: 'pdf-1',
      title: 'Flutter Notes',
      category: 'Programming',
      description: 'Flutter widgets and layouts notes.',
      fileName: 'flutter_notes.pdf',
      url: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
      createdAt: DateTime.now(),
      ownerId: 'user-1',
    ),
    PdfModel(
      id: 'pdf-2',
      title: 'DBMS Notes',
      category: 'Database',
      description: 'DBMS concepts and SQL notes.',
      fileName: 'dbms_notes.pdf',
      url: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
      createdAt: DateTime.now(),
      ownerId: 'user-1',
    ),
  ];

  final Map<String, Set<String>> bookmarksByUser = {};

  String _newId(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  void updateTheme(AppThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void updateLanguage(AppLanguage value) {
    language = value;
    notifyListeners();
  }

  String? login({
    required String email,
    required String password,
    required UserRole role,
  }) {
    try {
      final user = users.firstWhere(
            (u) =>
        u.email.trim().toLowerCase() == email.trim().toLowerCase() &&
            u.password == password &&
            u.role == role,
      );
      currentUser = user;
      notifyListeners();
      return null;
    } catch (_) {
      return 'Invalid credentials';
    }
  }

  String? signup({
    required String name,
    required String email,
    required String password,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    if (users.any((u) => u.email.toLowerCase() == cleanEmail)) {
      return 'Email already exists';
    }

    final user = AppUser(
      id: _newId('user'),
      name: name.trim(),
      email: cleanEmail,
      password: password,
      role: UserRole.user,
    );

    users.add(user);
    currentUser = user;
    notifyListeners();
    return null;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  List<PdfModel> get currentUserPdfs {
    final uid = currentUser?.id;
    if (uid == null) return [];
    return pdfs.where((pdf) => pdf.ownerId == uid).toList();
  }

  bool isBookmarked(String pdfId) {
    final uid = currentUser?.id;
    if (uid == null) return false;
    return bookmarksByUser[uid]?.contains(pdfId) ?? false;
  }

  void toggleBookmark(String pdfId) {
    final uid = currentUser?.id;
    if (uid == null) return;

    final set = bookmarksByUser.putIfAbsent(uid, () => <String>{});
    if (set.contains(pdfId)) {
      set.remove(pdfId);
    } else {
      set.add(pdfId);
    }
    notifyListeners();
  }

  List<PdfModel> userBookmarks() {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final ids = bookmarksByUser[uid] ?? <String>{};
    return pdfs.where((p) => p.ownerId == uid && ids.contains(p.id)).toList();
  }

  Future<String?> addPdf({
    required String title,
    required String category,
    required String description,
    required String fileName,
    List<int>? bytes,
    String? url,
  }) async {
    if (title.trim().isEmpty ||
        category.trim().isEmpty ||
        description.trim().isEmpty) {
      return 'Fill all fields';
    }

    final uid = currentUser?.id;
    if (uid == null) return 'User not logged in';

    String? savedPath;

    if (bytes != null && bytes.isNotEmpty) {
      final dir = await getApplicationDocumentsDirectory();

      final pdfDir = Directory("${dir.path}/pdfs");

      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }

      final file = File(
        "${pdfDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName",
      );

      await file.writeAsBytes(bytes);
      savedPath = file.path;
    }

    pdfs.insert(
      0,
      PdfModel(
        id: _newId('pdf'),
        title: title.trim(),
        category: category.trim(),
        description: description.trim(),
        fileName: fileName,
        filePath: savedPath,
        url: url,
        createdAt: DateTime.now(),
        ownerId: uid,
      ),
    );

    await savePdfs();

    notifyListeners();
    return null;
  }
  Future<void> savePdfs() async {
    final prefs = await SharedPreferences.getInstance();

    final data = pdfs.map((p) {
      return {
        'id': p.id,
        'title': p.title,
        'category': p.category,
        'description': p.description,
        'fileName': p.fileName,
        'filePath': p.filePath,
        'url': p.url,
        'ownerId': p.ownerId,
        'createdAt': p.createdAt.toIso8601String(),
      };
    }).toList();

    await prefs.setString('pdfs', jsonEncode(data));
  }

  Future<void> loadPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('pdfs');

    if (savedData == null) return;

    final List decodedData = jsonDecode(savedData);

    pdfs.clear();

    pdfs.addAll(
      decodedData.map(
            (e) => PdfModel(
          id: e['id'],
          title: e['title'],
          category: e['category'],
          description: e['description'],
          fileName: e['fileName'],
          filePath: e['filePath'],
          url: e['url'],
          ownerId: e['ownerId'],
          createdAt: DateTime.tryParse(e['createdAt'] ?? '') ?? DateTime.now(),
        ),
      ),
    );

    notifyListeners();
  }

  void updatePdf(PdfModel updated) {
    final index = pdfs.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      pdfs[index] = updated;
      if (!categories.contains(updated.category)) {
        categories.add(updated.category);
      }
      notifyListeners();
    }
  }

  void deletePdf(String id) {
    pdfs.removeWhere((p) => p.id == id);
    for (final entry in bookmarksByUser.values) {
      entry.remove(id);
    }
    notifyListeners();
  }

  void addCategory(String name) {
    final value = name.trim();
    if (value.isNotEmpty && !categories.contains(value)) {
      categories.add(value);
      notifyListeners();
    }
  }

  void renameCategory(String oldName, String newName) {
    final value = newName.trim();
    if (value.isEmpty) return;

    final index = categories.indexOf(oldName);
    if (index != -1) {
      categories[index] = value;
      for (var i = 0; i < pdfs.length; i++) {
        if (pdfs[i].category == oldName) {
          pdfs[i] = pdfs[i].copyWith(category: value);
        }
      }
      notifyListeners();
    }
  }

  void deleteCategory(String name) {
    categories.remove(name);
    for (var i = 0; i < pdfs.length; i++) {
      if (pdfs[i].category == name) {
        pdfs[i] = pdfs[i].copyWith(category: 'General');
      }
    }
    if (!categories.contains('General')) {
      categories.add('General');
    }
    notifyListeners();
  }

  void addUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) {
    users.add(
      AppUser(
        id: _newId('user'),
        name: name.trim(),
        email: email.trim().toLowerCase(),
        password: password,
        role: role,
      ),
    );
    notifyListeners();
  }

  void updateUser(AppUser updated) {
    final index = users.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      users[index] = updated;
      notifyListeners();
    }
  }

  void deleteUser(String id) {
    if (currentUser?.id == id) return;
    users.removeWhere((u) => u.id == id);
    bookmarksByUser.remove(id);
    pdfs.removeWhere((p) => p.ownerId == id);
    notifyListeners();
  }
}