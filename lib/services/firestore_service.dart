import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream for real-time questions
  Stream<QuerySnapshot<Map<String, dynamic>>> getQuestionsStream() {
    return _firestore.collection('questions').snapshots();
  }

  Future<bool> checkAnswer(String questionId, String submittedAnswer) async {
    final questionDoc =
        await _firestore.collection('questions').doc(questionId).get();
    final correctAnswer = questionDoc['answer'].toString().toLowerCase();
    return submittedAnswer.toLowerCase() == correctAnswer;
  }

  Future<void> decrementAttempt(String userId, String questionId) async {
    final userRef = _firestore.collection('users').doc(userId);

    final userData = await userRef.get();
    if (userData.exists) {
      final attempts = userData['attempts'] ?? {};
      final remaining = attempts[questionId] ?? 3;

      if (remaining > 0) {
        await userRef.update({
          'attempts.$questionId': remaining - 1,
        });
      } else {
        throw Exception('No attempts left for this question!');
      }
    }
  }

  Future<int> getRemainingAttempts(String userId, String questionId) async {
    final userRef = _firestore.collection('users').doc(userId);

    final userData = await userRef.get();
    if (userData.exists) {
      final attempts = userData['attempts'] ?? {};
      return attempts[questionId] ??
          3; // Default to 3 if no attempts are recorded
    }
    return 3;
  }

  Future<void> initializeUser(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);

    // Check if the user already exists
    final userDoc = await userRef.get();
    if (!userDoc.exists) {
      final user = FirebaseAuth.instance.currentUser;

      await userRef.set({
        'name': user?.displayName ??
            'Anonymous', // Fetch displayName or default to 'Anonymous'
        'totalEarnings': 0, // Default earnings
        'attempts': {}, // Empty attempts map
      });
    }
  }

  Future<void> registerUser(String email, String password, String name) async {
    // Create user
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update the Firebase user's display name
    await credential.user?.updateDisplayName(name);
    await credential.user?.reload();

    // Save user data to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(credential.user?.uid)
        .set({
      'name': name,
      'totalEarnings': 0, // Default earnings
      'attempts': {}, // Empty attempts map
    });
  }

  Future<void> updateUserName(String userId, String newName) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Update display name in Firebase Auth
      await user.updateDisplayName(newName);
      await user.reload();

      // Update Firestore data
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await userRef.update({'name': newName});
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getLeaderboard() {
    return _firestore
        .collection('users')
        .orderBy('totalEarnings', descending: true)
        .snapshots();
  }
}
