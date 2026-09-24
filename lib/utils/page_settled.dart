import 'dart:async';

import 'package:flutter/widgets.dart';


/// How long a page's [StaggeredEntrance]s need after the route itself has
/// finished sliding in: the last animated index's delay plus its own drift.
const kEntranceSettle = Duration(milliseconds: 350);

/// Runs [action] once this page has fully arrived — its route transition is
/// over and its content has finished settling in.
///
/// For things that would otherwise land on a page still in motion, like a
/// guided tour whose spotlight should frame elements that are already at
/// rest. Call it from `initState` (or a post-frame callback); [action] is
/// skipped if the page is gone by then.
void whenPageSettled(BuildContext context, VoidCallback action) {
  final animation = ModalRoute.of(context)?.animation;

  void afterEntrance() {
    final wait = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : kEntranceSettle;
    Timer(wait, () {
      if (context.mounted) action();
    });
  }

  if (animation == null || animation.isCompleted) {
    afterEntrance();
    return;
  }
  late final AnimationStatusListener listener;
  listener = (status) {
    if (status == AnimationStatus.completed) {
      animation.removeStatusListener(listener);
      if (context.mounted) afterEntrance();
    } else if (status == AnimationStatus.dismissed) {
      animation.removeStatusListener(listener);
    }
  };
  animation.addStatusListener(listener);
}
