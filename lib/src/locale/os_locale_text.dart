/// Holds all translatable string keys used by the grid UI.
///
/// Provides English defaults for every key. Override individual strings
/// by passing a custom instance to the `localeText` property on `OsGrid`,
/// or use [OsLocaleText.fromMap] to override only specific keys from a map.
///
/// ```dart
/// OsGrid(
///   localeText: OsLocaleText(
///     noRowsToShow: 'Keine Zeilen vorhanden',
///     page: 'Seite',
///   ),
///   ...
/// )
/// ```
class OsLocaleText {
  /// Creates a locale text instance with English defaults.
  ///
  /// Any parameter left as `null` uses the built-in English default.
  const OsLocaleText({
    String? noRowsToShow,
    String? page,
    String? of,
    String? to,
    String? more,
    String? next,
    String? previous,
    String? first,
    String? last,
    String? loadingOoo,
    String? selectAll,
    String? searchOoo,
    String? filterOoo,
    String? applyFilter,
    String? resetFilter,
    String? clearFilter,
    String? equals,
    String? notEqual,
    String? contains,
    String? notContains,
    String? startsWith,
    String? endsWith,
    String? lessThan,
    String? lessThanOrEqual,
    String? greaterThan,
    String? greaterThanOrEqual,
    String? inRange,
    String? blank,
    String? notBlank,
    String? andCondition,
    String? orCondition,
    String? pinLeft,
    String? pinRight,
    String? noPin,
    String? autosizeThisColumn,
    String? autosizeAllColumns,
    String? resetColumns,
    String? sortAscending,
    String? sortDescending,
    String? clearSort,
    String? general,
    String? columns,
    String? filters,
    String? filter,
    String? clear,
    String? apply,
    String? pinColumn,
    String? plusCondition,
    String? expandAll,
    String? collapseAll,
    String? deselectAll,
    String? fromOoo,
    String? toOoo,
    String? filterValueOoo,
    String? dateFormatOoo,
    String? noActiveFilter,
    String? active,
    String? isBlank,
    String? isNotBlank,
    String? blanks,
    String? before,
    String? beforeOrOn,
    String? after,
    String? afterOrOn,
    String? today,
    String? selectTime,
    String? cancel,
    String? ok,
    String? mondayShort,
    String? tuesdayShort,
    String? wednesdayShort,
    String? thursdayShort,
    String? fridayShort,
    String? saturdayShort,
    String? sundayShort,
    String? january,
    String? february,
    String? march,
    String? april,
    String? may,
    String? june,
    String? july,
    String? august,
    String? september,
    String? october,
    String? november,
    String? december,
    String? summed,
    String? averaged,
    String? minimum,
    String? maximum,
    String? count,
    String? sortedAscending,
    String? sortedDescending,
    String? selected,
    String? notSelected,
    String? rowGroup,
    String? children,
    String? rowsSelected,
    String? gridSummary,
    String? menu,
    String? dialog,
  }) : noRowsToShow = noRowsToShow ?? 'No Rows To Show',
       page = page ?? 'Page',
       of = of ?? 'of',
       to = to ?? 'to',
       more = more ?? 'more',
       next = next ?? 'Next',
       previous = previous ?? 'Previous',
       first = first ?? 'First',
       last = last ?? 'Last',
       loadingOoo = loadingOoo ?? 'Loading...',
       selectAll = selectAll ?? 'Select All',
       searchOoo = searchOoo ?? 'Search...',
       filterOoo = filterOoo ?? 'Filter...',
       applyFilter = applyFilter ?? 'Apply Filter',
       resetFilter = resetFilter ?? 'Reset Filter',
       clearFilter = clearFilter ?? 'Clear Filter',
       equals = equals ?? 'Equals',
       notEqual = notEqual ?? 'Not equal',
       contains = contains ?? 'Contains',
       notContains = notContains ?? 'Not contains',
       startsWith = startsWith ?? 'Starts with',
       endsWith = endsWith ?? 'Ends with',
       lessThan = lessThan ?? 'Less than',
       lessThanOrEqual = lessThanOrEqual ?? 'Less than or equal',
       greaterThan = greaterThan ?? 'Greater than',
       greaterThanOrEqual = greaterThanOrEqual ?? 'Greater than or equal',
       inRange = inRange ?? 'In range',
       blank = blank ?? 'Blank',
       notBlank = notBlank ?? 'Not blank',
       andCondition = andCondition ?? 'AND',
       orCondition = orCondition ?? 'OR',
       pinLeft = pinLeft ?? 'Pin Left',
       pinRight = pinRight ?? 'Pin Right',
       noPin = noPin ?? 'No Pin',
       autosizeThisColumn = autosizeThisColumn ?? 'Autosize This Column',
       autosizeAllColumns = autosizeAllColumns ?? 'Autosize All Columns',
       resetColumns = resetColumns ?? 'Reset Columns',
       sortAscending = sortAscending ?? 'Sort Ascending',
       sortDescending = sortDescending ?? 'Sort Descending',
       clearSort = clearSort ?? 'Clear Sort',
       general = general ?? 'General',
       columns = columns ?? 'Columns',
       filters = filters ?? 'Filters',
       filter = filter ?? 'Filter',
       clear = clear ?? 'Clear',
       apply = apply ?? 'Apply',
       pinColumn = pinColumn ?? 'Pin Column',
       plusCondition = plusCondition ?? '+ Condition',
       expandAll = expandAll ?? 'Expand All',
       collapseAll = collapseAll ?? 'Collapse All',
       deselectAll = deselectAll ?? 'Deselect All',
       fromOoo = fromOoo ?? 'From...',
       toOoo = toOoo ?? 'To...',
       filterValueOoo = filterValueOoo ?? 'Filter value...',
       dateFormatOoo = dateFormatOoo ?? 'YYYY-MM-DD',
       noActiveFilter = noActiveFilter ?? 'No active filter',
       active = active ?? 'Active',
       isBlank = isBlank ?? 'Is blank',
       isNotBlank = isNotBlank ?? 'Is not blank',
       blanks = blanks ?? '(Blanks)',
       before = before ?? 'Before',
       beforeOrOn = beforeOrOn ?? 'Before or on',
       after = after ?? 'After',
       afterOrOn = afterOrOn ?? 'After or on',
       today = today ?? 'Today',
       selectTime = selectTime ?? 'Select time',
       cancel = cancel ?? 'Cancel',
       ok = ok ?? 'OK',
       mondayShort = mondayShort ?? 'Mo',
       tuesdayShort = tuesdayShort ?? 'Tu',
       wednesdayShort = wednesdayShort ?? 'We',
       thursdayShort = thursdayShort ?? 'Th',
       fridayShort = fridayShort ?? 'Fr',
       saturdayShort = saturdayShort ?? 'Sa',
       sundayShort = sundayShort ?? 'Su',
       january = january ?? 'January',
       february = february ?? 'February',
       march = march ?? 'March',
       april = april ?? 'April',
       may = may ?? 'May',
       june = june ?? 'June',
       july = july ?? 'July',
       august = august ?? 'August',
       september = september ?? 'September',
       october = october ?? 'October',
       november = november ?? 'November',
       december = december ?? 'December',
       summed = summed ?? 'Sum',
       averaged = averaged ?? 'Avg',
       minimum = minimum ?? 'Min',
       maximum = maximum ?? 'Max',
       count = count ?? 'Count',
       sortedAscending = sortedAscending ?? 'sorted ascending',
       sortedDescending = sortedDescending ?? 'sorted descending',
       selected = selected ?? 'Selected',
       notSelected = notSelected ?? 'Not selected',
       rowGroup = rowGroup ?? 'Row Group',
       children = children ?? 'children',
       rowsSelected = rowsSelected ?? '{n} rows selected',
       gridSummary = gridSummary ?? '{rows} rows, {selected} selected',
       menu = menu ?? 'Menu',
       dialog = dialog ?? 'Dialog';

