import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'pdf_model.dart';
import 'pdf_viewer_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final  bool useOnlineBackend = true;

  late final String baseUrl = useOnlineBackend
      ? "https://pdf-viewer-app-4.onrender.com"
      : "http://192.168.29.74:5000";

final Set<String> bookmarkedIds = {};
late Future<List<PdfModel>> pdfFuture;

  final store = AppStore.instance;
Future<void> uploadPdf({
  required Uint8List bytes,
  required String fileName,
  required String title,
  required String category,
  required String description,
}) async {
  try {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/api/upload-pdf"),
    );

    request.fields["title"] = title;
    request.fields["category"] = category;
    request.fields["description"] = description;
    request.fields["ownerId"] = store.currentUser?.id ?? "user-1";

    request.files.add(
      http.MultipartFile.fromBytes(
        "pdf",
        bytes,
        filename: fileName,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    debugPrint("UPLOAD STATUS: ${response.statusCode}");
    debugPrint("UPLOAD BODY: $responseBody");

    if (response.statusCode == 200 || response.statusCode == 201) {
      clearPdfForm();

      setState(() {
        selectedMenu = tr("Dashboard", "डैशबोर्ड");
        pdfFuture = fetchPdfsFromDatabase();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF uploaded successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $responseBody")),
      );
    }
  } catch (e) {
    debugPrint("UPLOAD ERROR: $e");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Upload error: $e")),
    );
  }
}

Future<List<PdfModel>> fetchPdfsFromDatabase() async {
  try {
    final response = await http.get(
      Uri.parse(
        "https://pdf-viewer-app.onrender.com/api/pdfs/${store.currentUser?.id ?? ""}",
      ),
    )
    .timeout(const Duration(seconds: 10),
    );

    print(response.body);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      return data.map((e) => PdfModel.fromJson(e)).toList();
    } else {
      return [];
    }
  } catch (e) {
    print("Fetch Error: $e");
    return [];
  }
}
Future<void> pickPdf() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true,
  );

  if (result != null && result.files.single.bytes != null) {
    final file = result.files.single;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          title: file.name,
          bytes: file.bytes,
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PDF file data not found")),
    );
  }
}
Future<void> deletePdf(String id) async {
  try {
    final response = await http.delete(
      Uri.parse("$baseUrl/api/pdfs/$id"),
    );

    if (response.statusCode == 200) {

      setState(() {
        pdfFuture = fetchPdfsFromDatabase();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PDF deleted successfully"),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$e")),
    );
  }
}
Widget buildCreativeHeader(double width) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [
          Color(0xff7C3AED),
          Color(0xff2563EB),
          Color(0xff06B6D4),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.deepPurple.withOpacity(.35),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome Back 👋",
                style: GoogleFonts.poppins(
                  fontSize: width > 700 ? 28 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Manage, read, upload and organize your PDFs beautifully.",
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  // upload dialog call here
                },
                icon: const Icon(Icons.upload_file),
                label: const Text("Upload PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (width > 600)
          const Icon(
            Icons.picture_as_pdf,
            size: 95,
            color: Colors.white,
          ),
      ],
    ),
  ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2);
}

  String selectedMenu = "Dashboard";
  final searchController = TextEditingController();

  final pdfTitleController = TextEditingController();
  final pdfCategoryController = TextEditingController();
  final pdfDescriptionController = TextEditingController();
  final pdfUrlController = TextEditingController();

  final categoryController = TextEditingController();
  final userNameController = TextEditingController();
  final userEmailController = TextEditingController();
  final userPasswordController = TextEditingController();

  PlatformFile? selectedPdfFile;
  String selectedPdfFileName = "";

  String? editingPdfId;
  AppUser? editingUser;
  UserRole selectedUserRole = UserRole.user;

  bool get isAdmin => store.currentUser?.role == UserRole.admin;

  String tr(String english, String hindi) {
    return store.language == AppLanguage.hindi ? hindi : english;
  }

  Uint8List? _toUint8List(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    return Uint8List.fromList(bytes);
  }

  Uint8List? _pdfBytes(PdfModel pdf) {
    if (pdf.filePath != null && pdf.filePath!.isNotEmpty) {
      final file = File(pdf.filePath!);
      if (file.existsSync()) {
        return file.readAsBytesSync();
      }
    }
    return _toUint8List(pdf.bytes);
  }

  void _resetLocalState() {
    setState(() {
      selectedMenu = tr("Dashboard", "डैशबोर्ड");
      searchController.clear();

      pdfTitleController.clear();
      pdfCategoryController.clear();
      pdfDescriptionController.clear();
      pdfUrlController.clear();

      categoryController.clear();
      userNameController.clear();
      userEmailController.clear();
      userPasswordController.clear();

      selectedPdfFile = null;
      selectedPdfFileName = "";
      editingPdfId = null;
      editingUser = null;
      selectedUserRole = UserRole.user;
    });
  }

List<PdfModel> get filteredPdfs {

  final query = searchController.text
      .trim()
      .toLowerCase();

  List<PdfModel> source = store.currentUserPdfs;

  // ✅ Bookmarks source
  if (selectedMenu == tr("Bookmarks", "बुकमार्क")) {
    source = store.currentUserPdfs
        .where((pdf) => pdf.isBookmarked)
        .toList();
  }

  if (query.isEmpty) return source;

  return source.where((pdf) {

    return pdf.title
        .toLowerCase()
        .contains(query) ||

        pdf.category
            .toLowerCase()
            .contains(query) ||

        pdf.description
            .toLowerCase()
            .contains(query);

  }).toList();
}

  @override
  void initState() {
    super.initState();
    pdfFuture = fetchPdfsFromDatabase();
    store.addListener(_onStoreChanged);
    searchController.addListener(() {
      setState(() {});
    });
  }
