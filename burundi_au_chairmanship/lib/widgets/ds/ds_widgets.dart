import 'package:flutter/material.dart';
import '../../config/app_ds.dart';

/// Component kit for the 2026 redesign (`B4Africa Redesign.dc.html`).
///
/// Every screen in the comp is built from the same eight pieces, so they live
/// here rather than being re-inlined per screen.

/// Green header with a 28px bottom radius. Sits at the top of a scroll view
/// (not an AppBar) because the comp scrolls it away with the content.
class DsHeader extends StatelessWidget {
  final String title;

  /// Small line above the title (the "Monday 31 August · Mwaramutse" row).
  final String? overline;
  final bool showBack;

  /// Uses the 22px tab-root size instead of the 19px detail-page size.
  final bool large;
  final List<Widget> actions;

  /// Filter chips / date strip rendered under the title row.
  final Widget? bottom;
  final double bottomPad;
  final Color color;

  const DsHeader({
    super.key,
    required this.title,
    this.overline,
    this.showBack = true,
    this.large = false,
    this.actions = const [],
    this.bottom,
    this.bottomPad = 18,
    this.color = Ds.green,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = large ? Ds.screenTitle(context) : Ds.pageTitle(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Ds.headerHPad,
        MediaQuery.paddingOf(context).top + 20,
        Ds.headerHPad,
        bottomPad,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(Ds.rHeader),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack) _HeaderBack(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (overline != null)
                      Text(
                        overline!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    Text(title, style: titleStyle),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 14), bottom!],
        ],
      ),
    );
  }
}

class _HeaderBack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.maybePop(context),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 38px translucent circle used for header actions.
class DsHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  /// Accessibility label (read by screen readers).
  final String label;

  /// Small unread count rendered as a red dot badge.
  final int badge;
  const DsHeaderAction(
    this.icon, {
    super.key,
    required this.label,
    this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              // 44x44 tap target; the visible circle is drawn inside it.
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
            ),
            if (badge > 0)
              Positioned(
                right: 1,
                top: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Ds.red,
                    borderRadius: BorderRadius.circular(Ds.rPill),
                    border: Border.all(color: Ds.green, width: 1.5),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// White 16px card with the standard soft shadow.
class DsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Uses the heavier `0 4px 12px` shadow reserved for featured cards.
  final bool featured;
  final double radius;
  final Color? color;
  final bool clip;

  const DsCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.featured = false,
    this.radius = Ds.rCard,
    this.color,
    this.clip = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Ds.surface(context),
        borderRadius: r,
        boxShadow: featured ? Ds.shadowLg(context) : Ds.shadow(context),
      ),
      child: clip
          ? ClipRRect(borderRadius: r, child: child)
          : Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: r, onTap: onTap, child: content),
    );
  }
}

/// "Quick access · Accès rapide" + optional "See all".
class DsSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const DsSectionTitle(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: Ds.sectionTitle(context))),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel ?? 'See all',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Ds.green,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ALL-CAPS group label ("TODAY · AUJOURD'HUI").
class DsGroupLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;
  const DsGroupLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(22, 16, 22, 8),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(text.toUpperCase(), style: Ds.groupLabel(context)),
  );
}

enum DsTone { green, red, gold, neutral, white }

/// Status pill — "LIVE", "Registered", "Open", "FEATURED".
class DsPill extends StatelessWidget {
  final String label;
  final DsTone tone;
  final IconData? icon;
  final bool dense;