  // --- Overlay messages ---

  /// Displayed when the grid has no rows to show.
  final String noRowsToShow;

  /// Displayed while data is loading.
  final String loadingOoo;

  // --- Pagination ---

  /// Label for the page number (e.g. "Page 1 of 5").
  final String page;

  /// Separator in "Page 1 of 5".
  final String of;

  /// Separator in "1 to 10 of 100".
  final String to;

  /// Label for "more" in pagination context.
  final String more;

  /// Label for the Next page button.
  final String next;

  /// Label for the Previous page button.
  final String previous;

  /// Label for the First page button.
  final String first;

  /// Label for the Last page button.
  final String last;

  // --- Selection ---

  /// Label for the "Select All" checkbox/action.
  final String selectAll;

  // --- Search/Filter placeholders ---

  /// Placeholder text for search inputs.
  final String searchOoo;

  /// Placeholder text for filter inputs.
  final String filterOoo;

  // --- Filter actions ---

  /// Label for the "Apply Filter" button.
  final String applyFilter;

  /// Label for the "Reset Filter" button.
  final String resetFilter;

  /// Label for the "Clear Filter" button.
  final String clearFilter;

  // --- Filter operations ---

  /// Label for the "Equals" filter operation.
  final String equals;

  /// Label for the "Not equal" filter operation.
  final String notEqual;