void refreshPdfs() {
  setState(() {
    pdfFuture = fetchPdfsFromDatabase();
  });
}

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    searchController.dispose();
    pdfTitleController.dispose();
    pdfCategoryController.dispose();
    pdfDescriptionController.dispose();
    pdfUrlController.dispose();
    categoryController.dispose();
    userNameController.dispose();
    userEmailController.dispose();
    userPasswordController.dispose();
    super.dispose();
  }

  Future<void> pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // ✅ MOST IMPORTANT
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      if (file.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF bytes not loaded")),
        );
        return;
      }

      setState(() {
        selectedPdfFile = file;
        selectedPdfFileName = file.name;
      });
    }
  }

  void clearPdfForm() {
    pdfTitleController.clear();
    pdfCategoryController.clear();
    pdfDescriptionController.clear();
    pdfUrlController.clear();
    selectedPdfFile = null;
    selectedPdfFileName = "";
    editingPdfId = null;
  }
Future<void> savePdf() async {
  debugPrint("SAVE PDF CLICKED");

  final title = pdfTitleController.text.trim();
  final category = pdfCategoryController.text.trim();
  final description = pdfDescriptionController.text.trim();

  if (title.isEmpty || category.isEmpty || description.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill all fields")),
    );
    return;
  }

  if (selectedPdfFile == null || selectedPdfFile!.bytes == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select PDF file")),
    );
    return;
  }

  await uploadPdf(
    bytes: selectedPdfFile!.bytes!,
    fileName: selectedPdfFile!.name,
    title: title,
    category: category,
    description: description,
  );


  clearPdfForm();

  setState(() {
    selectedMenu = tr("Dashboard", "डैशबोर्ड");
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("PDF uploaded successfully")),
  );
}


  void editPdf(PdfModel pdf) {
    setState(() {
      editingPdfId = pdf.id;
      pdfTitleController.text = pdf.title;
      pdfCategoryController.text = pdf.category;
      pdfDescriptionController.text = pdf.description;
      pdfUrlController.text = pdf.url ?? '';
      selectedPdfFile = null;
      selectedPdfFileName = pdf.fileName;
      selectedMenu = tr("Upload PDF", "पीडीएफ अपलोड");
    });
  }

Future<void> downloadPdf(PdfModel pdf) async {
  try {
    // ✅ Local PDF bytes
    final bytes = _pdfBytes(pdf);

    if (bytes != null && bytes.isNotEmpty) {
      final dir = await getApplicationDocumentsDirectory();

      final fileName = pdf.fileName.toLowerCase().endsWith(".pdf")
          ? pdf.fileName
          : "${pdf.fileName}.pdf";

      final file = File("${dir.path}/$fileName");

      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
      return;
    }

    // ✅ Database PDF URL
    if (pdf.url != null && pdf.url!.isNotEmpty) {
      await OpenFilex.open(pdf.url!);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PDF file data not found")),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Download failed: $e")),
    );
  }
}
Future<void> sharePdf(PdfModel pdf) async {
  try {
    Uint8List? bytes = _pdfBytes(pdf);

    if ((bytes == null || bytes.isEmpty) &&
        pdf.url != null &&
        pdf.url!.trim().isNotEmpty) {
      final response = await http.get(Uri.parse(pdf.url!.trim()));

      if (response.statusCode == 200) {
        bytes = response.bodyBytes;
      }
    }

    if (bytes != null && bytes.isNotEmpty) {
      final dir = await getApplicationDocumentsDirectory();

      final fileName = pdf.fileName.toLowerCase().endsWith(".pdf")
          ? pdf.fileName
          : "${pdf.fileName}.pdf";

      final file = File("${dir.path}/$fileName");

      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: "application/pdf")],
        text: pdf.url != null && pdf.url!.trim().isNotEmpty
            ? "${pdf.title}\n${pdf.url}"
            : pdf.title,
      );
      return;
    }

    if (pdf.url != null && pdf.url!.trim().isNotEmpty) {
      await Share.share(
        pdf.url!.trim(),
        subject: pdf.title,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PDF file data not found")),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Share failed: $e")),
    );
  }
}
Future<void> convertPdfToWord(PdfModel pdf) async {
  try {
    Uint8List? bytes;

    if (pdf.bytes != null && pdf.bytes!.isNotEmpty) {
      bytes = Uint8List.fromList(pdf.bytes!);
    } else if (pdf.url != null && pdf.url!.trim().isNotEmpty) {
      final pdfResponse = await http.get(Uri.parse(pdf.url!.trim()));

      if (pdfResponse.statusCode == 200) {
        bytes = pdfResponse.bodyBytes;
      }
    }

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF file data not found")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Converting PDF to Word...")),
    );

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/convert-pdf-to-word"),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        "pdf",
        bytes,
        filename: pdf.fileName,
      ),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final wordBytes = await response.stream.toBytes();

      final dir = await getApplicationDocumentsDirectory();

      final safeName = pdf.fileName
          .replaceAll(".pdf", "")
          .replaceAll(".PDF", "")
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");

      final file = File("${dir.path}/$safeName.docx");

      await file.writeAsBytes(wordBytes);
      await OpenFilex.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Word file created successfully")),
      );
    } else {
      final error = await response.stream.bytesToString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Conversion failed: $error")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Conversion error: $e")),
    );
  }
}
Future<void> convertPdfFromPdf({
  required PdfModel pdf,
  required String endpoint,
  required String outputExt,
  required String successText,
}) async {
  try {
    Uint8List? bytes = _pdfBytes(pdf);

    if ((bytes == null || bytes.isEmpty) &&
        pdf.url != null &&
        pdf.url!.trim().isNotEmpty) {
      final res = await http.get(Uri.parse(pdf.url!.trim()));
      if (res.statusCode == 200) bytes = res.bodyBytes;
    }

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF file data not found")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Converting $successText...")),
    );

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/$endpoint"),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        "pdf",
        bytes,
        filename: pdf.fileName,
      ),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final outBytes = await response.stream.toBytes();

      final dir = await getApplicationDocumentsDirectory();

      final safeName = pdf.fileName
          .replaceAll(".pdf", "")
          .replaceAll(".PDF", "")
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");

      final file = File("${dir.path}/$safeName.$outputExt");

      await file.writeAsBytes(outBytes, flush: true);
      await OpenFilex.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$successText created successfully")),
      );
    } else {
      final error = await response.stream.bytesToString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Conversion failed: $error")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Conversion error: $e")),
    );
  }
}

