# Steam Achievements Tracker

This is a mobile app built upon the Flutter framework that uses the Steam API. Given a Steam User's vanity URL, it orders all their owned games by percentage of achievements completed in descending order (it filters out games with 100% achievement completion).

The goal of this app is to provide a simple way to see which games are closest to 100% achievement completion for who care about such things, similar to the built in badge progress in the Steam UI.

## Getting Started


### Prerequisites

Flutter: [Get it here](https://flutter.dev/docs/get-started/install)

The Android SDK should also be installed: [Get it here](https://developer.android.com/studio#downloads)
An android emulator will be needed to run the app locally

### Installing

Before running the program, a valid Steam APIkey should be entered into 'configs.dart'. A Steam API key can be gotten from the [Steam Dev Portal](https://steamcommunity.com/dev/apikey)

NOTE: Your Steam API key is extremely sensitive and should be kept secret. Any commits/PRs that include this value will be rejected

Additional Note: The Steam Profile you are attempting to pull data from must be set to public. [See here for a Steam Knowledge Base article on privacy settings](https://support.steampowered.com/kb_article.php?ref=4113-YUDH-6401)


## Built With

* [Flutter](https://flutter.dev) - The Mobile App Framework

