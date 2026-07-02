import 'package:flutter/material.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    final newVersion = NewVersionPlus(
      androidId: "com.bbc.agsolutions", // Replace with your package name
    );

    final status = await newVersion.getVersionStatus();

    if (status == null) return;

    if (status.canUpdate) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Update Available"),
          content: Text(
            "A new version (${status.storeVersion}) is available.\n"
            "You are using ${status.localVersion}.",
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final url =
                    "https://play.google.com/store/apps/details?id=com.bbc.agsolutions&pcampaignid=web_share";

                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text("Update"),
            ),
          ],
        ),
      );
    }
  }
}