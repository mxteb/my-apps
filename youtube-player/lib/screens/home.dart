import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../main.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../yt.dart';
import 'playlist.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const HomeScreen({super.key, required this.onChanged});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ctl = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();

  String query = '';
  List<VideoItem> results = [];
  VideoSearchList? page;
  bool loading = false, loadingMore = false, noMore = false;
  String? error;
  List<String> suggestions = [];
  Timer? _debounce;
  int _req = 0;

  bool get hasQuery => query.isNotEmpty || ctl.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.pixels > scroll.position.maxScrollExtent - 600) _more();
    });
    focus.addListener(() => setState(() {}));
  }

  void focusSearch() => focus.requestFocus();

  void clearQuery() {
    ctl.clear();
    focus.unfocus();
    setState(() {
      query = '';
      results = [];
      error = null;
      suggestions = [];
    });
  }

  void _onType(String t) {
    setState(() {});
    _debounce?.cancel();
    if (t.trim().isEmpty) {
      setState(() => suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final s = await yt.search.getQuerySuggestions(t.trim());
        if (mounted && ctl.text == t) setState(() => suggestions = s.take(8).toList());
      } catch (_) {}
    });
  }

  Future<void> search(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    focus.unfocus();
    ctl.text = q;
    final id = videoIdFrom(q);
    if (id != null && (q.contains('/') || q.length == 11)) {
      openLink(q);
      return;
    }
    final pl = playlistIdFrom(q);
    if (pl != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaylistScreen(id: pl)));
      return;
    }
    Store.i.addSearch(q);
    final r = ++_req;
    setState(() {
      query = q;
      loading = true;
      error = null;
      results = [];
      noMore = false;
      suggestions = [];
    });
    widget.onChanged();
    try {
      final list = await yt.search.search(q);
      if (r != _req) return;
      page = list;
      results = list.map(itemFromVideo).toList();
      noMore = list.isEmpty;
    } catch (e) {
      if (r != _req) return;
      error = 'تعذّر البحث. تحقّق من اتصالك بالإنترنت ثم أعد المحاولة.';
    }
    if (mounted) setState(() => loading = false);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> _more() async {
    if (loading || loadingMore || noMore || page == null) return;
    setState(() => loadingMore = true);
    final r = _req;
    try {
      final next = await page!.nextPage();
      if (r != _req) return;
      if (next == null || next.isEmpty) {
        noMore = true;
      } else {
        page = next;
        final ids = results.map((e) => e.id).toSet();
        results.addAll(next.map(itemFromVideo).where((e) => ids.add(e.id)));
      }
    } catch (_) {
      noMore = true;
    }
    if (mounted) setState(() => loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(children: [
              if (!focus.hasFocus && query.isEmpty) ...[
                const _Logo(),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: ctl,
                  focusNode: focus,
                  textInputAction: TextInputAction.search,
                  onSubmitted: search,
                  onChanged: _onType,
                  decoration: InputDecoration(
                    hintText: 'ابحث أو الصق رابطًا',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: ctl.text.isEmpty
                        ? null
                        : IconButton(icon: const Icon(Icons.close_rounded), onPressed: clearQuery),
                    filled: true,
                    fillColor: dark ? C.nightCard : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _body() {
    if (focus.hasFocus && suggestions.isNotEmpty) {
      return ListView(children: [
        for (final s in suggestions)
          ListTile(
            leading: const Icon(Icons.search_rounded, size: 20),
            title: Text(s),
            trailing: IconButton(
              icon: const Icon(Icons.north_west_rounded, size: 18),
              onPressed: () {
                ctl.text = '$s ';
                ctl.selection = TextSelection.collapsed(offset: ctl.text.length);
                _onType(ctl.text);
              },
            ),
            onTap: () => search(s),
          ),
      ]);
    }
    if (query.isEmpty) return _start();
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'حدث خطأ',
        body: error,
        action: FilledButton(onPressed: () => search(query), child: const Text('إعادة المحاولة')),
      );
    }
    if (results.isEmpty) {
      return const EmptyState(icon: Icons.search_off_rounded, title: 'لا توجد نتائج');
    }
    return ListView.builder(
      controller: scroll,
      itemCount: results.length + 1,
      itemBuilder: (c, i) {
        if (i == results.length) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: loadingMore
                  ? const CircularProgressIndicator()
                  : const SizedBox(height: 10),
            ),
          );
        }
        final v = results[i];
        return VideoCard(v, onTap: () => openVideo(context, v), onLong: () => _quickActions(v));
      },
    );
  }

  void _quickActions(VideoItem v) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.headphones_rounded),
            title: const Text('تشغيل الصوت فقط'),
            onTap: () {
              Navigator.pop(c);
              openVideo(context, v, audio: true);
            },
          ),
          ListTile(
            leading: Icon(Store.i.isFavorite(v.id) ? Icons.favorite : Icons.favorite_border),
            title: Text(Store.i.isFavorite(v.id) ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة'),
            onTap: () {
              Store.i.toggleFavorite(v);
              Navigator.pop(c);
            },
          ),
        ]),
      ),
    );
  }

  Widget _start() {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final recent = s.history.take(12).toList();
        if (s.searches.isEmpty && recent.isEmpty) {
          return const EmptyState(
            icon: Icons.play_circle_outline_rounded,
            title: 'أهلًا بك في شوف',
            body: 'ابحث عن أي مقطع، أو شارك رابطًا من يوتيوب إلى التطبيق ليفتح هنا مباشرة.\nبلا إعلانات ولا تتبّع.',
          );
        }
        return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
          if (s.searches.isNotEmpty) ...[
            _Header('عمليات البحث الأخيرة', action: 'مسح', onAction: s.clearSearches),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final q in s.searches.take(12))
                  InputChip(
                    label: Text(q),
                    onPressed: () => search(q),
                    onDeleted: () => s.removeSearch(q),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  ),
              ]),
            ),
          ],
          if (recent.isNotEmpty) ...[
            const _Header('شاهدتَ مؤخرًا'),
            for (final v in recent) VideoRow(v, onTap: () => openVideo(context, v)),
          ],
        ]);
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _Header(this.text, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(9)),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 7),
      const Text('شوف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    ]);
  }
}
