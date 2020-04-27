=========================================================
GOAL : 
=========================================================

The main purpose of BatchFW is:

    Switch from game to game and automatically have all your data saved or restored on a given version of the CEMU emulator;

    Switch freely from a version of CEMU to another for a given game, and play with the same data you had on the first one. 
    You can also register multiple versions of the emulator;

All by creating shortcuts (or executables) on your desktop - or a folder of your choice.

With BatchFw there's no need to bother about saves, caches, controller profiles, CEMU or CemuHook settings and precompiled cache 
ignoring if you're an NVidia user - since you won't need to build a shader cache for each version.

The mlc01 path is in the game folder so

    you can backup a whole game by compressing its folder (saves, updates, DLCs, controller profiles, settings... are ALL included);

    your games library becomes portable: you can put it on an external drive and play on differents hosts (settings are stored by 
    host and you only have to manage the shortcuts you created for each Cemu install on each host);

Automatic graphics pack creation: you don't need to wait for the release of graphics packs for a yet not supported game to play at a 
resolution other than the native one (tested successfully on dozens of games) since BatchFW will try to create them automatically. 
And when an official pack for the game comes out BatchFW will automatically replace the created one.

FTP transferts with your Wii-U (optional) : BatchFw use WinScp for FTP transferts (WinScp.com + an ini file template) 
The first time you need to access to your Wii-U, you'll have to enter the IP and the port of the Wii-U and an ini file is created. 
If you're using a static IP adress policy on your local network, no need to create a another configuration. 
You'll be able to use the first one you created. 
Note that if you want to run _BatchFw_Install\resources\winScp\winScp.exe (WinwScp UI) it will also use this ini file. 
You'll only have to start/stop the ftpiiu server on your Wii-U and launch the provided scripts

