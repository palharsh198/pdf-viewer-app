
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'home_page.dart';
import 'login_page.dart';
import 'opened_pdf_page.dart';
import 'signup_page.dart';

void main() async {
WidgetsFlutterBinding.ensureInitialized();

await SystemChrome.setPreferredOrientations([
DeviceOrientation.portraitUp,
DeviceOrientation.landscapeLeft,
DeviceOrientation.landscapeRight,
]);

SystemChrome.setEnabledSystemUIMode(
SystemUiMode.edgeToEdge,
);

runApp(const PdfViewerApp());
}

class PdfViewerApp extends StatefulWidget {
const PdfViewerApp({super.key});

@override
State<PdfViewerApp> createState() => _PdfViewerAppState();
}

class _PdfViewerAppState extends State<PdfViewerApp> {
final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

StreamSubscription<List<SharedMediaFile>>? _intentSub;

@override
void initState() {
super.initState();

_intentSub =
ReceiveSharingIntent.instance.getMediaStream().listen(
(files) {
if (files.isNotEmpty) {
_openPdf(files.first.path);
}
},
);

ReceiveSharingIntent.instance
    .getInitialMedia()
    .then((files) {
if (files.isNotEmpty) {
WidgetsBinding.instance.addPostFrameCallback((_) {
_openPdf(files.first.path);
});
}
});
}

void _openPdf(String path) {
navigatorKey.currentState?.push(
MaterialPageRoute(
builder: (_) => OpenedPdfPage(path: path),
),
);
}

@override
void dispose() {
_intentSub?.cancel();
super.dispose();
}


@override
Widget build(BuildContext context) {
return MaterialApp(
navigatorKey: navigatorKey,
debugShowCheckedModeBanner: false,
title: 'PDF Viewer Pro',



theme: _lightTheme(),
darkTheme: _darkTheme(),

builder: (context, child) {
return Stack(
children: [
Container(
decoration: const BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0xff0F172A),
Color(0xff111827),
Color(0xff1E1B4B),
],
),
),
),

Positioned(
top: -120,
left: -80,
child: Container(
width: 260,
height: 260,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: Colors.deepPurple.withOpacity(.18),
),
)
    .animate(onPlay: (c) => c.repeat(reverse: true))
    .scale(
duration: 4.seconds,
begin: const Offset(1, 1),
end: const Offset(1.2, 1.2),
),
),

Positioned(
bottom: -100,
right: -80,
child: Container(
width: 240,
height: 240,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: Colors.blue.withOpacity(.15),
),
)
    .animate(onPlay: (c) => c.repeat(reverse: true))
    .moveY(
begin: -10,
end: 10,
duration: 5.seconds,
),
),

child ?? const SizedBox(),
],
);
},

initialRoute: '/splash',

routes: {
'/splash': (context) => const SplashScreen(),
'/login': (context) => const LoginPage(),
'/signup': (context) => const SignupPage(),
'/home': (context) => const HomePage(),
},
);
}

ThemeData _lightTheme() {
return ThemeData(
useMaterial3: true,
brightness: Brightness.light,
fontFamily: GoogleFonts.poppins().fontFamily,
colorSchemeSeed: Colors.deepPurple,
);
}

ThemeData _darkTheme() {
return ThemeData(
useMaterial3: true,
brightness: Brightness.dark,
scaffoldBackgroundColor: Colors.transparent,

fontFamily: GoogleFonts.poppins().fontFamily,

colorScheme: ColorScheme.fromSeed(
seedColor: Colors.deepPurple,
brightness: Brightness.dark,
),

appBarTheme: const AppBarTheme(
elevation: 0,
backgroundColor: Colors.transparent,
centerTitle: true,
),

snackBarTheme: SnackBarThemeData(
behavior: SnackBarBehavior.floating,
backgroundColor: Colors.deepPurple.shade400,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(18),
),
),

cardTheme: CardThemeData(
elevation: 0,
color: Colors.white.withOpacity(.05),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(26),
),
),

inputDecorationTheme: InputDecorationTheme(
filled: true,
fillColor: Colors.white.withOpacity(.05),

hintStyle: TextStyle(
color: Colors.white.withOpacity(.5),
),

border: OutlineInputBorder(
borderRadius: BorderRadius.circular(20),
borderSide: BorderSide.none,
),

enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(20),
borderSide: BorderSide.none,
),

focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(20),
borderSide: const BorderSide(
color: Colors.deepPurple,
width: 1.5,
),
),
),

elevatedButtonTheme: ElevatedButtonThemeData(
style: ElevatedButton.styleFrom(
elevation: 0,
backgroundColor: Colors.deepPurple,
foregroundColor: Colors.white,
padding: const EdgeInsets.symmetric(
horizontal: 22,
vertical: 16,
),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(20),
),
),
),
);
}
}

class SplashScreen extends StatefulWidget {
const SplashScreen({super.key});

@override
State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
@override
void initState() {
super.initState();

Future.delayed(const Duration(seconds: 3), () {
if (mounted) {
Navigator.pushReplacementNamed(context, '/login');
}
});
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.transparent,
body: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
width: 130,
height: 130,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(35),
gradient: const LinearGradient(
colors: [
Colors.deepPurple,
Colors.blue,
],
),
boxShadow: [
BoxShadow(
color: Colors.deepPurple.withOpacity(.4),
blurRadius: 30,
spreadRadius: 5,
),
],
),
child: const Icon(
Icons.picture_as_pdf,
color: Colors.white,
size: 70,
),
)
    .animate()
    .fade(duration: 900.ms)
    .scale(
begin: const Offset(.5, .5),
end: const Offset(1, 1),
),

const SizedBox(height: 30),

Text(
'PDF Viewer Pro',
style: GoogleFonts.poppins(
fontSize: 34,
fontWeight: FontWeight.bold,
color: Colors.white,
),
)
    .animate()
    .fade(delay: 500.ms)
    .slideY(begin: 1, end: 0),

const SizedBox(height: 12),

Text(
'Creative Premium PDF Experience',
style: GoogleFonts.poppins(
fontSize: 15,
color: Colors.white70,
),
)
    .animate()
    .fade(delay: 900.ms)
    .slideY(begin: 1, end: 0),

const SizedBox(height: 50),

SizedBox(
width: 130,
child: LinearProgressIndicator(
minHeight: 6,
borderRadius: BorderRadius.circular(20),
backgroundColor: Colors.white12,
color: Colors.deepPurple,
),
)
    .animate(onPlay: (c) => c.repeat())
    .fade(),

const SizedBox(height: 30),

SizedBox(
width: 180,
height: 180,
child: Lottie.network(
'https://assets4.lottiefiles.com/packages/lf20_j1adxtyb.json',
fit: BoxFit.contain,
),
),
],
),
),
);
}
}
