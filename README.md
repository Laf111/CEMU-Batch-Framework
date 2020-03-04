# CEMU's Batch FrameWork

BatchFw is a free framework for the **CEMU** emulator (WII-U) based on batch, wmic outputs, powershell, vbs scripts and 3rd party tools.

Versions of CEMU supported : **1.11.1 to 1.17.2**

(if you want to use earlier versions, create an installation per game and per user)


Last GFX packs checked (presets completion) : **V641**


## Main purpose:

- **Making easier the installation of many versions of CEMU to launch your games (keeping as stable as possible for your games and your rig);**

- **Handle more than one user/save (also with versions of CEMU < 1.15.19);**

- **Make your loadiine games library portable :**
    - **save settings PER user (including GFX and mods packs) and PER host,**
    - **game stats per user (using all version of CEMU that supports it) for all hosts used** 

- **Switch freely from a version of CEMU to another for a given game, and play with the same data you had on the first one;**

- **Switch from game to game and automatically have all your data saved or restored on a given version of the CEMU emulator;**

- **Ease install, backup (game+update+DLC+saves+settings) and uninstall games (no need to dig in the mlc01 folder);**

- **Complete/create GFX packs for ALL games (even if they are still not officially supported). Support all aspect ratios (multi-screen) including TV one (HDTV, ultrawide, DCI) and also support custom user's ones**

- **create FPS packs : for games using a FPS engine model, it allows you to play at 105, 110 or 120% emulation speed (V-sync need to be disabled).**

