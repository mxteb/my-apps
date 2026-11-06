import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../store.dart';

/// A normal mobile browser identity, so Google lets the user sign in.
const _browserUA =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36';

class Account {
  static Future<bool> signedIn() async {
    try {
      final cookies = await WebViewCookieManager().getCookies(domain: Uri.parse('https://www.youtube.com'));
      return cookies.any((c) => c.name == 'SAPISID' || c.name == 'LOGIN_INFO' || c.name == '__Secure-3PSID');
    } catch (_) {
      return false;
    }
  }

  static Future<void> signOut() async {
    await WebViewCookieManager().clearCookies();
  }
}

class WebScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool login;
  const WebScreen({super.key, required this.url, required this.title, this.login = false});

  factory WebScreen.watch(VideoItem v) =>
      WebScreen(url: 'https://m.youtube.com/watch?v=${v.id}', title: v.title);

  factory WebScreen.signIn() => const WebScreen(
        url: 'https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true'
            '&continue=https%3A%2F%2Fm.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Dm%26next%3Dhttps%253A%252F%252Fm.youtube.com%252F',
        title: 'تسجيل الدخول',
        login: true,
      );

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  double progress = 0;
  late final WebViewController web;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_browserUA)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => progress = p / 100);
        },
        onPageFinished: (url) async {
          if (!widget.login || _closing) return;
          final u = Uri.tryParse(url);
          if (u == null) return;
          if (u.host.endsWith('youtube.com') && !u.path.startsWith('/signin') && await Account.signedIn()) {
            _closing = true;
            if (mounted) Navigator.of(context).pop(true);
          }
        },
      ));
    final pc = web.platform;
    if (pc is AndroidWebViewController) {
      pc.setMediaPlaybackRequiresUserGesture(false);
      AndroidWebViewCookieManager(const PlatformWebViewCookieManagerCreationParams())
          .setAcceptThirdPartyCookies(pc, true);
    }
    web.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        final nav = Navigator.of(context);
        if (!widget.login && await web.canGoBack()) {
          await web.goBack();
        } else {
          nav.pop(await Account.signedIn());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: progress < 1
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: progress, minHeight: 2),
                )
              : null,
        ),
        body: WebViewWidget(controller: web),
      ),
    );
  }
}
