import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';

/// A responsive list wrapper that displays content appropriately for different screen sizes
class ResponsiveListWrapper extends StatelessWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  const ResponsiveListWrapper({
    super.key,
    required this.child,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottom,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = Responsive.isLargeScreen(context);

    if (isLargeScreen) {
      return Scaffold(
        backgroundColor: backgroundColor ?? Colors.grey.shade50,
        body: Row(
          children: [
            // Main content area
            Expanded(
              child: Column(
                children: [
                  // Top bar
                  _buildWebTopBar(context),
                  // Content
                  Expanded(
                    child: CenteredContent(
                      maxWidth: 1400,
                      padding: const EdgeInsets.all(24),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
      );
    }

    // Mobile layout
    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade600, Colors.blue.shade800],
            ),
          ),
        ),
        actions: actions,
        bottom: bottom,
      ),
      body: child,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }

  Widget _buildWebTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// A responsive form wrapper that constrains form width on larger screens
class ResponsiveFormWrapper extends StatelessWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const ResponsiveFormWrapper({
    super.key,
    required this.child,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = Responsive.isLargeScreen(context);

    if (isLargeScreen) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Column(
          children: [
            _buildWebTopBar(context),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade600, Colors.blue.shade800],
            ),
          ),
        ),
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackPressed ?? () => Navigator.pop(context),
              )
            : null,
        actions: actions,
      ),
      body: child,
    );
  }

  Widget _buildWebTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed ?? () => Navigator.pop(context),
              tooltip: 'Back',
            ),
          if (showBackButton) const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// A responsive card grid that displays cards in a grid on large screens
class ResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;

  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
  });

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.value(
      context,
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );

    if (columns == 1) {
      return Column(
        children: children
            .map((child) => Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: child,
                ))
            .toList(),
      );
    }

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: children.map((child) {
        final width = (MediaQuery.of(context).size.width -
                (Responsive.isLargeScreen(context) ? 260 : 0) -
                (spacing * (columns + 1))) /
            columns;
        return SizedBox(
          width: width.clamp(200.0, 500.0),
          child: child,
        );
      }).toList(),
    );
  }
}

/// A responsive data table wrapper
class ResponsiveDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool showCheckboxColumn;

  const ResponsiveDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.showCheckboxColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = Responsive.isLargeScreen(context);

    if (isLargeScreen) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns,
          rows: rows,
          showCheckboxColumn: showCheckboxColumn,
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          dataRowMinHeight: 60,
          dataRowMaxHeight: 80,
          columnSpacing: 24,
          horizontalMargin: 24,
        ),
      );
    }

    // For mobile, return as-is (handled by ListView in parent)
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: rows,
        showCheckboxColumn: showCheckboxColumn,
        columnSpacing: 16,
      ),
    );
  }
}
