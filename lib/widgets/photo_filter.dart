import 'dart:async';
import 'dart:io';
import 'dart:math' as Math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imageLib;
import 'package:path_provider/path_provider.dart';
import 'package:photofilters/filters/filters.dart';

class PhotoFilter extends StatelessWidget {
  final imageLib.Image image;
  final String filename;
  final Filter filter;
  final BoxFit fit;
  final Widget loader;

  PhotoFilter({
    required this.image,
    required this.filename,
    required this.filter,
    this.fit = BoxFit.fill,
    this.loader = const Center(child: CircularProgressIndicator()),
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: compute(
          applyFilter,
          <String, dynamic>{
            "filter": filter,
            "image": image,
            "filename": filename,
          }),
      builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return loader;
          case ConnectionState.active:
          case ConnectionState.waiting:
            return loader;
          case ConnectionState.done:
            if (snapshot.hasError)
              return Center(child: Text('Error: ${snapshot.error}'));
            return Image.memory(
              snapshot.data as dynamic,
              fit: fit,
            );
        }
      },
    );
  }
}

///The PhotoFilterSelector Widget for apply filter from a selected set of filters
class PhotoFilterSelector extends StatefulWidget {
  final Widget title;
  final Color appBarColor;
  final List<Filter> filters;
  final imageLib.Image image;
  final Widget loader;
  final BoxFit fit;
  final String filename;
  final bool circleShape;

