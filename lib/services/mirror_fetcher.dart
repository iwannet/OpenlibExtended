// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// Project imports:
import 'package:openlib/services/logger.dart';

/// Service to fetch mirror links in the background without showing UI
/// with improved stability, retry logic, and fallback mechanisms
class MirrorFetcherService {
  static final MirrorFetcherService _instance = MirrorFetcherService._internal();
  factory MirrorFetcherService() => _instance;
  MirrorFetcherService._internal();

  final AppLogger _logger = AppLogger();
  
  // Configuration
  static const int maxRetries = 3;
  static const int initialTimeoutSeconds = 15;
  static const int maxTimeoutSeconds = 30;
  static const int retryDelayMs = 1000;

  /// Fetch mirror links from the given URL in the background with retry logic
  /// Returns a list of mirror download links
  /// Uses exponential backoff and multiple fallback strategies
  Future<List<String>> fetchMirrors(String url, {int retryCount = 0}) async {
    _logger.info('Starting mirror fetch from: $url (attempt ${retryCount + 1}/$maxRetries)', tag: 'MirrorFetcher');
    
    final Completer<List<String>> completer = Completer<List<String>>();
    final List<String> bookDownloadLinks = [];
    HeadlessInAppWebView? headlessWebView;

    // Calculate timeout with exponential backoff
    final timeoutSeconds = initialTimeoutSeconds + (retryCount * 5);
    final effectiveTimeout = timeoutSeconds > maxTimeoutSeconds ? maxTimeoutSeconds : timeoutSeconds;

    try {
      // Create a headless webview to load the page
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          // Optimize for background fetching
          javaScriptEnabled: true,
          cacheEnabled: true,
          clearCache: false,
          mediaPlaybackRequiresUserGesture: false,
          // Improve stability
          useHybridComposition: false,
          allowsBackForwardNavigationGestures: false,
        ),
        onLoadStop: (controller, url) async {
          if (url == null) {
            _logger.warning('URL is null in onLoadStop', tag: 'MirrorFetcher');
            if (!completer.isCompleted) {
              completer.complete([]);
            }
            return;
          }
          
          _logger.debug('Page loaded: ${url.toString()}', tag: 'MirrorFetcher');
          
          try {
            if (url.toString().contains("slow_download")) {
              // For slow_download pages, extract the direct link
              await _extractSlowDownloadLink(controller, bookDownloadLinks);
            } else {
              // For other mirror pages, extract all IPFS/mirror links
              await _extractMirrorLinks(controller, bookDownloadLinks);
            }
            
            // Complete the future with the extracted links
            if (!completer.isCompleted) {
              completer.complete(bookDownloadLinks);
            }
          } catch (e) {
            _logger.error('Link extraction error', tag: 'MirrorFetcher', error: e);
            if (!completer.isCompleted) {
              completer.complete([]);
            }
          }
        },
        onLoadError: (controller, url, code, message) {
          _logger.error('Load error: $message (code: $code)', tag: 'MirrorFetcher');
          if (!completer.isCompleted) {
            completer.complete([]);
          }
        },
        onReceivedError: (controller, request, error) {
          _logger.error('WebView error: ${error.description}', tag: 'MirrorFetcher', error: error);
          if (!completer.isCompleted) {
            completer.complete([]);
          }
        },
        onWebViewCreated: (controller) {
          _logger.debug('WebView created successfully', tag: 'MirrorFetcher');
        },
      );

      // Run the headless webview
      await headlessWebView.run();
      _logger.debug('Headless webview started', tag: 'MirrorFetcher');

      // Wait for the page to load and links to be extracted with timeout
      final result = await completer.future.timeout(
        Duration(seconds: effectiveTimeout),
        onTimeout: () {
          _logger.warning('Mirror fetch timed out after $effectiveTimeout seconds', tag: 'MirrorFetcher');
          return [];
        },
      );

      // Dispose the headless webview
      await headlessWebView.dispose();
      _logger.debug('Headless webview disposed', tag: 'MirrorFetcher');

      // If we got results, return them
      if (result.isNotEmpty) {
        _logger.info('Successfully fetched ${result.length} mirror links', tag: 'MirrorFetcher');
        return result;
      }
      
      // If no results and we haven't exhausted retries, retry
      if (retryCount < maxRetries - 1) {
        _logger.info('No results, retrying... (${retryCount + 1}/$maxRetries)', tag: 'MirrorFetcher');
        await Future.delayed(Duration(milliseconds: retryDelayMs * (retryCount + 1)));
        return await fetchMirrors(url, retryCount: retryCount + 1);
      }
      
