import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

/// Live collaboration transport to the EduBoard backend.
///
/// Reconnection notes (network interruption handling):
///   - socket.io auto-reconnects with exponential backoff by default.
///   - Every (re)connect refreshes the auth payload with a fresh Firebase ID
///     token so long-lived connections never keep serving expired tokens.
///   - Connect errors don't tear the socket down; they surface a state stream
///     that the UI can read instead of crashing.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _currentBoardId;
  bool _intentionallyClosed = false;
  int _connectAttempts = 0;
  bool _connecting = false;

  final _shapeAddedController = StreamController<Map<String, dynamic>>.broadcast();
  final _shapeUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _shapeDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _boardClearedController = StreamController<void>.broadcast();
  final _participantCountController = StreamController<int>.broadcast();
  final _connectionStateController = StreamController<SocketConnectionState>.broadcast();

  Stream<Map<String, dynamic>> get onShapeAdded => _shapeAddedController.stream;
  Stream<Map<String, dynamic>> get onShapeUpdated => _shapeUpdatedController.stream;
  Stream<Map<String, dynamic>> get onShapeDeleted => _shapeDeletedController.stream;
  Stream<void> get onBoardCleared => _boardClearedController.stream;
  Stream<int> get onParticipantCount => _participantCountController.stream;
  Stream<SocketConnectionState> get connectionState => _connectionStateController.stream;

  bool get isConnected => _socket?.connected ?? false;
  int get connectAttempts => _connectAttempts;

  /// Safest obtainable auth identity: fresh Firebase ID token, falling back to
  /// the cached Firebase token or the backend JWT.
  Future<String?> _obtainAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    return ApiClient().getToken();
  }

  void connect([String? token]) {
    if (_socket != null && (_socket!.connected || _connecting)) return;
    _intentionallyClosed = false;
    _connecting = true;

    final wsUrl = ApiClient.defaultWsUrl;
    _connectAttempts++;

    _socket?.dispose();
    _socket = io.io(
      wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(8)
          .setReconnectionDelay(1500)
          .setReconnectionDelayMax(8000)
          .build(),
    );

    // Refresh the auth header on every fresh attempt so long reconnect
    // cycles never send a stale/expired token.
    final opts = _socket?.io.options;
    if (opts != null) {
      opts['auth'] = {'token': token};
    }

    _socket!.onConnect((_) {
      _connecting = false;
      _connectAttempts = 0;
      debugPrint('[SocketService] Connected to $wsUrl');
      _connectionStateController.add(SocketConnectionState.connected);
      if (_currentBoardId != null) {
        joinBoard(_currentBoardId!);
      }
    });

    _socket!.onConnectError((data) {
      debugPrint('[SocketService] Connect error: $data');
      _connectionStateController.add(SocketConnectionState.reconnecting);
    });

    _socket!.onDisconnect((_) {
      _connecting = false;
      debugPrint('[SocketService] Disconnected');
      if (!_intentionallyClosed) {
        _connectionStateController.add(SocketConnectionState.reconnecting);
      }
    });

    _socket!.on('shape-added', (data) {
      if (data is Map) {
        _shapeAddedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('shape-updated', (data) {
      if (data is Map) {
        _shapeUpdatedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('shape-deleted', (data) {
      if (data is Map) {
        _shapeDeletedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('clear-board', (_) {
      _boardClearedController.add(null);
    });

    _socket!.on('participant-count', (count) {
      if (count is int) {
        _participantCountController.add(count);
      } else if (count is num) {
        _participantCountController.add(count.round());
      }
    });

    _socket!.connect();
  }

  /// Connects asynchronously, resolving a fresh auth token first.
  ///
  /// The synchronous [connect] remains for existing call sites; this variant
  /// guarantees credential freshness on every (re)join.
  Future<void> connectAsync() async {
    if (isConnected || _connecting) return;
    final token = await _obtainAuthToken();
    connect(token);
  }

  void joinBoard(String boardId) {
    _currentBoardId = boardId;
    if (isConnected) {
      _socket!.emit('join-board', {'boardId': boardId});
    }
  }

  void emitShapeAdd(String boardId, Map<String, dynamic> shape) {
    if (isConnected) {
      _socket!.emit('shape-add', {'boardId': boardId, 'shape': shape});
    }
  }

  void emitShapeDelete(String boardId, String shapeId) {
    if (isConnected) {
      _socket!.emit('shape-delete', {'boardId': boardId, 'shapeId': shapeId});
    }
  }

  void emitClearBoard(String boardId) {
    if (isConnected) {
      _socket!.emit('clear-board', {'boardId': boardId});
    }
  }

  void leaveBoard(String boardId) {
    if (isConnected) {
      _socket!.emit('leave-board', {'boardId': boardId});
    }
    if (_currentBoardId == boardId) _currentBoardId = null;
  }

  void disconnect() {
    _intentionallyClosed = true;
    _connecting = false;
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _connectionStateController.add(SocketConnectionState.disconnected);
  }
}

enum SocketConnectionState { connected, reconnecting, disconnected }
