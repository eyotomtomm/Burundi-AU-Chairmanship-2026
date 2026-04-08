import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

class LiveQAWidget extends StatefulWidget {
  final int sessionId;

  const LiveQAWidget({super.key, required this.sessionId});

  @override
  State<LiveQAWidget> createState() => _LiveQAWidgetState();
}

class _LiveQAWidgetState extends State<LiveQAWidget> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  final Set<int> _upvotingIds = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await ApiService().getLiveQASessions();
      // Find the session matching our sessionId and extract its questions
      final session = sessions.firstWhere(
        (s) => s['id'] == widget.sessionId,
        orElse: () => <String, dynamic>{},
      );

      if (mounted) {
        setState(() {
          _questions = session.containsKey('questions')
              ? List<Map<String, dynamic>>.from(
                  (session['questions'] as List).map(
                    (q) => Map<String, dynamic>.from(q as Map),
                  ),
                )
              : [];
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load questions.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiService().submitQAQuestion(widget.sessionId, question);

      if (!mounted) return;

      _questionController.clear();
      FocusScope.of(context).unfocus();

      // Add the new question to the list optimistically
      setState(() {
        _questions.insert(0, {
          'id': result['id'] ?? DateTime.now().millisecondsSinceEpoch,
          'question': question,
          'upvotes': 0,
          'author': result['author'] ?? 'You',
          'created_at': DateTime.now().toIso8601String(),
          'is_answered': false,
        });
        _isSubmitting = false;
      });

      // Scroll to top to show the new question
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } on ApiException catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.burundiRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to submit question. Try again.'),
          backgroundColor: AppColors.burundiRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _upvoteQuestion(int questionId) async {
    if (_upvotingIds.contains(questionId)) return;

    setState(() => _upvotingIds.add(questionId));

    try {
      await ApiService().upvoteQAQuestion(widget.sessionId, questionId);

      if (!mounted) return;

      // Optimistic update
      setState(() {
        final index = _questions.indexWhere((q) => q['id'] == questionId);
        if (index != -1) {
          _questions[index] = Map<String, dynamic>.from(_questions[index]);
          _questions[index]['upvotes'] = (_questions[index]['upvotes'] ?? 0) + 1;
        }
        _upvotingIds.remove(questionId);
      });
    } on ApiException catch (e) {
      setState(() => _upvotingIds.remove(questionId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.burundiRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _upvotingIds.remove(questionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with refresh button
        _buildHeader(isDark),
        const SizedBox(height: 12),

        // Question input
        _buildQuestionInput(isDark),
        const SizedBox(height: 14),

        // Questions list
        _buildQuestionsList(isDark),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.question_answer,
          size: 20,
          color: AppColors.auGold,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Live Q&A',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
        // Question count badge
        if (_questions.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.auGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_questions.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.auGold,
              ),
            ),
          ),
        // Refresh button
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            onPressed: _isLoading ? null : _loadQuestions,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.auGold),
                  )
                : Icon(
                    Icons.refresh,
                    size: 20,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
            padding: EdgeInsets.zero,
            tooltip: 'Refresh questions',
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionInput(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              maxLines: 3,
              minLines: 1,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              decoration: InputDecoration(
                hintText: 'Ask a question...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitQuestion(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Material(
                color: AppColors.burundiGreen,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _isSubmitting ? null : _submitQuestion,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList(bool isDark) {
    if (_isLoading && _questions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.auGold,
          ),
        ),
      );
    }

    if (_errorMessage != null && _questions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 32,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadQuestions,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.burundiGreen,
              ),
            ),
          ],
        ),
      );
    }

    if (_questions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 36,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 10),
            Text(
              'No questions yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to ask!',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      );
    }

    // Constrain list height for embedding: show up to ~4 questions
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.separated(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: _questions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final question = _questions[index];
          return _buildQuestionTile(question, isDark);
        },
      ),
    );
  }

  Widget _buildQuestionTile(Map<String, dynamic> question, bool isDark) {
    final questionId = question['id'] as int? ?? 0;
    final questionText = question['question'] as String? ?? '';
    final upvotes = question['upvotes'] as int? ?? 0;
    final author = question['author'] as String? ?? 'Anonymous';
    final isAnswered = question['is_answered'] == true;
    final isUpvoting = _upvotingIds.contains(questionId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAnswered
              ? AppColors.burundiGreen.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upvote button
          Column(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: isUpvoting ? null : () => _upvoteQuestion(questionId),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_drop_up,
                          size: 24,
                          color: isUpvoting
                              ? AppColors.auGold
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                '$upvotes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: upvotes > 0
                      ? AppColors.auGold
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Question content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  questionText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      author,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (isAnswered) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.burundiGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 10, color: AppColors.burundiGreen),
                            SizedBox(width: 3),
                            Text(
                              'Answered',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.burundiGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