      return result;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch mirrors', tag: 'MirrorFetcher', error: e, stackTrace: stackTrace);
      
      // Cleanup on error
      try {
        await headlessWebView?.dispose();
      } catch (disposeError) {
        _logger.warning('Error disposing webview: $disposeError', tag: 'MirrorFetcher');
      }
      
      // Retry if we haven't exhausted retries
      if (retryCount < maxRetries - 1) {
        _logger.info('Error occurred, retrying... (${retryCount + 1}/$maxRetries)', tag: 'MirrorFetcher');
        await Future.delayed(Duration(milliseconds: retryDelayMs * (retryCount + 1)));
        return await fetchMirrors(url, retryCount: retryCount + 1);
      }
      
      // Return empty list on final failure
      return [];
    }
  }
  
  /// Extract slow download link with fallback strategies
  Future<void> _extractSlowDownloadLink(
    InAppWebViewController controller, 
    List<String> bookDownloadLinks
  ) async {
    try {
      // Primary extraction method
      String query = """
        var paragraphTag = document.querySelector('p[class*="mb-4"][class*="text-xl"][class*="font-bold"]');
        if (paragraphTag) {
          var anchorTag = paragraphTag.querySelector('a');
          if (anchorTag && anchorTag.href) {
            return anchorTag.href;
          }
        }
        return null;
      """;
      
      String? mirrorLink = await controller.evaluateJavascript(source: query);
      
      if (mirrorLink != null && mirrorLink.isNotEmpty && mirrorLink != 'null') {
        bookDownloadLinks.add(mirrorLink);
        _logger.info('Extracted slow_download link', tag: 'MirrorFetcher');
        return;
      }
      
      // Fallback: try alternative selector
      String fallbackQuery = """
        var allLinks = document.querySelectorAll('a[href]');
        for (var i = 0; i < allLinks.length; i++) {
          var href = allLinks[i].href;
          if (href && (href.includes('ipfs') || href.includes('cloudflare') || href.includes('download'))) {
            return href;
          }
        }
        return null;
      """;
      
      String? fallbackLink = await controller.evaluateJavascript(source: fallbackQuery);
      if (fallbackLink != null && fallbackLink.isNotEmpty && fallbackLink != 'null') {
        bookDownloadLinks.add(fallbackLink);
        _logger.info('Extracted slow_download link using fallback', tag: 'MirrorFetcher');
      }
    } catch (e) {
      _logger.error('Error extracting slow download link', tag: 'MirrorFetcher', error: e);
    }
  }
  
  /// Extract mirror links with fallback strategies
  Future<void> _extractMirrorLinks(
    InAppWebViewController controller,
    List<String> bookDownloadLinks
  ) async {
    try {
      // Primary extraction method
      String query = """
        var ipfsLinkTags = document.querySelectorAll('ul > li > a[href]');
        var ipfsLinks = [];
        ipfsLinkTags.forEach(function(e) {
          if (e.href) {
            ipfsLinks.push(e.href);
          }
        });
        return ipfsLinks;
      """;
      
      dynamic mirrorLinks = await controller.evaluateJavascript(source: query);
      
      if (mirrorLinks is List && mirrorLinks.isNotEmpty) {
        bookDownloadLinks.addAll(mirrorLinks.cast<String>());
        _logger.info('Extracted ${mirrorLinks.length} mirror links', tag: 'MirrorFetcher');
        return;
      }
      
      // Fallback 1: Try broader selector
      String fallbackQuery1 = """
        var allLinks = document.querySelectorAll('a[href]');
        var links = [];
        allLinks.forEach(function(e) {
          var href = e.href;
          if (href && (href.includes('ipfs') || href.includes('download') || href.includes('mirror'))) {
            links.push(href);
          }
        });
        return links;
      """;
      
      dynamic fallbackLinks = await controller.evaluateJavascript(source: fallbackQuery1);
      if (fallbackLinks is List && fallbackLinks.isNotEmpty) {
        bookDownloadLinks.addAll(fallbackLinks.cast<String>());
        _logger.info('Extracted ${fallbackLinks.length} mirror links using fallback', tag: 'MirrorFetcher');
      }
    } catch (e) {
      _logger.error('Error extracting mirror links', tag: 'MirrorFetcher', error: e);
    }
  }
}
