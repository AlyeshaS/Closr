// Inside lib/screens/activities/trivia/trivia_game_screen.dart
String _myUid = '';
String _partnerUid = ''; // ✨ Added to track the partner target document
bool _initializingAuth = true;

void _resolveCurrentUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    _myUid = user.uid;

    // Fetch user profile info to find partnerUid up front
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_myUid)
        .get();
    if (userDoc.exists && mounted) {
      final partnerEmailLower = userDoc.data()?['partnerEmailLower'] ?? '';
      if (partnerEmailLower.isNotEmpty) {
        final partnerQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('emailLower', isEqualTo: partnerEmailLower)
            .get();
        if (partnerQuery.docs.isNotEmpty) {
          setState(() {
            _partnerUid = partnerQuery.docs.first.id;
          });
        }
      }
    }
  }
  setState(() => _initializingAuth = false);
}
