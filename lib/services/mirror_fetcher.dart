// Package imports:
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Service to fetch mirror links in the background without showing UI
class MirrorFetcherService {
  static final MirrorFetcherService _instance = MirrorFetcherService._internal();
  factory MirrorFetcherService() => _instance;
  MirrorFetcherService._internal();

  /// Fetch mirror links from the given URL in the background
  /// Returns a list of mirror download links
  Future<List<String>> fetchMirrors(String url) async {
    final List<String> bookDownloadLinks = [];

    try {
      // Create a headless webview to load the page
      final headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        onLoadStop: (controller, url) async {
          if (url == null) return;
          
          try {
            if (url.toString().contains("slow_download")) {
              // For slow_download pages, extract the direct link
              String query =
                  """var paragraphTag=document.querySelector('p[class="mb-4 text-xl font-bold"]');var anchorTagHref=paragraphTag.querySelector('a').href;var url=()=>{return anchorTagHref};url();""";
              String? mirrorLink = await controller.evaluateJavascript(source: query);
              if (mirrorLink != null) {
                bookDownloadLinks.add(mirrorLink);
              }
            } else {
              // For other mirror pages, extract all IPFS/mirror links
              String query =
                  """var ipfsLinkTags=document.querySelectorAll('ul>li>a');var ipfsLinks=[];var getIpfsLinks=()=>{ipfsLinkTags.forEach(e=>{ipfsLinks.push(e.href)});return ipfsLinks};getIpfsLinks();""";
              List<dynamic> mirrorLinks =
                  await controller.evaluateJavascript(source: query);
              bookDownloadLinks.addAll(mirrorLinks.cast<String>());
            }
          } catch (e) {
            // Evaluation error, will return empty list
          }
        },
      );

      // Run the headless webview
      await headlessWebView.run();

      // Wait for the page to load and links to be extracted
      // Maximum wait time of 15 seconds
      int attempts = 0;
      const maxAttempts = 30; // 30 * 500ms = 15 seconds
      while (bookDownloadLinks.isEmpty && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      // Dispose the headless webview
      await headlessWebView.dispose();

      return bookDownloadLinks;
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }
}
