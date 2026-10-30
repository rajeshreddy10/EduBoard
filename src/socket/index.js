const { verifyToken } = require('../middleware/auth');
const db = require('../config/db');

const connectedUsers = new Map();
const roomSessions = new Map();

function initializeSocket(io) {
  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (token) {
      try {
        // verifyToken is async (JWT first, Firebase ID second) — a missing
        // await silently produced `Promise` websocket identities.
        const decoded = await verifyToken(token);
        if (decoded && decoded.id) {
          socket.userId = decoded.id;
          socket.userRole = decoded.role;
          socket.userEmail = decoded.email;
        }
      } catch (err) {
        console.warn('[Socket] Token verification failed:', err?.message);
      }
    }
    next();
  });

  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id}${socket.userId ? ` (user: ${socket.userId})` : ''}`);

    if (socket.userId) {
      connectedUsers.set(socket.userId, { socketId: socket.id, joinedAt: Date.now() });
    }

    socket.on('join-board', async (data) => {
      const { boardId } = data;
      socket.join(`board:${boardId}`);
      socket.currentBoard = boardId;

      if (socket.userId && db.db) {
        try {
          db.db.collection('whiteboards').doc(boardId).collection('collaborators').doc(socket.userId).set({
            user_id: socket.userId,
            permission: 'edit',
            is_online: true,
            last_active_at: new Date().toISOString()
          }, { merge: true });
        } catch {}
      }

      socket.to(`board:${boardId}`).emit('user-joined', {
        userId: socket.userId,
        socketId: socket.id,
        timestamp: Date.now()
      });

      const room = io.sockets.adapter.rooms.get(`board:${boardId}`);
      const participantCount = room ? room.size : 0;
      io.to(`board:${boardId}`).emit('participant-count', participantCount);
    });

    socket.on('shape-add', (data) => {
      const { boardId, shape } = data;
      socket.to(`board:${boardId}`).emit('shape-added', {
        shape,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('shape-update', (data) => {
      const { boardId, shapeId, changes } = data;
      socket.to(`board:${boardId}`).emit('shape-updated', {
        shapeId, changes,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('shape-delete', (data) => {
      const { boardId, shapeId } = data;
      socket.to(`board:${boardId}`).emit('shape-deleted', {
        shapeId,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('shape-move', (data) => {
      const { boardId, shapeId, x, y } = data;
      socket.to(`board:${boardId}`).emit('shape-moved', {
        shapeId, x, y,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('cursor-move', (data) => {
      const { boardId, x, y } = data;
      socket.to(`board:${boardId}`).emit('cursor-moved', {
        userId: socket.userId,
        x, y,
        timestamp: Date.now()
      });
    });

    // Color-Coded Laser Pointer stream
    socket.on('laser-move', (data) => {
      const { boardId, x, y, color, mode } = data;
      socket.to(`board:${boardId}`).emit('laser-moved', {
        userId: socket.userId,
        x, y, color: color || '#ef4444', mode: mode || 'red',
        timestamp: Date.now()
      });
    });

    socket.on('freehand-draw', (data) => {
      const { boardId, points, shapeId } = data;
      socket.to(`board:${boardId}`).emit('freehand-drawing', {
        shapeId, points,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('undo', (data) => {
      const { boardId } = data;
      socket.to(`board:${boardId}`).emit('undo-action', {
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('redo', (data) => {
      const { boardId } = data;
      socket.to(`board:${boardId}`).emit('redo-action', {
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('clear-board', (data) => {
      const { boardId } = data;
      socket.to(`board:${boardId}`).emit('board-cleared', {
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('comment-add', (data) => {
      const { boardId, comment } = data;
      socket.to(`board:${boardId}`).emit('comment-added', {
        comment,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('chat-message', (data) => {
      const { boardId, message } = data;
      io.to(`board:${boardId}`).emit('chat-message', {
        message,
        userId: socket.userId,
        userName: socket.userEmail,
        timestamp: Date.now()
      });
    });

    socket.on('board-state', (data) => {
      const { boardId, shapes } = data;
      socket.to(`board:${boardId}`).emit('board-state-sync', {
        shapes,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('request-board-state', (data) => {
      const { boardId } = data;
      socket.to(`board:${boardId}`).emit('board-state-request', {
        requesterId: socket.id,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('send-board-state', (data) => {
      const { targetSocketId, shapes } = data;
      io.to(targetSocketId).emit('board-state-receive', {
        shapes,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('start-recording', (data) => {
      const { boardId } = data;
      socket.to(`board:${boardId}`).emit('recording-started', {
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('stop-recording', (data) => {
      const { boardId } = data;
      socket.to(`board:${boardId}`).emit('recording-stopped', {
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('presentation-start', (data) => {
      const { boardId } = data;
      socket.to(`board:${boardId}`).emit('presentation-started', {
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('presentation-next', (data) => {
      const { boardId, currentStep } = data;
      socket.to(`board:${boardId}`).emit('presentation-next-step', {
        currentStep,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('presentation-prev', (data) => {
      const { boardId, currentStep } = data;
      socket.to(`board:${boardId}`).emit('presentation-prev-step', {
        currentStep,
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('presentation-end', (data) => {
      const { boardId } = data;
      socket.to(`board:${boardId}`).emit('presentation-ended', {
        userId: socket.userId,
        timestamp: Date.now()
      });
    });

    socket.on('typing', (data) => {
      const { boardId, isTyping } = data;
      socket.to(`board:${boardId}`).emit('user-typing', {
        userId: socket.userId,
        isTyping,
        timestamp: Date.now()
      });
    });

    socket.on('leave-board', (data) => {
      const { boardId } = data;
      socket.leave(`board:${boardId}`);

      if (socket.userId && db.db) {
        try {
          db.db.collection('whiteboards').doc(boardId).collection('collaborators').doc(socket.userId).set({
            is_online: false,
            last_active_at: new Date().toISOString()
          }, { merge: true });
        } catch {}
      }

      socket.to(`board:${boardId}`).emit('user-left', {
        userId: socket.userId,
        socketId: socket.id,
        timestamp: Date.now()
      });

      const room = io.sockets.adapter.rooms.get(`board:${boardId}`);
      const participantCount = room ? room.size : 0;
      io.to(`board:${boardId}`).emit('participant-count', participantCount);

      socket.currentBoard = null;
    });

    socket.on('join-room', (data) => {
      const { roomId } = data;
      socket.join(`room:${roomId}`);
      socket.currentRoom = roomId;

      if (!roomSessions.has(roomId)) {
        roomSessions.set(roomId, new Map());
      }
      const session = roomSessions.get(roomId);
      session.set(socket.id, { userId: socket.userId, joinedAt: Date.now() });

      io.to(`room:${roomId}`).emit('room-joined', {
        userId: socket.userId,
        participantCount: session.size,
        timestamp: Date.now()
      });
    });

    socket.on('room-message', (data) => {
      const { roomId, message } = data;
      io.to(`room:${roomId}`).emit('room-message', {
        message,
        userId: socket.userId,
        userName: socket.userEmail,
        timestamp: Date.now()
      });
    });

    socket.on('disconnect', async () => {
      console.log(`Socket disconnected: ${socket.id}`);

      if (socket.userId) {
        connectedUsers.delete(socket.userId);
        const boardId = socket.currentBoard;
        if (boardId && db.db) {
          try {
            db.db.collection('whiteboards').doc(boardId).collection('collaborators').doc(socket.userId).set({
              is_online: false,
              last_active_at: new Date().toISOString()
            }, { merge: true });
          } catch {}
          io.to(`board:${boardId}`).emit('user-left', {
            userId: socket.userId,
            socketId: socket.id,
            timestamp: Date.now()
          });
        }
        if (socket.currentRoom) {
          const session = roomSessions.get(socket.currentRoom);
          if (session) {
            session.delete(socket.id);
            if (session.size === 0) roomSessions.delete(socket.currentRoom);
          }
        }
      }
    });
  });

  return io;
}

function getConnectedUsers() {
  return Array.from(connectedUsers.entries()).map(([userId, data]) => ({
    userId,
    socketId: data.socketId,
    joinedAt: data.joinedAt
  }));
}

module.exports = initializeSocket;