Future<void> pickPdfForConvertFromPdf(
    String endpoint,
    String ext,
    String name,
    ) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true,
  );

  if (result == null || result.files.single.bytes == null) return;

  final file = result.files.single;

  final tempPdf = PdfModel(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    title: file.name,
    category: "Convert from PDF",
    description: name,
    fileName: file.name,
    bytes: file.bytes,
    ownerId: store.currentUser?.id ?? "user-1",
    createdAt: DateTime.now(),
  );

  await convertPdfFromPdf(
    pdf: tempPdf,
    endpoint: endpoint,
    outputExt: ext,
    successText: name,
  );
}

  void addCategory() {
    final name = categoryController.text.trim();
    if (name.isEmpty) return;

    store.addCategory(name);
    categoryController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr("Category added", "कैटेगरी जोड़ दी गई"))),
    );
  }

  void _showEditCategoryDialog(String oldCategory) {
    final editController = TextEditingController(text: oldCategory);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr("Edit Category", "कैटेगरी एडिट")),
          content: TextField(
            controller: editController,
            decoration: InputDecoration(
              labelText: tr("Category Name", "कैटेगरी नाम"),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr("Cancel", "रद्द करें")),
            ),
            FilledButton(
              onPressed: () {
                final newName = editController.text.trim();

                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr(
                          "Category name cannot be empty",
                          "कैटेगरी नाम खाली नहीं हो सकता",
                        ),
                      ),
                    ),
                  );
                  return;
                }

                store.renameCategory(oldCategory, newName);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tr("Category updated", "कैटेगरी अपडेट हो गई"),
                    ),
                  ),
                );
              },
              child: Text(tr("Update", "अपडेट")),
            ),
          ],
        );
      },
    );
  }

  void addOrUpdateUser() {
    final name = userNameController.text.trim();
    final email = userEmailController.text.trim().toLowerCase();
    final password = userPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr("Fill all user fields", "सभी यूज़र फील्ड भरें"))),
      );
      return;
    }

    if (editingUser == null) {
      store.addUser(
        name: name,
        email: email,
        password: password,
        role: selectedUserRole,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("User added", "यूज़र जोड़ दिया गया"))),
      );
    } else {
      store.updateUser(
        editingUser!.copyWith(
          name: name,
          email: email,
          password: password,
          role: selectedUserRole,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("User updated", "यूज़र अपडेट हो गया"))),
      );
    }

    userNameController.clear();
    userEmailController.clear();
    userPasswordController.clear();
    selectedUserRole = UserRole.user;
    editingUser = null;
    setState(() {});
  }

  Widget _buildSidebarHeader() {
    final user = store.currentUser;
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return DrawerHeader(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isAdmin ? Colors.deepPurple : Colors.indigo,
            child: Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.picture_as_pdf,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAdmin
                ? tr("Admin Panel", "एडमिन पैनल")
                : tr("PDF Viewer", "पीडीएफ व्यूअर"),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.grey.shade700,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

Widget _sideItem({
  required IconData icon,
  required String title,
  required bool closeDrawer,
}) {
  final isSelected = selectedMenu == title;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      tileColor: isSelected ? Colors.deepPurple.withOpacity(0.20) : Colors.transparent,
      leading: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.white70,
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
      onTap: () {
        setState(() {
          selectedMenu = title;
        });

        if (closeDrawer && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    ),
  );
}

Widget _buildSidebar({required bool closeDrawer}) {
  final items = [
    (tr("Dashboard", "डैशबोर्ड"), Icons.dashboard),
    (tr("Organize PDF", "पीडीएफ व्यवस्थित करें"), Icons.folder_copy_rounded),
    (tr("Convert to PDF", "पीडीएफ कन्वर्ट"),
    Icons.picture_as_pdf_rounded),
    (tr("Convert from PDF", "पीडीएफ से कन्वर्ट"),
    Icons.transform_rounded),
    (tr("Upload PDF", "पीडीएफ अपलोड"), Icons.upload_file),
    (tr("Edit PDF", "पीडीएफ एडिट"), Icons.edit),
    (tr("Delete PDF", "पीडीएफ डिलीट"), Icons.delete),
    (tr("Bookmarks", "बुकमार्क"), Icons.bookmark),
    (tr("Categories", "कैटेगरी"), Icons.category),
    (tr("Users", "यूज़र्स"), Icons.people),
    (tr("Settings", "सेटिंग्स"), Icons.settings),
  ];

  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.deepPurple.withOpacity(.25),
          Colors.black.withOpacity(.12),
        ],
      ),
    ),
    child: Column(
      children: [
        _buildSidebarHeader(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ...items.map(
                    (e) => _sideItem(
                  icon: e.$2,
                  title: e.$1,
                  closeDrawer: closeDrawer,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    tr("Logout", "लॉगआउट"),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    _resetLocalState();
                    store.logout();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                          (route) => false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.indigo.withOpacity(0.1),
              child: Icon(icon, color: Colors.indigo),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfCard(PdfModel pdf, double width) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              title: pdf.title,
              bytes: _pdfBytes(pdf),
              url: pdf.url,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(.10),
              Colors.white.withOpacity(.04),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.25),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.redAccent,
                          size: 36,
                        ),
                      ),
                      const Spacer(),

                      IconButton(
                        icon: Icon(
                          bookmarkedIds.contains(pdf.id)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: bookmarkedIds.contains(pdf.id)
                              ? Colors.amber
                              : Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            if (bookmarkedIds.contains(pdf.id)) {
                              bookmarkedIds.remove(pdf.id);
                            } else {
                              bookmarkedIds.add(pdf.id);
                            }
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                bookmarkedIds.contains(pdf.id)
                                    ? "Bookmark added"
                                    : "Bookmark removed",
                              ),
                            ),
                          );
                        },
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Colors.lightBlueAccent,
                        ),
                        onPressed: () {
                          sharePdf(pdf);
                        },
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          await deletePdf(pdf.id);

                          setState(() {
                            pdfFuture = fetchPdfsFromDatabase();
                          });
                        },
                      ),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    pdf.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: width > 700 ? 20 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    pdf.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.65),
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(.22),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(.08),
                            ),
                          ),
                          child: Text(
                            pdf.category,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff6D5DF6),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PdfViewerScreen(
                                        title: pdf.title,
                                        bytes: _pdfBytes(pdf),
                                        url: pdf.url,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  "Open",
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff16A34A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: () {
                                  convertPdfToWord(pdf);
                                },
                                icon: const Icon(
                                  Icons.article_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  "Word",
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: .15);
  }
  Widget _buildPdfGrid(double width, List<PdfModel> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(tr("No PDFs found", "कोई पीडीएफ नहीं मिली")),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width >= 1200
            ? 4
            : width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: width >= 700 ? 1.1 : 1.0,
      ),
      itemBuilder: (_, index) => _buildPdfCard(items[index], width),
    );
  }

  Widget _buildDashboard(double width) {
    final categoriesCount = store.categories.length;
    final pdfCount = store.currentUserPdfs.length;
    final userCount = store.users
        .where((u) => u.role == UserRole.user)
        .length;

    return ListView(
      padding: EdgeInsets.all(width > 700 ? 20 : 12),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xff8B5CF6),
                Color(0xff3B82F6),
                Color(0xff06B6D4),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(.35),
                blurRadius: 35,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -35,
                top: -35,
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 100,
                  color: Colors.white.withOpacity(.10),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, ${store.currentUser?.name ?? 'User'} 👋",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: width > 700 ? 28 : 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Manage your PDFs smartly, securely and beautifully.",
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(.85),
                      fontSize: width > 700 ? 17 : 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      cursorColor: Colors.deepPurple,
                      cursorWidth: 2,

                      style: GoogleFonts.poppins(
                        color: Colors.white,                     fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: tr("Search PDFs...", "पीडीएफ खोजें..."),
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.deepPurple.shade300,
                          size: 30,
                        ),
                        border: InputBorder.none,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.15),
        const SizedBox(height: 18),
        if (isAdmin)
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  tr("Total PDFs", "कुल पीडीएफ"),
                  pdfCount.toString(),
                  Icons.picture_as_pdf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  tr("Categories", "कैटेगरी"),
                  categoriesCount.toString(),
                  Icons.category,
                ),
              ),
            ],
          ),
        if (isAdmin) const SizedBox(height: 12),
        if (isAdmin)
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  tr("Users", "यूज़र्स"),
                  userCount.toString(),
                  Icons.people,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  tr("Bookmarks", "बुकमार्क"),
                  store.currentUserPdfs
                      .where((pdf) => pdf.isBookmarked)
                      .length
                      .toString(),
                  Icons.bookmark,
                ),
              ),
            ],
          ),
        FutureBuilder<List<PdfModel>>(
          future: pdfFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error: ${snapshot.error}",
                ),
              );
            }

            final pdfs = snapshot.data ?? [];
            final query = searchController.text.trim().toLowerCase();

            final filteredPdfs = query.isEmpty
                ? pdfs
                : pdfs.where((pdf) {
              return pdf.title.toLowerCase().contains(query) ||
                  pdf.category.toLowerCase().contains(query) ||
                  pdf.description.toLowerCase().contains(query);
            }).toList();

            final totalPdfCount = filteredPdfs.length;
            final bookmarkCount =
                pdfs.where((pdf) => bookmarkedIds.contains(pdf.id)).length;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        tr("Total PDFs", "कुल पीडीएफ"),
                        totalPdfCount.toString(),
                        Icons.picture_as_pdf,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        tr("Bookmarks", "बुकमार्क"),
                        bookmarkCount.toString(),
                        Icons.bookmark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                pdfs.isEmpty
                    ? const Center(child: Text("No PDFs found"))
                    : _buildPdfGrid(width, filteredPdfs),
              ],
            );
          },
        ),
      ],
    );
  }





