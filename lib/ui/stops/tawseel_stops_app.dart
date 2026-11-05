import 'package:flutter/material.dart';

import '../../domain/stop.dart';
import 'stop_tile.dart';
import 'sync_banner.dart';

class TawseelStopsApp extends StatefulWidget {
  const TawseelStopsApp({
    super.key,
    required this.stops,
    required this.pendingCount,
    this.textDirection = TextDirection.ltr,
  });

  final List<Stop> stops;
  final int pendingCount;
  final TextDirection textDirection;

  @override
  State<TawseelStopsApp> createState() => _TawseelStopsAppState();
}

class _TawseelStopsAppState extends State<TawseelStopsApp> {
  String? _selectedStopId;

  @override
  void initState() {
    super.initState();
    if (widget.stops.isNotEmpty) {
      _selectedStopId = widget.stops.first.id;
    }
  }

  @override
  void didUpdateWidget(covariant TawseelStopsApp oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.stops.any((stop) => stop.id == _selectedStopId)) {
      _selectedStopId = widget.stops.isNotEmpty ? widget.stops.first.id : null;
    }
  }

  void _selectStop(Stop stop) {
    setState(() {
      _selectedStopId = stop.id;
    });
  }

  Widget _buildStopsList() {
    return ListView.builder(
      itemCount: widget.stops.length,
      itemBuilder: (context, i) {
        final stop = widget.stops[i];

        return StopTile(
          key: Key('stop-${stop.id}'),
          stop: stop,
          onTap: () => _selectStop(stop),
          onCall: () {},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedStop = widget.stops.cast<Stop?>().firstWhere(
      (stop) => stop?.id == _selectedStopId,
      orElse: () => null,
    );

    return MaterialApp(
      title: 'Tawseel stops',
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          Directionality(textDirection: widget.textDirection, child: child!),
      home: Scaffold(
        appBar: AppBar(title: const Text("Today's stops")),
        body: Column(
          children: [
            SyncBanner(
              key: const Key('sync-banner'),
              pendingCount: widget.pendingCount,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return KeyedSubtree(
                      key: const Key('layout-compact'),
                      child: _buildStopsList(),
                    );
                  }

                  return KeyedSubtree(
                    key: const Key('layout-expanded'),
                    child: Row(
                      children: [
                        SizedBox(width: 320, child: _buildStopsList()),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: KeyedSubtree(
                            key: const Key('stop-detail'),
                            child: Center(
                              child: Text(selectedStop?.customerName ?? ''),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
