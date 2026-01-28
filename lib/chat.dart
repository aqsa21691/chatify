import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  late DatabaseReference _chatRef;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatRef = FirebaseDatabase.instance.ref('chat/${_chatId()}');
  }

  String sanitizeId(String id) => id.replaceAll(RegExp(r'[.#$\[\]]'), '_');

  String _chatId() {
    final currentId = sanitizeId(widget.currentUserId);
    final receiverId = sanitizeId(widget.receiverId);

    return currentId.hashCode <= receiverId.hashCode
        ? "${currentId}_$receiverId"
        : "${receiverId}_$currentId";
  }

  void sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final msg = {
      "message": text,
      "senderId": widget.currentUserId,
      "senderName": widget.currentUserName,
      "receiverId": widget.receiverId,
      "receiverName": widget.receiverName,
      "timestamp": ServerValue.timestamp,
    };

    _msgController.clear();
    _chatRef.push().set(msg).then((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String formatTime(dynamic timestamp) {
    if (timestamp == null) return "Sending...";
    final date = DateTime.fromMillisecondsSinceEpoch(
        timestamp is int ? timestamp : timestamp.toInt());
    return DateFormat("hh:mm a").format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ⭐ WhatsApp-style keyboard behavior
      backgroundColor: const Color(0xfffaf7f8),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          widget.receiverName,
          style: const TextStyle(
            color: Color.fromARGB(255, 1, 61, 14),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 1, 61, 14)),
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _chatRef.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(
                    child: Text(
                      "Start chatting...",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final value = snapshot.data!.snapshot.value;
                final messagesMap =
                    Map<String, dynamic>.from(value as Map<dynamic, dynamic>);

                final messagesList = messagesMap.entries
                    .map((e) => Map<String, dynamic>.from(
                        e.value as Map<dynamic, dynamic>))
                    .toList()
                  ..sort((a, b) =>
                      (a['timestamp'] as int).compareTo(b['timestamp'] as int));

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messagesList.length,
                  itemBuilder: (context, index) {
                    final data = messagesList[index];
                    final isMe = data["senderId"] == widget.currentUserId;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            data["senderName"],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 1, 61, 14),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color.fromARGB(255, 1, 61, 14)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  data["message"],
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatTime(data["timestamp"]),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMe
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          /// ⭐ WHATSAPP STYLE INPUT BAR — EXACT BEHAVIOR
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Color.fromARGB(255, 1, 61, 14),
                      size: 28,
                    ),
                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
