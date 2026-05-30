import 'package:web/web.dart' as web;

bool isIosNonSafari() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  final isIos = ua.contains('iphone') || ua.contains('ipad');
  final isSafari = ua.contains('safari') &&
      !ua.contains('crios') &&
      !ua.contains('fxios') &&
      !ua.contains('opios');
  return isIos && !isSafari;
}
