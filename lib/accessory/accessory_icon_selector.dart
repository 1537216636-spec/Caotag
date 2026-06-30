import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon_model.dart';

class AccessoryIconSelector {
  static Future<String?> showIconSelection(
      BuildContext context, String currentIcon, Color currentColor) async {
    final categories = AccessoryIconModel.getIconsByCategory();
    String? selectedIcon = currentIcon;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('选择图标', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: categories.map((cat) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  cat['category'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (cat['icons'] as List<Map<String, dynamic>>).map((icon) {
                                  final iconName = icon['name'] as String;
                                  final isMaterialIcon = iconName != 'custom';
                                  // 修复空安全：使用 selectedIcon?.startsWith()
                                  final isSelected = selectedIcon != null &&
                                      ((isMaterialIcon && icon['icon'].toString() == selectedIcon) ||
                                          (iconName == 'custom' && selectedIcon!.startsWith('file')));

                                  if (iconName == 'custom') {
                                    return GestureDetector(
                                      onTap: () async {
                                        final picker = ImagePicker();
                                        final picked = await picker.pickImage(source: ImageSource.gallery);
                                        if (picked != null) {
                                          setState(() {
                                            selectedIcon = picked.path;
                                          });
                                          Navigator.pop(context, selectedIcon);
                                        }
                                      },
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                              : Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: isSelected
                                              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                              : null,
                                        ),
                                        child: const Icon(Icons.add_a_photo, size: 30),
                                      ),
                                    );
                                  } else {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedIcon = icon['icon'].toString();
                                        });
                                        Navigator.pop(context, selectedIcon);
                                      },
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                              : Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: isSelected
                                              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                              : null,
                                        ),
                                        child: Icon(
                                          icon['icon'] as IconData,
                                          size: 30,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    );
                                  }
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}