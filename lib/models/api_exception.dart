class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? endpoint;

  const ApiException({
    required this.message,
    this.statusCode,
    this.endpoint,
  });

  @override
  String toString() {
    if (statusCode != null && endpoint != null) {
      return 'ApiException: HTTP $statusCode at $endpoint - $message';
    } else if (statusCode != null) {
      return 'ApiException: HTTP $statusCode - $message';
    } else if (endpoint != null) {
      return 'ApiException at $endpoint - $message';
    }
    return 'ApiException: $message';
  }
}