Widget buildCreativeStatCard({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return GlassmorphicContainer(
    width: double.infinity,
    height: 150.0,
    borderRadius: 26,
    blur: 20,
    border: 1,
    linearGradient: LinearGradient(
      colors: [
        color.withOpacity(.25),
        Colors.white.withOpacity(.06),
      ],
    ),
    borderGradient: LinearGradient(
      colors: [
        Colors.white.withOpacity(.35),
        Colors.white.withOpacity(.08),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 38),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title),
        ],
      ),
    ),
  ).animate().fadeIn().scale();
}




Widget _buildBookmarksPage(double width) {

  return FutureBuilder<List<PdfModel>>(
    future: fetchPdfsFromDatabase(),

    builder: (context, snapshot) {

      if (snapshot.connectionState ==
          ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      final allPdfs = snapshot.data ?? [];

      final bookmarkedPdfs = allPdfs
          .where(
            (pdf) => bookmarkedIds.contains(pdf.id),
      ).toList();

      return ListView(
        padding: EdgeInsets.all(
          width > 700 ? 20 : 12,
        ),

        children: [

          Text(
            tr("Bookmarks", "बुकमार्क"),
            style: TextStyle(
              fontSize: width > 700 ? 28 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            "${bookmarkedPdfs.length} Bookmarks",
          ),

          const SizedBox(height: 18),

          bookmarkedPdfs.isEmpty
              ? const Center(
            child: Text(
              "No bookmarked PDFs",
            ),
          )
              : _buildPdfGrid(
            width,
            bookmarkedPdfs,
          ),
        ],
      );
    },
  );
}

  Widget _buildUploadPdfPage(double width) {
    final saveButton = FilledButton.icon(
      onPressed: savePdf,
      icon: const Icon(Icons.upload_file),
      label: Text(
        editingPdfId == null
            ? tr("Save PDF", "पीडीएफ सेव करें")
            : tr("Update PDF", "पीडीएफ अपडेट करें"),
      ),
    );

    final clearButton = OutlinedButton(
      onPressed: clearPdfForm,
      child: Text(tr("Clear", "क्लियर")),
    );

    return ListView(
      padding: EdgeInsets.all(width > 700 ? 20 : 12),
      children: [
        Text(
          editingPdfId == null ? tr("Upload PDF", "पीडीएफ अपलोड") : tr(
              "Edit PDF", "पीडीएफ एडिट"),
          style: TextStyle(
            fontSize: width > 700 ? 28 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: EdgeInsets.all(width > 700 ? 24 : 16),
            child: Column(
              children: [
                TextField(
                  controller: pdfTitleController,
                  decoration: InputDecoration(
                    labelText: tr("PDF Title", "पीडीएफ शीर्षक"),
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pdfCategoryController,
                  decoration: InputDecoration(
                    labelText: tr("Category", "कैटेगरी"),
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pdfDescriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: tr("Description", "विवरण"),
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pdfUrlController,
                  decoration: InputDecoration(
                    labelText: tr(
                        "PDF URL (optional)", "पीडीएफ यूआरएल (वैकल्पिक)"),
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                _buildPickerBox(
                  title: tr("Upload PDF File", "पीडीएफ फाइल अपलोड"),
                  fileName: selectedPdfFileName,
                  emptyText: tr("No PDF selected", "कोई पीडीएफ चयनित नहीं"),
                  icon: Icons.picture_as_pdf,
                  onTap: pickPdfFile,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 420) {
                      return Column(
                        children: [
                          SizedBox(width: double.infinity, child: saveButton),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: clearButton),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: saveButton),
                        const SizedBox(width: 12),
                        Expanded(child: clearButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

Widget _buildEditPdfsPage(double width) {
  return FutureBuilder<List<PdfModel>>(
    future: fetchPdfsFromDatabase(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final pdfs = snapshot.data ?? [];

      return ListView(
        padding: EdgeInsets.all(width > 700 ? 20 : 12),
        children: [
          Text(
            tr("Edit PDF", "पीडीएफ एडिट"),
            style: TextStyle(
              fontSize: width > 700 ? 28 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),
          _editPdfToolsBar(),
          if (pdfs.isEmpty)
            const Center(child: Text("No PDFs found"))
          else
            ...pdfs.map(
                  (pdf) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.picture_as_pdf),
                  ),
                  title: Text(pdf.title),
                  subtitle: Text('${pdf.category}\n${pdf.description}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      editPdf(pdf);
                    },
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

Widget _buildDeletePdfsPage(double width) {
  return FutureBuilder<List<PdfModel>>(
    future: fetchPdfsFromDatabase(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final pdfs = snapshot.data ?? [];

      return ListView(
        padding: EdgeInsets.all(width > 700 ? 20 : 12),
        children: [
          Text(
            tr("Delete PDF", "पीडीएफ डिलीट"),
            style: TextStyle(
              fontSize: width > 700 ? 28 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          if (pdfs.isEmpty)
            const Center(child: Text("No PDFs found"))
          else
            ...pdfs.map(
                  (pdf) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.picture_as_pdf),
                  ),
                  title: Text(pdf.title),
                  subtitle: Text('${pdf.category}\n${pdf.description}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(tr("Delete PDF", "पीडीएफ डिलीट")),
                          content: Text(
                            "${tr("Delete", "डिलीट")} '${pdf.title}'?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(tr("Cancel", "रद्द करें")),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                await deletePdf(pdf.id);
                                Navigator.pop(context);
                                setState(() {});
                              },
                              child: Text(tr("Delete", "डिलीट")),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

  Widget _buildCategoriesPage(double width) {
    final addButton = FilledButton(
      onPressed: addCategory,
      child: Text(tr("Add", "जोड़ें")),
    );

    final clearButton = OutlinedButton(
      onPressed: () {
        categoryController.clear();
      },
      child: Text(tr("Clear", "क्लियर")),
    );

    return ListView(
      padding: EdgeInsets.all(width > 700 ? 20 : 12),
      children: [
        Text(
          tr("Categories", "कैटेगरी"),
          style: TextStyle(
            fontSize: width > 700 ? 28 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: tr("New Category", "नई कैटेगरी"),
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 420) {
                      return Column(
                        children: [
                          SizedBox(width: double.infinity, child: addButton),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: clearButton),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: addButton),
                        const SizedBox(width: 12),
                        Expanded(child: clearButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...store.categories.map(
              (category) =>
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.category),
                  ),
                  title: Text(category),
                  subtitle: Text(
                    '${store.currentUserPdfs
                        .where((p) => p.category == category)
                        .length} ${tr("PDFs", "पीडीएफ")}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        onPressed: () => _showEditCategoryDialog(category),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        onPressed: category == 'General'
                            ? null
                            : () => store.deleteCategory(category),
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildUsersPage(double width) {
    final saveButton = FilledButton(
      onPressed: addOrUpdateUser,
      child: Text(
        editingUser == null ? tr("Add User", "यूज़र जोड़ें") : tr(
            "Update User", "यूज़र अपडेट करें"),
      ),
    );

    final clearButton = OutlinedButton(
      onPressed: () {
        setState(() {
          editingUser = null;
          selectedUserRole = UserRole.user;
          userNameController.clear();
          userEmailController.clear();
          userPasswordController.clear();
        });
      },
      child: Text(tr("Clear", "क्लियर")),
    );

    return ListView(
      padding: EdgeInsets.all(width > 700 ? 20 : 12),
      children: [
        Text(
          tr("Users", "यूज़र्स"),
          style: TextStyle(
            fontSize: width > 700 ? 28 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                TextField(
                  controller: userNameController,
                  decoration: InputDecoration(
                    labelText: tr("Name", "नाम"),
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userEmailController,
                  decoration: InputDecoration(
                    labelText: tr("Email", "ईमेल"),
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userPasswordController,
                  decoration: InputDecoration(
                    labelText: tr("Password", "पासवर्ड"),
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  value: selectedUserRole,
                  decoration: InputDecoration(
                    labelText: tr("Role", "रोल"),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: UserRole.user,
                      child: Text(tr("User", "यूज़र")),
                    ),
                    DropdownMenuItem(
                      value: UserRole.admin,
                      child: Text(tr("Admin", "एडमिन")),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedUserRole = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 420) {
                      return Column(
                        children: [
                          SizedBox(width: double.infinity, child: saveButton),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: clearButton),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: saveButton),
                        const SizedBox(width: 12),
                        Expanded(child: clearButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...store.users.map(
              (user) =>
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      user.role == UserRole.admin
                          ? Icons.admin_panel_settings
                          : Icons.person,
                    ),
                  ),
                  title: Text(user.name),
                  subtitle: Text(
                      '${user.email}\n${user.role.name.toUpperCase()}'),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            editingUser = user;
                            userNameController.text = user.name;
                            userEmailController.text = user.email;
                            userPasswordController.text = user.password;
                            selectedUserRole = user.role;
                          });
                        },
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        onPressed: () async {
                          store.deleteUser(user.id);
                        },
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    String languageText(AppLanguage lang) {
      switch (lang) {
        case AppLanguage.english:
          return "English";
        case AppLanguage.hindi:
          return "Hindi";
      }
    }

    String themeText(AppThemeMode mode) {
      switch (mode) {
        case AppThemeMode.system:
          return tr("System", "सिस्टम");
        case AppThemeMode.light:
          return tr("Light", "लाइट");
        case AppThemeMode.dark:
          return tr("Dark", "डार्क");
      }
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        child: Icon(Icons.settings, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr("Settings", "सेटिंग्स"),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr("Theme", "थीम"),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<AppThemeMode>(
                    value: store.themeMode,
                    decoration: InputDecoration(
                      labelText: tr("Choose Theme", "थीम चुनें"),
                      prefixIcon: const Icon(Icons.palette_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: AppThemeMode.values.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(themeText(mode)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        store.updateTheme(value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr("Language", "भाषा"),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<AppLanguage>(
                    value: store.language,
                    decoration: InputDecoration(
                      labelText: tr("Choose Language", "भाषा चुनें"),
                      prefixIcon: const Icon(Icons.language_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: AppLanguage.values.map((lang) {
                      return DropdownMenuItem(
                        value: lang,
                        child: Text(languageText(lang)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        store.updateLanguage(value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: Theme
                        .of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr("Current Settings", "वर्तमान सेटिंग्स"),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text("${tr("Theme", "थीम")}: ${themeText(
                              store.themeMode)}"),
                          Text("${tr("Language", "भाषा")}: ${languageText(
                              store.language)}"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerBox({
    required String title,
    required String fileName,
    required String emptyText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName.isEmpty ? emptyText : fileName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(tr("Choose", "चुनें")),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double width) {
    switch (selectedMenu) {
      case "Dashboard":
      case "डैशबोर्ड":
        return _buildDashboard(width);

      case "Bookmarks":
      case "बुकमार्क":
        return _buildBookmarksPage(width);
      case "Upload PDF":
      case "पीडीएफ अपलोड":
        return _buildUploadPdfPage(width);
      case "Edit PDF":
      case "पीडीएफ एडिट":
        return _buildEditPdfsPage(width);
      case "Delete PDF":
      case "पीडीएफ डिलीट":
        return _buildDeletePdfsPage(width);
      case "Categories":
      case "कैटेगरी":
        return _buildCategoriesPage(width);
      case "Users":
      case "यूज़र्स":
        return _buildUsersPage(width);
      case "Organize PDF":
      case "पीडीएफ व्यवस्थित करें":
        return _buildOrganizePdfPage(width);
      case "Convert to PDF":
      case "पीडीएफ कन्वर्ट":
        return _buildConvertPdfPage(width);
      case "Convert from PDF":
      case "पीडीएफ से कन्वर्ट":
        return _buildConvertFromPdfPage(width);
      case "Settings":
      case "सेटिंग्स":
        return _buildSettingsPage();
      default:
        return _buildDashboard(width);
    }
  }

  Widget _buildDesktopLayout(double width) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 270,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.indigo.shade50,
          child: _buildSidebar(closeDrawer: false),
        ),
        Expanded(child: _buildBody(width)),
      ],
    );
  }

Widget _buildOrganizePdfPage(double width) {
  final isWide = width > 700;

  return ListView(
    padding: EdgeInsets.all(isWide ? 24 : 14),
    children: [
      Text(
        tr("Organize PDF", "पीडीएफ व्यवस्थित करें"),
        style: GoogleFonts.poppins(
          fontSize: isWide ? 30 : 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        "Merge PDF, Split PDF and Scan images into PDF.",
        style: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 22),

      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isWide ? 3 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isWide ? 1.15 : 2.45,
        children: [
          _organizeCard(
            title: "Merge PDF",
            subtitle: "Combine multiple PDFs into one file",
            icon: Icons.merge_type_rounded,
            color: Colors.deepPurple,
            onTap: mergePdfFiles,
          ),
          _organizeCard(
            title: "Split PDF",
            subtitle: "Split each page into separate PDF",
            icon: Icons.call_split_rounded,
            color: Colors.orange,
            onTap: splitPdfFile,
          ),
          _organizeCard(
            title: "Scan to PDF",
            subtitle: "Convert camera/gallery images to PDF",
            icon: Icons.document_scanner_rounded,
            color: Colors.green,
            onTap: scanToPdf,
          ),
        ],
      ),

    ],
  );
}
Widget _buildConvertPdfPage(double width) {
  final isWide = width > 700;

  return ListView(
    padding: EdgeInsets.all(isWide ? 24 : 14),
    children: [
      Text(
        "Convert to PDF",
        style: GoogleFonts.poppins(
          fontSize: isWide ? 30 : 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      const SizedBox(height: 10),

      Text(
        "Convert JPG, Word, PowerPoint and Excel into PDF.",
        style: GoogleFonts.poppins(
          color: Colors.white70,
        ),
      ),

      const SizedBox(height: 24),

      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isWide ? 2 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isWide ? 2.2 : 2.6,
        children: [

          _organizeCard(
            title: "JPG to PDF",
            subtitle: "Convert images into PDF",
            icon: Icons.image_rounded,
            color: Colors.amber,
            onTap: scanToPdf,
          ),

          _organizeCard(
            title: "Word to PDF",
            subtitle: "Convert DOC/DOCX into PDF",
            icon: Icons.article_rounded,
            color: Colors.blue,
            onTap: wordToPdf,
          ),

          _organizeCard(
            title: "PowerPoint to PDF",
            subtitle: "Convert PPT/PPTX into PDF",
            icon: Icons.slideshow_rounded,
            color: Colors.deepOrange,
            onTap: powerPointToPdf,
          ),

          _organizeCard(
            title: "Excel to PDF",
            subtitle: "Convert XLS/XLSX into PDF",
            icon: Icons.table_chart_rounded,
            color: Colors.green,
            onTap: excelToPdf,
          ),
        ],
      ),
    ],
  );
}
Widget _buildConvertFromPdfPage(double width) {
  final isWide = width > 700;

  return ListView(
    padding: EdgeInsets.all(isWide ? 24 : 14),
    children: [
      Text(
        "Convert from PDF",
        style: GoogleFonts.poppins(
          fontSize: isWide ? 30 : 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        "Convert PDF into JPG, Word, PowerPoint and Excel.",
        style: GoogleFonts.poppins(color: Colors.white70),
      ),
      const SizedBox(height: 24),

      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isWide ? 2 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isWide ? 2.2 : 2.6,
        children: [
          _organizeCard(
            title: "PDF to JPG",
            subtitle: "Convert PDF pages into images",
            icon: Icons.image_rounded,
            color: Colors.amber,
            onTap: () => pickPdfForConvertFromPdf(
              "pdf-to-jpg",
              "zip",
              "JPG ZIP",
            ),
          ),
          _organizeCard(
            title: "PDF to Word",
            subtitle: "Convert PDF into Word document",
            icon: Icons.article_rounded,
            color: Colors.blue,
            onTap: () => pickPdfForConvertFromPdf(
              "convert-pdf-to-word",
              "docx",
              "Word",
            ),
          ),
          _organizeCard(
            title: "PDF to PowerPoint",
            subtitle: "Convert PDF into PPT",
            icon: Icons.slideshow_rounded,
            color: Colors.deepOrange,
            onTap: () => pickPdfForConvertFromPdf(
              "pdf-to-ppt",
              "pptx",
              "PowerPoint",
            ),
          ),
          _organizeCard(
            title: "PDF to Excel",
            subtitle: "Convert PDF into Excel",
            icon: Icons.table_chart_rounded,
            color: Colors.green,
            onTap: () => pickPdfForConvertFromPdf(
              "pdf-to-excel",
              "xlsx",
              "Excel",
            ),
          ),
        ],
      ),
    ],
  );
}
  Widget _organizeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(.30),
              Colors.white.withOpacity(.05),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.25),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: .12);
  }

Future<void> mergePdfFiles() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least 2 PDFs")),
      );
      return;
    }

    final mergedDoc = sfpdf.PdfDocument();

    for (final file in result.files) {
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) continue;

      final sourceDoc = sfpdf.PdfDocument(inputBytes: bytes);

      for (int i = 0; i < sourceDoc.pages.count; i++) {
        final template = sourceDoc.pages[i].createTemplate();
        final page = mergedDoc.pages.add();
        page.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      sourceDoc.dispose();
    }

    final outputBytes = await mergedDoc.save();
    mergedDoc.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/merged_pdf.pdf");

    await file.writeAsBytes(outputBytes, flush: true);
    await uploadPdf(
      bytes: Uint8List.fromList(outputBytes),
      fileName: "merged_pdf.pdf",
      title: "Merged PDF",
      category: "Organized PDF",
      description: "PDF created by merge tool",
    );

    refreshPdfs();
    await OpenFilex.open(file.path);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PDFs merged successfully")),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Merge failed: $e")),
    );
  }
}

Future<void> splitPdfFile() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a PDF")),
      );
      return;
    }

    final sourceDoc = sfpdf.PdfDocument(
      inputBytes: result.files.single.bytes!,
    );

    final dir = await getApplicationDocumentsDirectory();

    for (int i = 0; i < sourceDoc.pages.count; i++) {
      final newDoc = sfpdf.PdfDocument();
      final template = sourceDoc.pages[i].createTemplate();
      final page = newDoc.pages.add();

      page.graphics.drawPdfTemplate(template, const Offset(0, 0));

      final bytes = await newDoc.save();
      newDoc.dispose();

      final file = File("${dir.path}/split_page_${i + 1}.pdf");
      await file.writeAsBytes(bytes, flush: true);
      await uploadPdf(
        bytes: Uint8List.fromList(bytes),
        fileName: "scanned_pdf.pdf",
        title: "Scanned PDF",
        category: "Organized PDF",
        description: "PDF created by scan tool",
      );

      refreshPdfs();
    }

    sourceDoc.dispose();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("PDF split successfully. Saved in ${dir.path}"),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Split failed: $e")),
    );
  }
}

Future<void> scanToPdf() async {
  try {
    final picker = ImagePicker();

    final images = await picker.pickMultiImage(
      imageQuality: 85,
    );

    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No images selected")),
      );
      return;
    }

    final document = sfpdf.PdfDocument();

    for (final image in images) {
      final imageBytes = await image.readAsBytes();

      final page = document.pages.add();
      final pageSize = page.getClientSize();

      final pdfImage = sfpdf.PdfBitmap(imageBytes);

      page.graphics.drawImage(
        pdfImage,
        Rect.fromLTWH(
          0,
          0,
          pageSize.width,
          pageSize.height,
        ),
      );
    }

    final bytes = await document.save();
    document.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/scanned_pdf.pdf");

    await file.writeAsBytes(bytes, flush: true);
    await uploadPdf(
      bytes: Uint8List.fromList(bytes),
      fileName: "scanned_pdf.pdf",
      title: "Scanned PDF",
      category: "Converted PDF",
      description: "JPG converted to PDF",
    );

    refreshPdfs();
    await OpenFilex.open(file.path);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Scan to PDF created successfully")),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Scan to PDF failed: $e")),
    );
  }
}
Future<void> wordToPdf() async {
  await convertOfficeFileToPdf(
    allowedExtensions: ['doc', 'docx'],
    typeName: "Word",
  );
}

Future<void> powerPointToPdf() async {
  await convertOfficeFileToPdf(
    allowedExtensions: ['ppt', 'pptx'],
    typeName: "PowerPoint",
  );
}

Future<void> excelToPdf() async {
  await convertOfficeFileToPdf(
    allowedExtensions: ['xls', 'xlsx'],
    typeName: "Excel",
  );
}

Future<void> convertOfficeFileToPdf({
  required List<String> allowedExtensions,
  required String typeName,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select $typeName file")),
      );
      return;
    }

    final selectedFile = result.files.single;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Converting $typeName to PDF...")),
    );

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/convert-office-to-pdf"),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        selectedFile.bytes!,
        filename: selectedFile.name,
      ),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final pdfBytes = await response.stream.toBytes();

      final safeName = selectedFile.name
          .replaceAll(RegExp(r'\.(docx|doc|pptx|ppt|xlsx|xls)$'), "")
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");

      final dir = await getApplicationDocumentsDirectory();
      final pdfFile = File("${dir.path}/$safeName.pdf");
      await pdfFile.writeAsBytes(pdfBytes, flush: true);




      await uploadPdf(
        bytes: Uint8List.fromList(pdfBytes),
        fileName: "$safeName.pdf",
        title: "$safeName PDF",
        category: "Converted PDF",
        description: "$typeName converted to PDF",
      );

      refreshPdfs();

      await OpenFilex.open(pdfFile.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$typeName converted successfully")),
      );
    } else {
      final error = await response.stream.bytesToString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Conversion failed: $error")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Conversion error: $e")),
    );
  }
}
  Future<void> editPdfTool({
    required String endpoint,
    required String outputName,
    String? watermark,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      final selectedFile = result.files.single;

      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/$endpoint"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          "pdf",
          selectedFile.bytes!,
          filename: selectedFile.name,
        ),
      );

      if (watermark != null) {
        request.fields["watermark"] = watermark;
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();

        await uploadPdf(
          bytes: Uint8List.fromList(bytes),
          fileName: outputName,
          title: outputName.replaceAll(".pdf", ""),
          category: "Edited PDF",
          description: "PDF edited successfully",
        );

        refreshPdfs();

        final dir = await getApplicationDocumentsDirectory();
        final file = File("${dir.path}/$outputName");
        await file.writeAsBytes(bytes, flush: true);
        await OpenFilex.open(file.path);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF edited successfully")),
        );
      } else {
        final error = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Edit failed: $error")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Edit error: $e")),
      );
    }
  }

  void rotatePdf() {
    editPdfTool(
      endpoint: "rotate-pdf",
      outputName: "rotated_pdf.pdf",
    );
  }

  void addPageNumbers() {
    editPdfTool(
      endpoint: "add-page-numbers",
      outputName: "numbered_pdf.pdf",
    );
  }

  void addWatermark() {
    editPdfTool(
      endpoint: "add-watermark",
      outputName: "watermarked_pdf.pdf",
      watermark: "PDF Viewer App",
    );
  }

  void cropPdf() {
    editPdfTool(
      endpoint: "crop-pdf",
      outputName: "cropped_pdf.pdf",
    );
  }
  Widget _editPdfToolsBar() {
    final tools = [
      ["Rotate PDF", Icons.rotate_right_rounded, rotatePdf],
      ["Add page numbers", Icons.format_list_numbered_rounded, addPageNumbers],
      ["Add watermark", Icons.approval_rounded, addWatermark],
      ["Crop PDF", Icons.crop_rounded, cropPdf],
    ];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "EDIT PDF",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          ...tools.map((tool) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: const Color(0xffB46A9B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(tool[1] as IconData, color: Colors.white, size: 18),
              ),
              title: Text(
                tool[0] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: tool[2] as VoidCallback,
            );
          }),
        ],
      ),
    );
  }
@override
Widget build(BuildContext context) {


    final width = MediaQuery
        .of(context)
        .size
        .width;
    final isDesktop = width >= 900;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
        title: Text(selectedMenu),
        centerTitle: true,
      ),

      drawer: isDesktop
          ? null
          : Drawer(
        child: SafeArea(
          child: _buildSidebar(closeDrawer: true),
        ),
      ),

      body: isDesktop
          ? _buildDesktopLayout(width)
          : _buildBody(width),

      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
        currentIndex:
        selectedMenu == tr("Bookmarks", "बुकमार्क") ? 1 : 0,
        onTap: (index) {
          setState(() {
            selectedMenu = index == 0
                ? tr("Dashboard", "डैशबोर्ड")
                : tr("Bookmarks", "बुकमार्क");
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: tr("Home", "होम"),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bookmark),
            label: tr("Bookmarks", "बुकमार्क"),
          ),
        ],
      ),
    );
  }
}