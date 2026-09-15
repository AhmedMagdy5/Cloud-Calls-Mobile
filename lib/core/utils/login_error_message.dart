/// User-friendly login / SIP error text for SnackBars.
String loginErrorMessage(Object error) {
  if (error is StateError) {
    return error.message;
  }
  final raw = error.toString();
  if (raw.contains('Failed host lookup') ||
      raw.contains('SocketException') ||
      raw.contains('Network is unreachable')) {
    return 'Cannot reach the server. Check the PBX address, internet connection, and firewall.';
  }
  if (raw.contains('Connection timed out') || raw.contains('TimeoutException')) {
    return 'Connection timed out. Verify the server address and that WebSocket (WSS) is enabled on your PBX.';
  }
  if (raw.contains('Connection refused')) {
    return 'Connection refused. Check PBX WebRTC/WSS port (usually 8089).';
  }
  if (raw.contains('401') || raw.contains('403') || raw.contains('Unauthorized')) {
    return 'Wrong extension or password.';
  }
  if (raw.contains('your-pbx-domain') ||
      raw.contains('your-freepbx-domain') ||
      raw.contains('DioException')) {
    return 'Backend API is not configured. Sign in with SIP using your PBX address, extension, and password.';
  }
  if (raw.length > 160) {
    return '${raw.substring(0, 157)}…';
  }
  return raw;
}
