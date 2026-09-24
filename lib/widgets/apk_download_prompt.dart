import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/apk_prompt_prefs.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../utils/app_modals.dart';
import 'staggered_entrance.dart';

/// Always resolves to whatever `.apk` asset the most recent GitHub Release
/// was published with, under this exact file name — GitHub's own
/// `/releases/latest/download/<name>` redirect, not a link to one specific
/// release. Publishing a new version is then just "attach an asset named
/// `inner-stars.apk` to a new release": this link, and every button that
/// uses it, never need to change. The repo path in the URL is the GitHub
/// repo's own name — update it here if the repo is ever renamed again.
const kApkDownloadUrl =
    'https://github.com/chiriacadrian2296/inner_stars/releases/latest/download/inner-stars.apk';

Future<void> openApkDownload() =>
    launchUrl(Uri.parse(kApkDownloadUrl), mode: LaunchMode.externalApplication);

/// The web build's answer to Chrome's own "Install app" prompt (which the
/// site no longer offers — see `web/index.html`): on an Android browser,
/// tell the person up front that this is the web version and where the real
/// app is. Shown at most once — however it's closed (download, or "stay on
/// the web"), that's recorded in [prefs] and it never comes back on its own;
/// Settings > About keeps a permanent copy of the same link.
Future<void> showApkDownloadPrompt(
  BuildContext context,
  ApkPromptPrefs prefs,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (dialogContext) {
      final strings = dialogContext.strings;
      final colors = dialogContext.colors;
      return AlertDialog(
        icon: StaggeredEntrance(
          index: 0,
          child: Icon(Icons.android, color: colors.gold, size: 32),
        ),
        title: StaggeredEntrance(
          index: 1,
          child: Text(strings.downloadApkPromptTitle),
        ),
        content: StaggeredEntrance(
          index: 2,
          child: Text(strings.downloadApkBannerBody),
        ),
        actions: [
          StaggeredEntrance(
            index: 3,
            axis: Axis.horizontal,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.downloadApkPromptContinueAction),
            ),
          ),
          StaggeredEntrance(
            index: 4,
            axis: Axis.horizontal,
            child: OutlinedButton.icon(
              onPressed: () {
                openApkDownload();
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.download, size: 18),
              label: Text(strings.downloadApkAction),
            ),
          ),
        ],
      );
    },
  );
  await prefs.setDismissed(true);
}
