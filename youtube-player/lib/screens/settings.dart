import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'web.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? signedIn;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final s = await Account.signedIn();
    if (mounted) setState(() => signedIn = s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final muted = mutedOf(context);
          return ListView(children: [
            const _Section('التشغيل'),
            ListTile(
              leading: const Icon(Icons.hd_outlined),
              title: const Text('الجودة الافتراضية'),
              subtitle: Text('${s.defaultHeight}p', textDirection: TextDirection.ltr, textAlign: TextAlign.right),
              onTap: () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (c) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final h in [1080, 720, 480, 360, 240, 144])
                      ListTile(
                        title: Text('${h}p', textDirection: TextDirection.ltr, textAlign: TextAlign.right),
                        trailing: s.defaultHeight == h ? const Icon(Icons.check_rounded, color: C.accent) : null,
                        onTap: () {
                          s.setDefaultHeight(h);
                          Navigator.pop(c);
                        },
                      ),
                  ]),
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.screen_lock_portrait_outlined),
              title: const Text('التشغيل في الخلفية'),
              subtitle: const Text('يستمر الصوت عند الخروج من التطبيق أو قفل الشاشة'),
              value: s.backgroundPlay,
              onChanged: s.setBackgroundPlay,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.data_saver_on_outlined),
              title: const Text('توفير البيانات'),
              subtitle: const Text('تشغيل المقاطع بجودة 360p'),
              value: s.dataSaver,
              onChanged: s.setDataSaver,
            ),
            const _Section('الحساب'),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(signedIn == true ? 'مسجَّل الدخول' : 'تسجيل الدخول إلى يوتيوب'),
              subtitle: const Text(
                  'اختياري. يُستخدم فقط لتشغيل المقاطع المقيّدة بالعمر عبر صفحة يوتيوب، ويبقى على جهازك.'),
              trailing: signedIn == true
                  ? TextButton(
                      onPressed: () async {
                        await Account.signOut();
                        _check();
                        if (context.mounted) toast(context, 'تم تسجيل الخروج');
                      },
                      child: const Text('خروج'),
                    )
                  : const Icon(Icons.chevron_left_rounded),
              onTap: signedIn == true
                  ? null
                  : () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WebScreen.signIn()));
                      await _check();
                      if (context.mounted && signedIn == true) toast(context, 'تم تسجيل الدخول');
                    },
            ),
            const _Section('الخصوصية'),
            SwitchListTile(
              secondary: const Icon(Icons.history_rounded),
              title: const Text('حفظ السجل'),
              subtitle: const Text('سجل المشاهدة وعمليات البحث، على جهازك فقط'),
              value: s.saveHistory,
              onChanged: s.setSaveHistory,
            ),
            ListTile(
              leading: const Icon(Icons.manage_search_rounded),
              title: const Text('مسح عمليات البحث'),
              onTap: () {
                s.clearSearches();
                toast(context, 'تم المسح');
              },
            ),
            const _Section('عن التطبيق'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Text(
                'شوف ١.٠٫٠\nمشغّل خفيف لمقاطع يوتيوب بلا إعلانات ولا حساب ولا خدمات Google. '
                'لا يجمع التطبيق أي بيانات؛ كل شيء محفوظ على جهازك.\n'
                'إذا توقّف التشغيل فجأة فغالبًا غيّر يوتيوب شيئًا، ويُصلَح بتحديث للتطبيق.',
                style: TextStyle(color: muted, height: 1.6),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String t;
  const _Section(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
        child: Text(t,
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
      );
}
