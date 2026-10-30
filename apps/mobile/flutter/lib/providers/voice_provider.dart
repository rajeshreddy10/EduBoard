import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/utilities/safe_json.dart';
import '../models/voice_block_model.dart';
import '../repositories/voice_repository.dart';
import 'whiteboard_provider.dart' show WhiteboardNotifier;

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  return LiveVoiceRepository();
});

class VoiceState {
  final bool isRecording;
  final bool isPaused;
  final String statusMessage;
  final String liveText;
  final String lastProcessedText;
  final List<VoiceBlockModel> blocks;
  final Duration elapsed;
  final double currentAudioLevel;
  final double confidence;
  final List<String> transcriptHistory;

  const VoiceState({
    this.isRecording = false,
    this.isPaused = false,
    this.statusMessage = 'Voice Board ready. Tap Start Recording to begin.',
    this.liveText = '',
    this.lastProcessedText = '',
    this.blocks = const [],
    this.elapsed = Duration.zero,
    this.currentAudioLevel = 0.0,
    this.confidence = 0.0,
    this.transcriptHistory = const [],
  });

  VoiceState copyWith({
    bool? isRecording,
    bool? isPaused,
    String? statusMessage,
    String? liveText,
    String? lastProcessedText,
    List<VoiceBlockModel>? blocks,
    Duration? elapsed,
    double? currentAudioLevel,
    double? confidence,
    List<String>? transcriptHistory,
  }) {
    return VoiceState(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      statusMessage: statusMessage ?? this.statusMessage,
      liveText: liveText ?? this.liveText,
      lastProcessedText: lastProcessedText ?? this.lastProcessedText,
      blocks: blocks ?? this.blocks,
      elapsed: elapsed ?? this.elapsed,
      currentAudioLevel: currentAudioLevel ?? this.currentAudioLevel,
      confidence: confidence ?? this.confidence,
      transcriptHistory: transcriptHistory ?? this.transcriptHistory,
    );
  }
}

class VoiceNotifier extends Notifier<VoiceState> {
  VoiceRepository get _repo => ref.read(voiceRepositoryProvider);
  StreamSubscription<List<VoiceBlockModel>>? _streamSub;
  Timer? _timer;
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _lastSentence = '';
  bool _speechInitialized = false;
  /// Stable id for the current recording session — set when a session is
  /// finished so the history snapshot for the SAME session id is reused.
  String _sessionId = '';

  @override
  VoiceState build() {
    ref.onDispose(() {
      _streamSub?.cancel();
      _timer?.cancel();
      try {
        _speech.stop();
      } catch (_) {}
    });

    Future.microtask(() => _init());
    return const VoiceState();
  }

  Future<void> _init() async {
    try {
      final initial = await _repo.getInitialBlocks();
      if (initial.isNotEmpty) {
        state = state.copyWith(blocks: initial);
      }
    } catch (e) {
      debugPrint('[Voice Init Warning] $e');
      state = state.copyWith(statusMessage: 'Offline. Previously saved transcripts shown when ready.');
    }

    _streamSub = _repo.watchVoiceBlocks().listen((liveBlocks) {
      if (liveBlocks.isNotEmpty) {
        state = state.copyWith(blocks: liveBlocks);
      }
    }, onError: (e) {
      debugPrint('[Voice Stream Warning] $e');
    });

    try {
      await Permission.microphone.request();
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    if (_speechInitialized) return;
    try {
      final available = await _speech.initialize(
        onError: (error) => debugPrint('[SpeechToText Error] $error'),
        onStatus: (status) => debugPrint('[SpeechToText Status] $status'),
      );
      _speechInitialized = available;
    } catch (e) {
      debugPrint('[SpeechToText Init Exception] $e');
      _speechInitialized = false;
    }
  }

  Future<void> startListening() async {
    _timer?.cancel();

    state = state.copyWith(
      isRecording: true,
      isPaused: false,
      statusMessage: 'Listening & transcribing lecture in real-time...',
      liveText: 'Listening...',
      currentAudioLevel: 0.65,
      confidence: 0.95,
      elapsed: Duration.zero,
    );

    await _initSpeech();

    if (_speechInitialized) {
      try {
        await _speech.listen(
          onResult: (result) {
            final recognized = result.recognizedWords;
            state = state.copyWith(
              liveText: recognized,
              confidence: result.confidence > 0 ? result.confidence : 0.95,
            );
            if (result.finalResult && recognized.isNotEmpty) {
              _processSentence(recognized);
            }
          },
        );
      } catch (e) {
        debugPrint('[SpeechToText Listen Exception] $e');
      }
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (state.isRecording && !state.isPaused) {
        state = state.copyWith(
          elapsed: state.elapsed + const Duration(seconds: 1),
          currentAudioLevel: (0.3 + ((t.tick % 6) * 0.12)).clamp(0.2, 1.0),
        );
      }
    });
  }