  /// Label for the "Contains" filter operation.
  final String contains;

  /// Label for the "Not contains" filter operation.
  final String notContains;

  /// Label for the "Starts with" filter operation.
  final String startsWith;

  /// Label for the "Ends with" filter operation.
  final String endsWith;

  /// Label for the "Less than" filter operation.
  final String lessThan;

  /// Label for the "Less than or equal" filter operation.
  final String lessThanOrEqual;

  /// Label for the "Greater than" filter operation.
  final String greaterThan;

  /// Label for the "Greater than or equal" filter operation.
  final String greaterThanOrEqual;

  /// Label for the "In range" filter operation.
  final String inRange;

  /// Label for the "Blank" filter operation.
  final String blank;

  /// Label for the "Not blank" filter operation.
  final String notBlank;

  // --- Filter condition combinators ---

  /// Label for the AND condition combinator.
  final String andCondition;

  /// Label for the OR condition combinator.
  final String orCondition;

  // --- Column menu ---

  /// Label for "Pin Left" in the column menu.
  final String pinLeft;

  /// Label for "Pin Right" in the column menu.
  final String pinRight;

  /// Label for "No Pin" in the column menu.
  final String noPin;

  /// Label for "Autosize This Column" in the column menu.
  final String autosizeThisColumn;

  /// Label for "Autosize All Columns" in the column menu.
  final String autosizeAllColumns;

  /// Label for "Reset Columns" in the column menu.
  final String resetColumns;

  // --- Sort ---

  /// Label for "Sort Ascending" in the column menu.
  final String sortAscending;

  /// Label for "Sort Descending" in the column menu.
  final String sortDescending;

  /// Label for "Clear Sort" in the column menu.
  final String clearSort;

  // --- Tabs and panel titles ---

  /// Label for the "General" tab in the tabbed column menu.
  final String general;

  /// Label for the "Columns" tab / Columns tool panel title.
  final String columns;

  /// Label for the "Filters" tool panel title.
  final String filters;

  /// Label for the "Filter" tab in the tabbed column menu.
  final String filter;

  // --- Common actions ---

  /// Label for the "Clear" button.
  final String clear;

  /// Label for the "Apply" button.
  final String apply;

  /// Header label for the pin sub-menu in the column menu.
  final String pinColumn;

  /// Label for adding an additional filter condition.
  final String plusCondition;

  /// Tooltip/label for the Expand All control.
  final String expandAll;

  /// Tooltip/label for the Collapse All control.
  final String collapseAll;

  /// Tooltip/label for the Deselect All control.
  final String deselectAll;

  // --- Filter input placeholders ---

  /// Placeholder for the lower bound of a range filter.
  final String fromOoo;

  /// Placeholder for the upper bound of a range filter.
  final String toOoo;

  /// Placeholder for a single filter value input.
  final String filterValueOoo;

  /// Hint showing the expected date format in date filter inputs.
  final String dateFormatOoo;

  // --- Filters tool panel summaries ---

  /// Shown when a filterable column has no active filter.
  final String noActiveFilter;

  /// Shown when a filter is active but has no describable conditions.
  final String active;

  /// Summary label for the blank condition.
  final String isBlank;

  /// Summary label for the not blank condition.
  final String isNotBlank;

  /// Label for the "(Blanks)" checklist entry in the set filter.
  final String blanks;

  // --- Date-specific operations ---

  /// Label for the date "before" operation.
  final String before;

  /// Label for the date "before or on" operation.
  final String beforeOrOn;

  /// Label for the date "after" operation.
  final String after;

  /// Label for the date "after or on" operation.
  final String afterOrOn;

  // --- Date picker ---

  /// Label for the Today button in the date picker.
  final String today;

  /// Title shown while picking a time after a date selection.
  final String selectTime;

