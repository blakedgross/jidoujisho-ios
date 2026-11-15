import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:foldable/foldable.dart';

/// Decides when readers show two pages side by side, like an open book: on
/// windows that are wide and tall enough for two readable pages, such as an
/// unfolded iPhone Duo, an iPad or an Android foldable in landscape.
///
/// Uses the window size rather than the device, so a folded iPhone Duo, a
/// phone in landscape or a narrow Split View window keep a single page.
class ReaderSpread {
  ReaderSpread._();

  /// The smallest window side, in logical pixels, that fits two pages. Matches
  /// the compact/medium window size class boundary.
  ///
  /// ッツ Ebook Reader applies the same rule to its column count, see
  /// `tool/ttu-ebook-reader/jidoujisho.patch`.
  static const double minimumShortestSide = 600;

  /// Whether a window of [size] shows a two-page spread.
  static bool isSpread(Size size) =>
      size.width > size.height && size.shortestSide >= minimumShortestSide;

  /// Whether the window of [context] shows a two-page spread.
  static bool of(BuildContext context) => isSpread(MediaQuery.sizeOf(context));

  /// Width of a fold or hinge currently running down the middle of the
  /// window, or 0 when there is none.
  ///
  /// The fold only counts while the device is partially open: laid flat, the
  /// iPhone Duo's inner display is continuous and its fold region is
  /// inactive. Android reports folds through [MediaQuery.displayFeaturesOf];
  /// iPhone Duo through the `foldable` plugin.
  static double foldGutterOf(BuildContext context) {
    for (DisplayFeature feature in MediaQuery.displayFeaturesOf(context)) {
      bool isVertical = feature.bounds.height > feature.bounds.width;
      bool isActive = feature.type == DisplayFeatureType.hinge ||
          (feature.type == DisplayFeatureType.fold &&
              feature.state == DisplayFeatureState.postureHalfOpened);
      if (isVertical && isActive) {
        return feature.bounds.width;
      }
    }

    FoldableData fold = DuoMediaQuery.of(context);
    if (!fold.isPartiallyOpen) {
      return 0;
    }
    for (ReservedRegion division in fold.activeDivisions) {
      if (division.bounds.height > division.bounds.width) {
        return division.bounds.width;
      }
    }
    return 0;
  }
}

/// A [SafeArea] that keeps a two-page spread centred on the fold.
///
/// Safe area insets can be asymmetric: the iPhone Duo inner display insets
/// only the side holding the status bar. In a spread, the larger horizontal
/// inset is applied to both sides so the gutter between the pages stays on
/// the window's centre line, where the fold is.
class ReaderSafeArea extends StatelessWidget {
  /// Create a reader safe area.
  const ReaderSafeArea({
    required this.child,
    this.top = true,
    this.bottom = true,
    super.key,
  });

  /// The reader.
  final Widget child;

  /// Whether to avoid the top inset.
  final bool top;

  /// Whether to avoid the bottom inset.
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    double horizontal = 0;
    if (ReaderSpread.of(context)) {
      EdgeInsets padding = MediaQuery.paddingOf(context);
      horizontal = max(padding.left, padding.right);
    }

    return SafeArea(
      top: top,
      bottom: bottom,
      minimum: EdgeInsets.symmetric(horizontal: horizontal),
      child: child,
    );
  }
}
