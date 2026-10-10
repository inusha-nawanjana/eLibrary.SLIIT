import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../library_state.dart';
import '../models.dart';
import 'auth.dart';

const previewChrome = kIsWeb || bool.fromEnvironment('DESIGN_PREVIEW');

const navy = Color(0xFF112850),
    orange = Color(0xFFE9781E),
    muted = Color(0xFF607289),
    surface = Color(0xFFF4F6F9),
    line = Color(0xFFE2E8F0),
    peach = Color(0xFFFDF1E8),
    green = Color(0xFF10B981);
TextStyle txt(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = navy,
  double? height = 1.2,
}) => TextStyle(
  fontFamily: 'Inter',
  letterSpacing: 0,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);
const bold = FontWeight.w700, heavy = FontWeight.w800, semi = FontWeight.w600;

class LibraryScope extends InheritedNotifier<LibraryState> {
  const LibraryScope({
    super.key,
    required LibraryState state,
    required super.child,
  }) : super(notifier: state);
  static LibraryState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LibraryScope>()!.notifier!;
}

Future<T?> push<T>(BuildContext c, Widget page) =>
    Navigator.of(c).push<T>(MaterialPageRoute(builder: (_) => page));
Future<bool> ensureLogin(BuildContext c) async {
  if (LibraryScope.of(c).signedIn) return true;
  return await push<bool>(c, const LoginScreen()) ?? false;
}

void showError(BuildContext c, Object e) => ScaffoldMessenger.of(c)
    .showSnackBar(
      SnackBar(content: Text(friendlyError(e)), backgroundColor: navy),
    );

class Art extends StatelessWidget {
  const Art(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.alignment = Alignment.center,
  });
  final String path;
  final double? width, height;
  final double radius;
  final BoxFit fit;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) {
    Widget error(BuildContext c, Object e, StackTrace? s) => Container(
      width: width,
      height: height,
      color: surface,
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book_outlined, color: muted),
    );
    final image = path.startsWith('data:')
        ? Image.memory(
            base64Decode(path.split(',').last),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: error,
          )
        : path.startsWith('https://')
        ? Image.network(
            path,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            errorBuilder: error,
          )
        : Image.asset(
            path,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            errorBuilder: error,
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

class Glyph extends StatelessWidget {
  const Glyph(this.file, {super.key, this.size = 20, this.color});
  final String file;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext c) => SvgPicture.asset(
    asset(file),
    width: size,
    height: size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}

class Brand extends StatelessWidget {
  const Brand({
    super.key,
    this.size = 22,
    this.subtitle = 'The Knowledge University',
    this.center = false,
    this.subtitleSize = 12,
  });
  final double size;
  final double subtitleSize;
  final String subtitle;
  final bool center;
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'eLibrary'),
            TextSpan(
              text: '.SLIIT',
              style: TextStyle(color: orange),
            ),
          ],
        ),
        style: txt(size, weight: heavy),
      ),
      const SizedBox(height: 2),
      Text(subtitle, style: txt(size > 25 ? 16 : subtitleSize, color: muted)),
    ],
  );
}

class DeviceStatus extends StatelessWidget {
  const DeviceStatus({super.key});
  @override
  Widget build(BuildContext c) => SizedBox(
    height: 44,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('9:41', style: txt(14, weight: semi)),
          Row(
            children: [
              const Glyph('53dce.svg'),
              const SizedBox(width: 6),
              const Glyph('f22ae.svg'),
              const SizedBox(width: 6),
              SvgPicture.asset(asset('8deea.svg'), width: 28, height: 20),
            ],
          ),
        ],
      ),
    ),
  );
}

class Screen extends StatelessWidget {
  const Screen({
    super.key,
    required this.child,
    this.title,
    this.header,
    this.back = false,
    this.trailing,
    this.tab,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.scroll = true,
    this.centerTitle = false,
    this.background = Colors.white,
  });
  final Widget child;
  final String? title;
  final Widget? header, trailing;
  final bool back, scroll, centerTitle;
  final int? tab;
  final EdgeInsets padding;
  final Color background;
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: background,
    body: SafeArea(
      top: !previewChrome,
      bottom: false,
      child: Column(
        children: [
          if (previewChrome) const DeviceStatus(),
          if (header != null)
            header!
          else if (title != null)
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    if (back)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Semantics(
                          label: 'Back',
                          button: true,
                          child: InkResponse(
                            onTap: () => Navigator.maybePop(c),
                            radius: 24,
                            child: const Glyph('c317c.svg', size: 24),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title!,
                        textAlign: centerTitle
                            ? TextAlign.center
                            : TextAlign.start,
                        style: txt(18, weight: heavy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailing != null)
                      trailing!
                    else if (centerTitle && back)
                      const SizedBox(width: 24),
                  ],
                ),
              ),
            ),
          Expanded(
            child: scroll
                ? SingleChildScrollView(
                    key: PageStorageKey(title ?? 'screen-${tab ?? 0}'),
                    padding: padding.copyWith(bottom: 24),
                    child: child,
                  )
                : Padding(padding: padding, child: child),
          ),
          if (tab != null)
            BottomBar(selected: tab!)
          else if (previewChrome)
            const HomeIndicator(),
        ],
      ),
    ),
  );
}

class HomeIndicator extends StatelessWidget {
  const HomeIndicator({super.key});
  @override
  Widget build(BuildContext c) => SizedBox(
    height: 13,
    child: Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: 134,
        height: 5,
        decoration: BoxDecoration(
          color: navy.withValues(alpha: .3),
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    ),
  );
}