- **For Wii-U owners: FTP interface + automatic installation of requiered files to play online** 
    - **get/sync online files (account, friends'list),** 
    - **sync saves between CEMU with the Wii-U**
    - **sync game stats between CEMU and the Wii-U,**
    - **get a snapshot of the games installed (saves, update, dlc, location mlc/usb),**
    - **dump safely a list of games automatically (scripts using a snapshot taken previously, ignoring errors caused by symlinks and using 2 passes of sync command). Games are ready to be launched (saves, update and DLC are installed automatically by BatchFw),**
    - **enable/disable Wii-U firmware update feature (by removing/creating the folder /storage_mlc/sys/update)** 
    - **ping the wii-U to avoid online simultaneous access** 
    


## How it works:

All by creating shortcuts (or executables) on your desktop - or a folder of your choice.

With BatchFw there's no need to bother about saves, caches, controller profiles, CEMU or CemuHook settings and precompiled cache ignoring if you're an NVidia user - since you won't need to build a shader cache for each version. BatchFw use the -mlc argument (introduced since 1.10) to set the mlc01 folder path outside the CEMU's folder. 

The mlc01 path is in the game folder so:

- your games library becomes portable: you can put it on an external drive and play on differents hosts (settings are stored by host and you only have to manage the shortcuts you created for each Cemu install on each host);

- you didn't go with a "big" mlc01 folder containing mixed saves, updates and DLC (including games you have deleted/installed) anymore (which is still the case if you use an external mlc01 folder);

- you can backup a whole game by compressing its folder (saves, updates, DLC, controller profiles, settings... are ALL included).

- uninstalling a game consist just in delete its folder.



## Main features:

- Handle muti users saves (per windows's profile) and online accounts (Wii-U owners);

- Supports CEMU accounts to import/export games saves;

- Save all settings including controller profiles for each players per game;

- Save separate CEMU settings per users (allow users to use differents mods);

- Handling game stats for every user taking all CEMU's versions (>= 1.15.18) and all hosts into account;

- Synchronize saves, transferable cache and game stats between BatchFw installs;

- Launch and close one or more third party softwares (DS4windows, Wiimotehook ...);

- Automatic graphics pack creation: you don't need to wait for the release of graphics packs for a yet not supported game to play at a resolution other than the native one (tested successfully on dozens of games) since BatchFW will try to create them automatically. And when an official pack for the game comes out BatchFW will automatically replace the created one;

- Automatic graphics pack completion (optional): BatchFw complete the range of available resolutions for your aspect ratios used. BatchFw compute your aspect ratio with the current resolution on each hosts. Common TV aspect ratios are proposed and you can define your own aspect ratio (by giving a resolution if you don't know the fractional number corresponding); 

- Prepare a SDcard content for your Wii-U (optional) : format using fat32format and install apps (HBL, DDD, NandDumper, CBHC, Loadiine_GX2, MOCHA, SigPatcher2SysMenu, WUP_installer_GX2, SaveMii_MOD, FTPiiU for MOCHA and CBHC);

- FTP transferts with your Wii-U (optional) : 
    - BatchFw use WinScp for FTP transferts (WinScp.com + an ini file template);
The first time you need to access to your Wii-U, you'll have to enter the IP and the port of the Wii-U and an ini file is created.
If you're using a static IP adress policy on your local network, no need to create a another configuration.
You'll be able to use the first one you created.
Note that if you want to run \_BatchFw\_Install\resources\winScp\winScp.exe (WinwScp UI) it will also use this ini file.
You'll only have to start/stop the ftpiiu server on your Wii-U and launch the provided scripts.
    - Map BatchFw's users to Wii-U profiles;
    - Automatically get online files and install files when an active network connection is found (you still need to dump opt.bin and seeprom.bin manually with NANDDUMPER);
    - List all your games installed on the Wii-U by taking a snapshot to a csv file containing for each game:
        - its location (mlc/usb);
        - if saves were found (for one user at least);
        - if an update is installed;
        - if a DLC is installed;
    - Dump a list of games :
        - define the list of games to dump (accordingly to the last snapshot taken)
        - decide if you want to import saves for all/a user/select for each game
        - dump sumultanously code, content, meta folder (game, update, DLC if found)
        - prepare the games to be emulated (install update, DLC and saves in the mlc01 folder of the game)
    - Enable/Disable Wii-U firmware update (by removing/creating the folder /storage_mlc/sys/update)
    - Import saves from the Wii-U (for all selected users including games stats from Wii-U);
    - Export saves to the Wii-U (for all selected users including CEMU games stats -> Wii-U)
   
    
    
### Other features:

- GPU Cache backup/restore per game (AMD, NVIDIA / OpenGL, Vulkan);

- Automatic GLCache cleanup when updating display drivers (CEMU leaves the old one);

- Secure CEMU threads by using a lock file (Though you won't be able to open multiple instances at once);

- Push the CEMU process priority to "above nromal" to "high" to minimize FPS drops while in game;

- Your own games compatibility datase per host you use (BatchFW logs silently the first version of CEMU that manages to run a game on this host);

- Your own CEMU X.Y.Z games compatibility list per host: compatibility per version and per host of all your games (last column in the csv file = code you have to enter @ http://compat.cemu.info/ to report your feedback for a game and it is filled automatically with your specs and the settings used);

- Easy game profile configuration per version (using shortcuts);

- Side by side game profile comparison;

- Double automatic backup of your transferable cache and saves for each games to avoid their corruption that can occur on CEMU crash;

- Automatic import of external transferable cache (you don't need to rename it with the right shaderCacheId of your game's region) to track broken shaderCacheId (as it happened with CEMU 1.8);

- Automatic graphic packs update (check availability);

- Automatic update (check availability);

- check pre requisites on each hosts (NTFS / mklink success / vbs & powershell scripts execution)


## Install: 

- Extract in your games folder;
- Launch _BatchFW_Install\\setup.bat;
- move or copy your mlc01 data when asked;
    - if you use external mlc01 folders per user, import all of them
    - if you use a CEMU installs per user, register all installs with importing mlc01 data   

When done, you can copy the whole directory containing your games and BatchFw install folder on an external drive to make your games library portable. To play on a new host, install CEMU on the new host and install BatchFw from the external device to create shortcuts (users already defined on another host are imported automatically, online files as well). 

Settings are saved by host (and per users). Transferable cache, controller profiles, graphic packs are shared/completed by all hosts.



## How to use:

- You want to create shortcuts to all your games for versions of CEMU using the ones created after the installation on your desktop?:

    - "C:\Users\\%USERNAME%\Desktop\Wii-U Games\BatchFW\Create CEMU's shortcuts for selected games.lnk" for a single CEMU version;

    - "C:\Users\\%USERNAME%\Desktop\Wii-U Games\BatchFW\Register CEMU installs.lnk" for more than one version (call setup.bat in silent mode);

- You want to change the way how Cemu is launched?: delete the shortcuts and re-create them;

- You want to delete your settings for version X.Y.Z or you want to recreate them?: use "C:\Users\\%USERNAME%\Desktop\Wii-U Games\CEMU\cemu_X.Y.Z\Delete my cemu_X.Y.Z's settings.lnk";

- You want to add a game?: once in your games folder, create shortcuts to this game with one or more version of CEMU by relaunching one of the 2 first scripts listed above;

- If shortcuts created before are broken (because the drive letter have changed for an USB drive or simply because you have moved your games): use the shortcut "Wii-U Games\Fix broken shortcuts.lnk";

- You don't need to manually open CEMU to play. Once you have collected all the settings (on the first launch of a game) for all versions of CEMU you play on, use the shortcuts on your desktop (Or your shortcuts folder);

"How to" informations are displayed in the console when creating shortcuts.

BatchFW does not need Adminstrator rights unless you want to create shortcuts at specifics locations.

All batch source code use delayed expansion mode and set your system charset to check/handle the minimum of unsupported characters in paths. When launching a game, batchFw is completly silent. It opens its log if needed and open Cemu's one if it crashes.

Code is well commented and is read only. 


## Tutorials & videos:

Install, create a portable loadiine library : https://1drv.ms/v/s!Apr2zdKB1g7fgkS7wOmXmanOFRRp?e=qhwmgU

Online files installation for all users : https://1drv.ms/v/s!Apr2zdKB1g7fgi17uiFUY7iteHet?e=qEa2ko

Dump a list of games : https://1drv.ms/v/s!Apr2zdKB1g7fgkIKKLfU5PeveU5u?e=2DiNlg


## FAQ: 

- **Do i need a Wii-U?**

    - No you don't. You can define users but obviously you'll cannot play online
    
- **Dumping games via network isn't it quite slow?**

    - Yes sure (Wii-U builtin network adapter suck : ~ 400Mb/h, a long night for BOTW) but total time has to be compared to a NANDUMPER's dump on SDCard + manual extraction with WFS Tools' time. Here all is done automatically by scripts : game are ready to be launched with saves, update and DLC already installed in the mlc01 folder located in the game one.     
    
- **Why backup/restore GLCache?**

    - CEMU version earlier than 1.15.1 does not protect the GLCache in shaderCache/driver/nvidia
    
    - GLCache is saved per game and so for versions >= 1.15.1 it avoids to handle only one big cache that could lead in extra RAM/VRAM consumption and generate stutters even with a full transferable shader cache


- **Playing with my games on a USB drive will not cripple performances?**

    - When you have a full cache (transferable) for each games : NO. CEMU load all in RAM and so it will only slightly upper  opening/closing times.
    
    
- **CEMU is already portable, what about install CEMU on a USB drive directlty?**

    First, you'll encounter heavy performance drops especially if some shaders needs to compile while playing (USB drives don't like read/write access at the same time) but also
    
    - If you install a single version of CEMU, you're not sure to manage to run all games without issues on every host but also : 
        - even if you can set relatives paths to avoid the USB drive letter change issue, you'll have to change some settings on every host (and need to backup them manually). Specially games profiles (recompiler mode) that are tweaked for a specific host (game's profile value will override the general UI settings) 
        - you'll have to recompile the entire shader cache each time, on each host.
        
    - If you install a version for each host (and use a custom mlc01 folder location) : 
        - you'll have to update your settings if the driver letter of your USB device is changed : even if relative paths syntax is supported when creating symlinks full paths are used : that's why BatchFw re-creates its symlinks on the fly)
        
    BatchFw fix broken shortcuts (Wii-U Games\\fix broken shortcuts.lnk can be also use if you move your games'folder)
    
    CEMU installs on host are only few Mb sized
    
    **You won't need to rebuild the shader cache everytime** (shader cache will be valid until the next drivers update and for most of CEMU's versions you'll install)
    
    BatchFw proposed to wipe all you traces on the host (Wii-U Games\\Wipe install traces on %USERDOMAIN%.lnk) 
        
- **How BatchFw will mess around with CEMU accounts (> 1.15.19) ?**

    - Same as it does with earlier version. All users use the 8000001 and so can use their saves on versions earlier than 1.15.19 (which introduced accounts). When imptoring Exporting games, you can choose source/target accounts to use
    
- **Why BatchFw's size is so big?**

    - Because of the third party software it comes with but mostly because of it packages files for offline installations :
        - GFX packs V2 and V3
        - CemuHook 0.5.7.3 and 0.5.6.4
        - shared fonts
    

## Recommendations: 

If you edit the source code, use a text editor that doesn't change ANSI files format to UTF8!

I recommend to not clone the repository : use the last released version (i also recommend to skip release candidate versions which are not fully validated).
Using the main branch could lead in regressions and troubles as bacth scripting is really difficult to check (no IDE, no compilation, poorly and unchecked syntax, file format issues...)  

But if you clone the repository anyway, take care that some files might be encoded in UTF8. You might use the script ./tools/fixBatFiles.bat (used to produce a release) to force the ANSI encoding and remove trailing spaces in all files (this script also put files in read only).


If you have any trouble don't seek for help or support on /r/CEMU or on discord, send me a private message on reddit, CEMU's Discord or GBATemp (to Laf111) and i'll gladly help you.
