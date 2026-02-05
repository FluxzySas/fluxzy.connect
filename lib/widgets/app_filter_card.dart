import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_info.dart';
import '../viewmodels/vpn_connection_viewmodel.dart';

/// A collapsible card widget for per-app VPN filtering.
/// Allows users to select which apps should use the VPN (whitelist mode).
class AppFilterCard extends ConsumerStatefulWidget {
  const AppFilterCard({super.key});

  @override
  ConsumerState<AppFilterCard> createState() => _AppFilterCardState();
}

class _AppFilterCardState extends ConsumerState<AppFilterCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vpnConnectionViewModelProvider);
    final viewModel = ref.read(vpnConnectionViewModelProvider.notifier);
    final installedAppsAsync = ref.watch(installedAppsProvider);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.apps,
                    color: state.isAppFilterEnabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Per-App VPN',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (state.isAppFilterEnabled &&
                            state.selectedAppCount > 0)
                          Text(
                            '${state.selectedAppCount} app${state.selectedAppCount == 1 ? '' : 's'} selected',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          )
                        else if (!state.isAppFilterEnabled)
                          Text(
                            'All apps use VPN',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.isAppFilterEnabled,
                    onChanged: (value) => viewModel.setAppFilterEnabled(value),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: _buildExpandedContent(
              context,
              state,
              viewModel,
              installedAppsAsync,
              theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    VpnConnectionState state,
    VpnConnectionViewModel viewModel,
    AsyncValue<List<AppInfo>> installedAppsAsync,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only selected apps will route traffic through VPN. All other apps will bypass.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search apps...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        viewModel.setAppSearchQuery('');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              isDense: true,
            ),
            onChanged: viewModel.setAppSearchQuery,
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  installedAppsAsync.whenData((apps) {
                    viewModel.selectAllApps(apps);
                  });
                },
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('Select All'),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: viewModel.clearAllApps,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All'),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // App list
          installedAppsAsync.when(
            data: (apps) => _buildAppList(
              context,
              state,
              viewModel,
              apps,
              theme,
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading apps...'),
                  ],
                ),
              ),
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load apps',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppList(
    BuildContext context,
    VpnConnectionState state,
    VpnConnectionViewModel viewModel,
    List<AppInfo> apps,
    ThemeData theme,
  ) {
    // Filter apps by search query
    final query = state.appSearchQuery.toLowerCase();
    final filteredApps = query.isEmpty
        ? apps
        : apps
            .where((app) =>
                app.appName.toLowerCase().contains(query) ||
                app.packageName.toLowerCase().contains(query))
            .toList();

    if (filteredApps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                query.isEmpty ? Icons.apps : Icons.search_off,
                color: theme.colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                query.isEmpty ? 'No apps found' : 'No matching apps',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: filteredApps.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant,
        ),
        itemBuilder: (context, index) {
          final app = filteredApps[index];
          final isSelected = state.selectedApps.contains(app.packageName);

          return _AppListTile(
            app: app,
            isSelected: isSelected,
            onToggle: () => viewModel.toggleAppSelection(app.packageName),
          );
        },
      ),
    );
  }
}

class _AppListTile extends StatelessWidget {
  final AppInfo app;
  final bool isSelected;
  final VoidCallback onToggle;

  const _AppListTile({
    required this.app,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // App icon
            _buildAppIcon(theme),
            const SizedBox(width: 12),
            // App info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    app.packageName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(ThemeData theme) {
    if (app.iconBase64 != null && app.iconBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(app.iconBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            Uint8List.fromList(bytes),
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultIcon(theme),
          ),
        );
      } catch (_) {
        return _buildDefaultIcon(theme);
      }
    }
    return _buildDefaultIcon(theme);
  }

  Widget _buildDefaultIcon(ThemeData theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.android,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
