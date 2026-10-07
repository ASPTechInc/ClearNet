enum GuideDataType { intro, doPage, dont, tip }

class GuideItem {
  const GuideItem({
    required this.type,
    required this.title,
    required this.description,
    this.image,
  });

  factory GuideItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    GuideDataType type;
    switch (typeStr) {
      case 'intro':
        type = GuideDataType.intro;
        break;
      case 'do':
      case 'doPage':
        type = GuideDataType.doPage;
        break;
      case 'dont':
        type = GuideDataType.dont;
        break;
      case 'tip':
      case 'top':
        type = GuideDataType.tip;
        break;
      default:
        type = GuideDataType.intro;
    }

    return GuideItem(
      type: type,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      image: json['image'] as String?,
    );
  }

  final GuideDataType type;
  final String title;
  final String description;
  final String? image;
}

class GuideData {
  const GuideData({required this.title, required this.pages});

  factory GuideData.fromJson(Map<String, dynamic> json) {
    final pagesList =
        (json['pages'] as List<dynamic>?)
            ?.map((e) => GuideItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return GuideData(
      title: json['title'] as String? ?? 'Guide',
      pages: pagesList,
    );
  }

  final String title;
  final List<GuideItem> pages;
}
