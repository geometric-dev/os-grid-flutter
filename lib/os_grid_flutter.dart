/// A high-performance, feature-rich data grid for Flutter.
///
/// Native Dart implementation of OS Grid for desktop and mobile platforms.
library;

// Accessibility
export 'src/accessibility/grid_live_region.dart';
export 'src/accessibility/grid_semantics.dart';
export 'src/accessibility/high_contrast_theme.dart';
// Aggregation
export 'src/aggregation/aggregation_service.dart';
export 'src/aligned_grids/aligned_grid_service.dart';
// Aligned Grids
export 'src/aligned_grids/os_aligned_grid.dart';
// Value Cache
export 'src/cache/value_cache.dart';
export 'src/cache/value_prefetcher.dart';
// Cell Span
export 'src/cell_span/cell_span_model.dart';
export 'src/cell_span/cell_span_params.dart';
export 'src/cell_span/cell_span_service.dart';
// Charts
export 'src/charts/chart_definition.dart';
export 'src/charts/chart_palette_popup.dart';
export 'src/charts/chart_range_service.dart';
// Clipboard
export 'src/clipboard/clipboard_service.dart';
// Column definitions
export 'src/columns/column_def_resolver.dart';
export 'src/columns/column_ref.dart';
export 'src/columns/column_state.dart';
export 'src/columns/os_column_annotation.dart';
export 'src/columns/os_column_def.dart';
export 'src/columns/os_column_factory.dart';
export 'src/columns/os_column_group.dart';
export 'src/columns/os_column_pin.dart';
export 'src/columns/os_column_schema.dart';
export 'src/context_menu/context_menu_popup.dart';
// Context Menu
export 'src/context_menu/context_menu_types.dart';
// Debug
export 'src/debug/grid_inspector.dart';
// External drag and drop
export 'src/drag_and_drop/drag_and_drop_config.dart';
export 'src/drag_and_drop/drag_and_drop_events.dart';
export 'src/drag_and_drop/drag_and_drop_service.dart';
// Editing
export 'src/editing/os_cell_editor.dart';
export 'src/editing/os_checkbox_cell_editor.dart';
export 'src/editing/os_custom_cell_editor.dart';
export 'src/editing/os_date_cell_editor.dart';
export 'src/editing/os_date_string_cell_editor.dart';
export 'src/editing/os_large_text_cell_editor.dart';
export 'src/editing/os_number_cell_editor.dart';
export 'src/editing/os_rich_select_cell_editor.dart';
export 'src/editing/os_select_cell_editor.dart';
export 'src/editing/os_text_cell_editor.dart';
export 'src/editing/undo_redo_service.dart';
export 'src/events/cell_events.dart';
export 'src/events/cell_focus_events.dart';
export 'src/events/chart_events.dart';
export 'src/events/clipboard_events.dart';
export 'src/events/column_events.dart';
export 'src/events/column_hover_events.dart';
export 'src/events/context_menu_events.dart';
export 'src/events/editing_events.dart';
export 'src/events/expand_collapse_events.dart';
export 'src/events/filter_events.dart';
export 'src/events/grid_state_events.dart';
export 'src/events/infinite_row_model_events.dart';
export 'src/events/lifecycle_events.dart';
// Events
export 'src/events/os_grid_event.dart';
export 'src/events/pagination_events.dart';
export 'src/events/pinned_row_events.dart';
export 'src/events/pivot_events.dart';
export 'src/events/row_data_events.dart';
export 'src/events/row_events.dart';
export 'src/events/row_group_events.dart';
export 'src/events/selection_events.dart';
export 'src/events/side_bar_events.dart';
export 'src/events/sort_events.dart';
export 'src/events/tooltip_events.dart';
export 'src/events/undo_redo_events.dart';
// Export
export 'src/export/csv_export.dart';
export 'src/export/xlsx_export.dart';
export 'src/filtering/date_filter_presets.dart';
export 'src/filtering/filter_evaluator.dart';
export 'src/filtering/filter_model.dart';
export 'src/filtering/filter_popup.dart';
export 'src/filtering/os_bigint_filter.dart';
export 'src/filtering/os_custom_filter.dart';
export 'src/filtering/os_date_filter.dart';
// Filtering
export 'src/filtering/os_filter.dart';
export 'src/filtering/os_number_filter.dart';
export 'src/filtering/os_set_filter.dart';
export 'src/filtering/os_text_filter.dart';
// Grid State
export 'src/grid_state/grid_state.dart';
export 'src/grid_state/grid_state_service.dart';
export 'src/infinite_row_model/block_cache.dart';
export 'src/infinite_row_model/infinite_datasource.dart';
// Infinite Row Model
export 'src/infinite_row_model/infinite_row_model.dart';
// Locale
export 'src/locale/os_locale_text.dart';
// Menu
export 'src/menu/column_menu_popup.dart';
export 'src/menu/os_column_menu_def.dart';
export 'src/menu/tabbed_column_menu.dart';
// Modules
export 'src/modules/clipboard_module.dart';
export 'src/modules/editing_module.dart';
export 'src/modules/feature_module.dart';
export 'src/modules/os_module.dart';
export 'src/modules/set_filter_module.dart';
export 'src/modules/sparkline_module.dart';
export 'src/modules/tree_data_module.dart';
// Core widget
export 'src/os_grid.dart';
export 'src/os_grid_controller.dart';
// Pagination
export 'src/pagination/os_pagination.dart';
// Params (callback parameter types)
export 'src/params/cell_renderer_params.dart';
export 'src/params/get_quick_filter_text_params.dart';
export 'src/params/header_value_getter_params.dart';
export 'src/params/navigation_params.dart';
export 'src/params/os_grid_callback_params.dart';
export 'src/params/os_grid_edit_callback_params.dart';
export 'src/params/value_formatter_params.dart';
export 'src/params/value_getter_params.dart';
export 'src/params/value_parser_params.dart';
export 'src/params/value_setter_params.dart';
// Pivot Mode
export 'src/pivot/pivot_service.dart';
// Render API
export 'src/render_api/cell_flash.dart';
export 'src/rendering/avatar_options.dart';
export 'src/rendering/column_group_layout.dart';
export 'src/rendering/focus_command.dart';
export 'src/rendering/grid_hit_test.dart';
export 'src/rendering/image_cell_cache.dart';
export 'src/rendering/image_options.dart';
export 'src/rendering/master_detail.dart';
export 'src/rendering/progress_bar_options.dart';
export 'src/rendering/sparkline_options.dart';
export 'src/rendering/text_painter_cache.dart';
// Rendering (internal, but exported for testing/advanced use)
export 'src/rendering/virtualised_grid.dart';
export 'src/row_auto_height/auto_height_calculator.dart';
// Row Auto Height
export 'src/row_auto_height/row_auto_height_module.dart';
export 'src/row_auto_height/row_height_layout.dart';
// Row drag
export 'src/row_drag/row_drag_event.dart';
export 'src/row_grouping/row_group_node.dart';
// Row Grouping
export 'src/row_grouping/row_group_panel_visibility.dart';
export 'src/row_grouping/row_group_service.dart';
export 'src/row_grouping/row_group_state.dart';
export 'src/row_grouping/tree_data_service.dart';
export 'src/row_model/async_transaction_service.dart';
export 'src/row_model/delta_sort_service.dart';
export 'src/row_model/immutable_data_service.dart';
// Row model
export 'src/row_model/row_node.dart';
export 'src/row_model/row_transaction.dart';
export 'src/row_model/server_side_datasource.dart';
export 'src/row_model/server_side_row_model.dart';
// Scrolling
export 'src/scrolling/scroll_command.dart';
export 'src/selection/cell_range.dart';
// Selection
export 'src/selection/os_row_selection.dart';
export 'src/side_bar/columns_tool_panel.dart';
export 'src/side_bar/filters_tool_panel.dart';
export 'src/side_bar/os_side_bar.dart';
// Side Bar
export 'src/side_bar/os_side_bar_def.dart';
export 'src/side_bar/os_tool_panel_def.dart';
// Sorting
export 'src/sorting/sort_direction.dart';
export 'src/sorting/sort_indicator_info.dart';
export 'src/sorting/sort_model.dart';
export 'src/sorting/sort_service.dart';
// Status bar
export 'src/status_bar/status_bar.dart';
export 'src/theming/os_cell_style.dart';
// Theming
export 'src/theming/os_grid_theme.dart';
export 'src/theming/os_row_style.dart';
export 'src/tooltip/tooltip_overlay.dart';
// Tooltip
export 'src/tooltip/tooltip_params.dart';
export 'src/tooltip/tooltip_service.dart';
// Utils
export 'src/utils/grid_error.dart';
// Validation
export 'src/validation/grid_validator.dart';
