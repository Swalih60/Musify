import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final TextEditingController t = TextEditingController();
  final FirestoreServices fs = FirestoreServices();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _songs = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _fetchLikedSongs();

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
  }

  Future<void> _fetchLikedSongs() async {
    DocumentSnapshot docSnapshot =
        await FirebaseFirestore.instance.collection('Users').doc(uid).get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      List<dynamic> lsongs = docSnapshot.get('songs') ?? [];

      List<Map<String, dynamic>> songsList =
          lsongs.map<Map<String, dynamic>>((song) {
        return {
          'title': song['title'] ?? 'Unknown Title',
          'url': song['url'],
        };
      }).toList();

      setState(() {
        _songs = songsList;
      });
    }
  }

  Future<void> _pickAndUploadFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;

      if (file.bytes != null) {
        String fileName = basename(file.name);

        try {
          FirebaseStorage storage = FirebaseStorage.instance;
          TaskSnapshot uploadTask =
              await storage.ref('uploads/$uid/$fileName').putData(file.bytes!);

          String downloadUrl = await uploadTask.ref.getDownloadURL();
          await fs.uploadSong(downloadUrl, uid, t.text, 'songs');
          Navigator.of(context).pop();

          print('File uploaded: $downloadUrl');
        } catch (e) {
          print('File upload failed: $e');
        }
      } else {
        print('File bytes are null');
      }
    } else {
      print('No file selected');
    }
  }

  void _playMusic(String url, String title, BuildContext ctx) async {
    try {
      await _audioPlayer.play(UrlSource(url));
      _showMusicDialog(
          ctx, url, title); // Pass the context here without casting
    } catch (e) {
      print("Error playing music: $e");
    }
  }

  void _pauseMusic() async {
    await _audioPlayer.pause();
  }

  void _seekMusic(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void _showMusicDialog(BuildContext context, String url, String title) {
    // bool isLiked = _songs.any((song) => song['title'] == title);

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
                      mainAxisAlignment: MainAxisAlignment.center,
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
                              _playMusic(url, title, context);
                            }
                            setDialogState(() {});
                          },
                        ),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24, // Large font size
                            fontWeight: FontWeight.bold, // Bold text
                            color:
                                Colors.white, // White color for better contrast
                            letterSpacing:
                                1.2, // Slight letter spacing for readability
                            shadows: [
                              Shadow(
                                offset: Offset(1.5,
                                    1.5), // Slight shadow for better visibility
                                blurRadius: 2,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                        // IconButton(
                        //   icon: Icon(
                        //     isLiked ? Icons.favorite : Icons.favorite_border,
                        //     size: 36,
                        //   ),
                        //   onPressed: () {
                        //     if (isLiked) {
                        //       // Remove the song from liked list
                        //       fs.removeSong(url, uid, title);
                        //       setDialogState(() {
                        //         isLiked = false;
                        //         _songs.removeWhere(
                        //             (song) => song['title'] == title);
                        //       });
                        //     } else {
                        //       // Add the song to liked list
                        //       fs.uploadSong(url, uid, title, 'Lsongs');
                        //       setDialogState(() {
                        //         isLiked = true;
                        //         _songs.add({'title': title, 'url': url});
                        //       });
                        //     }
                        //   },
                        // ),
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Upload Song'),
                content: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Enter Song Name',
                    border: OutlineInputBorder(),
                  ),
                  controller: t,
                ),
                actions: [
                  IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close)),
                  IconButton(
                      onPressed: () {
                        _pickAndUploadFile(context);
                      },
                      icon: const Icon(Icons.file_upload_rounded))
                ],
              );
            },
          );
        },
        child: const Icon(Icons.file_upload_outlined),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      body: _songs.isEmpty
          ? const Center(child: Text("No songs uploaded"))
          : ListView.builder(
              itemCount: _songs.length,
              padding: const EdgeInsets.only(top: 20),
              itemBuilder: (context, index) {
                final song = _songs[index];
                return ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(song['title']),
                  onTap: () => _playMusic(song['url'], song['title'], context),
                );
              },
            ),
      appBar: AppBar(
        title: const Text(
          "Uploaded Songs",
        ),
        centerTitle: true,
        backgroundColor: Colors.grey[850],
        elevation: 10,
        shadowColor: Colors.grey[400],
      ),
    );
  }
}