  /// Deduplication engine: filters out repeated phrases, duplicate sentences,
  /// and echoes from microphone pickup while applying proper capitalization and punctuation.
  String? dedupeSpeechText(String rawText, List<String> history) {
    final clean = rawText.trim();
    if (clean.isEmpty) return null;

    final lower = clean.toLowerCase();

    // 1. Direct repeat of previous sentence
    if (history.isNotEmpty) {
      final last = history.first.trim().toLowerCase();
      if (lower == last) return null;

      // 2. Substring of previous sentence (partial recognition echo)
      if (last.contains(lower) && lower.length < last.length) return null;

      // 3. Jaccard token similarity check (> 80% overlap is a duplicate echo)
      final newTokens = lower.split(RegExp(r'\s+')).toSet();
      final lastTokens = last.split(RegExp(r'\s+')).toSet();
      if (newTokens.isNotEmpty && lastTokens.isNotEmpty) {
        final intersection = newTokens.intersection(lastTokens).length;
        final union = newTokens.union(lastTokens).length;
        if (union > 0 && (intersection / union) > 0.82) {
          return null; // Drop duplicate phrase
        }
      }
    }

    // 4. Auto-punctuation & capitalization
    String formatted = clean[0].toUpperCase() + (clean.length > 1 ? clean.substring(1) : '');
    if (!formatted.endsWith('.') && !formatted.endsWith('?') && !formatted.endsWith('!')) {
      formatted += '.';
    }
    return formatted;
  }

  /// Extensible Voice Command Engine: interprets pedagogical voice commands
  /// spoken by the instructor and executes actions without polluting the board.
  bool _handleVoiceCommand(String text) {
    final lower = text.trim().toLowerCase();

    if (lower.contains('clear board') || lower.contains('clear canvas') || lower.contains('clear transcript')) {
      clearTranscript();
      state = state.copyWith(statusMessage: 'Voice Command: Board cleared.');
      return true;
    }

    if (lower == 'undo' || lower.contains('undo last')) {
      if (state.blocks.isNotEmpty) {
        deleteBlock(state.blocks.last.id);
        state = state.copyWith(statusMessage: 'Voice Command: Undo executed.');
      }
      return true;
    }

    if (lower.contains('save board') || lower.contains('save notes') || lower.contains('save session')) {
      _persistVoiceSessionToHistory();
      state = state.copyWith(statusMessage: 'Voice Command: Session saved to history.');
      return true;
    }

    if (lower.contains('color red') || lower.contains('color blue') || lower.contains('color azure') ||
        lower.contains('color green') || lower.contains('color emerald') ||
        lower.contains('color purple') || lower.contains('color violet')) {
      // Color commands are not applicable on the pure speech-to-text Voice Board.
      return true;
    }

    if (lower.contains('stop recording') || lower.contains('stop listening')) {
      stopRecording();
      state = state.copyWith(statusMessage: 'Voice Command: Stopped listening.');
      return true;
    }

    if (lower == 'pause' || lower.contains('pause listening')) {
      pauseListening();
      state = state.copyWith(statusMessage: 'Voice Command: Capture paused.');
      return true;
    }

    if (lower == 'resume' || lower.contains('resume listening')) {
      resumeListening();
      state = state.copyWith(statusMessage: 'Voice Command: Capture resumed.');
      return true;
    }

    return false;
  }