Other features:

    Handle muti users saves (per windows's profile);

    GLCache backup/restore per game (AMD, NVIDIA);

    Automatic GLCache cleanup when updating display drivers;

    Secure CEMU threads by using a lock file (Though you won't be able to open multiple instances at once);

    Your own games compatibility datase per host you use (BatchFW logs silently the first version of CEMU that manages to run a 
    game on this host);

    Your own CEMU X.Y.Z games compatibility list per host: compatibility per version and per host of all your games (last column in 
    the csv file = code you have to enter @ http://compat.cemu.info/ to report your feedback for a game and it is filled automatically 
    with your specs and the settings used);

    Easy game profile configuration per version (using shortcuts);

    Side by side game profile comparison;

    Double automatic backup of your transferable cache and saves for each games to avoid their corruption that can occur on CEMU crash;

    Automatic import of external transferable cache (you don't need to rename it with the right shaderCacheId of your game's region) to 
    track broken shaderCacheId (as it happened with CEMU 1.8) and not only...

    ect...


BatchFW does not need Adminstrator rights.

All batch source code is in delayed expansion mode and uses your system charset to check/handle the minimum of unsupported characters in paths.

Code is well commented and is read only. If you edit source code, use a text editor that doesn't change ANSI files format to UTF8!


Feel free to modify it or enhance it but share it if you do.


=========================================================
INSTALL-UPDATE-USE : 
=========================================================

---------------------------------------------------------
INSTALL : 
---------------------------------------------------------

    Extract the archive's contain in your loadiine's games folder, then go in _BatchFW_Install and launch Setup.bat
    
    On the first install, you can display this documentation and the BatchFW_readme.txt file is build.
    Then setup.bat will run in SILENT mode. 
    
    When answering questions in setup.bat, a log file for your current host is created under _BatchFW_Install.
    Never delete this file! It contains your host's settings (fullscreen mode, desired aspect ratio, GLCache path...)
    
    During the setup, you'll define an ouput (shortcut or executables) folder for all the CEMU's installs to use but also: 
        - check and update _BatchFW_Graphic_Packs folder;
        - browse to a folder containing mods for your games so they will be copied under each game's folder;
        - if you want to run CEMU in fullscreen or in windowed mode;
        - if you let BatchFw completes your graphic packs (GFX) presets (V3) or create intermediates packs (V2);
        - your desired display aspect ratios (only if you has chosen the previous option);
        - the number of users to create (each user uses his own saves when launching his shortcut);
        - to define an ordered list of third party software (DS4windows, CemuGyro, SepeedHack...) to launch before CEMU in 
          the order defined after checking if the program is not already running;
        - use externals mlc01 paths to copy/move saves, updates and DLC under each game's folder;
        - use your CEMU's mlc01 subfolder as well;
    
    Once the setup is finished, the output folder is opened in a windows explorer. 
    It contains:
        - shortcuts to BatchFw logs, readmes and tools ;
        - a CEMU folder that contains a subfolder for each version registered containing:
            * a shorctut for editing the log of this version (log of the last launch);
            * a shortcut to the script that deletes your settings for this version and each games (selected);
            * a gameProfiles sufolder containing shortcuts to edit example.ini and the profile files of your games
          and also a shortcut to delete settings for all your games and for all versions of CEMU you have registered.    
    
    Note: this folder contains only links or useless data and can be deleted to be fully recreated).
    
    
    RECOMMENDATIONS: 
    
    To be fully functional BatchFw needs that you register the last(s) version(s) of CEMU you used to play your games.            
    If you're using more the one version of CEMU (on version per game for example) register all installations and select 
    the games to associated with those versions.
             
    If you're using one version of CEMU per player (and handle differents saves this way) : register this version for one user
    and use the shortcut "Wii-U Games\BatchFW\Tools\Games's saves\Import Saves" to import saves for other users afterward.    
    
---------------------------------------------------------
UPDATE : 
---------------------------------------------------------

    BatchFW comes with an auto-updater

---------------------------------------------------------
USE : 
---------------------------------------------------------
    
    You don't need to manually open CEMU UI to play your game anymore. 
    Once you have collected all the settings (on the first launch of a game) for all versions of CEMU you play on, use the shortcuts 
    on your desktop (Or your shortcuts folder).

    You want to create shortcuts to all your games for versions of CEMU using the ones created after the installation on your desktop?:

        "Wii-U Games\BatchFW\Create CEMU's shortcuts for selected games.lnk" for a single CEMU version;
        "Wii-U Games\BatchFW\Set BatchFw settings and register CEMU installs.lnk" for more than one version (call setup.bat 
        in silent mode);

    You want to :
        - change the way how Cemu is launched?: delete the shortcuts and re-create them;
        - delete your settings for version X.Y.Z or you want to recreate them?: use "Wii-U Games\CEMU\cemu_X.Y.Z\Delete my cemu_X.Y.Z's settings.lnk";
        - add a game?: 
            * use "Wii-U Games\Import Games with updates and DLC.lnk" to browse to a folder that contains games, updates and DLC
              BatchFW will ties all new games in your games folder with installing their updates and DLC in each game's folder
            * once new games copied in your games folder, create shortcuts for those games
        - remove a game from your library?: simply delete its created shortcut (BatchFw's broken shortcuts appear as the others ones, but without icon);

    With BatchFw, to backup fully a game (saves + update + DLC + transferable cache + controller settings...) just compress your game's folder
        
    Since V11, "how to" informations are displayed in the console when creating shortcuts.
    
    BatchFW come with an embeded graphic pack folder (_BatchFW_Graphic_Packs) created during setup.bat
    It checks for a graphic packs update availability (on eSlashiee repository) and update its packs  
    Only graphic packs of the games you use are kept in _BatchFW_Graphic_Packs and in CEMU UI only the one for the game launched are displayed
    
    There's a specific documentation detailling graphic packs handling in BatchFW.
    
    Your open GLCache is backuped under %USERPROFILE%\AppData\Roaming OR local\%GPU_VENDOR%\_BatchFW_CemuGLCache per game,for all your game and 
    for all GPU users.
    
    If you run an NVIDIA GPU, you can choose to disable automatically the precompiled cache for all your games (batchFw will patch CemuHook 
    files and CEMU's game profile)
    So you go only with your GPU cache, saving space on your device by not duplicating the compiled shaders cache and making it compatible 
    with all version of CEMU.
    This cache is valid unless you update your display's drivers : no need to fully recompile each cache for each game on each CEMU's version
    like when using the precompiled shader cache)
    When you update your drivers, batchFW will automically detect the new cache to backup and remove the old one.

    Disabling precompiled cache is not proposed to AMD's GPU because of their 64Mo size cache limitation. But the GLCache is even backuped.
    
    If you run an iGPU (Intel graphics), you will be asked to use the -noLegacy CEMU's option (-Legacy if CemuW 1.15)

    AUTOMATIC_IMPORT : 
    
    This process is enabled by default.
    If any settings are already saved for a game, BatchFw will try to use them avoiding you to collect settings from scratch.
    It begins with the newer versions down to the the last ones.
    One or two checks are done (depending on the couple of versions checked) to decide if the import of the source is valid or not : 
    - bin files size check: if source file's size is striclty lower than target's one => invalid import
    - if bin files check is OK, check if all criticals nodes (settings ones only) in xml target file exist in source file, if not => invalid import
      
    In addition, on last versions of CEMU, its auto-updater handle the settings.xml file upgrade.

    WARNING : Do not delete log files created under ./logs 
    If you need to reset BatchFw to default, use the shortcut "Wii-U Games\BatchFW\Reset BatchFw.lnk"
    
    
---------------------------------------------------------
UNINSTALL : 
---------------------------------------------------------

    Launch uninstall.bat from your desktop : "Wii-U Games\BatchFW\Uninstall BatchFW"

=========================================================
HOW IT WORKS : 
=========================================================

When creating shortcuts for a CEMU's version : 

    - if a mlc01 subfolder does not exist in game's folder, batchFw will create one. 
    - controller profiles are copied in CEMU's subfolder

The first time you launch a game for a given CEMU's version, you 'll have to follow a wizard that help you to collect 
your settings for this game :

    - if a meta\meta.xml is missing, batchFw can creates one for you
    - if no graphic packs is found for this game, create ones for you (V2 and V3 graphic packs). 
    - get game's data from an internal wii-u title database and complete them with game's update version and DLC 
      presence before saving them in a text file under game's folder
    - if a profile file for this game is missing in CEMU, you will create one and save a copy in a 
      _BatchFW_Missing_Profiles folder in order to share it with the others versions of CEMU 
    - batchFw can display the example.ini of this version to helps you to fill the game's profile file with the 
      supported directives
    - you can also choose to browse to another CEMU's install folder to compare game's profiles of this game side by side.
    - batchFw will display the current CEMU and CemuHook settings detected
    - launch CEMU UI a first time to ask you to select you graphic packs, at least all controller profiles for each 
      players to this game
    - settings are saved under the game's folder for the current host under GAME_FOLDER\Cemu\settings\HOSTNAME\CEMU_VERSION\

        
After this wizard completed, all actions are done silently. 
When launching a game (using its shortcut or an executable), launchGame.bat script will :

    - check if an graphic pack update is available
    - if enabled, complete/create graphic packs for this game
    - copy saved settings to CEMU_FOLDER including only the graphic packs of this game
    - load game's saves for current user 
    - creates a 2 levels backup of game's saves
    - provide V2 and V3 graphic packs for this game (using links)
    - copy transferable shader cache to CEMU install
    - creates a 2 level backup of transferable shader cache
    - retore OpenGL Cache fot this game in the GLCache working directory
    - create a lock file in CEMU_FOLDER, launch CEMU with a high priority
    - when closing CEMU : remove lock file and analyse return code to initialize CEMU_STATUS for the game and this 
      CEMU's version
    - if CEMU's return code equal 0, search in compatibility report ot the current host if a row already exist for this 
      game, creates a new one otherwise
    - else, open CEMU's log file
    - search in CEMU's version report for current rig (host) if a row already exist, create a new one otherwise
    - save settings under game's folder for the current hosts
    - restore initial CEMU's graphicPacks subfolder
    - save games's saves for the current user.
    - save the transferable cache.
    - analyse OpenGL Cache Id, detects display driver update, remove obsolete cache and backup the new.
If an issue occurs, batchFw will open its log file.


Compatibility reports are available throught shorcuts created in Wii-U Games\CEMU\Games Compatibility Reports. 
There are saved on your disk, in your games folder under a _BatchFW_Games_Compatibility_Reports subfolder.

BatchFW does not backup game's profiles. Those files are specific to each version of CEMU.

Settings now overrided with the game's profile are saved in the settings.bin on earlier versions.


BatchFW creates logs under_BatchFW_install\logs for your games library and every hosts.
Do not delete this log, it also contain your settings 

With using the tools provided to copy/move mlc01 folder's data for all your games in theirs respectives folders, with 
versions of CEMU newer than 1.11 your CEMU folder will finally contains only its precompiled cache shader (host dependant). 
All game's data (saves, updates, DLC, settings and transferable cache) are in the game's folder.

Your controller profiles are saved under a _BatchFW_Controller_Profiles\USERDOMAIN (USERDOMAIN=host name) and 
delivered to each version of CEMU.


=========================================================
USING EXECUTABLES : 
=========================================================

There’s a limitation on specials characters allowed in the paths due to the conversion process from batch to exe.
For compatibility purpose, the converter is limited by using only the charset code 850.
(not even the ASCII~=1252 one). 

If you get an error in the log file when launching a game that indicates that RPX_FILE_PATH was not found, you can identify the 
unsupported characters in the path displayed; they will be substituted by the system with the character '?'.


=========================================================
CEMU HISTORY :
=========================================================

    CEMU 1.8     Broke shader cache compatibility -> If you try to import a shader cache on earlier 
                 version, it will be erase/reset by CEMU;
    CEMU 1.10    Added -mlc argument to customize path for mlc01 directory -> In earlier version, all 
                 games' data were mixed in mlc01 subfolder in CEMU;
    CEMU 1.11    Modified saving process and location: broken compatibility on saves -> Use Cemu 1.11 to 
                 import/format your saves from previous versions;
    CEMU 1.12.0  Added games list;
    CEMU 1.12.1  Added disable precompiled shader cache option (UI settings & in game profiles);
    CEMU 1.13    Added -mlc settings in UI to customize path for mlc01 directory;
    CEMU 1.14    Shader reworked and introduced V3 graphic packs;
    CEMU 1.15.1  Support for game's mods and protection of the GLCache under shaderCahce/driver/nvidia;
    CEMU 1.15.6  Save controler profile used in the game's profile when using the UI (right click on the game in the list);
    CEMU 1.15.10 Add auto-updater;
    CEMU 1.15.15 User game's profiles (not overwritted when updating);
    CEMU 1.15.19 Accounts handling (multi users)
    CEMU 1.16    Vulkan API
    CEMU 1.17.2  Enhance multi-core recompiler compatibility (more games support it)
                
Before 1.11, saves were in mlc01/emulatorSave/ShaderCacheId and updates and DLC were applied by overwriting files.
After 1.11, they are stored in mlc01/usr/save/titleId[0:7]/titleId[8:15]/* (where titleId is the 16 characters id 
of your game (cf http://wiiubrew.org/wiki/Title_database )), 

- updates are in mlc01/usr/title/titleId[0:7]/titleId[8:15] 
- and DLC are in mlc01/usr/title/titleId[0:7]/titleId[8:15]/aoc

Recommended versions for BatchFw are >=1.11 (to avoid down side save format conversion issues).
Anyways, if you want to use a version earlier than 1.11, you'd better have a specific Cemu install for those games.

About CemuHook : 
---------------------

Since CemuHook 0.5.6.0 for 1.8.1-1.11.3, appears a new option in Debug menu : 
    - Precompiled shader cache On/Off, in case you want to use only your GLCache (GPU OpenGL cache).

On newer versions (>=1.15), the GLCache is not protected in CEMU's folder under shaderCahce/driver/nvidia


=========================================================
MIGRATE MLC01 DATA :
=========================================================

BatchFw ties your game's mlc01 data to the game's folder.

- to easily switch between versions of CEMU by having them share: 
    * saves, 
    * updates, 
    * dlcs, 
  by using the -mlc argument; 
- to make your loadiines games library portable (gather all game's data in its mlc01 subfolder);
- to avoid having all data for all your games mixed in the CEMU's folder and prevent from leaving USELESS data 
  when uninstalling a game;

Shortcuts created will use -mlc option pointing to mlc01 game's subfolder (your initial mlc01 folder in your 
Cemu's folder will be untouched)
So you can safely choose the first time to copy your mlc01 CEMU's subfolder (and remove it later if you 
keep BatchFW installed);

But before copying or moving, check your left space on your drives. If you have enough space, we recommend to 
copy the mlc01 folder instead of moving it.

If you want to uninstall BatchFW and have progressed in some games, choose to revert mlc01 from games's folders 
to your CEMU folder in order to keep your last saves created during BatchFW's trial. 
You should also think to choose to revert transferable cache.


=========================================================
Contributors : 
=========================================================

- Laf111 (u/Laf111)
- Nicklaj (u/Themastersimo)