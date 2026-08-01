import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {

  static final SocketService instance = SocketService._internal();

  SocketService._internal();

  IO.Socket? socket;

  bool get isConnected => socket?.connected ?? false;

  void connect() {

    if (socket != null && socket!.connected) return;

    socket = IO.io(
      'http://34.22.87.81:3001',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket!.connect();

  }

  void joinRoom(int roomId, int userId) {

    socket?.emit('join_room', {
      'room_id': roomId,
      'user_id': userId,
    });

  }

  void sendMessage(int roomId, int userId, String message) {

    socket?.emit('send_message', {
      'room_id': roomId,
      'user_id': userId,
      'message': message,
    });

  }

  void onNewMessage(void Function(dynamic data) callback) {

    socket?.off('new_message');
    socket?.on('new_message', callback);

  }

  void onRoomEvent(String event, void Function(dynamic data) callback) {

    socket?.off(event);
    socket?.on(event, callback);

  }

  void disconnect() {

    socket?.disconnect();
    socket?.dispose();
    socket = null;

  }

}