  void _processSentence(String sentence) {
    // 1. Check for voice commands first
    if (_handleVoiceCommand(sentence)) return;

    // 2. Filter through deduplication engine
    final clean = dedupeSpeechText(sentence, state.transcriptHistory);
    if (clean == null || clean == _lastSentence) return;
    _lastSentence = clean;

    final history = [clean, ...state.transcriptHistory].take(20).toList();
    state = state.copyWith(transcriptHistory: history, lastProcessedText: clean);
    _addToCanvas(clean);
  }

  Future<void> _addToCanvas(String text) async {
    final newPos = Offset(
      60.0 + (state.blocks.length * 30.0) % 200,
      180.0 + (state.blocks.length * 90.0) % 350,
    );
    try {
      final newBlock = await _repo.addVoiceTranscription(text, state.elapsed, newPos);
      state = state.copyWith(blocks: [...state.blocks, newBlock]);
    } catch (e) {
      debugPrint('[Voice Canvas Save Warning] $e');
      // Never lose the teacher's words: keep the block locally even if the
      // backend/Firestore write failed while offline.
      state = state.copyWith(
        blocks: [
          ...state.blocks,
          VoiceBlockModel(
            id: 'voice_local_${DateTime.now().millisecondsSinceEpoch}',
            text: text,
            speakerName: 'Instructor',
            timestamp: state.elapsed,
            position: newPos,
          ),
        ],
      );
    }
    state = state.copyWith(statusMessage: 'Transcript block saved to canvas');
  }

  void pauseListening() {
    try {
      _speech.stop();
    } catch (_) {}
    state = state.copyWith(
      isPaused: true,
      statusMessage: 'Voice capture paused.',
    );
  }

  void resumeListening() {
    state = state.copyWith(
      isPaused: false,
      statusMessage: 'Resuming listening...',
    );
    startListening();
  }

  void stopListening() {
    _timer?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
    final hadBlocks = state.blocks.isNotEmpty;
    state = state.copyWith(
      isRecording: false,
      isPaused: false,
      statusMessage: hadBlocks ? 'Saving voice session to your history…' : 'Session completed.',
      currentAudioLevel: 0.0,
      liveText: '',
      confidence: 0.0,
    );
    if (hadBlocks) {
      _persistVoiceSessionToHistory();
    }
  }

  /// Private lesson history: voice sessions live in the SAME `whiteboards`
  /// collection as drawing boards (category `voiceSession`) so they show up in
  /// the History hub on mobile and Web, and can be re-opened from there.
  Future<void> _persistVoiceSessionToHistory() async {
    try {
      final snapshot = state.blocks;
      final duration = state.elapsed;
      final now = DateTime.now();
      final stamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      // Stable per-session id: re-stopping (pause/resume) reuses the record.
      if (_sessionId.isEmpty) {
        _sessionId = WhiteboardNotifier.mintBoardId(prefix: 'voiceboard');
      }
      final session = _sessionId;
      await _repo.saveVoiceSessionToHistory(
        sessionId: session,
        title: 'Voice Session · $stamp',
        blocks: snapshot,
        duration: duration,
      );
      state = state.copyWith(
        statusMessage: 'Voice session saved to history (${snapshot.length} blocks · ${duration.inMinutes} min).',
      );
    } catch (e) {
      debugPrint('[Voice History Save Warning] $e');
      state = state.copyWith(statusMessage: 'Voice session finished — transcription blocks kept locally.');
    }
  }

