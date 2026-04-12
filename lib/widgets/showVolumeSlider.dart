import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/play_controller.dart';

PlayController _playController = Get.find<PlayController>();

OverlayEntry? _overlayEntry;
Timer? _timer;
bool volumeSliderVisible = false;
void continueshowVolumeSlider() {
  if (volumeSliderVisible) {
    _startAutoCloseTimer();
  } else {
    showVolumeSlider();
  }
}

void showVolumeSlider() async {
  if (volumeSliderVisible) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    volumeSliderVisible = false;
    return;
  }
  volumeSliderVisible = true;
  _overlayEntry?.remove();
  _overlayEntry = null;
  _overlayEntry = _createOverlayEntry();
  Overlay.of(Get.context!).insert(_overlayEntry!);
  _startAutoCloseTimer();
}

void _startAutoCloseTimer() {
  _timer?.cancel();
  _timer = Timer(Duration(seconds: 3), () {
    _overlayEntry?.remove();
    _overlayEntry = null;
    volumeSliderVisible = false;
  });
}

OverlayEntry _createOverlayEntry() {
  return OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).size.height / 2 - 100,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
            volumeSliderVisible = false;
          },
          child: Container(
            height: 200,
            width: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface, // 使用当前主题的表面颜色
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(113, 120, 120, 120),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: RotatedBox(
              quarterTurns: -1,
              child: Obx(
                () => Slider(
                  min: 0.0,
                  max: 100.0,
                  value: _playController.currentVolume,
                  onChanged: (value) {
                    _playController.currentVolume = value;
                    _startAutoCloseTimer();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
