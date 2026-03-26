import 'package:flutter/material.dart';
import 'package:frontend/emoss_appbar.dart';
import 'package:frontend/emoss_sidebar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleOfflineLogic(String input) {
    String response = "I hear you. Can you tell me more about that?";
    String text = input.toLowerCase();

    if (text.contains("sad") || text.contains("lonely")) {
      response =
          "It's okay to feel this way. You're not alone, and I'm here to listen.";
    } else if (text.contains("anxious") || text.contains("stress")) {
      response =
          "Try to take three deep breaths. You've handled hard days before; you can handle this one too.";
    } else if (text.contains("happy") || text.contains("good")) {
      response =
          "That's wonderful! I'm glad you're having a bright moment. What made it special?";
    } else if (text.contains("tired") || text.contains("help")) {
      response = "Rest is important. Be gentle with yourself today.";
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => messages.add({"text": response, "sender": "ai"}));
        _scrollToBottom();
      }
    });
  }

  void _sendMessage() {
    String userText = _controller.text.trim(); // trim extra spaces/newlines
    if (userText.isEmpty) return;

    setState(() => messages.add({"text": userText, "sender": "user"}));
    _controller.clear();
    _scrollToBottom();

    // Call your AI/LLM or offline logic here
    _handleOfflineLogic(userText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: EmossAppBar(),
      drawer: const EmossSidebar(),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        "Hello. I am EMOSS.\n\nThis is a safe offline space.\nHow are you feeling right now?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      bool isUser = messages[index]["sender"] == "user";
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.all(16),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            gradient: isUser
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF6C63FF),
                                      Color.fromRGBO(75, 69, 178, 1),
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF252529),
                                      Color(0xFF1A1A1D),
                                    ],
                                  ),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isUser ? 20 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Text(
                            messages[index]["text"]!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _buildInputSection(),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Align(
      alignment: Alignment.bottomCenter, // Align to bottom
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ), // top padding lifts it
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1D),
            borderRadius: BorderRadius.circular(
              30,
            ), // rounded edges like ChatGPT
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Write your thoughts...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    border: InputBorder.none,
                    isDense: true, // reduces default height
                  ),
                  minLines: 1,
                  maxLines: 5, // allows multiline like ChatGPT
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: const CircleAvatar(
                  backgroundColor: Color(0xFF6C63FF),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
