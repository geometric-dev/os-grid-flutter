import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale/os_locale_text.dart';
import '../theming/grid_popup_surface.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';
import 'context_menu_types.dart';

/// A popup menu displayed on right-click (context menu) in the grid.
///
/// Renders a list of [OsContextMenuItem] items with support for icons,
/// keyboard shortcut hints, disabled state, separators, and nested sub-menus.
///
/// The visible menu is rendered into the nearest [Overlay] via an
/// [OverlayPortal], so it can escape narrow grid bounds. Placement flips
/// above the anchor once the real content height has been measured and the
/// window space below it is insufficient; styling resolves from [theme]
/// with Material fallbacks.
///
/// The menu is fully keyboard navigable: focus transfers into the first
/// enabled item when the menu opens; ArrowDown/ArrowUp move the highlight
/// between enabled items; Home/End jump to the first/last enabled item;
/// ArrowRight opens a sub-menu and ArrowLeft closes it; Enter/Space activate
/// the highlighted item; Escape closes an open sub-menu (or the whole menu);
/// and printable characters perform typeahead against item names.
class ContextMenuPopup extends StatefulWidget {
  const ContextMenuPopup({
    super.key,
    required this.items,
    required this.position,
    required this.gridSize,
    required this.onDismiss,
    this.theme,
    this.localeText,
  });

  /// The menu items to display.
  final List<OsContextMenuItem> items;

  /// The position (in grid-local coordinates) where the menu should appear.
  final Offset position;

  /// The total size of the grid widget (for positioning constraints).
  final Size gridSize;

  /// Called when the menu should be dismissed.
  final VoidCallback onDismiss;

  /// Theme for styling the popup.
  final OsGridTheme? theme;

  /// Localised labels reserved for built-in entries (defaults to English).
  ///
  /// Built-in item constants ([OsContextMenuItem.copy], etc.) are
  /// caller-provided data and are not re-localised by the popup itself.
  final OsLocaleText? localeText;

  @override
  State<ContextMenuPopup> createState() => _ContextMenuPopupState();
}

class _ContextMenuPopupState extends State<ContextMenuPopup> {
  static const _popupWidth = 220.0;
  static const _typeaheadResetDuration = Duration(milliseconds: 500);

  final FocusScopeNode _scopeNode = FocusScopeNode();

  // Non-separator items plus a parallel list of focus nodes, one per item.
  List<OsContextMenuItem> _items = const [];
  List<FocusNode> _itemNodes = const [];
  int _focusedIndex = -1;

  // State for the currently open sub-menu (index into [_items]).
  int? _openSubIndex;
  List<OsContextMenuItem> _openSubItems = const [];
  List<FocusNode> _subItemNodes = const [];
  int _focusedSubIndex = -1;
  int _subGeneration = 0;
  final OverlayPortalController _subMenuPortal = OverlayPortalController();

  Timer? _typeaheadTimer;
  String _typeaheadBuffer = '';

