import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:musify/auth/login.dart';
import 'package:musify/db/db_services.dart';

class FirstScreen extends StatefulWidget {
  const FirstScreen({super.key});

  @override
  _FirstScreenState createState() => _FirstScreenState();
}

class _FirstScreenState extends State<FirstScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final FirestoreServices fs = FirestoreServices();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  Color _appBarColor = Colors.transparent;
  List<Map<String, dynamic>> _songs = [];
  List<Map<String, dynamic>> _filteredSongs = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  List<String> Ltitles = [];

  @override
  void initState() {
    super.initState();
    _fetchLikedSongTitles();
    _fetchSongs();
    _focusNode.addListener(() {
      setState(() {
        _appBarColor = _focusNode.hasFocus ? Colors.white : Colors.transparent;
      });
    });

    _audioPlayer.onDurationChanged.listen((Duration d) {
      setState(() {
        _duration = d;
      });
    });

    _audioPlayer.onPositionChanged.listen((Duration p) {
      setState(() {
        _position = p;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      setState(() {
        _isPlaying = s == PlayerState.playing;
      });
    });

    // Listen to changes in the search bar and filter the song list
    _searchController.addListener(_filterSongs);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchLikedSongTitles() async {
    List<String> titles = await getLikedSongTitles();
    setState(() {
      Ltitles = titles;
    });
  }

  Future<List<String>> getLikedSongTitles() async {
    String currentUserId = uid;

    DocumentReference userDoc =
        FirebaseFirestore.instance.collection('Users').doc(currentUserId);

    DocumentSnapshot docSnapshot = await userDoc.get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      List<dynamic> lsongs = docSnapshot.get('Lsongs') ?? [];

      List<String> titles = lsongs.map<String>((song) {
        return song['title'] ?? 'Unknown Title';
      }).toList();

      return titles;
    }

    return [];
  }

  Future<void> _fetchSongs() async {
    final CollectionReference usersCollection =
        FirebaseFirestore.instance.collection('Users');

    final QuerySnapshot querySnapshot = await usersCollection.get();

    List<Map<String, dynamic>> songsList = [];

    for (var doc in querySnapshot.docs) {
      List<dynamic> songs = doc['songs'] ?? [];
      for (var song in songs) {
        if (song is Map<String, dynamic> && song.containsKey('url')) {
          songsList.add({
            'title': song['title'] ?? 'Unknown Title',
            'url': song['url'],
          });
        }
      }
    }

    setState(() {
      _songs = songsList;
      _filteredSongs = songsList; // Initialize filtered list with all songs
    });
  }

  void _filterSongs() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredSongs = _songs
          .where((song) => song['title'].toLowerCase().contains(query))
          .toList();
    });
  }

  void _playMusic(String url, String title) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    await _audioPlayer.play(UrlSource(url));
    _showMusicDialog(url, title);
  }

  void _pauseMusic() async {
    await _audioPlayer.pause();
  }

  void _seekMusic(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void _showMusicDialog(String url, String title) {
    bool isLiked = Ltitles.contains(title);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            _audioPlayer.onDurationChanged.listen((Duration d) {
              setDialogState(() {
                _duration = d;
              });
            });

            _audioPlayer.onPositionChanged.listen((Duration p) {
              setDialogState(() {
                _position = p;
              });
            });

            return Dialog(
              backgroundColor: Colors.black.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 36,
                          ),
                          onPressed: () {
                            if (_isPlaying) {
                              _pauseMusic();
                            } else {
                              _playMusic(url, title);
                            }
                            setDialogState(() {});
                          },
                        ),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                offset: Offset(1.5, 1.5),
                                blurRadius: 2,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 36,
                          ),
                          onPressed: () {
                            if (isLiked) {
                              fs.removeSong(url, uid, title);
                              setDialogState(() {
                                isLiked = false;
                                Ltitles.remove(title);
                              });
                            } else {
                              fs.uploadSong(url, uid, title, 'Lsongs');
                              setDialogState(() {
                                isLiked = true;
                                Ltitles.add(title);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Slider(
                      activeColor: Colors.purple,
                      inactiveColor: Colors.grey,
                      value: _position.inSeconds
                          .toDouble()
                          .clamp(0.0, _duration.inSeconds.toDouble()),
                      min: 0.0,
                      max: (_duration.inSeconds > 0)
                          ? _duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (double value) {
                        _seekMusic(Duration(seconds: value.toInt()));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_position)),
                          Text(_formatDuration(_duration)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        _audioPlayer.stop();
                        Navigator.of(context).pop();
                      },
                      child: const Text("Close"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    // ignore: use_build_context_synchronously
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) =>
          const LoginScreen(), // Replace with your actual login screen
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _appBarColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: _searchController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search for a song...',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _filteredSongs.length,
        itemBuilder: (context, index) {
          final song = _filteredSongs[index];
          return ListTile(
            title: Text(song['title']),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _playMusic(song['url'], song['title']),
            ),
          );
        },
      ),
    );
  }
}
