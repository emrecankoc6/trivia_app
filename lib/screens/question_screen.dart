import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({Key? key}) : super(key: key);

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _answerController = TextEditingController();

  Future<void> _submitAnswer(String questionId) async {
    final answer = _answerController.text.trim();

    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an answer.')),
      );
      return;
    }

    try {
      // Decrement the user's remaining attempts
      await _firestoreService.decrementAttempt(userId, questionId);

      // Check if the answer is correct
      final isCorrect = await _firestoreService.checkAnswer(questionId, answer);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isCorrect ? '🎉 Correct!' : '❌ Incorrect.')),
      );

      if (isCorrect) {
        // Optionally, move to the next question or perform other actions
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      // Clear the input field
      _answerController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trivia Questions')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getQuestionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No questions available.'));
          }

          final questions = snapshot.data!.docs;

          return ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              final hints = List.from(question['hints']);
              final prizePool = question['prizePool'];
              final questionId = question.id;

              return FutureBuilder<int>(
                future:
                    _firestoreService.getRemainingAttempts(userId, questionId),
                builder: (context, attemptsSnapshot) {
                  if (!attemptsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final remainingAttempts = attemptsSnapshot.data!;

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question ${index + 1}: ${hints[0]}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('Hints: ${hints.join(', ')}'),
                          const SizedBox(height: 8),
                          Text('Prize Pool: $prizePool'),
                          const SizedBox(height: 8),
                          Text('Remaining Attempts: $remainingAttempts'),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _answerController,
                            decoration: const InputDecoration(
                              labelText: 'Your Answer',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: remainingAttempts > 0
                                ? (value) {
                                    _submitAnswer(questionId);
                                  }
                                : null,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: remainingAttempts > 0
                                ? () {
                                    _submitAnswer(questionId);
                                  }
                                : null,
                            child: const Text('Submit Answer'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
