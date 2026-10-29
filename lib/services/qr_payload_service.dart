enum QrPayloadType {
  url,
  wifi,
  email,
  phone,
  sms,
  geo,
  unsupportedScheme,
  plainText,
  malformedUrl,
}

class QrPayload {
  final String rawContent;
  final QrPayloadType type;
  final String? url;
  final String label;
  final String description;

  const QrPayload({
    required this.rawContent,
    required this.type,
    this.url,
    required this.label,
    required this.description,
  });

  bool get isWebUrl => type == QrPayloadType.url && url != null && url!.isNotEmpty;
}

class QrPayloadClassifier {
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
  );

  static final RegExp _phoneRegExp = RegExp(
    r'^\+?[0-9\s\-()]{7,18}$',
  );

  static final RegExp _schemeRegExp = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9+.-]*:',
  );

  /// Classifies a decoded QR code raw content string into a structured [QrPayload].
  static QrPayload classify(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const QrPayload(
        rawContent: '',
        type: QrPayloadType.plainText,
        label: 'Empty Content',
        description: 'The scanned QR code contained no text or data.',
      );
    }

    final lower = trimmed.toLowerCase();

    // 1. Dangerous non-HTTP schemes
    if (lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('file:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('vbscript:')) {
      return QrPayload(
        rawContent: trimmed,
        type: QrPayloadType.unsupportedScheme,
        label: 'Dangerous Non-HTTP URI Scheme',
        description:
            'This QR code contains an executable or local scheme ($lower) that can trigger arbitrary script execution. DigiLens will not execute this payload.',
      );
    }

    // 2. Wi-Fi Configuration
    if (lower.startsWith('wifi:')) {
      return QrPayload(
        rawContent: trimmed,
        type: QrPayloadType.wifi,
        label: 'Wi-Fi Network Configuration',
        description:
            'This QR code encodes Wi-Fi network credentials. DigiLens specializes in web security and does not automatically configure device networks.',
      );
    }

    // 3. Mailto / Email
    if (lower.startsWith('mailto:') || _emailRegExp.hasMatch(trimmed)) {
      return QrPayload(
        rawContent: trimmed,
        type: QrPayloadType.email,
        label: 'Email Address / Mailto Link',
        description:
            'This QR code contains an email address. DigiLens specializes in analyzing web links for phishing and malware.',
      );
    }

    // 4. Telephone / Dial
    if (lower.startsWith('tel:') || lower.startsWith('telprompt:')) {
      return QrPayload(
        rawContent: trimmed,
        type: QrPayloadType.phone,
        label: 'Telephone Number',
        description:
            'This QR code contains a phone dialer link. DigiLens specializes in analyzing web URLs.',
      );
    }

    // 5. SMS / Messaging
    if (lower.startsWith('sms:') || lower.startsWith('smsto:')) {
      return QrPayload(
        rawContent: trimmed,
        type: QrPayloadType.sms,
        label: 'SMS Message Intent',
        description:
            'This QR code contains an SMS message prompt. DigiLens analyzes incoming SMS text via the Message Analyzer rather than raw QR codes.',
      );
    }

    // 6. Geographic coordinates
    if (lower.startsWith('geo:')) {
      return QrPayload(
        rawContent: trimmed,
        type: QrPayloadType.geo,
        label: 'Geographic Location',
        description:
            'This QR code contains map coordinate data, not an HTTP/HTTPS website URL.',
      );
    }

    // 7. Explicit HTTP / HTTPS
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        // Validate host structure (must contain dot, be localhost, or valid IP)
        final host = uri.host.toLowerCase();
        if (host.contains('.') || host == 'localhost' || _isIpAddress(host)) {
          return QrPayload(
            rawContent: trimmed,
            type: QrPayloadType.url,
            url: trimmed,
            label: 'Web URL',
            description: 'Standard web link ready for security analysis.',
          );
        }
      }
      return QrPayload(
        rawContent: trimmed,
        type: QrPayloadType.malformedUrl,
        label: 'Malformed Web URL',
        description:
            'This QR code attempts to use an HTTP/HTTPS scheme, but the domain or structure is invalid.',
      );
    }

    // 8. Other URI schemes (e.g. market:, intent:, ftp:, ssh:, myapp:)
    if (_schemeRegExp.hasMatch(trimmed) && !trimmed.contains(' ')) {
      return QrPayload(
        rawContent: trimmed,
        type: QrPayloadType.unsupportedScheme,
        label: 'Unsupported URI Scheme',
        description:
            'This QR code uses a custom or unsupported application scheme. DigiLens only verifies HTTP and HTTPS web URLs.',
      );
    }

    // 9. Plain phone number without 'tel:'
    if (_phoneRegExp.hasMatch(trimmed) && !trimmed.contains('.')) {
      return QrPayload(
        rawContent: trimmed,
        type: QrPayloadType.phone,
        label: 'Telephone Number',
        description:
            'This QR code contains a phone number rather than a web URL.',
      );
    }

    // 10. Web URL missing scheme (e.g. www.google.com or example.com/login)
    if (_looksLikeWebUrl(trimmed)) {
      final normalized = 'https://$trimmed';
      final uri = Uri.tryParse(normalized);
      if (uri != null && uri.host.isNotEmpty && uri.host.contains('.')) {
        return QrPayload(
          rawContent: trimmed,
          type: QrPayloadType.url,
          url: normalized,
          label: 'Web URL',
          description: 'Web link detected (HTTPS scheme applied for analysis).',
        );
      }
    }

    // 11. Plain text
    return QrPayload(
      rawContent: trimmed,
      type: QrPayloadType.plainText,
      label: 'Plain Text',
      description:
          'This QR code contains plain text, not a web URL. DigiLens analyzes website links for phishing and malware threats.',
    );
  }

  static bool _looksLikeWebUrl(String text) {
    if (text.contains(' ') || text.contains('\n') || text.contains('\t')) {
      return false;
    }
    final lower = text.toLowerCase();
    if (lower.startsWith('www.')) return true;

    // Check if it looks like domain.tld/path
    final parts = text.split('/');
    final domain = parts.first;
    if (domain.contains('.') && !domain.startsWith('.') && !domain.endsWith('.')) {
      final tld = domain.split('.').last.toLowerCase();
      // Common or valid TLD length check
      if (tld.length >= 2 && RegExp(r'^[a-z]{2,12}$').hasMatch(tld)) {
        return true;
      }
    }
    return false;
  }

  static bool _isIpAddress(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }
}
