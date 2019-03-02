# CEMU's Batch FrameWork

BatchFw is framework for the CEMU emulator (WII-U) based on batch, powershell and vbs scripts. 

CEMU is still under development and highly experimental. Therefore, due to its reverse-engineed nature, it tends to introduce regressions more rhan other softwares, and so it's useful to keep your working versions instead of systematically overwrite your install with the last one.

The main purpose of BatchFW is:

- Switch freely from a version of CEMU to another for a given game, and play with the same data you had on the first one. You can also register multiple versions of the emulator;
- Switch from game to game and automatically have all your data saved or restored on a given version of the CEMU emulator;

All by creating shortcuts (or executables) on your desktop - or a folder of your choice.

With BatchFw there's no need to bother about saves, caches, controller profiles, CEMU or CemuHook settings and precompiled cache ignoring if you're an NVidia user - since you won't need to build a shader cache for each version.

The mlc01 path is in the game folder so

- you can backup a whole game by compressing its folder (saves, updates, DLCs, controller profiles, settings... are ALL included);

- your games library becomes portable: you can put it on an external drive and play on differents hosts (settings are stored by host and you only have to manage the shortcuts you created for each Cemu install on each host);

Automatic graphics pack creation: you don't need to wait for the release of graphics packs for a yet not supported game to play at a resolution other than the native one (tested successfully on dozens of games) since BatchFW will try to create them automatically. And when an official pack for the game comes out BatchFW will automatically replace the created one.


Other features:

- Handle muti users saves (per windows's profile);

- GLCache backup/restore per game (AMD, NVIDIA);

- Automatic GLCache cleanup when updating display drivers;

- Secure CEMU threads by using a lock file (Though you won't be able to open multiple instances at once);

- Your own games compatibility datase per host you use (BatchFW logs silently the first version of CEMU that manages to run a game on this host);

- Your own CEMU X.Y.Z games compatibility list per host: compatibility per version and per host of all your games (last column in the csv file = code you have to enter @ http://compat.cemu.info/ to report your feedback for a game and it is filled automatically with your specs and the settings used);

- Easy game profile configuration per version (using shortcuts);

- Side by side game profile comparison;

- Double automatic backup of your transferable cache and saves for each games to avoid their corruption that can occur on CEMU crash;

- Automatic import of external transferable cache (you don't need to rename it with the right shaderCacheId of your game's region) to track broken shaderCacheId (as it happened with CEMU 1.8) and not only...

- Automatic graphic packs update (check availability)

- Automatic update (check availability)

    ect...


How to use:

- You want to create shortcuts to all your games for versions of CEMU using the ones created after the installation on your desktop?:

    - "C:\Users\%USERNAME%\Desktop\Wii-U Games\BatchFW\Create CEMU's shortcuts for selected games.lnk" for a single CEMU version;

    - "C:\Users\%USERNAME%\Desktop\Wii-U Games\BatchFW\Register CEMU installs.lnk" for more than one version (call setup.bat in silent mode);

- You want to change the way how Cemu is launched?: delete the shortcuts and re-create them;

- You want to delete your settings for version X.Y.Z or you want to recreate them?: use "C:\Users\%USERNAME%\Desktop\Wii-U Games\CEMU\cemu_X.Y.Z\Delete my cemu_X.Y.Z's settings.lnk";

- You want to add a game?: once in your games folder, create shortcuts to this game with one or more version of CEMU by relaunching one of the 2 first scripts listed above;

- You want to remove a game from your library?: simply delete its created shortcut (BatchFw's broken shortcuts appear as the others ones, but without icon);

- You don't need to manually open CEMU to play. Once you have collected all the settings (on the first launch of a game) for all versions of CEMU you play on, use the shortcuts on your desktop (Or your shortcuts folder);

Since V11, "how to" informations are displayed in the console when creating shortcuts.

BatchFW does not need Adminstrator rights.

All batch source code is in delayed expansion mode and uses your system charset to check/handle the minimum of unsupported characters in paths. When launching a game, batchFw is completly silent. It opens its log if needed and open Cemu's one if it crashes.

Code is well commented and is read only. 
If you edit source code, use a text editor that doesn't change ANSI files format to UTF8!
