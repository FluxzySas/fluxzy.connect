import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proxy_host.dart';
import '../viewmodels/vpn_connection_viewmodel.dart';

class AutodiscoverSection extends ConsumerWidget {
  const AutodiscoverSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vpnConnectionViewModelProvider);
    final viewModel = ref.read(vpnConnectionViewModelProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (state.isDiscovering)
              _PulsingIcon(
                icon: Icons.wifi_find,
                color: theme.colorScheme.primary,
                size: 20,
              )
            else
              Icon(Icons.wifi_find, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Discovered Proxies',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (state.isDiscovering)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _ScanningDots(color: theme.colorScheme.primary),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: viewModel.startDiscovery,
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildHostList(context, state, viewModel),
      ],
    );
  }

  Widget _buildHostList(
    BuildContext context,
    VpnConnectionState state,
    VpnConnectionViewModel viewModel,
  ) {
    final theme = Theme.of(context);

    if (state.isDiscovering && state.discoveredHosts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Column(
            children: [
              _RadarScanAnimation(color: theme.colorScheme.primary, size: 64),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Searching a fluxzy instance in the current network',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _AnimatedEllipsis(color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (state.discoveredHosts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.wifi_find,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Discover Fluxzy instances',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for Fluxzy proxy servers on your local network',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: viewModel.startDiscovery,
                icon: const Icon(Icons.search),
                label: const Text('Start Discovery'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.discoveredHosts.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
          itemBuilder: (context, index) {
            final host = state.discoveredHosts[index];

            return _HostListTile(
              host: host,
              onTap: () => viewModel.useDiscoveredHost(host),
            );
          },
        ),
      ),
    );
  }
}

class _HostListTile extends StatelessWidget {
  final ProxyHost host;
  final VoidCallback onTap;

  const _HostListTile({required this.host, required this.onTap});

  void _showHostDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _HostDetailsDialog(host: host),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(host.label, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      host.address,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (host.osName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        host.osName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => _showHostDetails(context),
                tooltip: 'View details',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostDetailsDialog extends StatelessWidget {
  final ProxyHost host;

  const _HostDetailsDialog({required this.host});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.dns, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(host.label, style: theme.textTheme.titleLarge)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(
                icon: Icons.computer,
                label: 'Host',
                value: host.hostname,
              ),
              _DetailRow(
                icon: Icons.numbers,
                label: 'Port',
                value: host.port.toString(),
              ),
              if (host.hostName != null)
                _DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Name',
                  value: host.hostName!,
                ),
              if (host.osName != null)
                _DetailRow(
                  icon: Icons.desktop_windows_outlined,
                  label: 'OS',
                  value: host.osName!,
                ),
              if (host.fluxzyVersion != null)
                _DetailRow(
                  icon: Icons.info_outline,
                  label: 'Fluxzy Version',
                  value: host.fluxzyVersion!,
                ),
              if (host.fluxzyStartupSetting != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Startup Settings',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      host.fluxzyStartupSetting!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing icon animation for the header
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(widget.icon, color: widget.color, size: widget.size),
        );
      },
    );
  }
}

/// Scanning dots animation (three dots bouncing)
class _ScanningDots extends StatefulWidget {
  final Color color;

  const _ScanningDots({required this.color});

  @override
  State<_ScanningDots> createState() => _ScanningDotsState();
}

class _ScanningDotsState extends State<_ScanningDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final scale = (value < 0.5)
                ? 1.0 + (value * 0.6)
                : 1.0 + ((1.0 - value) * 0.6);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Radar scan animation for the main discovering state
class _RadarScanAnimation extends StatefulWidget {
  final Color color;
  final double size;

  const _RadarScanAnimation({required this.color, required this.size});

  @override
  State<_RadarScanAnimation> createState() => _RadarScanAnimationState();
}

class _RadarScanAnimationState extends State<_RadarScanAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(
              color: widget.color,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Color color;
  final double progress;

  _RadarPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw concentric circles
    for (int i = 1; i <= 3; i++) {
      final radius = maxRadius * (i / 3);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, radius, paint);
    }

    // Draw expanding pulse rings
    for (int i = 0; i < 2; i++) {
      final ringProgress = (progress + (i * 0.5)) % 1.0;
      final radius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.6;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }

    // Draw center dot
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Animated ellipsis (...) for text
class _AnimatedEllipsis extends StatefulWidget {
  final Color color;

  const _AnimatedEllipsis({required this.color});

  @override
  State<_AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<_AnimatedEllipsis>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dotCount = (_controller.value * 4).floor() % 4;
        return SizedBox(
          width: 20,
          child: Text(
            '.' * dotCount,
            style: TextStyle(color: widget.color, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