class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.selected});
  final int selected;
  @override
  Widget build(BuildContext c) {
    const names = ['Home', 'E-books', 'Study Space', 'Activity', 'Profile'];
    const icons = [
      '36733.svg',
      '73b5f.svg',
      'de4a8.svg',
      'f44c3.svg',
      '2ffeb.svg',
    ];
    return ColoredBox(
      color: orange,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Expanded(
                        child: Semantics(
                          selected: i == selected,
                          button: true,
                          label: names[i],
                          child: InkWell(
                            onTap: () async {
                              final state = LibraryScope.of(c);
                              if (i >= 3 && !await ensureLogin(c)) return;
                              if (!c.mounted) return;
                              state.selectTab(i);
                              Navigator.of(c).popUntil((r) => r.isFirst);
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Glyph(
                                  icons[i],
                                  color: i == selected
                                      ? Colors.white
                                      : Colors.black.withValues(alpha: .65),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  names[i],
                                  style: txt(
                                    10,
                                    weight: i == selected
                                        ? bold
                                        : FontWeight.w500,
                                    color: i == selected
                                        ? Colors.white
                                        : Colors.black.withValues(alpha: .65),
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (previewChrome) const HomeIndicator(),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onTap,
    this.busy = false,
    this.color = navy,
    this.foreground = Colors.white,
    this.height = 50,
    this.outline = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy, outline;
  final Color color, foreground;
  final double height;
  final Widget? icon;
  @override
  Widget build(BuildContext c) => SizedBox(
    width: double.infinity,
    height: height,
    child: Material(
      color: outline ? Colors.white : color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: outline ? Border.all(color: color, width: 1.2) : null,
          ),
          alignment: Alignment.center,
          child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        label,
                        style: txt(
                          height < 40
                              ? 12
                              : height < 48
                              ? 14
                              : 16,
                          weight: bold,
                          color: outline ? color : foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

class Field extends StatelessWidget {
  const Field(
    this.label, {
    super.key,
    required this.controller,
    this.hint = '',
    this.validator,
    this.obscure = false,
    this.suffix,
    this.keyboard,
    this.lines = 1,
    this.readOnly = false,
    this.compact = false,
    this.onTap,
    this.onChanged,
  });
  final String label, hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscure, readOnly, compact;
  final Widget? suffix;
  final TextInputType? keyboard;
  final int lines;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label.isNotEmpty) ...[
        Text(label, style: txt(13, weight: semi)),
        const SizedBox(height: 8),
      ],
      TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscure,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        keyboardType: keyboard,
        maxLines: lines,
        style: txt(14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: txt(14, color: muted),
          suffixIcon: suffix,
          filled: true,
          fillColor: surface,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 13 : 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: orange),
          ),
          errorMaxLines: 2,
        ),
      ),
    ],
  );
}

String? requiredValue(String? v) =>
    (v?.trim().isEmpty ?? true) ? 'This field is required.' : null;
String? validPhone(String? v) =>
    RegExp(r'^\+?[0-9\s-]{9,16}$').hasMatch(v?.trim() ?? '')
    ? null
    : 'Enter a valid phone number.';

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.radius = 16,
    this.onTap,
    this.shadow = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final bool shadow;
  @override
  Widget build(BuildContext c) => Container(
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: line),
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: navy.withValues(alpha: .03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext c) {
    final color = switch (status) {
      'Available' || 'Active' => green,
      'Pending' || 'Reserved' => const Color(0xFFF59E0B),
      'Approved' => const Color(0xFF3B82F6),
      'Occupied' ||
      'Checked Out' ||
      'Rejected' ||
      'Cancelled' => const Color(0xFFEF4444),
      _ => muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: txt(11, weight: bold, color: color),
      ),
    );
  }
}

class Filters extends StatelessWidget {
  const Filters({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
  });
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext c) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onSelected(value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: value == selected ? orange : surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  value,
                  style: txt(
                    12,
                    weight: semi,
                    color: value == selected ? Colors.white : muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.title, this.message, {super.key});
  final String title, message;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
    child: Column(
      children: [
        const Icon(Icons.menu_book_outlined, size: 36, color: muted),
        const SizedBox(height: 16),
        Text(
          title,
          style: txt(16, weight: bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: txt(13, color: muted, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Future<void> approval(
  BuildContext c, {
  String? id,
  bool room = false,
  bool extension = false,
  bool download = false,
}) => showDialog<void>(
  context: c,
  barrierDismissible: false,
  barrierColor: const Color(0xFFEBEDF1),
  builder: (dialog) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 32),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: peach,
            ),
            alignment: Alignment.center,
            child: const Glyph('a435a.svg', size: 27),
          ),
          const SizedBox(height: 24),
          Text(
            download
                ? (kIsWeb ? 'Download Started' : 'Download Complete')
                : 'Waiting for Approval',
            style: txt(20, weight: heavy),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            download
                ? (kIsWeb
                      ? 'Your PDF download has started. Check your browser downloads to open it.'
                      : 'The eBook has been successfully saved to your device and is ready to read.')
                : extension
                ? 'Your extension request is being reviewed by the admin.'
                : room
                ? 'Your room reservation is being reviewed by the admin.'
                : 'Your reservation is being reviewed by the SLIIT Malabe Library Administrator. Check Your Activity for updates.',
            style: txt(14, color: muted, height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (id != null && !room) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: line, height: 1),
            ),
            Text('Reservation ID', style: txt(12, color: muted)),
            const SizedBox(height: 4),
            Text(
              '#${id.length > 24 ? id.substring(0, 8).toUpperCase() : id}',
              style: txt(14, weight: bold),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton('Done', height: 48, onTap: () => Navigator.pop(dialog)),
        ],
      ),
    ),
  ),
);
