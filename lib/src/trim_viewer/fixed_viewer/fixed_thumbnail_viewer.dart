import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';

class FixedThumbnailViewer extends StatefulWidget {
  final File videoFile;
  final int videoDuration;
  final double thumbnailHeight;
  final BoxFit fit;
  final int numberOfThumbnails;
  final VoidCallback onThumbnailLoadingComplete;
  final int quality;

  /// For showing the thumbnails generated from the video,
  /// like a frame by frame preview
  const FixedThumbnailViewer({
    Key? key,
    required this.videoFile,
    required this.videoDuration,
    required this.thumbnailHeight,
    required this.numberOfThumbnails,
    required this.fit,
    required this.onThumbnailLoadingComplete,
    this.quality = 75,
  }) : super(key: key);

  @override
  State<FixedThumbnailViewer> createState() => _FixedThumbnailViewerState();
}

class _FixedThumbnailViewerState extends State<FixedThumbnailViewer> {
  StreamController<List<String>> controller = StreamController<List<String>>();

  @override
  void initState() {
    super.initState();
    generateThumbnail();
  }

  void generateThumbnail() async {
    final String videoPath = widget.videoFile.path;
    double eachPart = widget.videoDuration / widget.numberOfThumbnails;
    List<String> byteList = [];
    // the cache of last thumbnail
    String? recentThumbnailPath;
    for (int i = 1; i <= widget.numberOfThumbnails; i++) {
      if (!mounted) break;
      String? thumbnailPath;
      try {
        final position = eachPart * 1000 * i;
        final ext = path.extension(videoPath);
        final videoDir = path.dirname(videoPath);
        final tempFilePath = path.join(videoDir, '${const Uuid().v4()}$ext');
        await File(tempFilePath).create(recursive: true);
        await File(videoPath).copy(tempFilePath);
        final thumbnailFile = await VideoCompress.getFileThumbnail(
          tempFilePath,
          quality: 20,
          position: position.toInt(),
        );
        await File(tempFilePath).delete(recursive: true);
        thumbnailPath = thumbnailFile.path;
      } catch (e) {
        debugPrint('ERROR: Couldn\'t generate thumbnails: $e');
      }

      // if current thumbnail is null use the last thumbnail
      if (thumbnailPath != null) {
        recentThumbnailPath = thumbnailPath;
      } else {
        thumbnailPath = recentThumbnailPath;
      }
      if (thumbnailPath != null) {
        byteList.add(thumbnailPath);
        controller.sink.add(byteList);
      }

      if (byteList.length == widget.numberOfThumbnails) {
        widget.onThumbnailLoadingComplete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: controller.stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<String> imageBytes = snapshot.data!;
          return Row(
            mainAxisSize: MainAxisSize.max,
            children: List.generate(
              widget.numberOfThumbnails,
              (index) => SizedBox(
                height: widget.thumbnailHeight,
                width: widget.thumbnailHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageBytes.isNotEmpty)
                      Opacity(
                        opacity: 0.2,
                        child: Image.file(
                          File(imageBytes.elementAt(0)),
                          fit: widget.fit,
                        ),
                      ),
                    index < imageBytes.length
                        ? FadeInImage(
                            image: FileImage(File(imageBytes[index])),
                            fit: widget.fit,
                            placeholder: MemoryImage(kTransparentImage),
                          )
                        : const SizedBox(),
                  ],
                ),
              ),
            ),
          );
        } else {
          return Container(
            color: Colors.grey[900],
            height: widget.thumbnailHeight,
            width: double.maxFinite,
          );
        }
      },
    );
  }
}