  const PhotoFilterSelector({
    Key? key,
    required this.title,
    required this.filters,
    required this.image,
    this.appBarColor = Colors.blue,
    this.loader = const Center(child: CircularProgressIndicator()),
    this.fit = BoxFit.fill,
    required this.filename,
    this.circleShape = false,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => new _PhotoFilterSelectorState();
}

class _PhotoFilterSelectorState extends State<PhotoFilterSelector> {
  String? filename;
  Map<String, List<int>?> cachedFilters = {};
  Map<String, List<int>?> previewCachedFilters = {};
  Filter? _filter;
  imageLib.Image? sourceImage;
  late bool loading;
  late imageLib.Image thumbImage;
  late imageLib.Image previewImage;


  @override
  void initState() {
    super.initState();
    loading = false;
    _filter = widget.filters[0];
    filename = widget.filename;
    sourceImage = widget.image;
    thumbImage = widget.image;
    previewImage = widget.image;

    processImage();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: widget.title,
          backgroundColor: widget.appBarColor,
          actions: <Widget>[
            loading
                ? Container()
                : IconButton(
                    icon: Icon(Icons.check),
                    onPressed: () async {
                      setState(() {
                        loading = true;
                      });
                      var imageFile = await saveFilteredImage();

                      Navigator.pop(context, {'image_filtered': imageFile});
                    },
                  )
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: loading
              ? widget.loader
              : Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        padding: EdgeInsets.all(12.0),
                        child: _buildFilteredImage(
                          _filter,
                          previewImage,
                          filename,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.filters.length,
                          itemBuilder: (BuildContext context, int index) {
                            return InkWell(
                              child: Container(
                                padding: EdgeInsets.all(5.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    _buildFilterThumbnail(
                                        widget.filters[index], thumbImage, filename),
                                    SizedBox(
                                      height: 5.0,
                                    ),
                                    Text(
                                      widget.filters[index].name,
                                    )
                                  ],
                                ),
                              ),
                              onTap: () => setState(() {
                                _filter = widget.filters[index];
                              }),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  _buildFilterThumbnail(
      Filter filter, imageLib.Image? image, String? filename) {
    if (cachedFilters[filter.name] == null) {
      return FutureBuilder<List<int>>(
        future: compute(
            applyFilter ,
            <String, dynamic>{
              "filter": filter,
              "image": image,
              "filename": filename,
            }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.active:
            case ConnectionState.waiting:
              return CircleAvatar(
                radius: 50.0,
                child: Center(
                  child: widget.loader,
                ),
                backgroundColor: Colors.white,
              );
            case ConnectionState.done:
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              cachedFilters[filter.name] = snapshot.data;
              return CircleAvatar(
                radius: 50.0,
                backgroundImage: MemoryImage(
                  snapshot.data as dynamic,
                ),
                backgroundColor: Colors.white,
              );
          }
          // unreachable
        },
      );
    } else {
      return CircleAvatar(
        radius: 50.0,
        backgroundImage: MemoryImage(
          cachedFilters[filter.name] as dynamic,
        ),
        backgroundColor: Colors.white,
      );
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/filtered_${_filter?.name ?? "_"}_$filename');
  }

  Future<File> saveFilteredImage() async {
    var imageFile = await _localFile;
    //

    var filterSourceImage = await compute(
        applyFilter ,
        <String, dynamic>{
          "filter": _filter,
          "image": sourceImage,
          "filename": filename,
        });
    await imageFile.writeAsBytes(filterSourceImage);
    return imageFile;
  }

  Widget _buildFilteredImage(
      Filter? filter, imageLib.Image? image, String? filename) {
    if (previewCachedFilters[filter?.name ?? "_"] == null) {
      return FutureBuilder<List<int>>(
        future: compute(
            applyFilter,
            <String, dynamic>{
              "filter": filter,
              "image": image,
              "filename": filename,
            }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return widget.loader;
            case ConnectionState.active:
            case ConnectionState.waiting:
              return widget.loader;
            case ConnectionState.done:
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              previewCachedFilters[filter?.name ?? "_"] = snapshot.data;
              return widget.circleShape
                  ? SizedBox(
                      height: MediaQuery.of(context).size.width / 3,
                      width: MediaQuery.of(context).size.width / 3,
                      child: Center(
                        child: CircleAvatar(
                          radius: MediaQuery.of(context).size.width / 3,
                          backgroundImage: MemoryImage(
                            snapshot.data as dynamic,
                          ),
                        ),
                      ),
                    )
                  : Image.memory(
                      snapshot.data as dynamic,
                      fit: BoxFit.contain,
                    );
          }
          // unreachable
        },
      );
    } else {
      return widget.circleShape
          ? SizedBox(
              height: MediaQuery.of(context).size.width / 3,
              width: MediaQuery.of(context).size.width / 3,
              child: Center(
                child: CircleAvatar(
                  radius: MediaQuery.of(context).size.width / 3,
                  backgroundImage: MemoryImage(
                    previewCachedFilters[filter?.name ?? "_"] as dynamic,
                  ),
                ),
              ),
            )
          : Image.memory(
              previewCachedFilters[filter?.name ?? "_"] as dynamic,
              fit: widget.fit,
            );
    }
  }

  void processImage() async {

    num thumbRatio = getRatio(200, 200 ,sourceImage!.height ,sourceImage!.width);

    var thumbImage = await compute(
        reduceSize ,
        <String, dynamic>{
          "width": (sourceImage!.width * thumbRatio).toInt(),
          "height": (sourceImage!.height * thumbRatio).toInt(),
          "image": sourceImage,
          "filename": filename,
        });

    num previewRatio = getRatio(MediaQuery.of(context).size.height, MediaQuery.of(context).size.width ,sourceImage!.height ,sourceImage!.width);//Math.min(MediaQuery.of(context).size.width /sourceImage!.width , MediaQuery.of(context).size.height /sourceImage!.height);

    previewRatio = previewRatio *2;

    var previewImage = await compute(
        reduceSize ,
        <String, dynamic>{
          "width": (previewRatio * sourceImage!.width).toInt(),
          "height": (previewRatio * sourceImage!.height).toInt(),
          "image": sourceImage,
          "filename": filename,
        });

    setState(() {

      this.thumbImage = thumbImage;
      this.previewImage = previewImage;

    });

  }
}

///The global applyfilter function
FutureOr<List<int>> applyFilter(Map<String, dynamic> params) {
  Filter? filter = params["filter"];
  imageLib.Image image = params["image"];
  String filename = params["filename"];
  List<int> _bytes = image.getBytes();
  if (filter != null) {
    filter.apply(_bytes as dynamic, image.width, image.height);
  }
  imageLib.Image _image =
      imageLib.Image.fromBytes(image.width, image.height, _bytes);
  _bytes = imageLib.encodeNamedImage(_image, filename)!;

  return _bytes;
}

///The global buildThumbnail function
FutureOr<List<int>> buildThumbnail(Map<String, dynamic> params) {
  int? width = params["width"];
  params["image"] = imageLib.copyResize(params["image"], width: width);
  return applyFilter(params);
}

///The global buildThumbnail function
FutureOr<imageLib.Image> reduceSize(Map<String, dynamic> params) {
  int? width = params["width"];
  int? height = params["height"];
  return imageLib.copyResize(params["image"], width: width,height: height);
}

num getRatio(num maxHeight,num maxWidth,num sourceImageHeight,num sourceImageWidth){
  return Math.min(maxWidth /sourceImageWidth , maxHeight /sourceImageHeight);
}