  /// Label for the Cancel button.
  final String cancel;

  /// Label for the OK (confirm) button.
  final String ok;

  /// Abbreviated Monday label in the date picker.
  final String mondayShort;

  /// Abbreviated Tuesday label in the date picker.
  final String tuesdayShort;

  /// Abbreviated Wednesday label in the date picker.
  final String wednesdayShort;

  /// Abbreviated Thursday label in the date picker.
  final String thursdayShort;

  /// Abbreviated Friday label in the date picker.
  final String fridayShort;

  /// Abbreviated Saturday label in the date picker.
  final String saturdayShort;

  /// Abbreviated Sunday label in the date picker.
  final String sundayShort;

  /// Name of January.
  final String january;

  /// Name of February.
  final String february;

  /// Name of March.
  final String march;

  /// Name of April.
  final String april;

  /// Name of May.
  final String may;

  /// Name of June.
  final String june;

  /// Name of July.
  final String july;

  /// Name of August.
  final String august;

  /// Name of September.
  final String september;

  /// Name of October.
  final String october;

  /// Name of November.
  final String november;

  /// Name of December.
  final String december;

  // --- Status bar aggregation panels ---

  /// Default label for the "sum" status panel.
  final String summed;

  /// Default label for the "avg" status panel.
  final String averaged;

  /// Default label for the "min" status panel.
  final String minimum;

  /// Default label for the "max" status panel.
  final String maximum;

  /// Default label for the "count" status panel.
  final String count;

  // --- Accessibility semantics ---

  /// State description appended to a header label when the column is sorted
  /// ascending (e.g. "Name, sorted ascending").
  ///
  /// Distinct from [sortAscending], which labels the sort menu action.
  final String sortedAscending;

  /// State description appended to a header label when the column is sorted
  /// descending (e.g. "Name, sorted descending").
  final String sortedDescending;

  /// Label for a selected checkbox cell.
  final String selected;

  /// Label for an unselected checkbox cell.
  final String notSelected;

  /// Prefix label for tree-data group rows, which have no backing column
  /// field name (e.g. "Row Group: USA — 5 children").
  final String rowGroup;

  /// Word for the child count in group row labels
  /// (e.g. "Country: USA — 5 children").
  final String children;

  /// Announcement when rows are selected.
  ///
  /// Interpolation: the literal token `{n}` is replaced with the selected
  /// row count by the caller. No plural rules are applied; provide a fully
  /// formatted string via an override if pluralisation is required.
  final String rowsSelected;

  /// Live-region announcement published after model updates.
  ///
  /// Interpolation: literal tokens `{rows}` and `{selected}` are replaced
  /// with the total and selected row counts by the caller. No plural rules
  /// are applied.
  final String gridSummary;

  /// Generic label describing a popup menu surface for screen readers.
  final String menu;

  /// Generic label describing a dialog-like popup surface for screen readers.
  final String dialog;

  /// The twelve month names, January through December, in order.
  List<String> get monthNames => [
    january,
    february,
    march,
    april,
    may,
    june,
    july,
    august,
    september,
    october,
    november,
    december,
  ];

  /// The seven abbreviated day-of-week labels, Monday through Sunday, in
  /// order (matching the calendar's week layout).
  List<String> get dayOfWeekInitials => [
    mondayShort,
    tuesdayShort,
    wednesdayShort,
    thursdayShort,
    fridayShort,
    saturdayShort,
    sundayShort,
  ];

  // --- Factory constructors ---

