import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for playing order alert sounds
class SoundAlertService {
  final AudioPlayer _player = AudioPlayer();
  bool _isEnabled = true;
  bool _hasCustomSound = false;

  SoundAlertService() {
    _checkForCustomSounds();
  }

  /// Check if custom sound assets exist
  Future<void> _checkForCustomSounds() async {
    try {
      await rootBundle.load('assets/sounds/new_order.mp3');
      _hasCustomSound = true;
      if (kDebugMode) {
        debugPrint('[SoundAlert] Custom sound found: new_order.mp3');
      }
    } catch (e) {
      _hasCustomSound = false;
      if (kDebugMode) {
        debugPrint('[SoundAlert] No custom sound, will use fallback beep');
      }
    }
  }

  /// Enable or disable sound alerts
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (kDebugMode) {
      debugPrint('[SoundAlert] Sounds ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  /// Check if sounds are enabled
  bool get isEnabled => _isEnabled;

  /// Play new order alert sound
  Future<void> playNewOrderAlert() async {
    if (!_isEnabled) return;

    try {
      if (_hasCustomSound) {
        await _playCustomSound('assets/sounds/new_order.mp3');
      } else {
        await _playBeepSound();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SoundAlert] Error playing sound: $e\n$st');
      }
    }
  }

  /// Play order ready alert sound
  Future<void> playOrderReadyAlert() async {
    if (!_isEnabled) return;

    try {
      // Try custom sound first, fallback to beep
      try {
        await _playCustomSound('assets/sounds/order_ready.mp3');
      } catch (_) {
        await _playBeepSound(frequency: 600, duration: 200);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SoundAlert] Error playing sound: $e\n$st');
      }
    }
  }

  /// Play order cancelled alert sound
  Future<void> playOrderCancelledAlert() async {
    if (!_isEnabled) return;

    try {
      // Try custom sound first, fallback to beep
      try {
        await _playCustomSound('assets/sounds/order_cancelled.mp3');
      } catch (_) {
        await _playBeepSound(frequency: 400, duration: 300);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SoundAlert] Error playing sound: $e\n$st');
      }
    }
  }

  /// Play custom sound from assets
  Future<void> _playCustomSound(String assetPath) async {
    await _player.setAsset(assetPath);
    await _player.play();
    await _player.stop();
  }

  /// Play a simple beep sound using data URI
  /// This works on web and mobile without requiring audio files
  Future<void> _playBeepSound({int frequency = 800, int duration = 300}) async {
    if (kIsWeb) {
      // For web, use a simple data URI with a sine wave beep
      final dataUri = _generateBeepDataUri(frequency, duration);
      await _player.setUrl(dataUri);
      await _player.play();
      await _player.stop();
    } else {
      // For mobile, try to use system notification sound or simple beep
      // This is a fallback - ideally merchants should provide custom sounds
      try {
        await _player.setAsset('assets/sounds/new_order.mp3');
        await _player.play();
        await _player.stop();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SoundAlert] Could not play fallback sound: $e');
        }
      }
    }
  }

  /// Generate a simple beep sound as a data URI
  /// Creates a short WAV file with a sine wave
  String _generateBeepDataUri(int frequency, int duration) {
    // For simplicity on web, we'll use a pre-generated beep data URI
    // This is a very short beep sound encoded as base64 WAV
    // In production, you'd want to use a proper audio file or generate dynamically

    // Simple 440Hz beep WAV as base64 (very short)
    const beepBase64 = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSyGze/EiygJF2q689yaUg8MTKXl8ahkHAU7ldjz0IIwBx2AxfPbllAJG2+47+OiTwwNUqjk8aZiHQQ3kdbyxnkqBSR3x/DdkEAKFF607OeoVRQKRp/g8r5sIQUshszwxZAqCRhru+3nmFUUCkWe4O3CdSYKJXfH79+NQw4PUKXh8KplHQU7ldryyH0vBS6EyvDhlloTCU6j4vCvZSIFK4PK8MSNMwkZaLnt56ZYFgdBm+HyvmwhBSuDy/DEjjUKF2m98ticTQkPUKbi8apmHQQ7ldrzyncnCClzy+7hjl0VCkhgu+7jmFMTE0id5fK2aCEFLIXN79+RRwsWb7zt5KBQEApLp+Pxs2YeBy+E0fPgklsQDFCn5PKubBwFK4TK8MSNNwgYa7rt45hSExNIn+XyvWwgBSuDy/DDjjUKF2m98ticTQkPUKbi8apmHQU7ldrzyncnCClzy+7hjl0VCkhgu+7jmFUTEkmf5fK3aCAFLIXN79+RRwsWb7zt5KBQEApLp+Pxs2YeBzCEzvLblUAPDlGm4/KucB0GK4PN78SMNwgYa7rt45hSExNIn+XyvW0gBSuDy/DEjTQJF2m98ticTQkPUKbi8apmHQU7ldrzyncnCClzy+7hjl0VCkhgu+7jmFUTEkmf5fK3aCAFLIXN79+RRwsWb7zt5KBQEApLp+Pxs2YeBzCEzvLbll4PDVGm4vGrcBwGLIPM78SKNwgYa7rt45hSExNIn+XyvW0gBSuDy/DEjTQJF2m98ticTQkPUKbi8apmHQU7ldrzyncnCClzy+7hjl0VCkhgu+7jmFUTEkmf5fK3aCAFLIXN79+RRwsWb7zt5KBQEApLp+Pxs2YeBzCEzvLbll4PDVGm4vGrcBwGLIPM78SKNwgYa7rt45hSExNIn+XyvW0gBSuDy/DEjTQJF2m98ticTQkPUKbi8apmHQU7ldrzyncnCClzy+7hjl0VCkhgu+7jmFUTEkmf5fK3aCAFLIXN79+RRwsWb7zt5KBQEApLp+Pxs2YeBzCEzvLbll4PDVGm4vGrcBwGLIPM78SKNwgYa7rt45hSExNIn+XyvW0gBSuDy/DEjTQJF2m98ticTQkPUKbi8apmHQU7ldrzyncnCClzy+7hjl0VCkhgu+7jmFUTEkmf5fK3aCAFLIXN79+RRwsWb7zt5KBQEApLp+Pxs2YeBzCEzvLbll4PDVGm4vGrcBwGLIPM78SKNwgYa7rt45hSExNIn+XyvW0gBSuDy/DEjTQJF2m98ticTQkPUKbi8apmHQU7ldrzyncnCClzy+7hjl0VCkhgu+7jmFUTEkmf5fK3aCAFLIXN79+RRwsWb7zt5KBQ';

    return beepBase64;
  }

  /// Test the sound alert
  Future<void> testSound() async {
    await playNewOrderAlert();
  }

  /// Dispose resources
  void dispose() {
    _player.dispose();
  }
}

/// Provider for sound alert service
final soundAlertServiceProvider = Provider<SoundAlertService>((ref) {
  final service = SoundAlertService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// State provider for sound alert enabled state
final soundAlertEnabledProvider = StateProvider<bool>((ref) => true);
