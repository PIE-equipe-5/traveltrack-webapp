import 'package:flutter/material.dart';

class NearbyQuestPanel extends StatefulWidget {
  const NearbyQuestPanel({
    super.key,
    required this.isExpanded,
    required this.onExpand,
    required this.onCollapse,
    required this.child,
  });

  final bool isExpanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final Widget child;

  @override
  State<NearbyQuestPanel> createState() => _NearbyQuestPanelState();
}

class _NearbyQuestPanelState extends State<NearbyQuestPanel> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.isExpanded) {
      return Dismissible(
        key: const ValueKey('nearby-quest-sheet'),
        direction: DismissDirection.down,
        resizeDuration: null,
        onDismissed: (_) => widget.onCollapse(),
        child: widget.child,
      );
    }

    return Center(
      child: GestureDetector(
        onVerticalDragStart: (_) => _dragDistance = 0,
        onVerticalDragUpdate: (details) => _dragDistance += details.delta.dy,
        onVerticalDragEnd: (details) {
          if (_dragDistance < -20 || (details.primaryVelocity ?? 0) < -100) {
            widget.onExpand();
          }
        },
        child: Material(
          color: Colors.white,
          elevation: 4,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: InkWell(
            onTap: widget.onExpand,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_arrow_up, size: 20),
                  SizedBox(width: 6),
                  Text('Quête à proximité'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
