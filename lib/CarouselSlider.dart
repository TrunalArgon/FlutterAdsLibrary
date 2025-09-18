import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// -------------------- MODEL --------------------
class BannerItem {
  final String? link;
  final int isDeepLink;
  final String? image;
  final int sliderTime;
  final String? title;
  final String? seriesId;
  final String? offerCode;

  BannerItem({
    this.link,
    required this.isDeepLink,
    this.image,
    required this.sliderTime,
    this.title,
    this.seriesId,
    this.offerCode,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      link: json["link"],
      isDeepLink: json["is_deep_link"] ?? 0,
      image: json["image"],
      sliderTime: json["slider_time"] ?? 3,
      title: json["title"],
      seriesId: json["series_id"],
      offerCode: json["offer_code"],
    );
  }
}

/// -------------------- CAROUSEL WIDGET --------------------
class BannerCarousel extends StatefulWidget {
  final Map<String, List<Map<String, Object?>>> bannerItem;
  const BannerCarousel({required this.bannerItem});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final CarouselSliderController _carouselController = CarouselSliderController();

  List<BannerItem> bannerList = [];
  Timer? _autoPlayTimer;
  int bannerCurrentIndex = 0;
  int sliderTime = 5; // default

  @override
  void initState() {
    super.initState();
    bannerList = (widget.bannerItem["banneras"] as List)
        .map((e) => BannerItem.fromJson(e))
        .where((banner) {
      final imageUrl = banner.image;
      if (imageUrl?.isEmpty ?? true)
        return false;
      else
        return true;
    }).toList();
    if (bannerList.isNotEmpty) {
      sliderTime = bannerList[0].sliderTime;
      _startAutoPlayTimer();
    }
  }

  /// -------------------- TIMER LOGIC --------------------
  void _startAutoPlayTimer() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(Duration(seconds: sliderTime), (timer) {
      _onNextPage();
    });
  }

  void _onNextPage() {
    if (bannerList.isEmpty) return;

    int nextIndex = (bannerCurrentIndex + 1) % bannerList.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carouselController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });

    setState(() {
      bannerCurrentIndex = nextIndex;
      sliderTime = bannerList[bannerCurrentIndex].sliderTime;
    });

    _startAutoPlayTimer();
  }

  void _onPageChanged(int index, CarouselPageChangedReason reason) {
    if (bannerCurrentIndex != index) {
      setState(() {
        bannerCurrentIndex = index;
        sliderTime = bannerList[bannerCurrentIndex].sliderTime;
        _startAutoPlayTimer();
      });
    }
  }

  /// -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    if (bannerList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        CarouselSlider.builder(
          carouselController: _carouselController,
          itemCount: bannerList.length,
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height * 0.071,
            viewportFraction: 1,
            autoPlay: false,
            onPageChanged: _onPageChanged,
          ),
          itemBuilder: (context, index, realIndex) {
            final banner = bannerList[index];
            return GestureDetector(
              onTap: () async {
                // TODO: implement navigation as per banner.type, deep link, etc.
                if (banner.link != null && banner.link!.isNotEmpty) {
                  String url = banner.link.toString();
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url));
                  } else {
                    if(kDebugMode) debugPrint("Clicked on banner → ${banner.link}");
                  }
                  if(kDebugMode) debugPrint("Clicked on banner → ${banner.link}");
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9.0),
                  child: CachedNetworkImage(
                    imageUrl: banner.image ?? "",
                    memCacheWidth: 1200,
                    memCacheHeight: 200,
                    filterQuality: FilterQuality.low,
                    fit: BoxFit.fill,
                    width: MediaQuery.of(context).size.width,
                  ),
                ),
              ),
            );
          },
        ),
        if (bannerList.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(bannerList.length, (index) {
                return _buildIndicator(bannerCurrentIndex == index);
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      height: 6,
      width: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.blue : const Color(0XFFD9D9D9),
      ),
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }
}