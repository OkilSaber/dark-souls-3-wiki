import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'favorites.dart';
import 'motion.dart';
import 'screens/home_screen.dart';
import 'theme.dart';
import 'wiki_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the system bars so the translucent chrome has something to
  // blur, and keep the bars themselves transparent.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const DarkSoulsWikiApp());
}

class DarkSoulsWikiApp extends StatefulWidget {
  const DarkSoulsWikiApp({super.key});

  @override
  State<DarkSoulsWikiApp> createState() => _DarkSoulsWikiAppState();
}

class _DarkSoulsWikiAppState extends State<DarkSoulsWikiApp> {
  final _repo = WikiRepository();
  final _favorites = FavoritesStore();
  late final Future<void> _loading = _boot();

  /// Index and saved pages load together; favourites are then reconciled
  /// against what the bundle actually contains.
  Future<void> _boot() async {
    await Future.wait([_repo.load(), _favorites.load()]);
    _favorites.pruneMissing(_repo.pages.containsKey);
  }

  @override
  void dispose() {
    _favorites.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The scope sits *above* MaterialApp on purpose. Pushed routes mount under
    // the Navigator, which is itself above `home` — so a scope placed inside
    // `home` would be invisible to every screen except the first one.
    return FavoritesScope(
      notifier: _favorites,
      child: MaterialApp(
        title: 'Dark Souls 3 Wiki',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        scrollBehavior: const _SoulsScrollBehavior(),
        home: FutureBuilder<void>(
          future: _loading,
          builder: (context, snap) {
            if (snap.hasError) return _StartupError(error: snap.error!);
            // Cross-fade rather than cut, so a fast load does not flash.
            return AnimatedSwitcher(
              duration: Motion.medium,
              switchInCurve: Motion.easeOut,
              child: snap.connectionState == ConnectionState.done
                  ? HomeScreen(repo: _repo)
                  : const _Splash(),
            );
          },
        ),
      ),
    );
  }
}

/// Allow dragging with a mouse or trackpad as well as touch, so the app also
/// behaves when the foldable is open on a desk. Android already supplies the
/// stretch overscroll that Material 3 defaults to.
class _SoulsScrollBehavior extends MaterialScrollBehavior {
  const _SoulsScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, size: 40, color: AppTheme.ember),
            SizedBox(height: 18),
            Text('Dark Souls III',
                style: TextStyle(
                  fontFamily: AppTheme.displayFamily,
                  fontSize: 24,
                  letterSpacing: -0.4,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                )),
            SizedBox(height: 6),
            Text('Kindling the bonfire…',
                style: TextStyle(color: AppTheme.textFaint, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 36),
              const SizedBox(height: 14),
              const Text('Could not load the wiki data.'),
              const SizedBox(height: 8),
              Text('$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textFaint, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