  /// Creates an [OsLocaleText] by merging a map of overrides onto the
  /// English defaults.
  ///
  /// Keys in the map correspond to the property names (camelCase).
  /// Unknown keys are silently ignored.
  ///
  /// ```dart
  /// OsGrid(
  ///   localeText: OsLocaleText.fromMap({
  ///     'noRowsToShow': 'Aucune ligne à afficher',
  ///     'page': 'Page',
  ///   }),
  ///   ...
  /// )
  /// ```
  factory OsLocaleText.fromMap(Map<String, String> overrides) {
    return OsLocaleText(
      noRowsToShow: overrides['noRowsToShow'],
      page: overrides['page'],
      of: overrides['of'],
      to: overrides['to'],
      more: overrides['more'],
      next: overrides['next'],
      previous: overrides['previous'],
      first: overrides['first'],
      last: overrides['last'],
      loadingOoo: overrides['loadingOoo'],
      selectAll: overrides['selectAll'],
      searchOoo: overrides['searchOoo'],
      filterOoo: overrides['filterOoo'],
      applyFilter: overrides['applyFilter'],
      resetFilter: overrides['resetFilter'],
      clearFilter: overrides['clearFilter'],
      equals: overrides['equals'],
      notEqual: overrides['notEqual'],
      contains: overrides['contains'],
      notContains: overrides['notContains'],
      startsWith: overrides['startsWith'],
      endsWith: overrides['endsWith'],
      lessThan: overrides['lessThan'],
      lessThanOrEqual: overrides['lessThanOrEqual'],
      greaterThan: overrides['greaterThan'],
      greaterThanOrEqual: overrides['greaterThanOrEqual'],
      inRange: overrides['inRange'],
      blank: overrides['blank'],
      notBlank: overrides['notBlank'],
      andCondition: overrides['andCondition'],
      orCondition: overrides['orCondition'],
      pinLeft: overrides['pinLeft'],
      pinRight: overrides['pinRight'],
      noPin: overrides['noPin'],
      autosizeThisColumn: overrides['autosizeThisColumn'],
      autosizeAllColumns: overrides['autosizeAllColumns'],
      resetColumns: overrides['resetColumns'],
      sortAscending: overrides['sortAscending'],
      sortDescending: overrides['sortDescending'],
      clearSort: overrides['clearSort'],
      general: overrides['general'],
      columns: overrides['columns'],
      filters: overrides['filters'],
      filter: overrides['filter'],
      clear: overrides['clear'],
      apply: overrides['apply'],
      pinColumn: overrides['pinColumn'],
      plusCondition: overrides['plusCondition'],
      expandAll: overrides['expandAll'],
      collapseAll: overrides['collapseAll'],
      deselectAll: overrides['deselectAll'],
      fromOoo: overrides['fromOoo'],
      toOoo: overrides['toOoo'],
      filterValueOoo: overrides['filterValueOoo'],
      dateFormatOoo: overrides['dateFormatOoo'],
      noActiveFilter: overrides['noActiveFilter'],
      active: overrides['active'],
      isBlank: overrides['isBlank'],
      isNotBlank: overrides['isNotBlank'],
      blanks: overrides['blanks'],
      before: overrides['before'],
      beforeOrOn: overrides['beforeOrOn'],
      after: overrides['after'],
      afterOrOn: overrides['afterOrOn'],
      today: overrides['today'],
      selectTime: overrides['selectTime'],
      cancel: overrides['cancel'],
      ok: overrides['ok'],
      mondayShort: overrides['mondayShort'],
      tuesdayShort: overrides['tuesdayShort'],
      wednesdayShort: overrides['wednesdayShort'],
      thursdayShort: overrides['thursdayShort'],
      fridayShort: overrides['fridayShort'],
      saturdayShort: overrides['saturdayShort'],
      sundayShort: overrides['sundayShort'],
      january: overrides['january'],
      february: overrides['february'],
      march: overrides['march'],
      april: overrides['april'],
      may: overrides['may'],
      june: overrides['june'],
      july: overrides['july'],
      august: overrides['august'],
      september: overrides['september'],
      october: overrides['october'],
      november: overrides['november'],
      december: overrides['december'],
      summed: overrides['summed'],
      averaged: overrides['averaged'],
      minimum: overrides['minimum'],
      maximum: overrides['maximum'],
      count: overrides['count'],
      sortedAscending: overrides['sortedAscending'],
      sortedDescending: overrides['sortedDescending'],
      selected: overrides['selected'],
      notSelected: overrides['notSelected'],
      rowGroup: overrides['rowGroup'],
      children: overrides['children'],
      rowsSelected: overrides['rowsSelected'],
      gridSummary: overrides['gridSummary'],
      menu: overrides['menu'],
      dialog: overrides['dialog'],
    );
  }

