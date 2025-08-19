import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

const String kHomeUrl = "https://hame-chiz-shop.ir";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "HameChiz",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});
  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _web;
  late PullToRefreshController _ptr;
  bool _isOffline = false;
  bool _isLoading = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _ptr = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.teal,
        backgroundColor: Colors.white,
      ),
      onRefresh: () async {
        if (_web != null) {
          final url = await _web!.getUrl();
          url != null
              ? await _web!.loadUrl(urlRequest: URLRequest(url: url))
              : await _web!.loadUrl(
                  urlRequest: URLRequest(url: WebUri(kHomeUrl)),
                );
        }
      },
    );
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results);
    _connSub = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final offline = results.contains(ConnectivityResult.none);
    if (mounted) setState(() => _isOffline = offline);
    if (!offline && _web != null) _web!.reload();
  }

  Future<void> _showErrorPage() async {
    await _ptr.endRefreshing();
    if (_web == null) return;

    const errorHtml = """
    <html lang="fa"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1"></head>
    <body style='direction:rtl;display:flex;gap:16px;flex-direction:column;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#f5f5f5;'>
      <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#757575" stroke-width="2">
        <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path>
        <line x1="12" y1="9" x2="12" y2="13"></line>
        <line x1="12" y1="17" x2="12.01" y2="17"></line>
      </svg>
      <h3 style='color:#424242;margin:0;'>خطا در اتصال به اینترنت</h3>
      <p style='color:#757575;margin:8px 0 0;text-align:center;'>اتصال به سرور برقرار نشد</p>
      <button style='padding:12px 24px;border-radius:12px;border:0;background:#00897b;color:#fff;margin-top:16px;font-size:16px;'
              onclick="window.flutter_inappwebview.callHandler('retry')">تلاش مجدد</button>
    </body></html>
    """;

    await _web!.loadData(data: errorHtml, baseUrl: WebUri(kHomeUrl));
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _web?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_web != null && await _web!.canGoBack()) {
          await _web!.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(kHomeUrl)),
                pullToRefreshController: _ptr,
                initialSettings: InAppWebViewSettings(
                  javaScriptCanOpenWindowsAutomatically: true,

                  javaScriptEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  cacheEnabled: true,
                  transparentBackground: true,
                ),
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },
                onCreateWindow: (controller, createWindowRequest) async {
                  controller.loadUrl(
                    urlRequest: URLRequest(
                      url: createWindowRequest.request.url,
                    ),
                  );
                  return true;
                },

                onWebViewCreated: (controller) {
                  _web = controller;
                  controller.addJavaScriptHandler(
                    handlerName: "retry",
                    callback: (_) => controller.loadUrl(
                      urlRequest: URLRequest(url: WebUri(kHomeUrl)),
                    ),
                  );
                },

                onLoadStart: (_, __) {
                  setState(() => _isLoading = true);
                },
                onLoadStop: (_, __) async {
                  await _ptr.endRefreshing();
                  setState(() => _isLoading = false);
                },
                onReceivedError: (_, __, ___) async {
                  await _showErrorPage();
                  setState(() => _isLoading = false);
                },
                onReceivedHttpError: (_, __, ___) async {
                  await _showErrorPage();
                  setState(() => _isLoading = false);
                },
              ),

              if (_isLoading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(Colors.teal.shade400),
                    minHeight: 2,
                  ),
                ),

              if (_isOffline)
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.signal_wifi_connected_no_internet_4_rounded,
                          size: 120,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "!اتصال به اینترنت قطع شد",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "لطفاً اتصال اینترنت خود را بررسی کنید",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text("تلاش مجدد"),
                          onPressed: () async {
                            final results = await Connectivity()
                                .checkConnectivity();
                            _updateConnectionStatus(results);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
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
