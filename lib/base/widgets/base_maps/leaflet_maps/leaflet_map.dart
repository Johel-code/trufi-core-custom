import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:trufi_core/base/blocs/map_layer/map_layers_cubit.dart';
import 'package:trufi_core/base/blocs/map_configuration/map_configuration_cubit.dart';
import 'package:trufi_core/base/blocs/map_tile_provider/map_tile_provider_cubit.dart';
import 'package:trufi_core/base/blocs/panel/panel_cubit.dart';
import 'package:trufi_core/base/blocs/providers/gps_location_provider.dart';
import 'package:trufi_core/base/models/trufi_latlng.dart';
import 'package:trufi_core/base/models/trufi_place.dart';
import 'package:trufi_core/base/pages/saved_places/search_locations_cubit/search_locations_cubit.dart';
import 'package:trufi_core/base/translations/trufi_base_localizations.dart';
import 'package:trufi_core/base/utils/util_icons/icons.dart';
import 'package:trufi_core/base/widgets/base_maps/leaflet_maps/decoder_data.dart';
import 'package:trufi_core/base/widgets/base_maps/leaflet_maps/leaflet_map_controller.dart';
import 'package:trufi_core/base/widgets/base_maps/leaflet_maps/poi_marker_modal.dart';
import 'package:trufi_core/base/widgets/base_maps/leaflet_maps/utils/leaflet_map_utils.dart';
import 'package:trufi_core/base/widgets/base_maps/map_buttons/map_type_button.dart';
import 'package:trufi_core/base/widgets/base_maps/map_buttons/your_location_button.dart';
import 'package:trufi_core/base/widgets/screen/screen_helpers.dart';

typedef LayerOptionsBuilder = List<Widget> Function(BuildContext context);

class LeafletMap extends StatefulWidget {
  final LeafletMapController trufiMapController;
  final LayerOptionsBuilder layerOptionsBuilder;
  final LayerOptionsBuilder? layerOptionsBuilderTop;
  final Widget? floatingActionButtons;
  final TapCallback? onTap;
  final LongPressCallback? onLongPress;
  final PositionCallback? onPositionChanged;
  final double? bottomPaddingButtons;
  final bool showPOILayers;
  const LeafletMap({
    super.key,
    required this.trufiMapController,
    required this.layerOptionsBuilder,
    this.layerOptionsBuilderTop,
    this.floatingActionButtons,
    this.onTap,
    this.onLongPress,
    this.onPositionChanged,
    this.bottomPaddingButtons,
    this.showPOILayers = false,
  });

  @override
  State<LeafletMap> createState() => _LeafletMapState();
}

