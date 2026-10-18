//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_COMMENT_SHEET.DART                                           //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:flutter/material.dart';
import '../models/comment_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATIC MODAL LAUNCHER                                 //
class MytubeCommentSheet extends StatefulWidget {
  final String videoId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserAvatar;
  final bool isCurrentUserAdmin;

  const MytubeCommentSheet({
    super.key,
    required this.videoId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatar,
    this.isCurrentUserAdmin = false,
  });

  static void show(
    BuildContext context, {
    required String videoId,
    required String currentUserId,
    required String currentUserName,
    required String currentUserAvatar,
    bool isCurrentUserAdmin = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MytubeCommentSheet(
        videoId: videoId,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
        isCurrentUserAdmin: isCurrentUserAdmin,
      ),
    );
  }

  @override
  State<MytubeCommentSheet> createState() => _MytubeCommentSheetState();
}
//............................................................................//

//No ke-3....................................................................//
//STATE LIFECYCLE & CONTROLLERS                                              //
class _MytubeCommentSheetState extends State<MytubeCommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirestoreMytubeService _service = FirestoreMytubeService();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
//............................................................................//

//No ke-4....................................................................//
//COMMENT SUBMISSION LOGIC                                                   //
  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (widget.currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masuk terlebih dahulu untuk berkomentar.')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final newComment = CommentMytubeModel(
        id: '',
        videoId: widget.videoId,
        userId: widget.currentUserId,
        userName: widget.currentUserName.isNotEmpty ? widget.currentUserName : 'Pengguna',
        userAvatarUrl: widget.currentUserAvatar,
        commentText: text,
        isAdminComment: widget.isCurrentUserAdmin,
        createdAt: DateTime.now(),
      );

      await _service.addComment(
        videoId: widget.videoId,
        comment: newComment,
      );

      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim komentar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
//............................................................................//

//No ke-5....................................................................//
//UI LAYOUT & REAL-TIME STREAM LIST                                          //
  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.72,
      padding: EdgeInsets.only(bottom: keyboardPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Komentar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // List Komentar Realtime
          Expanded(
            child: StreamBuilder<List<CommentMytubeModel>>(
              stream: _service.getCommentsStream(widget.videoId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  );
                }

                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada komentar.\nJadilah yang pertama berkomentar!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return _buildCommentItem(comments[index]);
                  },
                );
              },
            ),
          ),

          // Bar Input Komentar
          _buildInputBar(),
        ],
      ),
    );
  }
//............................................................................//

//No ke-6....................................................................//
//COMMENT ITEM TILE & INPUT FIELD                                            //
  Widget _buildCommentItem(CommentMytubeModel comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white12,
          backgroundImage: comment.userAvatarUrl.isNotEmpty
              ? NetworkImage(comment.userAvatarUrl)
              : null,
          child: comment.userAvatarUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.white54, size: 18)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.userName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (comment.isAdminComment) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blueAccent, width: 0.5),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                comment.commentText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF151518),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Tambahkan komentar...',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.blueAccent, size: 22),
                    onPressed: _submitComment,
                  ),
          ],
        ),
      ),
    );
  }
}
//............................................................................//