  /// Returns a map of all locale keys to their current values.
  ///
  /// Useful for serialisation or debugging.
  Map<String, String> toMap() {
    return {
      'noRowsToShow': noRowsToShow,
      'page': page,
      'of': of,
      'to': to,
      'more': more,
      'next': next,
      'previous': previous,
      'first': first,
      'last': last,
      'loadingOoo': loadingOoo,
      'selectAll': selectAll,
      'searchOoo': searchOoo,
      'filterOoo': filterOoo,
      'applyFilter': applyFilter,
      'resetFilter': resetFilter,
      'clearFilter': clearFilter,
      'equals': equals,
      'notEqual': notEqual,
      'contains': contains,
      'notContains': notContains,
      'startsWith': startsWith,
      'endsWith': endsWith,
      'lessThan': lessThan,
      'lessThanOrEqual': lessThanOrEqual,
      'greaterThan': greaterThan,
      'greaterThanOrEqual': greaterThanOrEqual,
      'inRange': inRange,
      'blank': blank,
      'notBlank': notBlank,
      'andCondition': andCondition,
      'orCondition': orCondition,
      'pinLeft': pinLeft,
      'pinRight': pinRight,
      'noPin': noPin,
      'autosizeThisColumn': autosizeThisColumn,
      'autosizeAllColumns': autosizeAllColumns,
      'resetColumns': resetColumns,
      'sortAscending': sortAscending,
      'sortDescending': sortDescending,
      'clearSort': clearSort,
      'general': general,
      'columns': columns,
      'filters': filters,
      'filter': filter,
      'clear': clear,
      'apply': apply,
      'pinColumn': pinColumn,
      'plusCondition': plusCondition,
      'expandAll': expandAll,
      'collapseAll': collapseAll,
      'deselectAll': deselectAll,
      'fromOoo': fromOoo,
      'toOoo': toOoo,
      'filterValueOoo': filterValueOoo,
      'dateFormatOoo': dateFormatOoo,
      'noActiveFilter': noActiveFilter,
      'active': active,
      'isBlank': isBlank,
      'isNotBlank': isNotBlank,
      'blanks': blanks,
      'before': before,
      'beforeOrOn': beforeOrOn,
      'after': after,
      'afterOrOn': afterOrOn,
      'today': today,
      'selectTime': selectTime,
      'cancel': cancel,
      'ok': ok,
      'mondayShort': mondayShort,
      'tuesdayShort': tuesdayShort,
      'wednesdayShort': wednesdayShort,
      'thursdayShort': thursdayShort,
      'fridayShort': fridayShort,
      'saturdayShort': saturdayShort,
      'sundayShort': sundayShort,
      'january': january,
      'february': february,
      'march': march,
      'april': april,
      'may': may,
      'june': june,
      'july': july,
      'august': august,
      'september': september,
      'october': october,
      'november': november,
      'december': december,
      'summed': summed,
      'averaged': averaged,
      'minimum': minimum,
      'maximum': maximum,
      'count': count,
      'sortedAscending': sortedAscending,
      'sortedDescending': sortedDescending,
      'selected': selected,
      'notSelected': notSelected,
      'rowGroup': rowGroup,
      'children': children,
      'rowsSelected': rowsSelected,
      'gridSummary': gridSummary,
      'menu': menu,
      'dialog': dialog,
    };
  }

  /// Resolves a locale key to its translated value.
  ///
  /// Looks up the key in this instance's properties. If the key is not
  /// recognised, returns [defaultValue].
  ///
  /// This is the primary method used internally by grid components to
  /// obtain translated text.
  String getLocaleText(String key, String defaultValue) {
    final map = toMap();
    return map[key] ?? defaultValue;
  }