class _LeafletMapState extends State<LeafletMap> {
  bool isTrackingPosition = false;
  int mapZoom = 0;
  @override
  Widget build(BuildContext context) {
    final mapConfiguratiom = context.read<MapConfigurationCubit>().state;
    final currentMapType = context.watch<MapTileProviderCubit>().state;
    final customLayersCubit = context.watch<MapLayersCubit>();
    final searchLocationsCubit = context.watch<SearchLocationsCubit>();
    final showCustomLayers =
        widget.showPOILayers && customLayersCubit.layersContainer.isNotEmpty;
    int? clusterSize;
    Size? markerClusterSize;
    switch (mapZoom) {
      case 15:
        clusterSize = 25;
        markerClusterSize = const Size(30, 35);
        break;
      case 16:
        clusterSize = 40;
        markerClusterSize = const Size(35, 40);
        break;
      case 17:
        clusterSize = 30;
        markerClusterSize = const Size(25, 40);
        break;
      case 18:
        clusterSize = 30;
        markerClusterSize = const Size(35, 45);
        break;
    }
    return Stack(
      children: [
        StreamBuilder<TrufiLatLng?>(
          initialData: null,
          stream: GPSLocationProvider().streamLocation,
          builder: (context, snapshot) {
            final currentLocation = snapshot.data;
            return FlutterMap(
              key: Key(
                  widget.trufiMapController.mapController.hashCode.toString()),
              mapController: widget.trufiMapController.mapController,
              options: MapOptions(
                // TODO update interactiveFlags
                interactiveFlags: InteractiveFlag.drag |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.pinchMove |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom,
                minZoom: mapConfiguratiom.onlineMinZoom,
                maxZoom: mapConfiguratiom.onlineMaxZoom,
                initialZoom: mapConfiguratiom.onlineZoom,
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                initialCenter: mapConfiguratiom.center.toLatLng(),
                onMapReady: () {
                  if (!widget.trufiMapController.readyCompleter.isCompleted) {
                    widget.trufiMapController.readyCompleter.complete();
                  }
                },
                onPositionChanged: (
                  MapPosition position,
                  bool hasGesture,
                ) {
                  if (widget.onPositionChanged != null) {
                    Future.delayed(Duration.zero, () {
                      widget.onPositionChanged!(position, hasGesture);
                    });
                  }
                  if (hasGesture && isTrackingPosition) {
                    setState(() {
                      isTrackingPosition = false;
                    });
                  }
                  // fix render issue
                  Future.delayed(Duration.zero, () {
                    final int zoom = position.zoom?.round() ?? 0;
                    if (mapZoom != zoom) {
                      setState(() => mapZoom = zoom);
                    }
                  });
                },
              ),
              children: [
                ...currentMapType.currentMapTileProvider
                    .buildTileLayerOptions(),
                if (showCustomLayers)
                  ...customLayersCubit.activeCustomLayers(
                    zoom: mapZoom,
                    layers: widget.layerOptionsBuilder(context),
                    layersClusterPOIs: MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        builder: (context, markers) {
                          return Container();
                        },
                        alignment: Alignment.center,
                        maxClusterRadius: clusterSize ?? 80,
                        size: markerClusterSize ?? const Size(30, 30),
                        centerMarkerOnClick: false,
                        zoomToBoundsOnClick: false,
                        spiderfyCluster: false,
                        showPolygon: false,
                        markers: customLayersCubit.markers(mapZoom),
                        onClusterTap: (onClusterTap) {
                          SelectPOIDialog.showMarkerClusterNode(context,
                              onClusterTap: onClusterTap);
                        },
                      ),
                    ),
                  )
                else
                  ...widget.layerOptionsBuilder(context),
                _markerInMap(places: [
                  ...searchLocationsCubit.state.myDefaultPlaces
                      .where((element) => element.isLatLngDefined),
                  ...searchLocationsCubit.state.myPlaces
                ]),
                if (widget.layerOptionsBuilderTop != null)
                  ...widget.layerOptionsBuilderTop!(context),
                MarkerLayer(markers: [
                  buildYourLocationMarker(
                    currentLocation,
                    mapConfiguratiom.markersConfiguration.yourLocationMarker,
                  )
                ]),
              ],
            );
          },
        ),
        if (showCustomLayers)
          const Positioned(
            top: 16.0,
            right: 16.0,
            child: MapTypeButton(),
          ),
        Positioned(
          bottom: widget.bottomPaddingButtons ?? 25.0,
          right: 16.0,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (widget.floatingActionButtons != null)
                  widget.floatingActionButtons!,
                const Padding(padding: EdgeInsets.all(4.0)),
                YourLocationButton(
                  trufiMapController: widget.trufiMapController,
                  isTrackingPosition: isTrackingPosition,
                  setTracking: (isTraking) {
                    setState(() {
                      isTrackingPosition = isTraking;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 5.0,
          left: 10,
          child:
              SafeArea(child: mapConfiguratiom.mapAttributionBuilder!(context)),
        ),
      ],
    );
  }
}

class _markerInMap extends StatelessWidget {
  final List<TrufiLocation> places;

  const _markerInMap({required this.places});

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: places.map((location) {
        return Marker(
          point: LatLng(location.latitude, location.longitude),
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
            ),
            padding: EdgeInsets.all(2),
            child: GestureDetector(
              onTap: () {
                final panelCubit = context.read<PanelCubit>();
                panelCubit.setPanel(
                  MarkerPanel(
                    panel: (
                      context,
                      onFetchPlan, {
                      isOnlyDestination,
                    }) =>
                        POIMarkerModal(
                      location: location,
                      onFetchPlan: onFetchPlan,
                    ),
                    positon: location.latLng,
                    minSize: 120,
                  ),
                );
              },
              child: FittedBox(
                child: typeToIconData(location.type, color: Colors.white),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class SelectPOIDialog extends StatelessWidget {
  static Future<void> showMarkerClusterNode(
    BuildContext buildContext, {
    required MarkerClusterNode onClusterTap,
  }) async {
    return await showTrufiDialog<void>(
      context: buildContext,
      builder: (BuildContext context) => SelectPOIDialog(
        onClusterTap: onClusterTap,
      ),
    );
  }

  final MarkerClusterNode onClusterTap;
  const SelectPOIDialog({
    super.key,
    required this.onClusterTap,
  });

  @override
  Widget build(BuildContext context) {
    final localization = TrufiBaseLocalization.of(context)!;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 4, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      insetPadding: EdgeInsets.zero,
      iconPadding: EdgeInsets.zero,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              "${localization.selectYourPointInterest} (${onClusterTap.markers.length})"),
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.close,
              size: 30,
            ),
            splashRadius: 25,
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        height: 350,
        child: ListView.builder(
          itemCount: onClusterTap.markers.length,
          itemBuilder: (context, index) {
            final key = onClusterTap.markers[index].key;
            return key != null
                ? Column(
                    children: [
                      ShowOverlappingData(
                        keyData: key,
                        markerNode: onClusterTap.markers[index],
                      ),
                      const Divider(
                        height: 5,
                        color: Colors.grey,
                      )
                    ],
                  )
                : Container();
          },
        ),
      ),
    );
  }
}
