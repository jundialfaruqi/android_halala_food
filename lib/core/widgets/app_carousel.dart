import 'package:flutter/material.dart';

/// App Core Widget untuk Material 3 Carousel yang mengimplementasikan
/// standar resmi Material Design 3 (https://m3.material.io/components/carousel/overview).
///
/// Mendukung layout fixed `itemExtent` maupun layout `weighted` (M3 multi-browse / hero peeking layout).
class AppCarousel extends StatelessWidget {
  /// Tinggi wadah carousel view
  final double height;

  /// Ukuran lebar item utama di sumbu scroll (horizontal).
  /// Wajib pada layout standar (non-weighted).
  final double? itemExtent;

  /// Ukuran kompresi minimum saat item scroll keluar/masuk viewport
  final double shrinkExtent;

  /// Proporsi flex untuk layout weighted (multi-browse layout M3)
  final List<int>? flexWeights;

  /// Jarak padding di sekeliling setiap item carousel
  final EdgeInsets? padding;

  /// Bentuk border shape untuk setiap item (default: RoundedRectangleBorder circular 20)
  final ShapeBorder shape;

  /// Elevasi item
  final double elevation;

  /// Warna latar belakang item carousel
  final Color backgroundColor;

  /// Mengaktifkan efek snapping ke batas item saat digeser
  final bool itemSnapping;

  /// Apakah mengaktifkan splash inkwell penutup di atas child.
  /// Disetel false secara default agar tombol dan interaksi child di dalam item dapat diklik.
  final bool enableSplash;

  /// Callback opsional saat item diklik
  final ValueChanged<int>? onTap;

  /// Controller untuk mengontrol posisi dan scroll carousel
  final CarouselController? controller;

  /// Daftar widget child carousel
  final List<Widget> children;

  const AppCarousel({
    super.key,
    this.height = 200,
    double this.itemExtent = 280,
    this.shrinkExtent = 0.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 4.0),
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    this.elevation = 0.0,
    this.backgroundColor = Colors.transparent,
    this.itemSnapping = true,
    this.enableSplash = false,
    this.onTap,
    this.controller,
    required this.children,
  }) : flexWeights = null;

  /// Konstruktor khusus dengan weighted layout (Material 3 Multi-Browse Hero / Peeking)
  const AppCarousel.weighted({
    super.key,
    this.height = 200,
    required List<int> this.flexWeights,
    this.shrinkExtent = 0.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 4.0),
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    this.elevation = 0.0,
    this.backgroundColor = Colors.transparent,
    this.itemSnapping = true,
    this.enableSplash = false,
    this.onTap,
    this.controller,
    required this.children,
  }) : itemExtent = null;

  /// Konstruktor builder untuk membuat carousel secara dinamis dari list data
  factory AppCarousel.builder({
    Key? key,
    double height = 200,
    double itemExtent = 280,
    double shrinkExtent = 0.0,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 4.0),
    ShapeBorder shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    double elevation = 0.0,
    Color backgroundColor = Colors.transparent,
    bool itemSnapping = true,
    bool enableSplash = false,
    ValueChanged<int>? onTap,
    CarouselController? controller,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    return AppCarousel(
      key: key,
      height: height,
      itemExtent: itemExtent,
      shrinkExtent: shrinkExtent,
      padding: padding,
      shape: shape,
      elevation: elevation,
      backgroundColor: backgroundColor,
      itemSnapping: itemSnapping,
      enableSplash: enableSplash,
      onTap: onTap,
      controller: controller,
      children: List.generate(
        itemCount,
        (index) => Builder(builder: (context) => itemBuilder(context, index)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: flexWeights != null
          ? CarouselView.weighted(
              controller: controller,
              flexWeights: flexWeights!,
              shrinkExtent: shrinkExtent,
              padding: padding,
              shape: shape,
              elevation: elevation,
              backgroundColor: backgroundColor,
              itemSnapping: itemSnapping,
              enableSplash: enableSplash,
              onTap: onTap,
              children: children,
            )
          : CarouselView(
              controller: controller,
              itemExtent: itemExtent ?? 280,
              shrinkExtent: shrinkExtent,
              padding: padding,
              shape: shape,
              elevation: elevation,
              backgroundColor: backgroundColor,
              itemSnapping: itemSnapping,
              enableSplash: enableSplash,
              onTap: onTap,
              children: children,
            ),
    );
  }
}
