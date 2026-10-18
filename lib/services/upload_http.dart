import 'dart:io';
import 'package:http/http.dart' as http;

/// PUT يتبع إعادة التوجيه (301/302/303/307/308) يدويًا مع إبقاء الطريقة (PUT) والمحتوى.
/// حزمة http لا تتبع التحويل في PUT تلقائيًا، فكان الرفع يفشل بـ «HTTP 302» عند وجود تحويل
/// من Cloudflare (مثل http→https أو نطاق/مسار قديم لخدمة الرفع).
/// الأمان: لا نتبع إلا إلى https، ولا نرسل رمز الدخول إلى مضيف مختلف.
Future<http.Response> putFollowingRedirects(
  Uri uri, {
  required Map<String, String> headers,
  required List<int> body,
  Duration timeout = const Duration(minutes: 10),
}) async {
  final client = http.Client();
  try {
    var url = uri;
    for (var i = 0; i < 5; i++) {
      final h = Map<String, String>.from(headers);
      if (url.host != uri.host) h.removeWhere((k, _) => k.toLowerCase() == 'authorization');
      final req = http.Request('PUT', url)
        ..followRedirects = false
        ..headers.addAll(h)
        ..bodyBytes = body;
      final res = await http.Response.fromStream(await client.send(req).timeout(timeout));
      if ({301, 302, 303, 307, 308}.contains(res.statusCode)) {
        final loc = res.headers['location'];
        if (loc == null || loc.isEmpty) {
          throw HttpException('خدمة الرفع حوّلت الطلب (HTTP ${res.statusCode}) دون عنوان جديد. تحقق من عنوان uploadApi.');
        }
        final next = url.resolve(loc);
        if (next.scheme != 'https') throw HttpException('خدمة الرفع حوّلت الطلب إلى عنوان غير آمن: $next');
        if (next.host != uri.host) {
          throw HttpException('خدمة الرفع حوّلت الطلب إلى مضيف آخر (${next.host}). حدّث settings/uploadApi إلى العنوان الصحيح: ${next.origin}');
        }
        url = next;
        continue;
      }
      return res;
    }
    throw HttpException('تكرار إعادة التوجيه من خدمة الرفع. آخر عنوان: $url');
  } finally {
    client.close();
  }
}
