# CEMU's Batch FrameWork

BatchFw is a free framework for the CEMU emulator (WII-U) based on batch, powershell and vbs scripts.
All versions of CEMU released from the 1.11.0 are supported.


## The main purpose of BatchFW is:

- Handle more than one user/save and for Wii-U owners, sync CEMU with the Wii-U (accounts, saves);
- Making easier the installation of many versions of CEMU to launch your games (keeping as stable as possible for your games and your rig);
- Switch freely from a version of CEMU to another for a given game, and play with the same data you had on the first one; 
- Switch from game to game and automatically have all your data saved or restored on a given version of the CEMU emulator;
- Check new release before updating your main install;
- Make your loadiine games library portable.


## How it works:

All by creating shortcuts (or executables) on your desktop - or a folder of your choice.

With BatchFw there's no need to bother about saves, caches, controller profiles, CEMU or CemuHook settings and precompiled cache ignoring if you're an NVidia user - since you won't need to build a shader cache for each version. BatchFw also clean useless GLcaches left in CEMU folder on a display drivers’ update.

The mlc01 path is in the game folder so:

- you can backup a whole game by compressing its folder (saves, updates, DLCs, controller profiles, settings... are ALL included);

- your games library becomes portable: you can put it on an external drive and play on differents hosts (settings are stored by host and you only have to manage the shortcuts you created for each Cemu install on each host);

Main features of BatchFw:
- Launch and close one or more third party softwares (DS4windows, Wiimotehook ...);

- Automatic graphics pack creation: you don't need to wait for the release of graphics packs for a yet not supported game to play at a resolution other than the native one (tested successfully on dozens of games) since BatchFW will try to create them automatically. And when an official pack for the game comes out BatchFW will automatically replace the created one.

- Automatic graphics pack completion (optional): BatchFw complete the range of available resolutions for one or more aspect ratios.  

- Prepare a SDcard content for your Wii-U (optional) : format using fat32format and install apps (HBL, DDD, NandDumper, CBHC, Loadiine_GX2, MOCHA, SigPatcher2SysMenu, WUP_installer_GX2, SaveMii_MOD, FTPiiU for MOCHA and CBHC).

- FTP transferts with your Wii-U (optional) : BatchFw use WinScp for FTP transferts (WinScp.com + an ini file template)
The first time you need to access to your Wii-U, you'll have to enter the IP and the port of the Wii-U and an ini file is created.
If you're using a static IP adress policy on your local network, no need to create a another configuration.
You'll be able to use the first one you created.
Note that if you want to run \_BatchFw\_Install\resources\winScp\winScp.exe (WinwScp UI) it will also use this ini file.
You'll only have to start/stop the ftpiiu server on your Wii-U and launch the provided scripts.


## Other features:

- Handle muti users saves (per windows's profile) and online accounts (Wii-U owners);

- This last feature allows you to handle multiple saves per user by defining as many "pseudo users" as differents saves you want (user_slot1, user_slot2... in this case, online user account will follow);

- Save all settings including controller profiles for each players per game;

- Save separate CEMU settings per users (allow users to use differents mods);

- GLCache backup/restore per game (AMD, NVIDIA);

- Automatic GLCache cleanup when updating display drivers;

- Secure CEMU threads by using a lock file (Though you won't be able to open multiple instances at once);

- Your own games compatibility datase per host you use (BatchFW logs silently the first version of CEMU that manages to run a game on this host);

- Your own CEMU X.Y.Z games compatibility list per host: compatibility per version and per host of all your games (last column in the csv file = code you have to enter @ http://compat.cemu.info/ to report your feedback for a game and it is filled automatically with your specs and the settings used);

- Easy game profile configuration per version (using shortcuts);

- Side by side game profile comparison;

- Double automatic backup of your transferable cache and saves for each games to avoid their corruption that can occur on CEMU crash;

- Automatic import of external transferable cache (you don't need to rename it with the right shaderCacheId of your game's region) to track broken shaderCacheId (as it happened with CEMU 1.8) and not only...

- Automatic graphic packs update (check availability);

- Automatic update (check availability);

    ect...


## Install : 

- Extract in your games folder;
- launch _BatchFW_Install\\setup.bat;
- move or copy your mlc01 data when asked;
- launch all your games a first time using the shortcuts created for the current user (boot to the menu is sufficient) to let BatchFw collect your settings, get your transferable cache and create a save for the current user.

If you use some external mlc01 folder or a/some CEMU install per user, repeat the last two steps for each user.

When done, you can copy the whole directory containing your games and BatchFw install folder on an external drive to make your games library portable. To play on a new host, install BatchFw from the HDD, install CEMU and create shortcuts (users already defined on another host are imported automatically, online files as well). 

Settings are saved by host (and per users). Transferable cache, controller profiles, graphic packs are shared by all hosts.



## How to use:

- You want to create shortcuts to all your games for versions of CEMU using the ones created after the installation on your desktop?:

    - "C:\Users\\%USERNAME%\Desktop\Wii-U Games\BatchFW\Create CEMU's shortcuts for selected games.lnk" for a single CEMU version;

    - "C:\Users\\%USERNAME%\Desktop\Wii-U Games\BatchFW\Register CEMU installs.lnk" for more than one version (call setup.bat in silent mode);

- You want to change the way how Cemu is launched?: delete the shortcuts and re-create them;

- You want to delete your settings for version X.Y.Z or you want to recreate them?: use "C:\Users\\%USERNAME%\Desktop\Wii-U Games\CEMU\cemu_X.Y.Z\Delete my cemu_X.Y.Z's settings.lnk";

- You want to add a game?: once in your games folder, create shortcuts to this game with one or more version of CEMU by relaunching one of the 2 first scripts listed above;

- If you use an external drive and shortcuts created before are broken (because the drive letter have changed): simply delete the shortcuts and re create them;

- You don't need to manually open CEMU to play. Once you have collected all the settings (on the first launch of a game) for all versions of CEMU you play on, use the shortcuts on your desktop (Or your shortcuts folder);

"How to" informations are displayed in the console when creating shortcuts.

BatchFW does not need Adminstrator rights unless you want to create shortcuts at specifics locations.

All batch source code use delayed expansion mode and set your system charset to check/handle the minimum of unsupported characters in paths. When launching a game, batchFw is completly silent. It opens its log if needed and open Cemu's one if it crashes.

Code is well commented and is read only. 


## Last tutorials :

V11 (install, mlc01 import... uninstall) : https://1drv.ms/v/s!Apr2zdKB1g7fghwWMdKpepl5S48C?e=UbjaQh

V12 (multi users without a Wii-U) : https://www.reddit.com/r/cemu/comments/ahkt5d/batchfw_v12_multiusers_mode_save_per_users_each/

V13 (install/import games update and DLC) : https://www.reddit.com/r/cemu/comments/axw1ag/batchfw_v13_now_fully_silent_launchclose_3rd/

V13-6 : https://1drv.ms/v/s!Apr2zdKB1g7fgi17uiFUY7iteHet?e=qEa2ko


## Recommendations : 

If you edit the source code, use a text editor that doesn't change ANSI files format to UTF8!

I recommend to not clone the repository : use the last released version.

But if you clone the repository anyway, take care that some files might be encoded in UTF8. You might use the script ./tools/fixBatFiles.bat (used to produce a release) to force the ANSI encoding and remove trailing spaces in all files (this script also put files in read only).

If you have any trouble, send me a private message on CEMU's reddit, Discord (/u/Laf111) or GBATemp (Laf111) and i'll gladly help you.
