import 'package:flutter/material.dart';

import 'l10n.dart';
import 'screens/home.dart';
import 'sorter.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settings.load();
  final sorter = Sorter()..init();
  runApp(PhotoSorterApp(sorter: sorter));
}

class PhotoSorterApp extends StatelessWidget {
  const PhotoSorterApp({super.key, required this.sorter});
  final Sorter sorter;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      title: tr('فرز الصور', 'Photo Sorter'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(settings.lang),
      builder: (context, child) => Directionality(textDirection: isAr ? TextDirection.rtl : TextDirection.ltr, child: child!),
      home: HomeScreen(sorter: sorter),
    ),
  );
}
