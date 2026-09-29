# os_grid_flutter example

Runnable demos for [`os_grid_flutter`](../). Run the launcher and pick a
demo, or run any demo standalone:

```bash
flutter pub get
flutter run                    # the launcher
flutter run -t lib/demos/community_features/community_features_demo.dart
```

## The launcher

| Demo | What it shows |
|---|---|
| Community Features | 18 categorised showcase pages — filtering, editing, selection, grouping, side bar, overlays, clipboard, theming, data persistence, master/detail, aligned grids |
| Basics | Olympics grid — quick filter, selection, pagination |
| Performance | 100k+ rows, grouping, pivot mode, range selection |
| Finance | Live quote grid with animated cell renderers |
| HR | Employee directory with avatar and progress-bar renderers |
| Inventory | Stock dashboard with image cells and context styling |
| Rendering Spike | Canvas rendering experiments and stress scenarios |

The Community Features app has its own Home hub: pick a grid theme there and
it flows down to every page. Use the drawer or the prev/next arrows to move
around.

## Platform folders

Only the `windows/` runner is committed. To run on another desktop, mobile
or web target, generate the runner once:

```bash
flutter create . --platforms=macos      # or ios, android, linux, web
```

## Integration tests

`integration_test/` holds end-to-end suites covering sort/filter/pagination,
selection/clipboard/fill, editing/undo/read-only, column state, rows/tree/
master-detail/drag, infinite/aligned/span and pivot mode. They need a
device or desktop target:

```bash
flutter test integration_test            # on a connected target
```

## Charts

The Integrated Charts demo lives in the companion package, not here — the
companion is not on pub.dev, and keeping it out of this app keeps the
published example's dependencies resolvable:

```bash
cd ../packages/os_grid_flutter_charts/example && flutter run
```