  const DsPill(
    this.label, {
    super.key,
    this.tone = DsTone.green,
    this.icon,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg, fg;
    switch (tone) {
      case DsTone.green:
        bg = Ds.tint(context);
        fg = Ds.greenDeep;
      case DsTone.red:
        bg = Ds.red;
        fg = Colors.white;
      case DsTone.gold:
        bg = Ds.goldTintOf(context);
        fg = Ds.goldInk;
      case DsTone.neutral:
        bg = Ds.subtle(context);
        fg = Ds.body(context);
      case DsTone.white:
        bg = Colors.white;
        fg = Ds.green;
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 10,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Ds.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: tone == DsTone.red ? 0.8 : 0,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chip. `onGreen` renders the header variant (white when selected,
/// 16%-white otherwise); the default renders the on-canvas variant.
class DsFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool onGreen;

  const DsFilterChip(
    this.label, {
    super.key,
    required this.selected,
    this.onTap,
    this.onGreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg, fg;
    Border? border;
    if (onGreen) {
      bg = selected ? Colors.white : Colors.white.withValues(alpha: 0.16);
      fg = selected ? Ds.green : Colors.white;
    } else if (selected) {
      bg = Ds.green;
      fg = Colors.white;
    } else {
      bg = Ds.surface(context);
      fg = Ds.body(context);
      border = Border.all(color: Ds.outline(context));
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: onGreen ? 16 : 14,
          vertical: onGreen ? 8 : 7,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.circular(Ds.rPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: onGreen ? 13 : 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// 36px rounded icon square used at the head of every grouped list row.
class DsIconSquare extends StatelessWidget {
  final IconData icon;
  final Color? tint;
  final Color? color;
  final double size;
  final double radius;

  const DsIconSquare(
    this.icon, {
    super.key,
    this.tint,
    this.color,
    this.size = 36,
    this.radius = Ds.rIcon,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: tint ?? Ds.subtle(context),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(icon, size: size * 0.53, color: color ?? Ds.body(context)),
  );
}

/// One row of a [DsTileGroup].
class DsTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconTint;
  final Color? iconColor;
  final String title;
  final String? subtitle;

  /// Right-aligned grey value ("English", "2 open").
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final Color? titleColor;

  const DsTile({
    super.key,
    this.icon,
    this.iconTint,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.chevron = true,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              DsIconSquare(icon!, tint: iconTint, color: iconColor),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Ds.tileTitle(
                      context,
                    ).copyWith(color: titleColor ?? Ds.ink(context)),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: Ds.meta(context)),
                  ],
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 6),
                child: Text(
                  value!,
                  style: TextStyle(fontSize: 13, color: Ds.muted(context)),
                ),
              ),
            // Without this a wrapping subtitle runs under the switch.
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
            if (trailing == null && chevron)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Ds.chevron,
              ),
          ],
        ),
      ),
    );
  }
}

/// White 16px card holding [DsTile]s separated by hairlines.
class DsTileGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const DsTileGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Divider(height: 1, thickness: 1, color: Ds.hairline(context)));
      }
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Ds.surface(context),
        borderRadius: BorderRadius.circular(Ds.rCard),
        boxShadow: Ds.shadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Ds.rCard),
        child: Material(
          color: Colors.transparent,
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
    );
  }
}

/// The 44×26 pill switch drawn in the comp.
class DsSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const DsSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? Ds.green : Ds.outline(context),
          borderRadius: BorderRadius.circular(Ds.rPill),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single "418M / Lack safe water" stat card.
class DsStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const DsStat(this.value, this.label, {super.key, this.valueColor});

  @override
  Widget build(BuildContext context) => DsCard(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: valueColor ?? Ds.green,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Ds.body(context)),
        ),
      ],
    ),
  );
}

/// Row of equal-width [DsStat]s.
class DsStatRow extends StatelessWidget {
  final List<Widget> stats;
  final EdgeInsetsGeometry margin;
  const DsStatRow(
    this.stats, {
    super.key,
    this.margin = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: stats[i]),
        ],
      ],
    ),
  );
}

/// Full-width green action button (`13px 0`, 12px radius).
class DsPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool expand;
  final double radius;
  const DsPrimaryButton(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.expand = true,
    this.radius = Ds.rTile,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 18, vertical: 13),
      decoration: BoxDecoration(
        color: onTap == null ? Ds.green.withValues(alpha: 0.4) : Ds.green,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    final tappable = GestureDetector(onTap: onTap, child: child);
    return expand
        ? SizedBox(width: double.infinity, child: tappable)
        : tappable;
  }
}

/// Green-outlined counterpart to [DsPrimaryButton].
class DsOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool expand;
  final double radius;
  const DsOutlineButton(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.expand = false,
    this.radius = Ds.rTile,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 18, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Ds.green, width: 1.5),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Ds.green),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Ds.green,
              ),
            ),
          ),
        ],
      ),
    );
    final tappable = GestureDetector(onTap: onTap, child: child);
    return expand
        ? SizedBox(width: double.infinity, child: tappable)
        : tappable;
  }
}

/// Highlighted note strip (gold in the comp: "Delegate credential", "Share my
/// live location").
class DsNoteBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  const DsNoteBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.margin = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Ds.goldTintOf(context),
            borderRadius: BorderRadius.circular(Ds.rCard),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: Ds.goldDeep),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Ds.ink(context),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 12, color: Ds.goldInk),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Ds.goldDeep,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grey caption used under a settings group.
class DsFootnote extends StatelessWidget {
  final String text;
  final bool center;
  const DsFootnote(this.text, {super.key, this.center = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
    child: Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(fontSize: 12, color: Ds.muted(context), height: 1.5),
    ),
  );
}

/// Placeholder that stands in for a photo slot while an image loads or when
/// none is set — the diagonal-stripe swatch used throughout the comp.
class DsImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final IconData? icon;
  final bool dark;

  const DsImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.radius = Ds.rCard,
    this.icon,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2E3B2C) : Ds.greenTintDeep,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon ?? Icons.image_rounded,
        size: 22,
        color: dark ? Colors.white24 : const Color(0xFF7C8878),
      ),
    );
  }
}

/// Bottom action bar pinned to the safe area (article, event detail).
class DsBottomBar extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const DsBottomBar({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    // SafeArea already adds the home-indicator inset — adding it to `padding`
    // as well double-counts it and leaves a dead band under the row.
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Ds.surface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Ds.rSheet),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }
}