  /// Re-open a saved voice session from the History hub deep link
  /// (`/voiceboard?id=...`): restores the transcription blocks of the ORIGINAL
  /// session instead of starting an empty canvas.
  Future<bool> loadVoiceSession(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return false;
    try {
      final data = await _repo.loadSavedVoiceSession(id);
      List<VoiceBlockModel> blocks = [];
      final blocksRaw = data['blocks'];
      if (blocksRaw is List && blocksRaw.isNotEmpty) {
        blocks = blocksRaw
            .whereType<Map>()
            .map((m) => VoiceBlockModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } else if (data['elements'] is List && (data['elements'] as List).isNotEmpty) {
        // Fallback for sessions created on Web: elements array
        final elements = data['elements'] as List;
        int i = 0;
        blocks = elements.whereType<Map>().map((e) {
          final text = e['text']?.toString() ?? '';
          final x = asDoubleOr(e['x'], 60.0 + (i * 30.0) % 200);
          final y = asDoubleOr(e['y'], 180.0 + (i * 90.0) % 350);
          i++;
          return VoiceBlockModel(
            id: e['id']?.toString() ?? 'voice_${DateTime.now().millisecondsSinceEpoch}_$i',
            text: text,
            speakerName: 'Instructor',
            timestamp: Duration(seconds: i * 5),
            position: Offset(x, y),
          );
        }).toList();
      } else if (data['transcript'] is String && (data['transcript'] as String).trim().isNotEmpty) {
        // Fallback for plain transcript text
        final lines = (data['transcript'] as String).split('\n').where((l) => l.trim().isNotEmpty).toList();
        int i = 0;
        blocks = lines.map((line) {
          i++;
          return VoiceBlockModel(
            id: 'voice_${DateTime.now().millisecondsSinceEpoch}_$i',
            text: line.trim(),
            speakerName: 'Instructor',
            timestamp: Duration(seconds: i * 5),
            position: Offset(60.0, 180.0 + (i * 60.0)),
          );
        }).toList();
      }

      if (blocks.isNotEmpty) {
        _lastSentence = '';
        state = state.copyWith(
          blocks: blocks,
          transcriptHistory: blocks.map((b) => b.text).take(20).toList(),
          elapsed: Duration(seconds: asIntOr(data['duration_seconds'], state.elapsed.inSeconds)),
          liveText: '',
          isPaused: false,
          statusMessage: 'Voice session restored — continuing "${data['title'] ?? 'saved session'}" (${blocks.length} blocks).',
        );
        _sessionId = id;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Voice Session Restore Warning] $e');
      return false;
    }
  }

  void clearTranscript() {
    state = state.copyWith(
      transcriptHistory: [],
      liveText: '',
      lastProcessedText: '',
      statusMessage: 'Transcript history cleared',
    );
  }

  Future<void> insertManualText(String text) async {
    if (text.trim().isNotEmpty) {
      await _addToCanvas(text.trim());
    }
  }

  void toggleRecording() {
    if (state.isRecording && !state.isPaused) {
      pauseListening();
    } else if (state.isRecording && state.isPaused) {
      resumeListening();
    } else {
      startListening();
    }
  }

  void startRecording() => startListening();
  void stopRecording([String? dictatedText]) {
    if (dictatedText != null && dictatedText.trim().isNotEmpty) {
      _addToCanvas(dictatedText.trim());
    }
    stopListening();
  }

  void updateBlockPosition(String id, Offset newPos) {
    final updated = state.blocks.map((b) {
      if (b.id == id) {
        return b.copyWith(position: newPos);
      }
      return b;
    }).toList();
    state = state.copyWith(blocks: updated);
    // Persist best-effort; repository swallows its own failures.
    _repo.saveBlockPosition(id, newPos).catchError((e) {
      debugPrint('[Voice Block Position Warning] $e');
    });
  }

  void deleteBlock(String id) {
    state = state.copyWith(
      blocks: state.blocks.where((b) => b.id != id).toList(),
    );
  }

  void editBlockText(String id, String newText) {
    final updated = state.blocks.map((b) {
      if (b.id == id) return b.copyWith(text: newText.trim());
      return b;
    }).toList();
    state = state.copyWith(blocks: updated);
  }

  void resizeBlockWidth(String id, double deltaWidth) {
    final updated = state.blocks.map((b) {
      if (b.id == id) {
        final newWidth = (b.width + deltaWidth).clamp(200.0, 500.0);
        return b.copyWith(width: newWidth);
      }
      return b;
    }).toList();
    state = state.copyWith(blocks: updated);
  }

  /// Explicit save: persists the current voice session to history.
  Future<void> saveSession() async {
    await _persistVoiceSessionToHistory();
  }
}

final voiceProvider = NotifierProvider<VoiceNotifier, VoiceState>(VoiceNotifier.new);
