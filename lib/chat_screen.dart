import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive/hive.dart';

class SimpleChatScreen extends StatefulWidget {
  const SimpleChatScreen({super.key});

  @override
  State<SimpleChatScreen> createState() => _SimpleChatScreenState();
}

class _SimpleChatScreenState extends State<SimpleChatScreen> {
  final TextEditingController _controller = TextEditingController();

  List<Map<String, String>> messages = [];

  late Box chatBox;

  final String apiKey = "OPENROUTER_API_KEY";

  String? selectedMode;
  bool showModeSelector = true;

  // ---------------- SYSTEM PROMPT ----------------
  static const String _systemPrompt = '''
You are Code Buddy, a friendly and knowledgeable programming assistant.
Your ONLY purpose is to help with coding and programming questions.

Rules:
- Only answer programming-related questions
- Keep answers simple and beginner-friendly
- Use code examples when needed
- Be encouraging
''';

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    chatBox = Hive.box('chatBox');
    loadMessages();
  }

  // ---------------- LOAD ----------------
  void loadMessages() {
    final data = chatBox.get('messages');

    if (data != null) {
      messages = List<Map<String, String>>.from(
        (data as List).map((e) => Map<String, String>.from(e)),
      );
    }

    setState(() {});
  }

  // ---------------- SAVE ----------------
  void saveMessages() {
    chatBox.put('messages', messages);
  }

  void updateChat() {
    chatBox.put('messages', messages);
  }

  // ---------------- MODE SELECTOR ----------------
  Widget buildModeSelector() {
    final modes = ["Dart", "Python", "Java", "C++", "Compare"];

    if (!showModeSelector) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Wrap(
        spacing: 8,
        children: modes.map((mode) {
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              setState(() {
                selectedMode = mode;
                showModeSelector = false;

                String text = mode == "Compare"
                    ? "Compare Dart vs Python vs Java"
                    : "Explain $mode programming";

                messages.add({
                  "role": "user",
                  "content": text,
                });
              });

              saveMessages();

              sendMessage(
                mode == "Compare"
                    ? "Compare Dart vs Python vs Java in simple table"
                    : "Explain $mode programming with examples",
              );
            },
            child: Text(mode, style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
      ),
    );
  }

  // ---------------- CLEAR CHAT ----------------
  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat"),
        content: const Text("Are you sure you want to delete all messages?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                messages.clear();
                showModeSelector = true;
                selectedMode = null;
              });

              chatBox.delete('messages');

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chat cleared")),
              );
            },
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------------- DELETE MESSAGE ----------------
  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message"),
        content: const Text("Do you want to delete this message?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                messages.removeAt(index);
              });

              saveMessages();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Message deleted")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------------- SEND MESSAGE ----------------
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add({"role": "user", "content": text});
    });

    saveMessages();

    _controller.clear();

    final response = await http.post(
      Uri.parse("https://openrouter.ai/api/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "openai/gpt-4o-mini",
        "messages": [
          {"role": "system", "content": _systemPrompt},
          ...messages,
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final reply = data["choices"][0]["message"]["content"];

      setState(() {
        messages.add({"role": "assistant", "content": reply});
      });

      saveMessages();
    } else {
      setState(() {
        messages.add({
          "role": "assistant",
          "content": "Error: ${response.statusCode}"
        });
      });

      saveMessages();
    }
  }

  // ---------------- EMPTY UI ----------------
  Widget buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.code, size: 60, color: Color(0xFF3B0764)),
            SizedBox(height: 10),
            Text(
              "Code Buddy",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B0764)),
            ),
            SizedBox(height: 8),
            Text(
              "Ask about Dart, Python, Java, C++, CSS, HTML",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7C3AED)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- MESSAGE UI ----------------
  Widget buildMessage(Map<String, String> msg, int index) {
    bool isUser = msg["role"] == "user";

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text("Copy"),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(
                      ClipboardData(text: msg["content"] ?? ""),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Copied")),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text("Delete"),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteDialog(index);
                  },
                ),
              ],
            );
          },
        );
      },
      child: Align(
        alignment:
            isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser
                ? const Color(0xFF7C3AED).withValues(alpha: 0.9)
                : const Color(0xFF6B6196).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: MarkdownBody(
            data: msg["content"] ?? "",
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                color: isUser
                    ? const Color(0xFFF5F0FF)
                    : const Color(0xFF1E0A3C),
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCABAE9),

      appBar: AppBar(
        title: const Text("Code Buddy"),
        backgroundColor: const Color(0xFF3B0764),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: messages.isEmpty ? null : _confirmClearChat,
          ),
        ],
      ),

      body: Column(
        children: [
          buildModeSelector(),

          Expanded(
            child: messages.isEmpty
                ? buildEmptyState()
                : ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (_, i) => buildMessage(messages[i], i),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send,
                      color: Color(0xFF6B21A8)),
                  onPressed: () =>
                      sendMessage(_controller.text),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}