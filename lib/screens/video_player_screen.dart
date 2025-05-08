import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class _VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String? caption;
  
  const _VideoPlayerScreen({
    required this.videoPath,
    this.caption,
  });

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        setState(() {
          _isPlaying = true;
        });
      });
      
    _controller.addListener(() {
      if (!_controller.value.isPlaying && _isPlaying) {
        setState(() {
          _isPlaying = false;
        });
      } else if (_controller.value.isPlaying && !_isPlaying) {
        setState(() {
          _isPlaying = true;
        });
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.caption != null
            ? Text(
                widget.caption!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: _isPlaying
                              ? const SizedBox.shrink()
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.play_arrow,
                                      size: 80.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}