  @override
  void initState() {
    super.initState();
    _rebuildItemNodes();
    // Transfer focus into the menu so keyboard navigation works immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusInitial();
    });
  }

  @override
  void didUpdateWidget(covariant ContextMenuPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _closeSubMenu(refocusParent: false);
      _rebuildItemNodes();
    }
  }

  @override
  void dispose() {
    _typeaheadTimer?.cancel();
    for (final node in _itemNodes) {
      node.dispose();
    }
    for (final node in _subItemNodes) {
      node.dispose();
    }
    _scopeNode.dispose();
    super.dispose();
  }

  void _rebuildItemNodes() {
    for (final node in _itemNodes) {
      node.dispose();
    }
    _items = [
      for (final item in widget.items)
        if (!item.isSeparator) item,
    ];
    _itemNodes = List.generate(_items.length, (index) {
      return FocusNode(debugLabel: 'context-menu-item-${_items[index].name}')
        ..addListener(() => _handleMainFocusChanged(index));
    });
    _focusedIndex = -1;
  }

  void _handleMainFocusChanged(int index) {
    if (mounted &&
        index < _itemNodes.length &&
        _itemNodes[index].hasFocus &&
        _focusedIndex != index) {
      setState(() => _focusedIndex = index);
    }
  }

  void _handleSubFocusChanged(int index) {
    if (mounted &&
        index < _subItemNodes.length &&
        _subItemNodes[index].hasFocus &&
        _focusedSubIndex != index) {
      setState(() => _focusedSubIndex = index);
    }
  }

  void _focusInitial() {
    final first = _findEnabledIndex(_items, fromLast: false);
    if (first != null) {
      _itemNodes[first].requestFocus();
    } else {
      // Nothing enabled: keep focus on the scope so Escape still works.
      _scopeNode.requestFocus();
    }
  }

  static bool _isEnabled(OsContextMenuItem item) =>
      !item.disabled && !item.isSeparator;

  static int? _findEnabledIndex(
    List<OsContextMenuItem> items, {
    required bool fromLast,
  }) {
    if (fromLast) {
      for (var i = items.length - 1; i >= 0; i--) {
        if (_isEnabled(items[i])) return i;
      }
    } else {
      for (var i = 0; i < items.length; i++) {
        if (_isEnabled(items[i])) return i;
      }
    }
    return null;
  }

  int get _currentMainIndex {
    if (_focusedIndex >= 0 &&
        _focusedIndex < _itemNodes.length &&
        _itemNodes[_focusedIndex].hasFocus) {
      return _focusedIndex;
    }
    return -1;
  }

  int get _currentSubIndex {
    if (_focusedSubIndex >= 0 &&
        _focusedSubIndex < _subItemNodes.length &&
        _subItemNodes[_focusedSubIndex].hasFocus) {
      return _focusedSubIndex;
    }
    return -1;
  }

  void _moveHighlight(
    List<OsContextMenuItem> items,
    List<FocusNode> nodes,
    int currentIndex,
    int delta,
  ) {
    if (items.isEmpty) return;
    var index = currentIndex;
    for (var step = 0; step < items.length; step++) {
      index = (index + delta) % items.length;
      if (!_isEnabled(items[index])) continue;
      _clearTypeahead();
      nodes[index].requestFocus();
      return;
    }
  }

  void _jumpHighlight(
    List<OsContextMenuItem> items,
    List<FocusNode> nodes, {
    required bool last,
  }) {
    final target = _findEnabledIndex(items, fromLast: last);
    if (target == null) return;
    _clearTypeahead();
    nodes[target].requestFocus();
  }

  void _openSubMenuAt(int index, {required bool moveFocusIn}) {
    final item = _items[index];
    final subMenu = item.subMenu;
    if (!_isEnabled(item) || subMenu == null || subMenu.isEmpty) return;

    if (_openSubIndex == index) {
      if (moveFocusIn) _requestFocusedSubItem(_findEnabled(subMenu));
      return;
    }

    _clearTypeahead();
    // Safe outside the build phase: the framework defers overlay attachment.
    _subMenuPortal.show();
    setState(() {
      for (final node in _subItemNodes) {
        node.dispose();
      }
      _subGeneration++;
      _openSubIndex = index;
      _openSubItems = subMenu.toList();
      _focusedSubIndex = -1;
      _subItemNodes = List.generate(_openSubItems.length, (subIndex) {
        return FocusNode(
          debugLabel: 'context-menu-sub-${_openSubItems[subIndex].name}',
        )..addListener(() => _handleSubFocusChanged(subIndex));
      });
    });
    if (moveFocusIn) _requestFocusedSubItem(_findEnabled(subMenu));
  }

  int? _findEnabled(List<OsContextMenuItem> items) =>
      _findEnabledIndex(items, fromLast: false);

  void _requestFocusedSubItem(int? subIndex) {
    if (subIndex == null) return;
    // The sub-menu lives in an OverlayPortal that attaches one frame later.
    final generation = _subGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _openSubIndex == null ||
          _subGeneration != generation ||
          subIndex >= _subItemNodes.length) {
        return;
      }
      _subItemNodes[subIndex].requestFocus();
    });
  }

  void _closeSubMenu({required bool refocusParent}) {
    final parent = _openSubIndex;
    if (parent == null) return;
    _clearTypeahead();
    if (_subMenuPortal.isShowing) _subMenuPortal.hide();
    setState(() {
      _subGeneration++;
      for (final node in _subItemNodes) {
        node.dispose();
      }
      _subItemNodes = const [];
      _openSubItems = const [];
      _openSubIndex = null;
      _focusedSubIndex = -1;
    });
    if (refocusParent &&
        parent < _itemNodes.length &&
        _itemNodes[parent].canRequestFocus) {
      _itemNodes[parent].requestFocus();
    }
  }

  void _toggleSubMenuFromPointer(int index) {
    if (_openSubIndex == index) {
      _closeSubMenu(refocusParent: false);
    } else {
      _openSubMenuAt(index, moveFocusIn: false);
    }
  }

  void _activateMainItem(int index) {
    final item = _items[index];
    if (!_isEnabled(item)) return;
    final subMenu = item.subMenu;
    if (subMenu != null && subMenu.isNotEmpty) {
      _openSubMenuAt(index, moveFocusIn: true);
      return;
    }
    final action = item.action;
    if (action == null) return;
    widget.onDismiss();
    action();
  }

  void _activateSubItem(int index) {
    final item = _openSubItems[index];
    if (!_isEnabled(item)) return;
    final action = item.action;
    if (action == null) return;
    widget.onDismiss();
    action();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      if (_openSubIndex != null) {
        _closeSubMenu(refocusParent: true);
      } else {
        widget.onDismiss();
      }
      return KeyEventResult.handled;
    }

    final focusInSubMenu = _subItemNodes.any((n) => n.hasFocus);

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      if (focusInSubMenu) {
        _moveHighlight(_openSubItems, _subItemNodes, _currentSubIndex, delta);
      } else {
        _moveHighlight(_items, _itemNodes, _currentMainIndex, delta);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) {
      final last = key == LogicalKeyboardKey.end;
      if (focusInSubMenu) {
        _jumpHighlight(_openSubItems, _subItemNodes, last: last);
      } else {
        _jumpHighlight(_items, _itemNodes, last: last);
      }
      return KeyEventResult.handled;
    }

    if (!focusInSubMenu && key == LogicalKeyboardKey.arrowRight) {
      final index = _currentMainIndex;
      if (index >= 0) {
        final subMenu = _items[index].subMenu;
        if (subMenu != null && subMenu.isNotEmpty) {
          _openSubMenuAt(index, moveFocusIn: true);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    if (focusInSubMenu && key == LogicalKeyboardKey.arrowLeft) {
      _closeSubMenu(refocusParent: true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.select) {
      final index = focusInSubMenu ? _currentSubIndex : _currentMainIndex;
      if (index < 0) return KeyEventResult.ignored;
      if (focusInSubMenu) {
        _activateSubItem(index);
      } else {
        _activateMainItem(index);
      }
      return KeyEventResult.handled;
    }

    if (_applyTypeahead(event, focusInSubMenu)) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _applyTypeahead(KeyEvent event, bool inSubMenu) {
    if (event is KeyRepeatEvent) return false;
    final character = event.character;
    if (character == null || character.length != 1) return false;
    if (character.codeUnitAt(0) <= 0x20) return false;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return false;
    }

    final items = inSubMenu ? _openSubItems : _items;
    final nodes = inSubMenu ? _subItemNodes : _itemNodes;
    final current = inSubMenu ? _currentSubIndex : _currentMainIndex;

    _typeaheadBuffer += character.toLowerCase();
    _restartTypeaheadTimer();

    final match = _findTypeaheadMatch(items, current);
    if (match == null) return false;
    nodes[match].requestFocus();
    return true;
  }

  int? _findTypeaheadMatch(List<OsContextMenuItem> items, int current) {
    if (items.isEmpty || _typeaheadBuffer.isEmpty) return null;
    for (var offset = 1; offset <= items.length; offset++) {
      final index = (current + offset) % items.length;
      if (_isEnabled(items[index]) &&
          items[index].name.toLowerCase().startsWith(_typeaheadBuffer)) {
        return index;
      }
    }
    return null;
  }

  void _restartTypeaheadTimer() {
    _typeaheadTimer?.cancel();
    _typeaheadTimer = Timer(_typeaheadResetDuration, _clearTypeahead);
  }

  void _clearTypeahead() {
    _typeaheadTimer?.cancel();
    _typeaheadTimer = null;
    _typeaheadBuffer = '';
  }

  double _estimateHeight() {
    var height = 0.0;
    for (final item in widget.items) {
      height += item.isSeparator ? 9.0 : 36.0;
    }
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedGridTheme.from(widget.theme);

    return GridPopupSurface(
      key: const Key('context-menu-surface'),
      anchorRect: Rect.fromLTWH(widget.position.dx, widget.position.dy, 0, 0),
      anchorMode: PopupAnchorMode.belowAnchor,
      gap: 0,
      gridSize: widget.gridSize,
      popupWidth: _popupWidth,
      estimatedHeight: _estimateHeight(),
      onBarrierTap: widget.onDismiss,
      blurSigma: widget.theme?.popupBlurSigma ?? 0,
      contentBuilder: (context) => FocusScope(
        node: _scopeNode,
        onKeyEvent: _handleKeyEvent,
        child: FocusTraversalGroup(
          child: Material(
            elevation: resolved.popupElevation,
            borderRadius: BorderRadius.circular(resolved.panelRadius),
            color: resolved.background,
            child: Container(
              width: _popupWidth,
              decoration: BoxDecoration(
                border: Border.all(color: resolved.border),
                borderRadius: BorderRadius.circular(resolved.panelRadius),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(resolved.panelRadius),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildRows(resolved),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRows(ResolvedGridTheme resolved) {
    final widgets = <Widget>[];
    var navigableIndex = 0;
    for (final item in widget.items) {
      if (item.isSeparator) {
        widgets.add(Divider(height: 1, thickness: 1, color: resolved.border));
        continue;
      }
      widgets.add(_buildRow(item, navigableIndex, resolved));
      navigableIndex++;
    }
    return widgets;
  }

  Widget _buildRow(
    OsContextMenuItem item,
    int index,
    ResolvedGridTheme resolved,
  ) {
    final subMenu = item.subMenu;
    final hasSubMenu = subMenu != null && subMenu.isNotEmpty;

    return Focus(
      focusNode: _itemNodes[index],
      canRequestFocus: !item.disabled,
      child: hasSubMenu
          ? _SubMenuItemWidget(
              item: item,
              resolved: resolved,
              onDismiss: widget.onDismiss,
              isOpen: _openSubIndex == index,
              isHighlighted: _focusedIndex == index,
              subFocusNodes: _openSubIndex == index ? _subItemNodes : const [],
              highlightedChildIndex: _openSubIndex == index
                  ? _focusedSubIndex
                  : null,
              subMenuPortal: _subMenuPortal,
              onHoverOpen: () => _openSubMenuAt(index, moveFocusIn: false),
              onHoverClose: () {
                if (_openSubIndex == index) _closeSubMenu(refocusParent: false);
              },
              onTapParent: () => _toggleSubMenuFromPointer(index),
              onChildTap: _activateSubItem,
            )
          : _ContextMenuItemWidget(
              item: item,
              resolved: resolved,
              isHighlighted: _focusedIndex == index,
              onTap: item.disabled || item.action == null
                  ? null
                  : () => _activateMainItem(index),
            ),
    );
  }
}

/// A single interactive context menu item row with hover/focus highlight.
class _ContextMenuItemWidget extends StatefulWidget {
  const _ContextMenuItemWidget({
    required this.item,
    required this.resolved,
    required this.isHighlighted,
    this.onTap,
  });

  final OsContextMenuItem item;
  final ResolvedGridTheme resolved;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  State<_ContextMenuItemWidget> createState() => _ContextMenuItemWidgetState();
}

class _ContextMenuItemWidgetState extends State<_ContextMenuItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final resolved = widget.resolved;
    final isDisabled = widget.item.disabled;
    final textColor = isDisabled
        ? resolved.disabledForeground
        : resolved.foreground;
    final iconColor = isDisabled
        ? resolved.disabledForeground
        : resolved.mutedForeground;
    final highlight = (widget.isHighlighted || _hovered) && !isDisabled;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: highlight ? resolved.hover : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                Icon(widget.item.icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.item.name,
                  style: resolved.text(13, color: textColor),
                ),
              ),
              if (widget.item.shortcut != null)
                Text(
                  widget.item.shortcut!,
                  style: resolved.text(11, color: resolved.hintForeground),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A menu item that owns a sub-menu shown on hover, click, or ArrowRight.
///
/// Visibility and sub-item focus nodes are owned by the popup state so the
/// whole menu shares one keyboard navigation model; this widget only tracks
/// pointer presence for hover behaviour.
class _SubMenuItemWidget extends StatefulWidget {
  const _SubMenuItemWidget({
    required this.item,
    required this.resolved,
    required this.onDismiss,
    required this.isOpen,
    required this.isHighlighted,
    required this.subFocusNodes,
    required this.highlightedChildIndex,
    required this.subMenuPortal,
    required this.onHoverOpen,
    required this.onHoverClose,
    required this.onTapParent,
    required this.onChildTap,
  });

  final OsContextMenuItem item;
  final ResolvedGridTheme resolved;
  final VoidCallback onDismiss;
  final bool isOpen;
  final bool isHighlighted;
  final List<FocusNode> subFocusNodes;
  final int? highlightedChildIndex;
  final OverlayPortalController subMenuPortal;
  final VoidCallback onHoverOpen;
  final VoidCallback onHoverClose;
  final VoidCallback onTapParent;
  final ValueChanged<int> onChildTap;

  @override
  State<_SubMenuItemWidget> createState() => _SubMenuItemWidgetState();
}

class _SubMenuItemWidgetState extends State<_SubMenuItemWidget> {
  bool _pointerInRegion = false;
  bool _hovered = false;
  final LayerLink _layerLink = LayerLink();

  void _handleExit() {
    _pointerInRegion = false;
    // Delay hiding to allow the mouse to travel onto the sub-menu surface
    // (which shares [_pointerInRegion] through its own MouseRegion).
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_pointerInRegion && mounted && widget.isOpen) {
        widget.onHoverClose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = widget.resolved;
    final isDisabled = widget.item.disabled;
    final textColor = isDisabled
        ? resolved.disabledForeground
        : resolved.foreground;
    final highlight =
        (widget.isOpen || widget.isHighlighted || _hovered) && !isDisabled;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: widget.subMenuPortal,
        overlayChildBuilder: (overlayContext) {
          return CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.topLeft,
            showWhenUnlinked: false,
            child: Align(
              // OverlayPortal lays its deferred child out with tight
              // window-size constraints (Flutter 3.44+). Without this Align
              // the fixed-width SizedBox below is clamped up to the window
              // size and the submenu fills the screen.
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Material(
                    elevation: resolved.popupElevation,
                    borderRadius: BorderRadius.circular(resolved.panelRadius),
                    color: resolved.background,
                    child: MouseRegion(
                      onEnter: (_) => _pointerInRegion = true,
                      onExit: (_) => _handleExit(),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: resolved.border),
                          borderRadius: BorderRadius.circular(
                            resolved.panelRadius,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            resolved.panelRadius,
                          ),
                          child: FocusTraversalGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _buildSubMenuRows(resolved),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: MouseRegion(
          onEnter: (_) {
            _pointerInRegion = true;
            _hovered = true;
            widget.onHoverOpen();
          },
          onExit: (_) {
            _hovered = false;
            _handleExit();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isDisabled ? null : widget.onTapParent,
            child: Container(
              color: highlight ? resolved.hover : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (widget.item.icon != null) ...[
                    Icon(
                      widget.item.icon,
                      size: 16,
                      color: isDisabled
                          ? resolved.disabledForeground
                          : resolved.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.item.name,
                      style: resolved.text(13, color: textColor),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: resolved.hintForeground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSubMenuRows(ResolvedGridTheme resolved) {
    final subMenu = widget.item.subMenu!;
    final nodes = widget.subFocusNodes;
    final widgets = <Widget>[];
    for (var i = 0; i < subMenu.length; i++) {
      final subItem = subMenu[i];
      if (subItem.isSeparator) {
        widgets.add(Divider(height: 1, thickness: 1, color: resolved.border));
        continue;
      }
      widgets.add(
        Focus(
          focusNode: i < nodes.length ? nodes[i] : null,
          canRequestFocus: !subItem.disabled,
          child: _ContextMenuItemWidget(
            item: subItem,
            resolved: resolved,
            isHighlighted: widget.highlightedChildIndex == i,
            onTap: subItem.disabled || subItem.action == null
                ? null
                : () => widget.onChildTap(i),
          ),
        ),
      );
    }
    return widgets;
  }
}
