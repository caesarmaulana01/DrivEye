import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _videoPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/splash.mp4',
    )
      ..initialize().then((_) {
        setState(() {});
        _playVideo();
      })
      ..setVolume(0.0);
  }

  void _playVideo() async {
    _controller.play();
    _videoPlayed = true;

    // Menunggu hingga video selesai
    await Future.delayed(_controller.value.duration!);

    // Navigasi hanya jika video belum diputar kembali dari ChooseMode
    if (_videoPlayed) {
      Navigator.pushReplacementNamed(context, '/chooseMode');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF225DF9),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(
            _controller,
          ),
        )
            : Container(),
      ),
    );
  }
}