  /// The default English locale instance.
  static const OsLocaleText defaultLocale = OsLocaleText();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OsLocaleText) return false;
    return noRowsToShow == other.noRowsToShow &&
        page == other.page &&
        of == other.of &&
        to == other.to &&
        more == other.more &&
        next == other.next &&
        previous == other.previous &&
        first == other.first &&
        last == other.last &&
        loadingOoo == other.loadingOoo &&
        selectAll == other.selectAll &&
        searchOoo == other.searchOoo &&
        filterOoo == other.filterOoo &&
        applyFilter == other.applyFilter &&
        resetFilter == other.resetFilter &&
        clearFilter == other.clearFilter &&
        equals == other.equals &&
        notEqual == other.notEqual &&
        contains == other.contains &&
        notContains == other.notContains &&
        startsWith == other.startsWith &&
        endsWith == other.endsWith &&
        lessThan == other.lessThan &&
        lessThanOrEqual == other.lessThanOrEqual &&
        greaterThan == other.greaterThan &&
        greaterThanOrEqual == other.greaterThanOrEqual &&
        inRange == other.inRange &&
        blank == other.blank &&
        notBlank == other.notBlank &&
        andCondition == other.andCondition &&
        orCondition == other.orCondition &&
        pinLeft == other.pinLeft &&
        pinRight == other.pinRight &&
        noPin == other.noPin &&
        autosizeThisColumn == other.autosizeThisColumn &&
        autosizeAllColumns == other.autosizeAllColumns &&
        resetColumns == other.resetColumns &&
        sortAscending == other.sortAscending &&
        sortDescending == other.sortDescending &&
        clearSort == other.clearSort &&
        general == other.general &&
        columns == other.columns &&
        filters == other.filters &&
        filter == other.filter &&
        clear == other.clear &&
        apply == other.apply &&
        pinColumn == other.pinColumn &&
        plusCondition == other.plusCondition &&
        expandAll == other.expandAll &&
        collapseAll == other.collapseAll &&
        deselectAll == other.deselectAll &&
        fromOoo == other.fromOoo &&
        toOoo == other.toOoo &&
        filterValueOoo == other.filterValueOoo &&
        dateFormatOoo == other.dateFormatOoo &&
        noActiveFilter == other.noActiveFilter &&
        active == other.active &&
        isBlank == other.isBlank &&
        isNotBlank == other.isNotBlank &&
        blanks == other.blanks &&
        before == other.before &&
        beforeOrOn == other.beforeOrOn &&
        after == other.after &&
        afterOrOn == other.afterOrOn &&
        today == other.today &&
        selectTime == other.selectTime &&
        cancel == other.cancel &&
        ok == other.ok &&
        mondayShort == other.mondayShort &&
        tuesdayShort == other.tuesdayShort &&
        wednesdayShort == other.wednesdayShort &&
        thursdayShort == other.thursdayShort &&
        fridayShort == other.fridayShort &&
        saturdayShort == other.saturdayShort &&
        sundayShort == other.sundayShort &&
        january == other.january &&
        february == other.february &&
        march == other.march &&
        april == other.april &&
        may == other.may &&
        june == other.june &&
        july == other.july &&
        august == other.august &&
        september == other.september &&
        october == other.october &&
        november == other.november &&
        december == other.december &&
        summed == other.summed &&
        averaged == other.averaged &&
        minimum == other.minimum &&
        maximum == other.maximum &&
        count == other.count &&
        sortedAscending == other.sortedAscending &&
        sortedDescending == other.sortedDescending &&
        selected == other.selected &&
        notSelected == other.notSelected &&
        rowGroup == other.rowGroup &&
        children == other.children &&
        rowsSelected == other.rowsSelected &&
        gridSummary == other.gridSummary &&
        menu == other.menu &&
        dialog == other.dialog;
  }

  @override
  int get hashCode => Object.hashAll([
    noRowsToShow,
    page,
    of,
    to,
    more,
    next,
    previous,
    first,
    last,
    loadingOoo,
    selectAll,
    searchOoo,
    filterOoo,
    applyFilter,
    resetFilter,
    clearFilter,
    equals,
    notEqual,
    contains,
    notContains,
    startsWith,
    endsWith,
    lessThan,
    lessThanOrEqual,
    greaterThan,
    greaterThanOrEqual,
    inRange,
    blank,
    notBlank,
    andCondition,
    orCondition,
    pinLeft,
    pinRight,
    noPin,
    autosizeThisColumn,
    autosizeAllColumns,
    resetColumns,
    sortAscending,
    sortDescending,
    clearSort,
    general,
    columns,
    filters,
    filter,
    clear,
    apply,
    pinColumn,
    plusCondition,
    expandAll,
    collapseAll,
    deselectAll,
    fromOoo,
    toOoo,
    filterValueOoo,
    dateFormatOoo,
    noActiveFilter,
    active,
    isBlank,
    isNotBlank,
    blanks,
    before,
    beforeOrOn,
    after,
    afterOrOn,
    today,
    selectTime,
    cancel,
    ok,
    mondayShort,
    tuesdayShort,
    wednesdayShort,
    thursdayShort,
    fridayShort,
    saturdayShort,
    sundayShort,
    january,
    february,
    march,
    april,
    may,
    june,
    july,
    august,
    september,
    october,
    november,
    december,
    summed,
    averaged,
    minimum,
    maximum,
    count,
    sortedAscending,
    sortedDescending,
    selected,
    notSelected,
    rowGroup,
    children,
    rowsSelected,
    gridSummary,
    menu,
    dialog,
  ]);
}
