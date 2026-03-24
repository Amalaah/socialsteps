import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class TutorialVideoScreen extends StatefulWidget {
  final String videoPath;
  final VoidCallback onFinished;
  final String? buttonText;

  const TutorialVideoScreen({
    super.key,
    required this.videoPath,
    required this.onFinished,
    this.buttonText,
  });

  @override
  State<TutorialVideoScreen> createState() => _TutorialVideoScreenState();
}

class _TutorialVideoScreenState extends State<TutorialVideoScreen> {
  late VideoPlayerController _controller;
  bool _showButton = false;
  bool _finishedCalled = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });

    _controller.addListener(() {
      if (_controller.value.isInitialized &&
          _controller.value.position >= _controller.value.duration) {
        if (!_finishedCalled) {
          if (widget.buttonText != null) {
            if (!_showButton && mounted) {
              setState(() {
                _showButton = true;
              });
            }
          } else {
            _finishedCalled = true;
            widget.onFinished();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(),
          ),
          if (_showButton)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    if (!_finishedCalled) {
                      _finishedCalled = true;
                      widget.onFinished();
                    }
                  },
                  child: Text(widget.buttonText!),
                ),
              ),
            ),
          // Skip and Replay controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.skip_next, size: 20),
                  label: const Text("Skip"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.85),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    if (!_finishedCalled) {
                      _finishedCalled = true;
                      _controller.pause();
                      widget.onFinished();
                    }
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.replay, size: 20),
                  label: const Text("Replay"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.85),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    _controller.seekTo(Duration.zero);
                    _controller.play();
                    setState(() {
                      _showButton = false;
                      _finishedCalled = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}