import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';

class AccessoryListItem extends StatelessWidget {
  final Accessory accessory;
  final Widget? distance;
  final Placemark? herePlace;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AccessoryListItem({
    Key? key,
    required this.accessory,
    this.distance,
    this.herePlace,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastLocation = accessory.lastLocation;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surface,
        elevation: 0,
        shadowColor: theme.shadowColor.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          highlightColor: theme.colorScheme.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                AccessoryIcon(icon: accessory.icon, color: accessory.color, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        accessory.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (accessory.datePublished != null)
                        Text(
                          DateFormat('MM/dd HH:mm').format(accessory.datePublished!),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      if (lastLocation != null)
                        FutureBuilder<Placemark?>(
                          future: accessory.place,
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              final place = snapshot.data!;
                              final address = [
                                place.locality,
                                place.subLocality,
                                place.street,
                              ].where((s) => s != null && s.isNotEmpty).join(' ');
                              if (address.isNotEmpty) {
                                return Text(
                                  address,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,   // 允许两行
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
                            }
                            return Text(
                              '${lastLocation.latitude.toStringAsFixed(4)}, ${lastLocation.longitude.toStringAsFixed(4)}',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                    ],
                  ),
                ),
                if (distance != null) distance!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}