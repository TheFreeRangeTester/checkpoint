# Save and resume

Quick Checkpoint opens directly from the library, the game's recap card, the new small Quick Checkpoint widget, and the speech-bubble button in the medium Resume Session widget. The current game is preselected. A text checkpoint needs two taps plus typing: open the composer, then Save. It does not require starting a playing session.

The composer accepts a summary, an optional next objective, an image, or just an image. The explicit next objective takes priority over older pending tasks in the game, library preview, and widget. Completing or deleting it restores the oldest pending task. Existing tasks are kept.

“Checkpoint from Screenshot” on the game opens the photo picker first. The screenshot preview preserves the whole image, and text is optional. Loading and save errors keep the draft open; Save waits for the selected image to load.

The initial “Previously on…” card combines the latest checkpoint summary, the next objective, the most recently pinned reference (including its image), and the latest checkpoint image when different. Images open at full size. All pinned notes remain in Notes.

## Choose a game for the widget

Touch and hold the small Quick Checkpoint widget, choose **Edit Widget**, then **Game**. Select any active game, including games outside the four recently played entries. Each copy of the widget keeps its own choice. Tapping the widget opens Quick Checkpoint with that game preselected.

**Last Played Game** is the default and follows the automatic selection. A fixed choice stays fixed when you play another game. Renaming the game updates the displayed title. If the chosen game is deleted or marked finished, the widget shows **Game unavailable** and asks you to edit its choice; it does not silently switch to another game.

Existing widget snapshots remain readable. Open the app once after updating so it can sync the full active-game list. If iOS has cached the old static widget, remove and add the small Quick Checkpoint widget again, then configure it.

Configuration uses Apple's [AppIntentConfiguration and WidgetConfigurationIntent](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget).

## Shortcuts URLs

Use a URL action followed by Open URLs in Apple Shortcuts:

- `checkpoint://quick-checkpoint` — composer with the most recent active game selected.
- `checkpoint://capture` — photo picker first.
- Append `/GAME-UUID` to either URL to select a particular game.
- `checkpoint://game/GAME-UUID` continues to open the game's recap.

If there are only finished games, the composer selects the most recently finished game. Saving never reactivates a game or changes its last-played date. A missing game ID shows an error instead of silently saving to another game.

## Data and verification

The preferred objective uses an optional `nextObjectiveID`, allowing existing SwiftData stores to migrate. Backup v4 includes that ID, with decoding support for v1–v3.

Tests cover persisted text and photo checkpoints, objective priority and fallback, unchanged playing/completion dates, blank drafts, widget agreement, backup round trips, legacy backups, and deep links. Check the composer, photo picker, recap and widget on a device before release, including large text and a cold launch from each URL.
