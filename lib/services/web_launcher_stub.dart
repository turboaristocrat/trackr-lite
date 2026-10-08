// Stub implementation for non-web platforms
bool canWebShare() => false;

Future<bool> triggerWebShare(String title, String text) async => false;

void openExternalUriDirect(String uri) {
  // No-op or native handling
}
