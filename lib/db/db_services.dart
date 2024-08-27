import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreServices {
  final CollectionReference users =
      FirebaseFirestore.instance.collection('Users');

  Future<void> uploadSong(
      String url, String uid, String title, String array) async {
    try {
      await FirebaseFirestore.instance.collection("Users").doc(uid).set({
        array: FieldValue.arrayUnion([
          {
            'title': title,
            'url': url,
          }
        ])
      }, SetOptions(merge: true));
      print('Song uploaded successfully');
    } catch (e) {
      print('Failed to upload song: $e');
    }
  }

  Future<void> removeSong(String url, String uid, String title) async {
    try {
      await FirebaseFirestore.instance.collection("Users").doc(uid).update({
        'Lsongs': FieldValue.arrayRemove([
          {
            'title': title,
            'url': url,
          }
        ])
      });
      print('Song removed successfully');
    } catch (e) {
      print('Failed to remove song: $e');
    }
  }

  Stream<QuerySnapshot> readSongs() {
    final songs = users.orderBy('time', descending: true).snapshots();
    return songs;
  }
}
