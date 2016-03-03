/* AMX Mod X based Script (for MOD Counter-Strike)
*
*   HUST Pick-Up-Game Mode Plugin
*
*   │  Author  :       Chen Shi (aka. real, HUST CSer & NUDT)
*   │  Contact :       bigbryant@qq.com
*   │  Version :       1.4.1
*
*   This plugin is free software; you can redistribute it and/or modify it
*   under the terms of the GNU General Public License as published by the
*   Free Software Foundation; either version 2 of the License, or (at
*   your option) any later version.
*
*   This plugin is distributed in the hope that it will be useful, but
*   WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
*   General Public License for more details.
*
*   │  Changelog: 2016-03-02
*
*       1.4.1   1) fix all menu bugs
*               2) minor fixes
*
*       1.4.1a5 1) change pick team menu into count down menu
*
*       1.4.1a4 1) remove customed team select menu, use system defined instead
*               2) fix some of counting down bug
*               3) add customized config file path and config files
*               4) add intermission break time CVAR
*
*       1.4:    1) add 5-link function to the plugin
*               2) improve comments for the code
*               3) minor code optimization
*
*       1.3:    1) merged ShowMoney and PlayerMenu into plugin
*               2) set endless round time in warmup time
*               3) set endless buy time in warmup time
*               4) player will respawn instantly after death with 3secs protection
*               5) player will spawn with the weapon he held when he dead
*               6) dropped weapon will vanish in 5secs with no player pick them up
*               7) fix hud message channels for different messages, use director
*                  hudmessage to show prompt message
*
*       1.3a:   1) merge hust_ShowTeamMoney, see func "ShowTeamMoney"
*               2) player will respawn immediately in warmup time when dead
*               3) remove "hp_common_matchlive" cvar
*
*               todo:
*               1) how to easily realize endless round time in one round? <solved>
*               2) how to remove droped weapons in warmup time? <done>
*               3) merge pl_menu into plugin <done>
*
*       1.2.1:  fix client name change bug
*
*       1.2:    add pug match menu for admins
*
*       1.1:    fix some bugs. Add new CVAR
*               "hp_common_matchlive"   to tell if match is live now
*
*       1.0:    initial edition, realize match administration
*               add 2 CVARs
*               "hp_kniferound" set to 1 to enable a knife round before firsthalf
*               "hp_teamlimit" set 1 to enable team limitation when choosing team
*
*
===============================================================================*/

#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <fun>

#tryinclude "colorchat"
#tryinclude "dhudmessage"

#if AMXX_VERSION_NUM < 181
    #assert "AMX MOD X 1.8.1+ is required, compiling will be terminated..."
    #endinput
#endif

#if AMXX_VERSION_NUM < 183
    #if !defined _colorchat_included
        #assert "colorchat.inc required.^nDownload colorchat.inc at https://forums.alliedmods.net/showthread.php?t=94960"
    #endif

    #if !defined _dhudmessage_included
        #assert "dhudmessage.inc required.^nDownload dhudmessage.inc at https://forums.alliedmods.net/showthread.php?t=149210"
    #endif
#endif

//====PRE-PROCESSING FINISHED===================================================

// This section defines some pdata offset and values used in the code

const   m_iMenu                     =   205;
const   m_bHasChangeTeamThisRound   =   125;
const   r_MENU_TEAM_SELECT          =   1;
const   r_MENU_MODEL_SELECT         =   3;

//====PDATA OFFSETS DEFINITION FINISHED=========================================


new const PLUGIN_NAME[]     =   "HUST PUG";
new const PLUGIN_VERSION[]  =   "1.4.1a5";
new const PLUGIN_AUTHOR[]   =   "real";

// need flag "b" to control the plugin
new const PLUGIN_ACCESS     =   ADMIN_RESERVATION;

// max player supported
const   MAX_PLAYERS         =   32;

// default config file sub directory
new const PUG_CONFIG_DIR[]  =   "hustpug";
new const PUG_CONFIG_FILE[] =   "hustpug.cfg";

// Max Director HUD NUM
const   MAX_DHUD            =   8;

// offset of taskids
const   OFFSET_HUDMSG       =   100000;
const   OFFSET_RSP          =   150000;
const   OFFSET_MENU         =   200000;
const   OFFSET_COUNT        =   250000;
const   OFFSET_SCROLL       =   300000;
const   OFFSET_SETMODEL     =   350000;
const   OFFSET_R3           =   400000;
const   OFFSET_5LINK        =   450000;
const   OFFSET_CLEARPOS     =   500000;

// consts of different hudmsg task ID
const   TASKID_SHOWREADY    =   OFFSET_HUDMSG + ( 1 << 0 );
const   TASKID_SHOWNOTIFY   =   OFFSET_HUDMSG + ( 1 << 1 );
const   TASKID_SHOWSCORE    =   OFFSET_HUDMSG + ( 1 << 2 );

// Sync HUD Obj handles
new     g_hsyncReadyList;
new     g_hsyncScoreBoard;
new     g_hsyncNotify;
new     g_hsyncShowMoney;
new     g_hsync5Link;

// HUD message positions
new const Float: HUD_POS_RDYLIST[]      =   { 0.7, 0.2 };
new const Float: HUD_POS_NOTIFY[]       =   { -1.0, 0.0 };
new const Float: HUD_POS_SCOREBOARD[]   =   { -1.0, 0.0 };
new const Float: HUD_POS_SHOWMONEY[]    =   { 0.6, 0.2 };
new const Float: HUD_POS_PLRDY[]        =   { -1.0, 0.55 };
new const Float: HUD_POS_MATCHNOT[]     =   { -1.0, 0.4 };
new const Float: HUD_POS_ACT[]          =   { -1.0, 0.3 };
new const Float: HUD_POS_5LINK[]        =   { -1.0, 0.8 };
    
// HUD message interval
new const Float: HUD_INT_RDYLIST        =   10.0;
new const Float: HUD_INT_SCOREBOARD     =   10.0;
new const Float: HUD_INT_NOTIFY         =   20.0;
    
new bool: g_HudPlRdyPosFlag[MAX_DHUD];  // array to record available HUD display position

// consts about PUG status
enum {
    STATUS_WARM = 1,
    STATUS_KNIFE,
    STATUS_F_HALF,
    STATUS_INTER,
    STATUS_S_HALF
};

// weapon model prefix
new const WEAPON_MODEL_PREFIX[]     =   "models/w_";
new const WEAPONBOX_CLASSNAME[]     =   "weaponbox";
new const SHIELD_CLASSNAME[]        =   "weapon_shield";

// const of primary and secondary weapon index bits
new const CSW_PRIMARY       =   0x59fcf1a8;
new const CSW_SECONDARY     =   0x4030c02;

// const of all weapon and ammo name and max clip num
new const WEAPON_NAME[][] = {
    "",
    "weapon_p228",
    "weapon_shield",
    "weapon_scout",
    "weapon_hegrenade",
    "weapon_xm1014",
    "weapon_c4",
    "weapon_mac10",
    "weapon_aug",
    "weapon_smokegrenade",
    "weapon_elite",
    "weapon_fiveseven",
    "weapon_ump45",
    "weapon_sg550",
    "weapon_galil",
    "weapon_famas",
    "weapon_usp",
    "weapon_glock18",
    "weapon_awp",
    "weapon_mp5navy",
    "weapon_m249",
    "weapon_m3",
    "weapon_m4a1",
    "weapon_tmp",
    "weapon_g3sg1",
    "weapon_flashbang",
    "weapon_deagle",
    "weapon_sg552",
    "weapon_ak47",
    "weapon_knife",
    "weapon_p90"
};
new const WEAPON_MAXAMMO[] = {
    0, 52, 0, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 100, 
    120, 30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, 0, 100
};

// const for blocking map objectives in warmup time
new const OBJECTIVE_ENTS[][] = {
    "func_bomb_target",
    "info_bomb_target",
    "hostage_entity",
    "monster_scientist",
    "func_hostage_rescue",
    "info_hostage_rescue",
    "info_vip_start",
    "func_vip_safetyzone",
    "func_escapezone"
};
new const _OBJECTIVE_ENTS[][] = {
    "_func_bomb_target",
    "_info_bomb_target",
    "_hostage_entity",
    "_monster_scientist",
    "_func_hostage_rescue",
    "_info_hostage_rescue",
    "_info_vip_start",
    "_func_vip_safetyzone",
    "_func_escapezone"
};
const   HW_HIDE_TIMER_FLAG  =   ( 1 << 4 );

// global variable to record status now
new     g_StatusNow;

// global message strings
new     g_szHUDScore[256];                      // string of HUD score
new     g_szReadyList[512];                     // string of ready list

// array to record ready status of players
new     bool: g_ready[MAX_PLAYERS + 1];         // array to save ready state of players
new     g_name[MAX_PLAYERS + 1][32];            // array to save name of players
new     CsTeams: g_teamHash[MAX_PLAYERS + 1];   // array to save team of players
new     g_Tnum, g_Cnum;                         // number of members for each team
new     g_rdy;                                  // number of ready number
new     g_WarmWeapon[MAX_PLAYERS + 1][2];       // record weapon that user have in warmup time

// Scores
new     g_Score[2][2];          // storage for match score, pre-sub stands for team, lat-sub stands for 1, 2 half
new     g_RoundNum;             // variable to record current match round
new     g_scorebuff[2];         // score buffer that use to see if team scored

// CVAR pointers
new     g_pcKnifeRound;         // hp_kniferound
new     g_pcTeamLimit;          // hp_teamlimit
new     g_pcShowMoney;          // hp_showmoney
new     g_pcIntermission;       // hp_intermission
new     g_pcMaxRound;           // hp_maxround
new     g_pcWarmCfg, g_pcMatchCfg; // hp_warmcfg, hp_matchcfg
new     g_pcEnable5Link;        // hp_enable5link
new     g_pcLinkTime;           // hp_linktime
new     g_pcAmxShowAct;         // amx_show_activity
new     g_pcHostName;           // hostname
new     g_pcFreezeTime;         // mp_freezetime
new     g_pcAllTalk;            // sv_alltalk

// global match parameters
new     g_MaxRound;            // max round of the match
    
// vars to save 5-link status of player
new     bool: g_playertalk[MAX_PLAYERS + 1];
new     g_5linkcount[MAX_PLAYERS + 1];
    
// some message ids
new     g_msgidTeamScore;       // message id for "TeamScore" Msg
new     g_msgidHideWeapon;      // message id for "HideWeapon" Msg
new     g_msgidRoundTime;       // message id for "RoundTime" Msg
new     g_msgidWeapPickup;      // message id for "WeapPickup" Msg
new     g_msgidCurWeapon;       // message id for "CurWeapon" Msg
new     g_msgidTextMsg;         // TextMsg
new     g_msgidClCorpse;        // ClCorpse

// some message handles
new     g_hmsgHideWeapon;       // handle for registered message "HideWeapon"
new     g_hmsgWeapPickup;       // handle for registered message "WeapPickup"
new     g_hmsgCurWeapon;        // handle for registered message "CurWeapon"

// some ham forward handles
new     HamHook: g_hamPostSpawn;        // handle of HookPlayerSpawnPost
new     HamHook: g_hamFwdDeath;         // handle of HookPlayerDeathFwd
new     HamHook: g_hamPostTouch[3];     // handle of Ham_Touch for weaponbox, armoury and weapon_shield
new     HamHook: g_hamPostDeath5Link;
new     HamHook: g_hamFwdSpawn5Link;

// forward handles
new     g_hfwdGetCvarFloat;
new     g_hfwdSetModel;
new     g_hfwdSetClientListen;

// Player menu related part
const   MAP_VOTE_NUM        =   9;      // vote map list item num (9 max)
const   OFFSET_COUNT_MENU_PICKTEAM      =   250500;
const   OFFSET_COUNT_MENU_SWAPASK       =   251000;
const   OFFSET_COUNT_MENU_VOTEMAP       =   251500;
const   OFFSET_COUNT_MENU_VOTEKICK      =   252000;
    // pre-built menu bodies and handles
new     g_szMenuPickTeam[256];
new     g_hmMatchMenu;              // handle of PUG Match menu
new     g_hmPlayerMenu;             // handle of PUG player menu
    // count down globals
new     g_countdownPickTeam;
new     g_countdownVoteMap;
new     g_countdownVoteKick;
new     g_countdownSwapMenu[MAX_PLAYERS + 1]; // count down global for swap menu
new     g_countdownSwapAsk[MAX_PLAYERS + 1];
    // map related globals
        // vars to save swap requests and choices
new     g_SwapRequest[MAX_PLAYERS + 1];             // player requesting states
new     g_SwapBeRQ[MAX_PLAYERS + 1];                // player requested states
new     bool: g_SwapJudge[MAX_PLAYERS + 1];         // if swap agreed
new     bool: g_bIsOnVote;              // to indicate if a vote is on now
new     g_tskidOnVote;
new     g_kickid, g_kickagree;          // player who is being vote kicked
new     g_countPickTeam, g_mPickTeamAgree;
new     Array: g_Maps, g_Mapnum;        // maps name and map num
new     g_VoteMapCount[MAP_VOTE_NUM + 1], g_VoteMapid[MAP_VOTE_NUM + 1];   // save map vote result
new     g_countVoteMap, g_countVoteKick;
new     bool: g_bTeamPicked[MAX_PLAYERS + 1];
new     bool: g_bMapVoted[MAX_PLAYERS + 1];
new     bool: g_bKickVoted[MAX_PLAYERS + 1];

new     g_hostname[32];                 // hostname of server

// Game Time
new     Float: g_GameTime;              // global variable to get game time

//====GLOBAL VAR DEFINITION FINISHED============================================


//==============================================================================
//  ┌────────────────────────────┐
//  │  5-LINK RELATED FUNCTIONS  │
//  └────────────────────────────┘
//      → hamFwdSpawn5Link
//      → hamPostDeath5Link
//          ├ RemoveTalkFlag ←
//          │   └ PlayerMute ← 
//          └ Show5LinkCountdown ←
//      → fwdSetClListen
//==============================================================================

/*
    This function is a HAM forward to hook player spawn in when using 5-link
    function. It aims to recover talking status of player.
    
    g_hamFwdSpawn5Link = RegisterHam( Ham_Spawn, "player", "hamFwdSpawn5Link", 0 )
    
    @param  id      :   index of spawned player
    @return none
*/
public hamFwdSpawn5Link( id )
{
    g_playertalk[id] = true;
    remove_task( id + OFFSET_5LINK, 0 );
    
    return HAM_IGNORED;
}

/*
    This function is a HAM forward to hook player death in when using 5-link
    function. It aims to set a certain amount of time for player talking with
    his teammates after death. Talk time is set by CVAR hp_linktime.
    
    g_hamPostDeath5Link = RegisterHam( Ham_Killed, "player", "hamPostDeath5Link", 1 )
    
    @param  id      :   index of spawned player
    @return none
*/
public hamPostDeath5Link( id )
{
    if( get_pcvar_num( g_pcAllTalk ) == 1 || !StatLive() ) return HAM_IGNORED;

    new talktime = get_pcvar_num( g_pcLinkTime );
    
    if( talktime > 60 ) talktime = 60;
    if( talktime > 0 ) {
        set_task( float( talktime ), "RemoveTalkFlag", id + OFFSET_5LINK );
        g_5linkcount[id] = talktime;
        set_task( 1.0, "Show5LinkCountdown", id + OFFSET_5LINK, _, _, "a", talktime );
        set_hudmessage( 0xff, 0xff, 0xff, HUD_POS_5LINK[0], HUD_POS_5LINK[1], 0, 0.0, 1.0, 0.0, 0.0, -1 );
        ShowSyncHudMsg( id, g_hsync5Link, "%L", LANG_SERVER, "TEAM_TALK_MSG", talktime );
    }
    else {
        set_hudmessage( 0xff, 0xff, 0xff, HUD_POS_5LINK[0], HUD_POS_5LINK[1], 0, 0.0, 5.0, 0.0, 0.0, -1 );
        ShowSyncHudMsg( id, g_hsync5Link, "%L", LANG_SERVER, "TEAM_TALK_MSG_PERM" );
    }
    
    return HAM_IGNORED;
}

/*
    This function is used to display a count down message when team talk is
    appearing its functionality.
    This function is using a NORMAL HUD message
    
    HUD params:
        ├ CHANNEL:    CH_5LINK
        ├ POSITION:   HUD_POS_5LINK[]
        └ COLOR:      #FFFFFF (white)
    
    @param  tskid       :   tskid = id + OFFSET_5LINK is the task id.
    @return none
*/
public Show5LinkCountdown( tskid )
{
    new id = tskid - OFFSET_5LINK;
    
    if( --g_5linkcount[id] > 0 ) {
        set_hudmessage( 0xff, 0xff, 0xff, HUD_POS_5LINK[0], HUD_POS_5LINK[1], 0, 0.0, 1.0, 0.0, 0.0, -1 );
        ShowSyncHudMsg( id, g_hsync5Link, "%L", LANG_SERVER, "TEAM_TALK_MSG", g_5linkcount[id] );
    }
    else {
        set_hudmessage( 0xff, 0xff, 0xff, HUD_POS_5LINK[0], HUD_POS_5LINK[1], 0, 0.0, 5.0, 0.0, 0.0, -1 );
        ShowSyncHudMsg( id, g_hsync5Link, "%L", LANG_SERVER, "TEAM_TALK_OVERMSG" );
    }
    
    return;
}

/*
    This function is used set a player unable to talk.
    
    @param  id          :   index of player
    @return none
*/
public PlayerMute( id )
{
    static receiver;
    
    for( new i = 0; i < MAX_PLAYERS; i++ ) {
        receiver = i + 1;
        if( !is_user_connected( receiver ) || receiver == id ) continue;
        if( g_teamHash[id] != g_teamHash[receiver] ) continue;
            
        engfunc( EngFunc_SetClientListening, receiver, id, false );
    }
    
    return;
}

/*
    This function is used set a player unable to talk.
    
    @param  id          :   index of player
    @return none
*/
public RemoveTalkFlag( tskid )
{        
    new id = tskid - OFFSET_5LINK;
    
    if( is_user_alive( id ) ) return;
    
    g_playertalk[id] = false;
    PlayerMute( id );
    
    return;
}

/*
    This function is a fakemeta forward hook SetClientListening
    
    g_hfwdSetClientListen = register_forward( FM_Voice_SetClientListening, "fwdSetClListenCl", 0 )
    
    @param  receiver    :   listener
    @param  sender      :   talker
    @param  bListen     :   if listener can hear talker
    @return none
*/
public fwdSetClListen( receiver, sender, bool: bListen )
{
    if( !is_user_connected( receiver ) || 
        !is_user_connected( sender ) || 
        is_user_alive( sender ) ||
        sender == receiver ||
        g_teamHash[receiver] != g_teamHash[sender] )
        return FMRES_IGNORED;
        
    engfunc( EngFunc_SetClientListening, receiver, sender, g_playertalk[sender] );
    
    return FMRES_SUPERCEDE;
}

//==============================================================================
//  ┌─────────────────────────────────────┐
//  │  GENERIC MESSAGE RELATED FUNCTIONS  │
//  └─────────────────────────────────────┘
//      → CheckHostName
//      → findHUDPos
//          └ ClearHUDPos ←
//      → ServerSay
//          └ client_print_color *
//      → FireMsgTeamScore
//      → FireMsgTextMsg
//      → RefreshReadyList
//          └ ShowReadyList ←
//      → ShowNotification
//      → RefreshHUDScore
//          └ ShowHUDScore ←
//      → readMap
//      → ShowTeamMoney
//      → eventResetHUD
//==============================================================================

/*
    Checks name of current hostname by checking CVAR "hostname"
    
    @param  none
    @return none
*/
public CheckHostName()
{
    get_pcvar_string( g_pcHostName, g_hostname, 31 );
    formatex( g_name[0], 31, "%s", g_hostname );
    
    return;
}

/*
    This function frees the display position for PlayerReady HUD messages.
    The parameter is sent by a set_task() function
    
    @param  para[0]     :    position offsets compared to original position
    @param  para[1]     :    indicate positive/nagative offsets
    @return none
*/
public ClearHUDPos( tskid )
{
    g_HudPlRdyPosFlag[tskid - OFFSET_CLEARPOS] = false;
    
    return;
}

/*
    This function finds an available position for PlayerReady HUD message.
    The private array para[] is used for sending parameters to ClearHUDPos
    
    @param  none
    @return             :   the y-axis offset of an available display position
*/
Float: findHUDPos()
{
    static i;
    
    for( i = 0; i < MAX_DHUD; i++ ) 
        if( !g_HudPlRdyPosFlag[i] ) {
            g_HudPlRdyPosFlag[i] = true;
            set_task( 4.5, "ClearHUDPos", i + OFFSET_CLEARPOS );
            
            return 0.05 * i;
        }
        
    return 0.0;
}

/*
    This function generates server prompts similar to server_cmd( "say %s", Msg[] ).
    This function uses client_print_color() (requires colorchat.inc or AMXX183+) to
    create colored messages.
    
    @param  fmt[]       :   formatted string
    @return none
*/
ServerSay( const fmt[], any:... )
{
    static Msg[256];
    new argn = numargs();

    if( argn == 1 )
        formatex( Msg, 255, fmt );
    else
        vformat( Msg, 255, fmt, 2 );
    client_print_color( 0, GREY, "^4<%s> ^3%s", g_hostname, Msg );
    
    return;
}

/*
    This function fires a public message TeamScore to indicate team change of
    team scores.
    
    @param  team        :   team id
    @param  score       :   team score
    @return none
*/
FireMsgTeamScore( CsTeams: team, score )
{
    message_begin( MSG_ALL, g_msgidTeamScore );
    {
        switch( team ) {
            case CS_TEAM_T  :   write_string( "TERRORIST" );
            case CS_TEAM_CT :   write_string( "CT" );
        }
        write_short( score );
    }
    message_end();
    
    return;
}

/*
    This function fires a MSG_ONE message TextMsg to indicate that the corresponding
    team has too many players and cannot attend to.
    
    @param  id          :   index of player
    @param  team        :   team id
    @return none
*/
FireMsgTextMsg( id, CsTeams: team )
{
    message_begin( MSG_ONE, g_msgidTextMsg, _, id );
    {
        write_byte( print_center );
        switch( team ) {
            case CS_TEAM_T  :   write_string( "#Too_Many_Terrorists" );
            case CS_TEAM_CT :   write_string( "#Too_Many_CTs" );
        }
    }
    message_end();
    
    return;
}

/*
    This function updates the player information instantly.
    This function will be called after player using "jointeam" or "chooseteam"
    command with 0.1sec delay to fix display bug of readylist.
    
    @param  none
    @return none
*/
RefreshReadyList()
{
    new i, id, CsTeams: team, itot, iurdy;
    new len1, len2;
    static name[32], teamtag[5], rdymsg[512], urdymsg[512];
    
    itot = g_Tnum + g_Cnum;
    iurdy = itot - g_rdy;
    len1 = formatex( rdymsg, 511, "%L", LANG_SERVER, "PUG_RDYLIST_RDYTITLE", g_rdy, itot );
    len2 = formatex( urdymsg, 511, "%L", LANG_SERVER, "PUG_RDYLIST_URDTITLE", iurdy, itot );
    for( i = 0; i < MAX_PLAYERS; i++ ) {
        id = i + 1;        
        if( !is_user_connected( id ) ) continue;
        team = g_teamHash[id];               
        if( team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED ) continue;

        formatex( name, 31, "%s", g_name[id] );
        if( team == CS_TEAM_T )
            formatex( teamtag, 4, "(T)" );
        else
            formatex( teamtag, 4, "(CT)" );
        if( g_ready[id] )
            len1 += formatex( rdymsg[len1], 511 - len1, "%s%s^n", teamtag, name );
        else
            len2 += formatex( urdymsg[len2], 511 - len2, "%s%s^n", teamtag, name );
    }
    formatex( g_szReadyList, charsmax( g_szReadyList ), "%s^n%s", rdymsg, urdymsg );
    
    ShowReadyList( { 0 } );
    
    return;
}

/*
    This function shows a list under radar to indicate "ready" and "unready"
    player list. The list uses normal HUD system.
    
    HUD params:
        ├ CHANNEL:    CH_RDYLIST
        ├ POSITION:   HUD_POS_RDYLIST[]
        └ COLOR:      #FFFF00 (yellow)
    
    @param  none
    @return none
*/
public ShowReadyList( const index[] )
{
    set_hudmessage( 0xff, 0xff, 0x00, HUD_POS_RDYLIST[0], HUD_POS_RDYLIST[1], 0, 0.0, HUD_INT_RDYLIST, 0.0, 0.0, -1 );
    ShowSyncHudMsg( index[0], g_hsyncReadyList, g_szReadyList );
    
    return;
}

/*
    This function shows a pre-defined text on the top-center of screen in warmup 
    time. The message uses normal HUD system.
    
    HUD params:
        ├ CHANNEL:    CH_NOTIFY
        ├ POSITION:   HUD_POS_NOTIFY[]
        └ COLOR:      #00FFFF (cyan)
    
    @param  none
    @return none
*/
public ShowNotification( const index[] )
{
    set_hudmessage( 0x00, 0xff, 0xff, HUD_POS_NOTIFY[0], HUD_POS_NOTIFY[1], 0, 0.0, HUD_INT_NOTIFY, 0.0, 0.0, -1 );
    ShowSyncHudMsg( index[0], g_hsyncNotify, "%L", LANG_SERVER, "PUG_WARM_NOTIFY" );
    
    return;
}

/*
    This function updates the HUD scoreboard information instantly.
    This function will be called every time when a team scores or game progress
    changed.
    
    @param  none
    @return none
*/
RefreshHUDScore()
{
    static len;
    new maxl = charsmax( g_szHUDScore );
    new St = g_Score[0][0] + g_Score[0][1];
    new Sc = g_Score[1][0] + g_Score[1][1];
    
    switch( g_StatusNow ) {
        case STATUS_KNIFE: len = formatex( g_szHUDScore, maxl, "%L", LANG_SERVER, "PUG_KNIFEROUND" );
        case STATUS_F_HALF: len = formatex( g_szHUDScore, maxl, "%L", LANG_SERVER, "PUG_F_HALF" );
        case STATUS_S_HALF: len = formatex( g_szHUDScore, maxl, "%L", LANG_SERVER, "PUG_S_HALF" );
        case STATUS_INTER: len = formatex( g_szHUDScore, maxl, "%L", LANG_SERVER, "PUG_INTER" );    
    }
    len += formatex( g_szHUDScore[len], maxl - len, " %L", LANG_SERVER, "PUG_MATCHPROC", g_RoundNum, 2 * g_MaxRound );
    len += formatex( g_szHUDScore[len], maxl - len, "^n%L", LANG_SERVER, "PUG_SCOREBOARD", St, Sc );
    
    ShowHUDScore( { 0 } );
    
    return;
}

/*
    This function shows a scoreboard on the top-center of screen in match. 
    The message uses normal HUD system.
    
    HUD params:
        ├ CHANNEL:    CH_SCOREBOARD
        ├ POSITION:   HUD_POS_SCOREBOARD[]
        └ COLOR:      #FFFFFF (white)
    
    @param  none
    @return none
*/
public ShowHUDScore( const index[] )
{
    set_hudmessage( 0xff, 0xff, 0xff, HUD_POS_SCOREBOARD[0], HUD_POS_SCOREBOARD[1], 0, 0.0, HUD_INT_SCOREBOARD, 0.0, 0.0, -1 );
    ShowSyncHudMsg( index[0], g_hsyncScoreBoard, g_szHUDScore );
    
    return;
}

/*
    This function load map config files from server files. 
    
    @param  none
    @return none
*/
readMap()
{
    new maps_ini_file[64], len;
    
    g_Maps = ArrayCreate( 32 );
    len = get_configsdir( maps_ini_file, 63 );
    len += formatex( maps_ini_file[len], 63 - len, "/maps.ini" );
    if ( !file_exists( maps_ini_file ) )
        get_cvar_string( "mapcyclefile", maps_ini_file, 63 );
    if ( !file_exists( maps_ini_file ) )
        formatex( maps_ini_file, 63, "mapcycle.txt" );
    
    new fp = fopen( maps_ini_file, "r" );
    
    if( !fp ) return;
        
    new textline[256], mapname[32];
    
    while( !feof( fp ) ) {
        fgets( fp, textline, 255 );
        
        if( textline[0] == ';' ) continue;
        if( parse( textline, mapname, 31 ) < 1 ) continue;
        if( !is_map_valid( mapname ) ) continue;
            
        ArrayPushString( g_Maps, mapname );
        g_Mapnum++;
    }
    fclose( fp );
    
    return;
}

/*
    This function set a delay to show team money and ShowTeamMoney actually shows
    the team money for corresponding teams. This function use a normal HUD message.
    
    HUD params:
        ├ CHANNEL:    CH_SHOWMONEY
        ├ POSITION:   HUD_POS_SHOWMONEY[]
        └ COLOR:      #FF0000 (red) TERRORISTs
                      #0000FF (blue) CTs
    
    @param  none
    @return none
*/
public ShowTeamMoney()
{
    static Playerid[32], CsTeams: team[32], MsgT[256], MsgCT[256], lenT, lenCT;
    new i, money, PlayerNum, id;
    new Float: holdtime;
    
    get_players( Playerid, PlayerNum, "h", "" );
    lenT = formatex( MsgT, 255, "%L :^n^n", LANG_SERVER, "TELL_MONEY_TITLE_T" );
    lenCT = formatex( MsgCT, 255, "%L ：^n^n", LANG_SERVER, "TELL_MONEY_TITLE_CT" );
    for( i = 0; i < PlayerNum; i++ ) {
        id = Playerid[i];
        team[i] = g_teamHash[id];
        switch( team[i] ) {
            case CS_TEAM_CT: {
                money = cs_get_user_money( id );
                lenCT += formatex( MsgCT[lenCT], 255 - lenCT, "%s    ( %d )^n", g_name[id], money );
            }
            case CS_TEAM_T: {
                money = cs_get_user_money( id );
                lenT += formatex( MsgT[lenT], 255 - lenT, "%s    ( %d )^n", g_name[id], money );
            }
        }
    }
    
    holdtime = get_pcvar_float( g_pcFreezeTime ) - 1.0;
    for( i = 0; i < PlayerNum; i++ ) {
        id = Playerid[i];
        switch( team[i] ) {
            case CS_TEAM_CT: {
                set_hudmessage( 0x00, 0x00, 0xff, HUD_POS_SHOWMONEY[0], HUD_POS_SHOWMONEY[1], 0, 0.0, holdtime, 0.5, 1.0, -1 );
                ShowSyncHudMsg( id, g_hsyncShowMoney, MsgCT );
            }
            case CS_TEAM_T:{
                set_hudmessage( 0xff, 0x00, 0x00, HUD_POS_SHOWMONEY[0], HUD_POS_SHOWMONEY[1], 0, 0.0, holdtime, 0.5, 1.0, -1 );
                ShowSyncHudMsg( id, g_hsyncShowMoney, MsgT );
            }
        }
    }
    
    return;
}

/*
    This function hooks the event "ResetHUD" and its behavior depends on the
    match status.
    
    @param  id      :   index of player
    @return none
*/
public eventResetHUD( id )
{
    static index[2];
    index[0] = id;
    
    switch( g_StatusNow ) {
        case STATUS_WARM: {
            message_begin( MSG_ONE, g_msgidHideWeapon, _, id );
            {
                write_byte( HW_HIDE_TIMER_FLAG );
            }
            message_end();
            ShowReadyList( index );
            ShowNotification( index );
        }
        case STATUS_F_HALF, STATUS_S_HALF: {
            new Float: time = get_gametime();
            if( time - g_GameTime > 1.0 ) ShowHUDScore( index );
        }
        case STATUS_INTER: {
            ShowHUDScore( index );
            ShowReadyList( index );
        }
    }

    return;
}

//==============================================================================
//  ┌────────────────────────────┐
//  │  GENERIC USEFUL FUNCTIONS  │
//  └────────────────────────────┘
//      → LoadSettings
//      → SwapTeam
//          ├ swap_int ←
//          └ ServerSay
//      → StatLive
//      → StatMatch
//      → InitPlayerInfo
//      → RefreshReadyList
//          └ PutPlayer ←
//      → StripWeapon
//      → SetAllowGrens
//          ├ {*fwdSetInfiniteBuyTime*}
//          ├ {*fwdSetModel*}
//          ├ {*msgWeapPickup*}
//          ├ {*msgHideWeapon*}
//          └ {*fwdSetClListen*}
//==============================================================================

/*
    This function is used to load plugin config file in directory
    %CONFIGSDIR%/hustpug/hustpug.cfg
    
    @param  none
    @return none
*/
LoadSettings()
{
    static fpath[64], len;
    
    len = get_configsdir( fpath, 63 );
    len += formatex( fpath[len], 63 - len, "/%s/%s", PUG_CONFIG_DIR, PUG_CONFIG_FILE );
    if( file_exists( fpath ) )
        server_cmd( "exec ^"%s^"", fpath );
    else
        ServerSay( "%L", LANG_SERVER, "PUG_PLUGINCFG_NOTFOUND", PUG_CONFIG_FILE );
        
    return;
}

/*
    This function exchange values of two integer variables
    
    swap_int( int *, int * )
    
    @param  a, b    :   variables need to swap their values
    @return none
*/
swap_int( &a, &b )
{
    a = a ^ b;
    b = a ^ b;
    a = a ^ b;
    
    return;
}

/*
    This function alters team for CTs and Ts players. cs_set_user_team() is used
    to change teams, and this function will not trigger TeamInfo event. The user
    model cannot be selective either. Before the swap procedure, 
    cs_set_user_defuse() is used to strip defuse kit for CTs and Bomber will drop
    C4.
    
    @param  none
    @return none
*/
public SwapTeam()
{
    new i, id, CsTeams: team, wbox, st, sc;
    new bool: needtrans = false, transid;
    
    for( i = 0; i < MAX_PLAYERS; i++ ) {
        id = i + 1;
        if( !is_user_connected( id ) ) continue;
        team = g_teamHash[id];
        switch( team ) {
            case CS_TEAM_T: {
                if( is_user_alive( id ) && user_has_weapon( id, CSW_C4 ) ) {
                    engclient_cmd( id, "drop", "weapon_c4" );
                    
                    new c4ent = engfunc( EngFunc_FindEntityByString, 0, "classname", "weapon_c4" );
                    if( c4ent ) {
                        wbox = pev( c4ent, pev_owner );
                        if( wbox != 0 && wbox != id ) needtrans = true;
                    }
                }
                cs_set_user_team( id, CS_TEAM_CT, CS_DONTCHANGE );
                PutPlayer( id, team, CS_TEAM_T );
            }
            case CS_TEAM_CT: {
                if( is_user_alive( id ) ) {
                    cs_set_user_defuse( id, 0 );
                    transid = id;
                }
                cs_set_user_team( id, CS_TEAM_T, CS_DONTCHANGE );
                PutPlayer( id, team, CS_TEAM_CT );
            }
        }
    }
    if( !StatLive() ) RefreshReadyList();
    // finish C4 transfer if needed
    if( needtrans ) {
        set_pev( wbox, pev_flags, pev( wbox, pev_flags) | FL_ONGROUND );
        dllfunc( DLLFunc_Touch, wbox, transid );
    }   
    
    // swap scores and number of players
    swap_int( g_Score[0][0], g_Score[1][0] );
    swap_int( g_Score[0][1], g_Score[1][1] );
    swap_int( g_Tnum, g_Cnum );
    // fire 2 messages to update scores on scoreboard
    if( g_StatusNow == STATUS_S_HALF ) {
        sc = g_Score[1][1];
        st = g_Score[0][1];
    }
    else {
        sc = g_Score[1][0];
        st = g_Score[0][0];
    }
    FireMsgTeamScore( CS_TEAM_T, st );
    FireMsgTeamScore( CS_TEAM_CT, sc );
    if( task_exists( TASKID_SHOWSCORE, 0 ) ) RefreshHUDScore();
    
    ServerSay( "%L", LANG_SERVER, "PUG_TEAMSWAP_FINISH" );
    
    return;
}

/*
    These two function are almost the same. The difference between them,
    Live -  stands for a real matching status, only 1st/2nd half and overtime are
            called LIVE.
    Match - stands for there is a match on, except for STATUS_WARM, all other status
            are all MATCH on.
    
    @param  none
    @return none
*/
bool: StatLive() {
    return ( g_StatusNow != STATUS_WARM && g_StatusNow != STATUS_INTER );
}
bool: StatMatch() {
    return ( g_StatusNow != STATUS_WARM );
}

/*
    This function initialize the player ready status and player team hash table.
    This function will be called when plugin firstly loaded, EnterIntermission and
    Match end. Or other situation that need player to use "say ready" command.
    
    @param  none
    @return none
*/
InitPlayerInfo()
{
    g_rdy = 0;
    arrayset( g_ready, false, sizeof( g_ready ) );

    RefreshReadyList();
    
    return;
}

/*
    This function updates the player team and name.
    This function will be called in function RefreshReadyList().
    
    @param  id      :   index of player that needs to be updated
    @param  oldteam :   original team of player
    @param  newteam :   new team of player
    @return none
*/
PutPlayer( id, CsTeams: oldteam, CsTeams: newteam )
{ 
    if( oldteam == newteam ) return;

    g_teamHash[id] = newteam;
    switch( oldteam ) {
        case CS_TEAM_T:     g_Tnum--;
        case CS_TEAM_CT:    g_Cnum--;
    }    
    switch( newteam ) {
        case CS_TEAM_T:     g_Tnum++;
        case CS_TEAM_CT:    g_Cnum++;
        default: {
            g_rdy -= _:( g_ready[id] );
            g_ready[id] = false;
        }
    }
    if( oldteam == CS_TEAM_UNASSIGNED )
        get_user_name( id, g_name[id], 31 );
    
    return;
}

/*
    This function strips specific weapon from a player.
    
    @param  id      :   index of player that needs to be striped
    @param  wid     :   weapon id
    @return none
*/
StripWeapon( id, wid )
{
    if( !wid || !is_user_alive( id ) ) return;
    
    static wEnt;
    
    wEnt = find_ent_by_owner( 32, WEAPON_NAME[wid], id );
    if( !wEnt ) return;
    
    if( get_user_weapon( id ) == wid ) 
        ExecuteHam( Ham_Weapon_RetireWeapon, wEnt );
    if( !ExecuteHam( Ham_RemovePlayerItem, id, wEnt ) ) return;
    ExecuteHam( Ham_Item_Kill, wEnt );
    set_pev( id, pev_weapons, pev( id, pev_weapons ) & ~( 1 << wid ) );
    
    return;
}

/*
    This is function enable/disables most forwards used in warmup time.
    This is a very IMPORTANT FUNCTION!!!!!!
    
    @param  bifon       :   true - disable forwards, prepare for MATCH
                            false - enable forwards, prepare for WARMUP
    @return none
*/
SetAllowGrens( bool: bifon )
{
    if( bifon ) {
        server_cmd( "amx_restrict off flash" );
        server_cmd( "amx_restrict off hegren" );
        server_cmd( "amx_restrict off sgren" );
        unregister_forward( FM_CVarGetFloat, g_hfwdGetCvarFloat, 0 );
        unregister_forward( FM_SetModel, g_hfwdSetModel, 0 );
        // disable Spawn Ham Forward
        DisableHamForward( g_hamPostSpawn );
        DisableHamForward( g_hamFwdDeath );
        DisableHamForward( g_hamPostTouch[0] );
        DisableHamForward( g_hamPostTouch[1] );
        DisableHamForward( g_hamPostTouch[2] );
        // disable WeapPickup message
        unregister_message( g_msgidWeapPickup, g_hmsgWeapPickup );
        unregister_message( g_msgidCurWeapon, g_hmsgCurWeapon );
        // deal with 5-link forwards
        if( get_pcvar_num( g_pcEnable5Link ) == 1 ) {
            g_hfwdSetClientListen = register_forward( FM_Voice_SetClientListening, "fwdSetClListenCl", 0 );
            EnableHamForward( g_hamPostDeath5Link );
            EnableHamForward( g_hamFwdSpawn5Link );
        }
    }
    else {
        server_cmd( "amx_restrict on flash" );
        server_cmd( "amx_restrict on hegren" );
        server_cmd( "amx_restrict on sgren" );
        g_hfwdGetCvarFloat = register_forward( FM_CVarGetFloat, "fwdSetInfiniteBuyTime", 0 );
        g_hfwdSetModel = register_forward( FM_SetModel, "fwdSetModel", 0 );
        // enabel ham forward spawn
        EnableHamForward( g_hamPostSpawn );
        EnableHamForward( g_hamFwdDeath );
        EnableHamForward( g_hamPostTouch[0] );
        EnableHamForward( g_hamPostTouch[1] );
        EnableHamForward( g_hamPostTouch[2] );
        // register some messages
        g_hmsgWeapPickup = register_message( g_msgidWeapPickup, "msgWeapPickup" );
        g_hmsgCurWeapon = register_message( g_msgidCurWeapon, "msgCurWeapon" );
        // deal with 5-link forwards
        if( get_pcvar_num( g_pcEnable5Link ) == 1 ) {
            unregister_forward( FM_Voice_SetClientListening, g_hfwdSetClientListen );
            DisableHamForward( g_hamPostDeath5Link );
            DisableHamForward( g_hamFwdSpawn5Link );
        }
    }
    
    return;
}

//==============================================================================
//  ┌───────────────────────────────┐
//  │  WARM-UP-TIME GAME FUNCTIONS  │
//  └───────────────────────────────┘
//      → eventTeamInfo
//          ├ RefreshReadyList
//          └ PutPlayer
//      → hamFwdPlayerDeath
//          └ DelayRespawn ←
//      → hamPostPlayerSpawn
//          ├ RemoveProtect ←
//          └ StripWeapon
//      → msgWeapPickup
//      → msgCurWeapon
//      → fwdSetModel
//          └ DelayRemoveEnt ←
//      → hamPostWeaponTouch
//          └ DelayRemoveTask ←
//      → SetMapObjective
//          └ {*msgHideWeapon*}
//      → msgHideWeapon
//      → fwdSetInfiniteBuyTime
//==============================================================================

/*
    This function is registered to hook event "TeamInfo". It aims to respawn a
    player instantly when they firstly join a team in warmup time. It called
    DelayRespawn() function to respawn the player.
    
    Event "TeamInfo" has 2 arguments in which the first one indicates the 
    player's index
    
    @param  none
    @return none
*/
public eventTeamInfo()
{
    static tname[2], CsTeams: team, CsTeams: oteam;
    read_data( 2, tname, 1 );
    new id = read_data( 1 );

    switch( tname[0] ) {
        case 'U': team = CS_TEAM_UNASSIGNED;
        case 'T': team = CS_TEAM_T;
        case 'C': team = CS_TEAM_CT;
        case 'S': team = CS_TEAM_SPECTATOR;
    }
    oteam = g_teamHash[id];
    if( oteam != team ) {
        PutPlayer( id, oteam, team );
        if( !StatLive() ) RefreshReadyList();
    } 
    
    if( g_Tnum * g_Cnum == 0 && StatMatch() ) server_cmd( "hp_forcestop" );
    
    return;
}

/*
    This function is used to spawn a player in warmup time. It is usually called
    with a small amount of delay time to ensure the correctness of the result. In
    order to specify the task, player id will contain in taskid with offset
    OFFSET_RSP.
    
    @param  tskid       :   taskid = id + OFFSET_RSP is the task id.
    @return none
*/
public DelayRespawn( tskid )
{
    new id = tskid - OFFSET_RSP;
    
    if( is_user_alive( id ) || !is_user_connected( id ) ) return;
    
    new CsTeams: team = g_teamHash[id];
        
    if( team != CS_TEAM_T && team != CS_TEAM_CT ) return;
    
    ExecuteHamB( Ham_CS_RoundRespawn, id );
    
    return;
}

/*
    This function is a HAM forward to hook player death in warmup time. It aims
    to acquire the guns player holding when they dead. Then it calls function 
    DelayRespawn() with 0.5sec delay to respawn the player.
    
    g_hamFwdDeath = RegisterHam( Ham_Killed, "player", "hamFwdPlayerDeath", 0 )

        g_WarmWeapon[id][0, 1]  0 - primary, 1 - secondary
        bit ( 1 << 0 ) stands for burst mode
        bit ( 1 << 1 ) stands for silencer mode
        weapon id lies to the left begin with bit ( 1 << 2 )
    
    @param  id      :   index of dead player
    @return none
*/
public hamFwdPlayerDeath( id )
{
    new wps[32], wpnum, i;
    static m4a1, famas, usp, glock;
        
    get_user_weapons( id, wps, wpnum );
    for( i = 0; i < wpnum; i++ ) {
        if( CSW_PRIMARY & ( 1 << wps[i] ) ) {
            g_WarmWeapon[id][0] = ( wps[i] << 2 );
            switch( wps[i] ) {
                case CSW_M4A1: {
                    m4a1 = find_ent_by_owner( 32, "weapon_m4a1", id );
                    if( cs_get_weapon_silen( m4a1 ) ) g_WarmWeapon[id][0] |= 2;
                }
                case CSW_FAMAS: {
                    famas = find_ent_by_owner( 32, "weapon_famas", id );
                    if( cs_get_weapon_burst( famas ) ) g_WarmWeapon[id][0] |= 1;
                }
            }
        }
        if( CSW_SECONDARY & ( 1 << wps[i] ) ) {
            g_WarmWeapon[id][1] = ( wps[i] << 2 );
            switch( wps[i] ) {
                case CSW_USP: {
                    usp = find_ent_by_owner( 32, "weapon_usp", id );
                    if( cs_get_weapon_silen( usp ) ) g_WarmWeapon[id][1] |= 2;
                }
                case CSW_GLOCK18: {
                    glock = find_ent_by_owner( 32, "weapon_glock18", id );
                    if( cs_get_weapon_burst( glock ) ) g_WarmWeapon[id][1] |= 1;
                }
            }
        }
    }
            
    set_task( 0.5, "DelayRespawn", id + OFFSET_RSP );
    
    return HAM_IGNORED;
}

/*
    This function is a HAM forward to hook player spawn in warmup time. It aims
    to recover the guns player holding when they dead. It will be triggered by
    function DelayRespawn(). It will also give the player 3secs godmode time.
    
    g_hamPostSpawn = RegisterHam( Ham_Spawn, "player", "hamPostPlayerSpawn", 1 )
    
    @param  id      :   index of spawned player
    @return none
*/
public hamPostPlayerSpawn( id )
{
    if( !is_user_alive( id ) ) return HAM_IGNORED;
    
    static CsTeams: team, buff, wid, stat, wEnt;
    
    cs_set_user_money( id, 16000 );
    set_user_godmode( id, 1 );
    cs_set_user_armor( id, 100, CS_ARMOR_VESTHELM );
    team = g_teamHash[ id ];
    switch( team ) {
        case CS_TEAM_T: set_user_rendering( id, kRenderFxGlowShell, 0xff, 0, 0, kRenderNormal, 16 );
        case CS_TEAM_CT: set_user_rendering( id, kRenderFxGlowShell, 0, 0, 0xff, kRenderNormal, 16 );
    }
    if( ( buff = g_WarmWeapon[id][1] ) != 0 ) {
        wid = ( buff >> 2 );
        stat = ( buff & 3 );
        switch( team ) {
            case CS_TEAM_T: 
                if( wid != CSW_GLOCK18 ) {
                    StripWeapon( id, CSW_GLOCK18 );
                    give_item( id, WEAPON_NAME[wid] );
                }
            case CS_TEAM_CT: 
                if( wid != CSW_USP ) {
                    StripWeapon( id, CSW_USP );
                    give_item( id, WEAPON_NAME[wid] );
                }
        }
        if( ( wid == CSW_GLOCK18 || wid == CSW_USP ) && ( stat != 0 ) ) {
            wEnt = find_ent_by_owner( 32, WEAPON_NAME[wid], id );
            cs_set_weapon_silen( wEnt, ( stat & 2 ) != 0 ? 1 : 0, 0 );
            cs_set_weapon_burst( wEnt, ( stat & 1 ) != 0 ? 1 : 0 );
        }
    }
    if( ( buff = g_WarmWeapon[id][0] ) != 0 ) {
        wid = ( buff >> 2 );
        stat = ( buff & 3 );
        give_item( id, WEAPON_NAME[wid] );
        if( ( wid == CSW_M4A1 || wid == CSW_FAMAS ) && ( stat != 0 ) ) {
            wEnt = find_ent_by_owner( 32, WEAPON_NAME[wid], id );
            cs_set_weapon_silen( wEnt, ( stat & 2 ) != 0 ? 1 : 0, 0 );
            cs_set_weapon_burst( wEnt, ( stat & 1 ) != 0 ? 1 : 0 );
        }
    }
    g_WarmWeapon[id][0] = g_WarmWeapon[id][1] = 0;
    give_item( id, WEAPON_NAME[4] );
    give_item( id, WEAPON_NAME[25] );
    give_item( id, WEAPON_NAME[25] );
    
    set_task( 3.0, "RemoveProtect", id + OFFSET_RSP );
    
    return HAM_IGNORED;
}

/*
    This function is used to remove player's godmode 3secs after spawning.
    
    @param  tskid       :   tskid = id + OFFSET_RSP is the task id.,
    @return none
*/
public RemoveProtect( tskid )
{
    new id = tskid - OFFSET_RSP;
    
    if( !is_user_alive( id ) ) return;
    set_user_godmode( id, 0 );
    set_user_rendering( id, kRenderFxNone );
    
    return;
}

/*
    This function hooks the message "WeapPickup" and it's blocks the HUD icon of
    default secondary weapon if they had an alternative one. This message only
    registered in warmup time.
    
    g_msgidWeapPickup = get_user_msgid( "WeapPickup" )
    g_hmsgWeapPickup = register_message( g_msgidWeapPickup, "msgWeapPickup" )
    
    @param  id          :   index of player
    @return none
*/
public msgWeapPickup( msgid, idest, id )
{
    if( !is_user_alive( id ) || g_WarmWeapon[id][1] == 0 ) return PLUGIN_CONTINUE;
    
    new wid = ( g_WarmWeapon[id][1] >> 2 );
    new msgwid = get_msg_arg_int( 1 );

    if( ( ( 1 << msgwid ) & CSW_SECONDARY ) != 0 && wid != msgwid )  
        return PLUGIN_HANDLED;
    
    return PLUGIN_CONTINUE;
}

/*
    This function hooks the message "CurWeapon" to give infinite back pack
    ammo to player when warmup time.
    
    g_msgidCurWeapon = get_user_msgid( "CurWeapon" )
    g_hmsgCurWeapon = register_message( g_msgidCurWeapon, "msgCurWeapon" )
    
    @param  id          :   index of player
    @return none
*/
public msgCurWeapon( msgid, idest, id )
{
    if( !is_user_alive( id ) || get_msg_arg_int( 1 ) == 0 ) return PLUGIN_CONTINUE;

    new wpid = get_msg_arg_int( 2 );
    if( WEAPON_MAXAMMO[wpid] > 2 )
        cs_set_user_bpammo( id, wpid, WEAPON_MAXAMMO[wpid] );
    
    return PLUGIN_CONTINUE;
}

/*
    This function is a fakemeta forward to hook player weapon drop in warmup time. 
    The function calls function DelayRemoveEnt() to kill the entity in 5secs. 
    
    g_hfwdSetModel = register_forward( FM_SetModel, "fwdSetModel", 0 )
    
    @param  ent         :   index of entity
    @param  model[]     :   model name
    @return none
*/
public fwdSetModel( ent, const model[] )
{
    if( !pev_valid( ent ) || !equali( model, WEAPON_MODEL_PREFIX, charsmax( WEAPON_MODEL_PREFIX ) ) )
        return FMRES_IGNORED;
        
    new id = pev( ent, pev_owner );
    static classname[32];
    
    if( !is_user_connected( id ) ) return FMRES_IGNORED;
    pev( ent, pev_classname, classname, 31 );
    if( !equal( classname, WEAPONBOX_CLASSNAME ) && !equal( classname, SHIELD_CLASSNAME ) )
        return FMRES_IGNORED;
        
    new tskid = ent + OFFSET_SETMODEL;
    if( !task_exists( tskid, 0 ) ) set_task( 5.0, "DelayRemoveEnt", tskid );
    set_rendering( ent, kRenderFxGlowShell, 0xcd, 0x7f, 0x32, kRenderNormal, 16 );
    
    return FMRES_IGNORED;
}

/*
    This function kills a weaponbox that player drops in warmup time.
    
    @param  tskid       :   tskid = ent + OFFSET_SETMODEL is the task id
    @return none
*/
public DelayRemoveEnt( tskid )
{
    new ent = tskid - OFFSET_SETMODEL;
    
    if( pev_valid( ent ) ) dllfunc( DLLFunc_Think, ent );
        
    return;
}

/*
    This function sets the task of DelayRemoveTask() task if the weapon has been
    touched by a player.
    
    @param  ent         :   index of weapon box
    @param  id          :   index of player
    @return none
*/
public hamPostWeaponTouch( ent, id )
{
    if( !is_user_alive( id ) ) return HAM_IGNORED;
        
    set_task( 0.1, "DelayRemoveTask", ent );
        
    return HAM_IGNORED;
}

/*
    This function removes the DelayRemoveEnt() task if the weapon has been
    picked up.
    
    @param  ent         :   index of weapon box
    @return none
*/
public DelayRemoveTask( ent )
{
    if( pev_valid( ent ) ) return;
        
    remove_task( ent + OFFSET_SETMODEL, 0 );
        
    return;
}

/*
    This function removes objective entities on objective maps to create unlimited
    round time in warmup time.
    
    @param  bifon       :   true - restore objective ents, prepare for MATCH
                            false - remove objective ents, prepare for WARMUP
    @return none
*/
SetMapObjective( const bool: bifon )
{
    static ent, i;
    
    ent = -1;
    for( i = 0; i < sizeof( OBJECTIVE_ENTS ); i++ )
        while( ( ent = engfunc( EngFunc_FindEntityByString, ent, "classname", bifon ? _OBJECTIVE_ENTS[i] : OBJECTIVE_ENTS[i] ) ) > 0 )
            set_pev( ent, pev_classname, bifon ? OBJECTIVE_ENTS[i] : _OBJECTIVE_ENTS[i]);
                
    return;
}

/*
    This function un/register the message related to hide round timer on bottom-
    center screen. And "msgHideWeapon" is used to block round timer.
    
    @param  ifblock     :   true - register HideWeapon Msg, prepare for MATCH
                            false - unregister HideWeapon Msg, prepare for WARMUP
    @return none
*/
SetBlockRoundTimer( const bool: ifblock )
{
    if( ifblock ) {
        g_hmsgHideWeapon = register_message( g_msgidHideWeapon, "msgHideWeapon" );
        set_msg_block( g_msgidRoundTime, BLOCK_SET );
    }
    else {
        unregister_message( g_msgidHideWeapon, g_hmsgHideWeapon );
        set_msg_block( g_msgidRoundTime, BLOCK_NOT );
    }
    
    return;
}

public msgHideWeapon()
{
    set_msg_arg_int( 1, ARG_BYTE, get_msg_arg_int( 1 ) | HW_HIDE_TIMER_FLAG );
    
    return;
}

/*
    This function is a fakemeta forward to hook and alter CVAR values. This is
    used to change mp_buytime value in warmup time to apply infinite buy time
    in warmup time. 
    
    g_hfwdGetCvarFloat = register_forward( FM_CVarGetFloat, "fwdSetInfiniteBuyTime", 0 )
    
    @param  szcvar      :   name of the cvar
    @return none
*/
public fwdSetInfiniteBuyTime( const szcvar[] )
{
    if( equal( szcvar, "mp_buytime" ) ) {
        forward_return( FMV_FLOAT, 99999.0 );
        return FMRES_SUPERCEDE;
    }
    
    return FMRES_IGNORED;
}

//==============================================================================
//  ┌─────────────────────────────────────┐
//  │  READY AUTO-START SYSTEM FUNCTIONS  │
//  └─────────────────────────────────────┘
//      → msgShowMenu
//      → clcmdJoinClass
//          └ DelayRespawn
//      → clcmdMenuSelect
//          ├ DelayRespawn
//          └ fnTeamSelect ←
//      → clcmdJoinTeam
//          └ fnTeamSelect ←
//      → clcmdChooseTeam
//          ├ MenuShowSwapMenu
//          └ SwapCenterCountDown
//      → PlayerReady
//          ├ findHUDPos
//          ├ ShowReadyList
//          └ AutoStart ←
//              ├ StopWarm
//              ├ EnterKnifeRound
//              ├ EnterFirstHalf
//              └ EnterSecondHalf
//      → PlayerUNReady
//          ├ ShowReadyList
//          └ findHUDPos
//==============================================================================

/*
    This function hooks "ShowMenu" message to force change to old-style team select
    menu to offer the option 6. Spectator.
    
    register_message( get_user_msgid( "ShowMenu" ), "msgShowMenu" )
    
    @param  id      :   index of player
    @return none
*/
public msgShowMenu( msgid, idest, id )
{
    static menutext[32], len;
    
    len = get_msg_arg_string( 4, menutext, 31 );

    if( containi( menutext, "Team_Select" ) != -1 && containi( menutext, "_Spect" ) == -1 ) {
        len += formatex( menutext[len], 31 - len, "_Spect" );
        set_msg_arg_string( 4, menutext );
        set_msg_arg_int( 1, ARG_SHORT, get_msg_arg_int( 1 ) | MENU_KEY_6 );
    }
    
    return PLUGIN_CONTINUE;
}

/*
    This function sets DelayRespawn for player after he had chosen his model in
    VGUI menu in warmup time.
    
    @param  id      :   index of player
    @return none
*/
public clcmdJoinClass( id )
{
    if( !StatMatch() && get_pdata_int( id, m_iMenu ) == r_MENU_MODEL_SELECT )
        set_task( 0.5, "DelayRespawn", id + OFFSET_RSP );
    
    return PLUGIN_CONTINUE;
}

/*
    This function is used to deal with the team select action triggered by
    old-style team select menu and jointeam command.
    
    @param  id      :   index of player
    @param  argn    :   argument after menuselect or jointeam
    @return tell main function to use or terminate original operation
*/
fnTeamSelect( id, argn )
{
    static Float: time, Float: ft;
    new tl = get_pcvar_num( g_pcTeamLimit );
    
    switch( argn ) {
        case 1: if( g_Tnum >= 5 && tl == 1 ) {
            if( !StatLive() ) FireMsgTextMsg( id, CS_TEAM_T );
            client_cmd( id, "chooseteam" );
            
            return PLUGIN_HANDLED;
        }
        case 2: if( g_Cnum >= 5 && tl == 1 ) {
            if( !StatLive() ) FireMsgTextMsg( id, CS_TEAM_CT );
            client_cmd( id, "chooseteam" );
            
            return PLUGIN_HANDLED;
        }
        case 5: if( g_Tnum >= 5 && g_Cnum >= 5 && tl == 1 ) {
            if( !StatLive() )
                client_print( id, print_center, "%L", LANG_SERVER, "PUG_MENU_CANTJOIN" );
            client_cmd( id, "chooseteam" );
            
            return PLUGIN_HANDLED;
        }
        case 6: {
            time = get_gametime();
            ft = get_pcvar_float( g_pcFreezeTime );
            if( time - g_GameTime > ft && is_user_alive( id ) ) {
                set_msg_block( g_msgidClCorpse, BLOCK_ONCE );
                user_kill( id );
                cs_set_user_team( id, CS_TEAM_SPECTATOR, CS_DONTCHANGE );
                PutPlayer( id, g_teamHash[id], CS_TEAM_SPECTATOR );
                if( !StatLive() ) RefreshReadyList();
                
                return PLUGIN_HANDLED;
            }
        }
    }
    
    return PLUGIN_CONTINUE;
}

/*
    This function deal with the old-style team select menu and realize the 
    team limit function. It also sets DelayRespawn for player who chose their
    model by old-style menu in warmup time.
    
    @param  id      :   index of player
    @return none
*/
public clcmdMenuSelect( id )
{
    new menuid = get_pdata_int( id, m_iMenu );
    static arg[3];
    read_argv( 1, arg, 2 );
    new argn = str_to_num( arg );
    
    switch( menuid ) {
        case r_MENU_TEAM_SELECT: return fnTeamSelect( id, argn );
        case r_MENU_MODEL_SELECT: 
            if( !StatMatch() ) set_task( 0.5, "DelayRespawn", id + OFFSET_RSP );
    }

    return PLUGIN_CONTINUE;
}

/*
    These 2 functions are used to marked player flag so they can change their
    team more than once in a single round.
    
    @param  none
    @return none
*/
public clcmdJoinTeam( id )
{
    set_pdata_int( id, m_bHasChangeTeamThisRound, get_pdata_int( id, m_bHasChangeTeamThisRound ) & ~( 1 << 8 ) );    
    if( read_argc() > 2 ) return PLUGIN_HANDLED;
    
    static arg[3];
    read_argv( 1, arg, 2 );
    new argn = str_to_num( arg );
    
    return fnTeamSelect( id, argn );
}

/*
    These functions is to hook client command chooseteam.
    
    @param  id      :   index of player
    @return none
*/
public clcmdChooseTeam( id )
{
    set_pdata_int( id, m_bHasChangeTeamThisRound, get_pdata_int( id, m_bHasChangeTeamThisRound ) & ~( 1 << 8 ) );
    
    const TSWAP = 5;
    new tl = get_pcvar_num( g_pcTeamLimit );
    new CsTeams: team = g_teamHash[id];
    new bool: flag;
    
    if( tl == 1 ) {
        switch( team ) {
            case CS_TEAM_T: flag = g_Cnum >= 5;
            case CS_TEAM_CT: flag = g_Tnum >= 5;
            default: flag = ( g_Cnum >= 5 && g_Tnum >= 5 );
        }
        if( StatLive() && flag ) {
            if( team == CS_TEAM_CT || team == CS_TEAM_T ) {
                if( task_exists( id + OFFSET_COUNT, 0 ) ) {
                    remove_task( id + OFFSET_COUNT, 0 );
                    client_print( id, print_center, "" );
                    MenuShowSwapMenu( id );
                }
                else {
                    g_countdownSwapMenu[id] = TSWAP + 1;
                    SwapCenterCountDown( id + OFFSET_COUNT );
                    set_task( 1.0, "SwapCenterCountDown", id + OFFSET_COUNT, _, _, "a", TSWAP );
                }
                
                return PLUGIN_HANDLED;
            }
            else {
                client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTTEAMSELECT" );
                
                return PLUGIN_HANDLED;
            }
        }
    }
    
    return PLUGIN_CONTINUE;
}

/*
    This function marks player to ready status when player executed the pre-defined
    command ( say !ready or sth. else ) and function PlayerUNReady() does the
    opposite. These functions are using Director HUD message to show prompt messages.
    Function findHUDPos() is called to find a available display position.
    
    HUD params:
        ├ CHANNEL:    DIRECTOR HUD
        ├ POSITION:   HUD_POS_PLRDY[] ( will be auto-adjusted to avoid overlap )
        └ COLOR:      #FFFFFF (white)
    
    @param  id          :   index of player
    @return none
*/
public PlayerReady( id )
{
    if( StatLive() ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTUSECMD" );
        return PLUGIN_CONTINUE;
    }
    
    if( g_teamHash[id] != CS_TEAM_T && g_teamHash[id] != CS_TEAM_CT ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTRDY" );
        return PLUGIN_CONTINUE;
    }
    
    if( g_ready[id] ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_ALREADYRDY" );
        return PLUGIN_CONTINUE;
    }
    else {
        g_ready[id] = true;
        g_rdy++;
    }    
    
    set_dhudmessage( 0xff, 0xff, 0xff, HUD_POS_PLRDY[0], HUD_POS_PLRDY[1] + findHUDPos(), 0, 0.0, 2.8, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_READYMSG", g_name[id] );
        
    RefreshReadyList();
    AutoStart( false, -1 );
    
    return PLUGIN_HANDLED;
}

public PlayerUNReady( id )
{
    if( StatLive() ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTUSECMD" );
        return PLUGIN_CONTINUE;
    }
    
    if( g_teamHash[id] != CS_TEAM_T && g_teamHash[id] != CS_TEAM_CT ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTURDY" );
        return PLUGIN_CONTINUE;
    }
    
    if( !g_ready[id] ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_HAVNOTRDY" );
        return PLUGIN_CONTINUE;
    }
    else {
        g_ready[id] = false;
        g_rdy--;
    }
    
    set_dhudmessage( 0xff, 0x55, 0x55, HUD_POS_PLRDY[0], HUD_POS_PLRDY[1] + findHUDPos(), 0, 0.0, 2.8, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_UREADYMSG", g_name[id] );
    
    RefreshReadyList();
    
    return PLUGIN_HANDLED;
}

/*
    This function checks if the match can start now. It is called by PlayerReady
    and ForceStart function.
    
    @param  force       :   boolean var to indicate that if the match will be
                            start forcely. If set to true, the game will auto
                            start regardless of how many players have been
                            ready.
    @param  ifKnife     :   This parameter indicate if the match will have knife
                            round before the first half. If set to -1, the knife
                            round will be decided by CVAR hp_kniferound. Set to
                            0 and 1 represent no knife round and force knife
                            round, respectively.
    @return none
*/
AutoStart( bool: force, ifKnife )
{
    if( g_rdy != 10 && !force ) return;
        
    if( g_Cnum * g_Tnum == 0 ) {
        set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
        show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_CANNOTBEGIN" );
        if( g_rdy == 10 ) for( new i = 0; i < MAX_PLAYERS; i++ )
            if( g_ready[i + 1] ) {
                PlayerUNReady( i + 1 );
                break;
            }
            
        return;
    }
        
    if( g_rdy == 10 ) {
        set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_ACT[0], HUD_POS_ACT[1], 0, 0.0, 5.0, 0.1, 0.1 );
        show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_ALLREADY" );
    }
        
    switch( g_StatusNow ) {
        case STATUS_WARM: {
            new bknife = get_pcvar_num( g_pcKnifeRound );
        
            StopWarm();
    
            if( ifKnife != -1 ) bknife = ifKnife;
            switch( bknife ) {
                case 0: EnterFirstHalf();
                case 1: {
                    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
                    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_KNIFEROUND_MSG" );
                    set_task( 3.0, "EnterKnifeRound" );
                }
            }
        }
        case STATUS_INTER: {
            remove_task( TASKID_SHOWREADY, 0 );
            EnterSecondHalf();
        }
    }
    
    return;
}

//==============================================================================
//  ┌───────────────────────────────────┐
//  │  REGULAR MATCH RELATED FUNCTIONS  │
//  └───────────────────────────────────┘
//      → eventCurWeapon
//      → StopWarm
//          ├ SetMapObjective
//          ├ SetBlockRoundTimer
//          └ SetAllowGrens
//      → EnterKnifeRound
//          └ KnifeRoundMsg ←
//      → EnterFirstHalf
//          └ R3Function ←
//              └ ScrollServerSay ←
//      → msgTeamScore
//          ├ UpdateScore ←
//          │   ├ EnterIntermission ←
//          │   │   ├ SwapTeam
//          │   │   ├ EnterSecondHalf ←
//          │   │   │   └ R3Function ←
//          │   │   └ ShowReadyList
//          │   ├ MatchWin ←
//          │   │   └ EnterWarm ←
//          │   │       ├ SetMapObjective
//          │   │       ├ SetBlockRoundTimer
//          │   │       └ SetAllowGrens
//          │   └ MatchDraw ←
//          │       └ EnterWarm ←
//          └ KnifeRoundWon ←
//              └ ShowPickTeamMenu
//==============================================================================

/*
    This function hooks "CurWeapon" event to force players to use knife in knife
    round.
    
    register_event( "CurWeapon", "eventCurWeapon", "be", "1=0", "2=29" )
    
    @param  id      :   index of player
    @return none
*/
public eventCurWeapon( id )
{
    if( g_StatusNow == STATUS_KNIFE )
        engclient_cmd( id, "weapon_knife" );

    return PLUGIN_CONTINUE;
}

/*
    This function lets the plugin enter warmup status and set proper tasks for
    warmup time
    
    @param  none
    @return none
*/
public EnterWarm()
{
    static fname[32], fpath[64], len;
    
    // block map objective
    SetMapObjective( false );
    SetBlockRoundTimer( true );
    // restrict grenades
    SetAllowGrens( false );
    
    // refresh player info
    InitPlayerInfo();
    // alter status to warmup time
    g_StatusNow = STATUS_WARM;
    
    remove_task( TASKID_SHOWSCORE, 0 );
    
    if( !task_exists( TASKID_SHOWREADY, 0 ) )
        set_task( HUD_INT_RDYLIST, "ShowReadyList", TASKID_SHOWREADY, { 0 }, 1, "b" );
    if( !task_exists( TASKID_SHOWNOTIFY, 0 ) )
        set_task( HUD_INT_NOTIFY, "ShowNotification", TASKID_SHOWNOTIFY, { 0 }, 1, "b" );
    
    get_pcvar_string( g_pcWarmCfg, fname, 31 );
    len = get_configsdir( fpath, 63 );
    len += formatex( fpath[len], 63 - len, "/%s/%s", PUG_CONFIG_DIR, fname );
    if( file_exists( fpath ) ) {  
        server_cmd( "exec ^"%s^"", fpath );
        ServerSay( "%L", LANG_SERVER, "PUG_WARMCFG_LOADED", fname );
    }
    else if( file_exists( fname ) ) {
        server_cmd( "exec ^"%s^"", fname );
        ServerSay( "%L", LANG_SERVER, "PUG_WARMCFG_LOADED", fname );
    }
    else
        ServerSay( "%L", LANG_SERVER, "PUG_CFGNOTFOUND", fname );

    server_cmd( "sv_restartround 1" );
    
    return;
}

/*
    This function lets the plugin stop warmup status and set proper tasks for
    match. This is usually called when preparing for match status.
    
    @param  none
    @return none
*/
StopWarm()
{
    static fname[32], fpath[64], len;
    
    // recover map objective
    SetMapObjective( true );
    SetBlockRoundTimer( false );
    // unrestrict grenades
    SetAllowGrens( true );
    
    remove_task( TASKID_SHOWREADY, 0 );
    remove_task( TASKID_SHOWNOTIFY, 0 );
    
    if( !task_exists( TASKID_SHOWSCORE, 0 ) )
        set_task( HUD_INT_SCOREBOARD, "ShowHUDScore", TASKID_SHOWSCORE, { 0 }, 1, "b" );
    
    // get match parameters
    g_MaxRound = get_pcvar_num( g_pcMaxRound );
    get_pcvar_string( g_pcMatchCfg, fname, 31 );
    len = get_configsdir( fpath, 63 );
    len += formatex( fpath[len], 63 - len, "/%s/%s", PUG_CONFIG_DIR, fname );
    if( file_exists( fpath ) ) {  
        server_cmd( "exec ^"%s^"", fpath );
        ServerSay( "%L", LANG_SERVER, "PUG_MATCHCFG_LOADED", fname );
    }
    else if( file_exists( fname ) ) {
        server_cmd( "exec ^"%s^"", fname );
        ServerSay( "%L", LANG_SERVER, "PUG_MATCHCFG_LOADED", fname );
    }
    else
        ServerSay( "%L", LANG_SERVER, "PUG_CFGNOTFOUND", fname );
    
    return;
}

/*
    This function lets the match enters kniferound. 
    
    @param  none
    @return none
*/
public EnterKnifeRound()
{
    g_StatusNow = STATUS_KNIFE;
    g_GameTime = get_gametime();
    
    g_Score[0][0] = g_Score[0][1] = g_Score[1][0] = g_Score[1][1] = 0;
    ServerSay( "%L", LANG_SERVER, "PUG_KNIFEROUND_MSG" );
    server_cmd( "sv_restartround 3" );
    set_task( 5.0, "KnifeRoundMsg" );
    
    return;
}

/*
    This function shows the kniferound prompt message. 
    This message uses director HUD message.
    
    HUD params:
        ├ CHANNEL:    DIRECTOR HUD
        ├ POSITION:   HUD_POS_MATCHNOT[]
        └ COLOR:      #FF0000 (red)
    
    @param  none
    @return none
*/
public KnifeRoundMsg()
{
    for( new i = 0; i < 4; i++ ) ServerSay( "%L", LANG_SERVER, "PUG_KNIFEROUND_STR" );
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_KNIFEROUND_HUD" );
    
    return;
}

/*
    This function is called when a team has won the kniferound and show them
    the team pick up menu to let them choose the team.
    This function uses the Director HUD message.
    
    HUD params:
        ├ CHANNEL:    DIRECTOR HUD
        ├ POSITION:   HUD_POS_MATCHNOT[]
        └ COLOR:      #FFFFFF (white)
    
    @param  team        :   team id of the winner's team
    @return none
*/
KnifeRoundWon( CsTeams: team )
{
    static teamname[16];
    
    if( team == CS_TEAM_T )
        formatex( teamname, 15, "%L", LANG_SERVER, "PUG_TNAME" );
    else
        formatex( teamname, 15, "%L", LANG_SERVER, "PUG_CTNAME" );
    set_dhudmessage( 0xff, 0xff, 0xff, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_KNIFEWON_MSG", teamname );

    MenuSetPickTeam( team );    
    
    return;
}

/*
    This function is called to process with Restart-3 procedure. 
    This function uses the Director HUD message.
    
    HUD params:
        ├ CHANNEL:    DIRECTOR HUD
        ├ POSITION:   HUD_POS_MATCHNOT[]
        └ COLOR:      #FF0000 (red)
    
    @param  tskid       :   t = tskid - OFFSET_R3 is the refresh interval
    @return none
*/
public R3Function( tskid )
{
    const R3_SCROLL_WID = 25;
    const R3_SCROLL_NUM = 2;
    
    new t = tskid - OFFSET_R3;
    new Float: inter = t * 2.0;
    
    if( t <= 3 ) {
        ServerSay( "%L", LANG_SERVER, "PUG_R3MSG", t );
        server_cmd( "sv_restartround %d", t );
        set_task( inter, "R3Function", tskid + 1 );
    }
    else {
        set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
        show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_HALFSTART_HUD" );
        set_task( 0.1, "ScrollServerSay", R3_SCROLL_WID + OFFSET_SCROLL, _, _, "a", R3_SCROLL_WID * R3_SCROLL_NUM );
    }
    
    return;
}

/*
    This function is called to produce a scrolled LIVE message in chat section.
    
    @param  tskid       :   width = tskid - OFFSET_SCROLL is the scrolling width of message
    @return none
*/
public ScrollServerSay( tskid )
{
    new i, width = tskid - OFFSET_SCROLL;
    static Msg[128], p1[64], p2[64], count;
    
    i = width - count - 1;
    arrayset( p1, '-', count );
    p1[count] = 0;
    arrayset( p2, '-', i );
    p2[i] = 0;
    formatex( Msg, 127, "[%s%L%s]", p1, LANG_SERVER, "PUG_HALFSTART_SCRL", p2 );
    ServerSay( Msg );
    count = ( count + 1 ) % width;
    
    return;
}

/*
    This function lets the match enters First Half.
    This function uses the Director HUD message to show prompt message.
    
    HUD params:
        ├ CHANNEL:    DIRECTOR HUD
        ├ POSITION:   HUD_POS_MATCHNOT[]
        └ COLOR:      #FF0000 (red)
    
    @param  none
    @return none
*/
public EnterFirstHalf()
{
    g_StatusNow = STATUS_F_HALF;
    
    g_Score[0][0] = g_Score[0][1] = g_Score[1][0] = g_Score[1][1] = 0;
    ServerSay( "%L", LANG_SERVER, "PUG_FHSTART_MSG" );
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_FHSTART_MSG" );

    set_task( 5.0, "R3Function", 1 + OFFSET_R3 );
    
    return;
}

/*
    This function lets the match enters Intermission. If the CVAR "hp_intermission"
    is "1" then function will reactivate autostart procedures, otherwise it will
    make the match enters Second Half directly. The function will also swap team
    automatically.
    This function uses the Director HUD message to show prompt message.
    
    HUD params:
        ├ CHANNEL:    DIRECTOR HUD
        ├ POSITION:   HUD_POS_MATCHNOT[]
        └ COLOR:      #FF0000 (red)
    
    @param  none
    @return none
*/
EnterIntermission()
{
    ServerSay( "%L", LANG_SERVER, "PUG_FHEND_MSG" , g_Score[0][0], g_Score[1][0] );
    ServerSay( "%L", LANG_SERVER, "PUG_DONTCHANGETEAM" );
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 3.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_FHEND_HUD", g_Score[0][0], g_Score[1][0] );
    set_task( 2.0, "SwapTeam" );
    
    switch( get_pcvar_num( g_pcIntermission ) ) {
        case 0: set_task( 3.0, "EnterSecondHalf" );
        case 1: {
            InitPlayerInfo();
            if( !task_exists( TASKID_SHOWREADY, 0 ) )
                set_task( HUD_INT_RDYLIST, "ShowReadyList", TASKID_SHOWREADY, { 0 }, 1, "b" );
            g_StatusNow = STATUS_INTER;
        }
    }
    
    return;
}

/*
    This function lets the match enters Second Half.
    This function uses the Director HUD message to show prompt message.
    
    HUD params:
        ├ CHANNEL:    DIRECTOR HUD
        ├ POSITION:   HUD_POS_MATCHNOT[]
        └ COLOR:      #FF0000 (red)
    
    @param  none
    @return none
*/
public EnterSecondHalf()
{
    g_Score[0][1] = g_Score[1][1] = 0;
    g_StatusNow = STATUS_S_HALF;
    ServerSay( "%L", LANG_SERVER, "PUG_SHSTART_MSG" );
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_SHSTART_MSG" );
    
    set_task( 5.0, "R3Function", 1 + OFFSET_R3 );
    
    return;
}

/*
    This function will be called when 1 team has won maxround+1 rounds.
    This function uses the Director HUD message to show prompt message.
    
    HUD params:
        ├ CHANNEL:    DIRECTOR HUD
        ├ POSITION:   HUD_POS_MATCHNOT[]
        └ COLOR:      #FF0000 (red)
    
    @param  team        :   team ID of winner's team
    @return none
*/
MatchWin( CsTeams: team )
{
    static teamname[16];
    
    switch( team ) {
        case CS_TEAM_T: formatex( teamname, 15, "%L", LANG_SERVER, "PUG_TNAME" );
        case CS_TEAM_CT: formatex( teamname, 15, "%L", LANG_SERVER, "PUG_CTNAME" );
    }
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_MATCHEND_HUD", g_Score[0][0] + g_Score[0][1], g_Score[1][0] + g_Score[1][1], teamname );
    ServerSay( "%L", LANG_SERVER, "PUG_MATCHEND_MSG", g_Score[0][0] + g_Score[0][1], g_Score[1][0] + g_Score[1][1] );
    
    set_task( 5.0, "EnterWarm" );
    
    return;
}

/*
    This function will be called when both team has won maxround rounds.
    This function uses the Director HUD message to show prompt message.
    
    HUD params:
        ├ CHANNEL:    DIRECTOR HUD
        ├ POSITION:   HUD_POS_MATCHNOT[]
        └ COLOR:      #FF0000 (red)
    
    @param  none
    @return none
*/
MatchDraw()
{
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_MATCHDRAW_HUD", g_MaxRound, g_MaxRound );
    ServerSay( "%L", LANG_SERVER, "PUG_MATCHDRAW_MSG", g_MaxRound, g_MaxRound );
    
    set_task( 5.0, "EnterWarm" );
    
    return;
}

/*
    This function updates the score for both teams and is called under the event
    "TeamScore". After updated the score, it will also judge if the current half
    fulfills the end condition.
    
    @param  team        :   team ID of scored team
    @param  score       :   score of corresponding team
    @return bool        :   if team has scored in last round
*/
bool: UpdateScore( CsTeams: team, score )
{
    new tid = _:( team ) - 1;
    new bool: bIfScored = false;
    
    switch( g_StatusNow ) {
        case STATUS_F_HALF:
            if( score > g_scorebuff[tid] ) {
                bIfScored = true;
                g_Score[tid][0]++;
                if( g_Score[0][0] + g_Score[1][0] == g_MaxRound ) 
                    EnterIntermission();
            }
        case STATUS_S_HALF:
            if( score > g_scorebuff[tid] ) {
                bIfScored = true;
                g_Score[tid][1]++;
                if( g_Score[tid][0] + g_Score[tid][1] == g_MaxRound + 1 ) 
                    MatchWin( team );                
                if( g_Score[0][0] + g_Score[0][1] == g_MaxRound && 
                    g_Score[1][0] + g_Score[1][1] == g_MaxRound ) 
                    MatchDraw();
            }
    }
    g_scorebuff[tid] = score;
    
    return bIfScored;
}

/*
    This function hooks the message "TeamScore" and put the correct team score
    onto the TAB scoreboard. It also update the score in match.
    
    g_msgidTeamScore = get_user_msgid( "TeamScore" )
    register_message( g_msgidTeamScore, "msgTeamScore" )
    
    @param  none
    @return none
*/ 
public msgTeamScore( msgid, idest, id )
{
    if( idest != MSG_ALL || !StatMatch() ) return PLUGIN_CONTINUE;
    
    static teamname[2], score, buff, tindex, CsTeams: team;
    new bool: bIfScored = false;
    
    get_msg_arg_string( 1, teamname, 2 );
    score = get_msg_arg_int( 2 );
    tindex = _:( teamname[0] == 'C' );
    team = CsTeams:( tindex + 1 );
    switch( g_StatusNow ) {
        case STATUS_KNIFE: 
            if( score > 0 ) {
                new Float: time = get_gametime();
                if( time - g_GameTime > 3.0 ) {
                    KnifeRoundWon( team );
                    buff = g_Score[tindex][0];
                }
            }
        case STATUS_F_HALF: {
            bIfScored = UpdateScore( team, score );
            buff = g_Score[tindex][0];
        }
        case STATUS_S_HALF: {
            bIfScored = UpdateScore( team, score );
            buff = g_Score[tindex][1];
        }
        default: buff = g_Score[tindex][0];
    }
    set_msg_arg_int( 2, ARG_SHORT, buff );
    if( bIfScored ) RefreshHUDScore();
    
    return PLUGIN_CONTINUE;
}

/*
    This function hooks the event "HLTV" in order to hook round start.
    Functions need to be called at round start is called here.
    
    register_event( "HLTV", "eventNewRoundStart", "a", "1=0", "2=0" )
    
    @param  none
    @return none
*/ 
public eventNewRoundStart()
{
    // update game time at every round start
    g_GameTime = get_gametime();
    // update round num
    if( StatLive() ) UpdateRoundNum();
    // Show Team Money at round start
    if( StatLive() && get_pcvar_num( g_pcShowMoney ) == 1 ) 
        set_task( 0.1, "ShowTeamMoney" );
    
    return;
}

/*
    This function updates the match round progress number. This will be called
    at every round start when match is on live.
    
    @param  none
    @return none
*/ 
UpdateRoundNum()
{
    switch( g_StatusNow ) {
        case STATUS_F_HALF, STATUS_S_HALF: 
            g_RoundNum = g_Score[0][0] + g_Score[0][1] + g_Score[1][0] + g_Score[1][1] + 1;
        case STATUS_INTER: 
            g_RoundNum = g_Score[0][0] + g_Score[0][1] + g_Score[1][0] + g_Score[1][1];
        default: 
            g_RoundNum = 0;
    }
    RefreshHUDScore();
    
    return;
}

//==============================================================================
//  ┌──────────────────────────┐
//  │  MENU RELATED FUNCTIONS  │
//  └──────────────────────────┘
//      ┌ MenuBuildShowPickTeam
//      ├ MenuSetPickTeam ←
//      │   └ MenuShowPickTeam ←
//      │       └ MenuJudgePickTeamVote ←
//      │           └ EnterFirstHalf
//      └ MenucmdPickTeam ←
//      ┌ MenuShowSwapMenu ←
//      ├ SwapCenterCountDown ←
//      └ MenucmdSwapMenu ←
//          └┌ MenuSetSwapAsk ←
//           │   └ MenuShowSwapAsk ←
//           │       └ MenuJudgeSwapAsk ←
//           └ MenucmdSwapAsk ←
//      ┌ MenuBuildMatchMenu ←
//      ├ MenuShowMatchMenu ←
//      └ MenucmdMatchMenu ←
//      ┌ MenuShowVoteMap ←
//      │   └ MenuShowVoteMap ←
//      │       └ MenuJudgeVoteMap ←
//      │           └ DelayChangelevel ←
//      └ MenucmdVoteMap ←
//          └ MenuJudgeVoteMap ←
//      ┌ MenuShowVoteKick ←
//      └ MenucmdVoteKick ←
//          └┌ MenuSetAskKick ←
//           │   └ MenuShowAskKick ←
//           │       └ MenuJudgeAskKick ←  
//           └ MenucmdAskKick ←
//               └ MenuJudgeAskKick ←  
//==============================================================================

/*
    These bunch of functions aims to proceed with a menu that shows after knife
    round to let the winner's team to pick the team they want. The pre-
    build function is called in plugin_cfg()
    
    Construct func      :   MenuConstructShowPickTeam
    Show Menu func      :   MenuShowPickTeam
    Menu Select func    :   MenucmdPickTeam
    Result func:        :   MenuJudgePickTeamVote
*/ 
MenuBuildPickTeam()
{
    new len = formatex( g_szMenuPickTeam, 255, "\y%L^n^n", LANG_SERVER, "PUG_MENU_PICKTEAMTITLE" );
    len += formatex( g_szMenuPickTeam[len], 255 - len, "\r1.  \w%L^n", LANG_SERVER, "PUG_MENU_PICKTEAMOP1" );
    len += formatex( g_szMenuPickTeam[len], 255 - len, "\r2.  \w%L^n^n", LANG_SERVER, "PUG_MENU_PICKTEAMOP2" );
    len += formatex( g_szMenuPickTeam[len], 255 - len, "%L \r", LANG_SERVER, "PUG_MENU_COUNTDOWNPROMPT" );
    
    return;
}

MenuSetPickTeam( CsTeams: team )
{
    const T_SHOWPICKTEAM = 10;
    static id, i, tid;
    
    g_bIsOnVote = true;     // set voting on flag
    remove_task( g_tskidOnVote, 0 );
    for( i = 0; i < MAX_PLAYERS; i++ ) {
        tid = i + 1;
        if( ( id = g_SwapBeRQ[tid] ) != 0 && g_teamHash[tid] == team ) {
            g_SwapBeRQ[tid] = g_SwapRequest[id] = 0;
            remove_task( tid + OFFSET_COUNT_MENU_SWAPASK, 0 );
        }
    }
    g_tskidOnVote = _:( team ) + OFFSET_COUNT_MENU_PICKTEAM;
    arrayset( g_bTeamPicked, false, sizeof( g_bTeamPicked ) );
    g_mPickTeamAgree = g_countPickTeam = 0;
    g_countdownPickTeam = T_SHOWPICKTEAM + 1;
    MenuShowPickTeam( _:( team ) + OFFSET_COUNT_MENU_PICKTEAM );
    set_task( 1.0, "MenuShowPickTeam", g_tskidOnVote, _, _, "a", T_SHOWPICKTEAM );
    
    return;
}

public MenuShowPickTeam( tskid )
{
    new CsTeams: team = CsTeams:( tskid - OFFSET_COUNT_MENU_PICKTEAM );
    static msg[256], i, id;
    
    if( --g_countdownPickTeam > 0 ) {
        formatex( msg, 255, "%s %d", g_szMenuPickTeam, g_countdownPickTeam );
        for( i = 0; i < MAX_PLAYERS; i++ ) {
            id = i + 1;
            if( !is_user_connected( id ) || g_bTeamPicked[id] || 
                g_teamHash[id] != team ) 
                continue;

            show_menu( id, 3, msg, 1, "#PUG_Menu_WinKnifeRound" );
        }
    }
    else
        MenuJudgePickTeamVote();
   
    return;
}

public MenucmdPickTeam( id, key )
{
    static name[32], Msg[128], pnum;
    
    get_user_name( id, name, 31 );
    g_bTeamPicked[id] = true;
    g_countPickTeam++;
    if( key == 0 ) {
        g_mPickTeamAgree++;
        formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PICKTEAMOP1RES", name );
    }
    else
        formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PICKTEAMOP2RES", name );
    ServerSay( Msg );
    if( g_teamHash[id] == CS_TEAM_T ) pnum = g_Tnum; else pnum = g_Cnum;
    
    if( g_countPickTeam >= pnum ) {
        remove_task( g_tskidOnVote, 0 );
        MenuJudgePickTeamVote();
    }
    
    return;
}

MenuJudgePickTeamVote()
{
    if( g_mPickTeamAgree > 2 ) {
        ServerSay( "%L", LANG_SERVER, "PUG_VOTESWAP" );
        SwapTeam();
    }
    else
        ServerSay( "%L", LANG_SERVER, "PUG_VOTENOTSWAP" );
        
    g_bIsOnVote = false; // remove vote on flag
    set_task( 1.0, "EnterFirstHalf" );
    
    return;
}

/*
    These bunch of functions aims to show a swap request menu to let player
    send a request to other player to swap their teams. After select the player
    wants to swap with, another SWAPASK menu will show to the player being selected.
    
    Show Menu func      :   MenuShowSwapMenu, MenuShowSwapAsk
    Menu Select func    :   MenucmdSwapMenu, MenucmdSwapAsk
    Result func         :   MenuJudgeSwapAsk
    
    The following 2 functions is to block the original menu
    Others              :   HookTeamMenu, HookVGuiTeamMenu
*/ 
public SwapCenterCountDown( tskid )
{
    new id = tskid - OFFSET_COUNT;
    
    if( --g_countdownSwapMenu[id] > 0 )
        client_print( id, print_center, "%L %L", LANG_SERVER, "PUG_CANTTEAMSELECT", LANG_SERVER, "PUG_WILLOPENSWAPMENU", g_countdownSwapMenu[id] );
    else
        client_print( id, print_center, "" );
        
    return;
}

MenuShowSwapMenu( id )
{
    new CsTeams: team = g_teamHash[id];
    new i, tid, hSwapMenu;
    static szMenuTitle[64], name[32], szid[3], Msg[128];
    
    if( g_SwapRequest[id] != 0 ) {
        client_print( id, print_chat, "%L", LANG_SERVER, "PUG_MENU_ALRDYRQSWAP" );
        return;
    }
    
    formatex( szMenuTitle, 63, "\y%L", LANG_SERVER, "PUG_MENU_SWAPTITLE" );
    hSwapMenu = menu_create( szMenuTitle, "MenucmdSwapMenu" );
    for( i = 0; i < MAX_PLAYERS; i++ ) {
        tid = i + 1;
        if( !is_user_connected( tid ) ) continue;
        if( tid == id || g_teamHash[tid] == team || g_teamHash[tid] == CS_TEAM_UNASSIGNED )
            continue;
            
        get_user_name( tid, name, 31 );
        switch( g_teamHash[tid] ) {
            case CS_TEAM_T:
                formatex( Msg, 127, "(%L) %s", LANG_SERVER, "PUG_TNAME", name );
            case CS_TEAM_CT:
                formatex( Msg, 127, "(%L) %s", LANG_SERVER, "PUG_CTNAME", name );
            case CS_TEAM_SPECTATOR:
                formatex( Msg, 127, "(%L) %s", LANG_SERVER, "PUG_SPECNAME", name );
        }
        formatex( szid, 2, "%d", tid );
        menu_additem( hSwapMenu, Msg, szid, ADMIN_ALL );
    }
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_EXITNAME" );
    menu_setprop( hSwapMenu, MPROP_EXITNAME, Msg );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_NEXTPAGE" );
    menu_setprop( hSwapMenu, MPROP_NEXTNAME, Msg );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PREVPAGE" );
    menu_setprop( hSwapMenu, MPROP_BACKNAME, Msg );
    show_menu( id, 0, "^n", 1 );
    menu_display( id, hSwapMenu, 0 );
    
    return;
}

public MenucmdSwapMenu( id, menu, item )
{
    static szBuffer[8], tid, szName[8], _access, _callback;
    
    menu_item_getinfo( menu, item, _access, szBuffer, 7, szName, 7, _callback );
    menu_destroy( menu );
    tid = str_to_num( szBuffer );
    
    if( item == MENU_EXIT ) return;
    
    if( g_SwapBeRQ[tid] != 0 ) {
        client_print( id, print_chat, "%L", LANG_SERVER, "PUG_MENU_SWAPCHOICEINVALID" );
        return;
    }
    
    g_SwapRequest[id] = tid;
    g_SwapBeRQ[tid] = id;
    
    MenuSetSwapAsk( tid );
    
    return;
}
//--------------------------------------------------------------------
MenuSetSwapAsk( tid )
{
    static const   T_SWAPASK   =   10;
    static szMenu[256], len, name1[32], name2[32], tn[16];
    new id = g_SwapBeRQ[tid], CsTeams: team = g_teamHash[id];
    
    get_user_name( id, name1, 31 );
    get_user_name( tid, name2, 31 );
    switch( team ) {
        case CS_TEAM_T: formatex( tn, 15, "%L", LANG_SERVER, "PUG_TNAME" );
        case CS_TEAM_CT: formatex( tn, 15, "%L", LANG_SERVER, "PUG_CTNAME" );
    }
    ServerSay( "%L", LANG_SERVER, "PUG_MENU_SWAPRQMSG", name1, name2 );
    len = formatex( szMenu, 255, "\y%L^n^n", LANG_SERVER, "PUG_MENU_SWAPASKTITLE", tn, name1 );
    len += formatex( szMenu[len], 255 - len, "\r1.  \w%L^n", LANG_SERVER, "PUG_MENU_AGREESWAP" );
    len += formatex( szMenu[len], 255 - len, "\r2.  \w%L^n^n", LANG_SERVER, "PUG_MENU_REJSWAP" );
    len += formatex( szMenu[len], 255 - len, "%L \r", LANG_SERVER, "PUG_MENU_COUNTDOWNPROMPT" );
    
    g_countdownSwapAsk[tid] = T_SWAPASK + 1;
    MenuShowSwapAsk( szMenu, tid + OFFSET_COUNT_MENU_SWAPASK );
    set_task( 1.0, "MenuShowSwapAsk", tid + OFFSET_COUNT_MENU_SWAPASK, szMenu, sizeof( szMenu ), "a", T_SWAPASK );
    
    return;
}

public MenuShowSwapAsk( const szMenu[], tskid )
{
    static msg[256];
    new id = tskid - OFFSET_COUNT_MENU_SWAPASK;
    
    if( --g_countdownSwapAsk[id] > 0 ) {
        formatex( msg, 255, "%s %d", szMenu, g_countdownSwapAsk[id] );
        show_menu( id, 3, msg, 1, "#PUG_Menu_IfAgreeToSwap" );
    }
    else
        MenuJudgeSwapAsk( id );
    
    return;
}

public MenucmdSwapAsk( id, key )
{
    switch( key ) {
        case 0: g_SwapJudge[id] = true;
        case 1: g_SwapJudge[id] = false;
    }
    remove_task( id + OFFSET_COUNT_MENU_SWAPASK, 0 );
    MenuJudgeSwapAsk( id );
    
    return;
}

MenuJudgeSwapAsk( tid )
{
    new id = g_SwapBeRQ[tid];
    new CsTeams: team1 = g_teamHash[id];
    new CsTeams: team2 = g_teamHash[tid];
    static tn[2], name1[32], name2[32];
    
    tn[1] = 0;
    if( team1 == CS_TEAM_T ) tn[0] = '1'; else tn[0] = '2';
    
    if( g_SwapJudge[tid] ) {
        if( team2 == CS_TEAM_SPECTATOR ) {
            set_msg_block( g_msgidClCorpse, BLOCK_ONCE );
            user_kill( id );
            cs_set_user_team( id, team2, CS_DONTCHANGE );
            PutPlayer( id, team1, team2 );
            client_cmd( tid, "jointeam ^"%s^"", tn );
        }
        else {
            cs_set_user_team( tid, team1, CS_DONTCHANGE );
            cs_set_user_team( id, team2, CS_DONTCHANGE );
            PutPlayer( id, team1, team2 );
            PutPlayer( tid, team2, team1 );
        }
        
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_MENU_SWAPAGREED" );
        client_print( tid, print_center, "%L", LANG_SERVER, "PUG_MENU_SWAPAGREE" );
        get_user_name( id, name1, 31 );
        get_user_name( tid, name2, 31 );
        set_dhudmessage( 0x00, 0xff, 0xff, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
        show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_MENU_SWAPFINISH", name1, name2 );
    }
    else {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_MENU_REJSWAP" );
        client_print( tid, print_center, "%L", LANG_SERVER, "PUG_MENU_REJSWAP" );
    }
    
    // remove RQ flags for both players
    g_SwapRequest[id] = g_SwapBeRQ[tid] = 0;
    g_SwapJudge[tid] = false;
    
    return;
}

/*
    These bunch of functions aims to show a menu that has match administrative
    menu to the administrators.
    
    Show Menu func      :   MenuShowMatchMenu
    Menu Select func    :   MenucmdMatchMenu
    Result func         :   N/A
*/
MenuBuildMatchMenu()
{
    new msg[128], tag[2];
    
    formatex( msg, 127, "\y%L", LANG_SERVER, "PUG_MENU_MATCHTITLE" );
    g_hmMatchMenu = menu_create( msg, "MenucmdMatchMenu" );
    tag[1] = 0; tag[0] = 0x30;
    formatex( msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHSTARTKNIFE" ); tag[0]++;
    menu_additem( g_hmMatchMenu, msg, tag, PLUGIN_ACCESS );
    formatex( msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHSTARTNOKNIFE" ); tag[0]++;
    menu_additem( g_hmMatchMenu, msg, tag, PLUGIN_ACCESS );
    formatex( msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHHALFR3" ); tag[0]++;
    menu_additem( g_hmMatchMenu, msg, tag, PLUGIN_ACCESS );
    formatex( msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHRER3" ); tag[0]++;
    menu_additem( g_hmMatchMenu, msg, tag, PLUGIN_ACCESS );
    formatex( msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHSTOP" ); tag[0]++;
    menu_additem( g_hmMatchMenu, msg, tag, PLUGIN_ACCESS );
    formatex( msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHPAUSE" ); tag[0]++;
    menu_additem( g_hmMatchMenu, msg, tag, PLUGIN_ACCESS );
    formatex( msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHSWAPTEAM" ); tag[0]++;
    menu_additem( g_hmMatchMenu, msg, tag, PLUGIN_ACCESS );
    formatex( msg, 127, "%L", LANG_SERVER, "PUG_MENU_EXITNAME" );
    menu_setprop( g_hmMatchMenu, MPROP_EXITNAME, msg );
    
    return;
}

public MenuShowMatchMenu( id, level, cid )
{
    if( !cmd_access( id, level, cid, 1 ) ) return PLUGIN_HANDLED;

    show_menu( id, 0, "^n", 1 );
    menu_display( id, g_hmMatchMenu );
    
    return PLUGIN_HANDLED;
}

public MenucmdMatchMenu( id, menu, item )
{       
    static info[2], name[2], _access, _callback, key;
    
    if( item == MENU_EXIT ) return;
    menu_item_getinfo( menu, item, _access, info, 1, name, 1, _callback );
    key = str_to_num( info );
    switch( key ) {
        case 1: client_cmd( id, "hp_forcestart -knife" );
        case 2: client_cmd( id, "hp_forcestart -noknife" );
        case 3: client_cmd( id, "hp_forcehalfr3" );
        case 4: client_cmd( id, "hp_forcerer3" );
        case 5: client_cmd( id, "hp_forcestop" );
        case 6: client_cmd( id, "amx_pause" );
        case 7: client_cmd( id, "hp_forceswap" );
    }
    
    return;
}

/*
    These bunch of functions aims to begin a map vote among all players.
    
    Show Menu func      :   MenuShowVoteMap
    Menu Select func    :   MenucmdVoteMap
    Result func         :   MenuJudgeVoteMap
*/
public MenuSetVoteMap( id )
{
    if( g_bIsOnVote ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_MENU_ALRDYVOTE" );
        return PLUGIN_HANDLED;
    }
    if( StatLive() ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTUSECMD" );
        return PLUGIN_HANDLED;
    }
    
    const T_VOTEMAP = 8;
    static Msg[512], len, mapname[32], nowmap[32];
    new smap = MAP_VOTE_NUM, i, j, k, bool: MapChosen[32], key;
    
    // set OnVote flag
    g_bIsOnVote = true;
    key |= MENU_KEY_0;
    
    get_mapname( nowmap, 31 );
    if( smap > g_Mapnum - 1 ) smap = g_Mapnum - 1;
    k = smap;
    for( i = 0; i < g_Mapnum; i++ ) {
        ArrayGetString( g_Maps, i, mapname, 31 );
        if( equal( mapname, nowmap ) ) {
            MapChosen[i] = true;
            g_VoteMapid[0] = i;
            break;
        }
    }
    
    g_bIsOnVote = true;
    len = formatex( Msg, 511, "\y%L^n^n", LANG_SERVER, "PUG_MENU_VOTEMAPTITLE" );
    while( k > 0 ) {
        j = random( g_Mapnum );
        while( MapChosen[j] ) j = random( g_Mapnum );
        MapChosen[j] = true;
        ArrayGetString( g_Maps, j, mapname, 31 );
        len += formatex( Msg[len], 511 - len, "\r%d.  \w%s^n", smap - k + 1, mapname );
        g_VoteMapid[smap - k + 1] = j;
        key |= 1 << ( smap - k );
        k--;
    }
    arrayset( g_VoteMapCount, 0, sizeof( g_VoteMapCount ) );
    arrayset( g_bMapVoted, false, sizeof( g_bMapVoted ) );
    g_tskidOnVote = key + OFFSET_COUNT_MENU_VOTEMAP;
    g_countVoteMap = 0;
    len += formatex( Msg[len], 511 - len, "^n\r0.  \w%L", LANG_SERVER, "PUG_MENU_EXTENDCURMAP" );
    len += formatex( Msg[len], 511 - len, "^n^n%L\r", LANG_SERVER, "PUG_MENU_COUNTDOWNPROMPT" );
    
    g_countdownVoteMap = T_VOTEMAP + 1;
    MenuShowVoteMap( Msg, g_tskidOnVote );
    set_task( 1.0, "MenuShowVoteMap", g_tskidOnVote, Msg, sizeof( Msg ), "a", T_VOTEMAP );
    
    return PLUGIN_HANDLED;
}

public MenuShowVoteMap( const szt[], tskid )
{
    new keys = tskid - OFFSET_COUNT_MENU_VOTEMAP;
    static id, szMenu[512];

    if( --g_countdownVoteMap > 0 ) {
        formatex( szMenu, 511, "%s %d", szt, g_countdownVoteMap );
        for( new i = 0; i < MAX_PLAYERS; i++ ) {
            id = i + 1;
            if( g_teamHash[id] != CS_TEAM_UNASSIGNED && !g_bMapVoted[id] ) {
                show_menu( id, keys, szMenu, 1, "#PUG_Menu_VoteMap" );
            }
        }
    }
    else
        MenuJudgeVoteMap();
    
    return;
}

public MenucmdVoteMap( id, key )
{
    static mapname[32];
    new index = ( key + 1 ) % 10;
    new pos = g_VoteMapid[index];
    
    ArrayGetString( g_Maps, pos, mapname, 31 );
    g_VoteMapCount[index]++;
    g_bMapVoted[id] = true;
    ServerSay( "%L", LANG_SERVER, "PUG_MENU_VOTEDMSG", g_name[id], mapname );
    if( ++g_countVoteMap > get_playersnum( 0 ) ) {
        remove_task( g_tskidOnVote, 0 );
        MenuJudgeVoteMap();
    }
    
    return;
}

public MenuJudgeVoteMap()
{
    new i, j, mapname[32], maxv = 0, pos;
    
    for( i = 0; i <= MAP_VOTE_NUM; i++ )
        if( g_VoteMapCount[i] > maxv ) {
            maxv = g_VoteMapCount[i];
            pos = g_VoteMapid[i];
            j = i;
        }
    g_bIsOnVote = false;
    
    if( maxv == 0 ) {
        ServerSay( "%L", LANG_SERVER, "PUG_MENU_INVALIDVOTE" );
        return;
    }
    
    if( j != 0 ) {
        ArrayGetString( g_Maps, pos, mapname, 31 );
        set_task( 3.0, "DelayChangelevel", _, mapname, 31 );
    }
    else
        formatex( mapname, 31, "%L", LANG_SERVER, "PUG_MENU_EXTENDCURMAP" );
    ServerSay( "%L", LANG_SERVER, "PUG_MENU_VOTEMAPRES", mapname );        
    
    return;
}

public DelayChangelevel( const mapname[] )
{
    server_cmd( "amx_map ^"%s^"", mapname );
    
    return;
}

/*
    These bunch of functions aims to begin a kick vote for specific player
    among all players.
    
    Show Menu func      :   MenuShowVoteKick
    Menu Select func    :   MenucmdVoteKick, MenucmdAskKick
    Result func         :   MenuJudgeAskKick
*/ 
public MenuShowVoteKick( tid )
{
    if( g_bIsOnVote ) {
        client_print( tid, print_center, "%L", LANG_SERVER, "PUG_MENU_ALRDYVOTE" );
        return PLUGIN_HANDLED;
    }
    
    static Msg[128], teamname[32], name[32], szid[3];
    new hMenu, i, id, CsTeams: team;

    formatex( Msg, 127, "\y%L", LANG_SERVER, "PUG_MENU_VOTEKICKTITLE" );
    hMenu = menu_create( Msg, "MenucmdVoteKick" );
    for( i = 0; i < MAX_PLAYERS; i++ ) {
        id = i + 1;
        if( !is_user_connected( id ) ) continue;
        team = g_teamHash[id];
        switch( team ) {
            case CS_TEAM_T: formatex( teamname, 31, "%L", LANG_SERVER, "PUG_TNAME" );
            case CS_TEAM_CT: formatex( teamname, 31, "%L", LANG_SERVER, "PUG_CTNAME" );
            case CS_TEAM_SPECTATOR: formatex( teamname, 31, "%L", LANG_SERVER, "PUG_SPECNAME" );
        }
        get_user_name( id, name, 31 );
        formatex( Msg, 127, "(%s) %s", teamname, name );
        formatex( szid, 2, "%d", id );
        if( access( id, ADMIN_IMMUNITY ) ) {
            strcat( Msg, "\r*", 127 );         
            menu_additem( hMenu, Msg, szid, ADMIN_KICK );
        }
        else
            menu_additem( hMenu, Msg, szid, ADMIN_ALL );
    }
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_EXITNAME" );
    menu_setprop( hMenu, MPROP_EXITNAME, Msg );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_NEXTPAGE" );
    menu_setprop( hMenu, MPROP_NEXTNAME, Msg );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PREVPAGE" );
    menu_setprop( hMenu, MPROP_BACKNAME, Msg );
    show_menu( tid, 0, "^n", 1 );
    menu_display( tid, hMenu, 0 );
    
    return PLUGIN_HANDLED;
}

public MenucmdVoteKick( id, menu, item )
{
    static _access, item_callback, voted[32], kicker[32], tid;
    
    menu_item_getinfo( menu, item, _access, voted, 31, kicker, 31, item_callback );
    menu_destroy( menu );
    tid = str_to_num( voted );
    
    if( item == MENU_EXIT ) return;
        
    MenuSetAskKick( id, tid );
    
    return;
}
//--------------------------------------------------------------------
MenuSetAskKick( kicker, kickid )
{
    if( g_bIsOnVote ) {
        client_print( kicker, print_center, "%L", LANG_SERVER, "PUG_MENU_ALRDYVOTE" );
        return;
    }
    
    const T_VOTEKICK = 10;
    static teamname[32], szMenu[256], len, CsTeams: team;
    
    g_bIsOnVote = true;
    g_tskidOnVote = kicker + OFFSET_COUNT_MENU_VOTEKICK;
    g_kickid = kickid;
    g_kickagree = g_countVoteKick = 0;
    arrayset( g_bKickVoted, false, sizeof( g_bKickVoted ) );
    team = g_teamHash[kickid];
    switch( team ) {
        case CS_TEAM_T: formatex( teamname, 31, "%L", LANG_SERVER, "PUG_TNAME" );
        case CS_TEAM_CT: formatex( teamname, 31, "%L", LANG_SERVER, "PUG_CTNAME" );
        case CS_TEAM_SPECTATOR: formatex( teamname, 31, "%L", LANG_SERVER, "PUG_SPECNAME" );
    }
    len = formatex( szMenu, 255, "\y%L^n^n", LANG_SERVER, "PUG_MENU_KICKASKTITLE", g_name[kicker], teamname, g_name[kickid] );
    len += formatex( szMenu[len], 255 - len, "\r1.  \w%L^n", LANG_SERVER, "PUG_MENU_KICKAGREE" );
    len += formatex( szMenu[len], 255 - len, "\r2.  \w%L", LANG_SERVER, "PUG_MENU_KICKREJ" );
    len += formatex( szMenu[len], 255 - len, "^n^n%L\r", LANG_SERVER, "PUG_MENU_COUNTDOWNPROMPT" );
    
    g_countdownVoteKick = T_VOTEKICK + 1;
    MenuShowAskKick( szMenu, g_tskidOnVote );
    set_task( 1.0, "MenuShowAskKick", g_tskidOnVote, szMenu, sizeof( szMenu ), "a", T_VOTEKICK );

    return;    
}

public MenuShowAskKick( const szt[], tskid )
{
    static szMenu[256], id, i;
    
    if( --g_countdownVoteKick > 0 ) {
        formatex( szMenu, 255, "%s %d", szt, g_countdownVoteKick );
        for( i = 0; i < MAX_PLAYERS; i++ ) {
            id = i + 1;
            if( g_teamHash[id] != CS_TEAM_UNASSIGNED && !g_bKickVoted[id] )
                show_menu( id, 3, szMenu, 1, "#PUG_Menu_VoteKick" );
        }
    }
    else
        MenuJudgeAskKick();
        
    return;
}

public MenucmdAskKick( id, key )
{
    if( key == 0 ) {
        g_kickagree++;
        client_print( 0, print_chat, "%L", LANG_SERVER, "PUG_MENU_AGREEKICKMSG", g_name[id] );
    }
    else
        client_print( 0, print_chat, "%L", LANG_SERVER, "PUG_MENU_REJKICKMSG", g_name[id] );
    g_bKickVoted[id] = true;
    if( ++g_countVoteKick >= get_playersnum( 0 ) ) {
        remove_task( g_tskidOnVote, 0 );
        MenuJudgeAskKick();
    }
        
    return;
}

MenuJudgeAskKick()
{
    new tot = get_playersnum( 0 );
    new Float: ratio = float( g_kickagree ) / float( tot );

    if( ratio >= 0.5 ) {
        ServerSay( "%L", LANG_SERVER, "PUG_MENU_KICKRESAGREE", ratio * 100.0 );
        server_cmd( "kick ^"%s^"", g_name[g_kickid] );
    }
    else
        ServerSay( "%L", LANG_SERVER, "PUG_MENU_KICKRESREJ", ratio * 100.0 );
    g_bIsOnVote = false;
    
    return;
}

/*
    These bunch of functions aims to show a menu for all players.
    
    Show Menu func      :   MenuShowPlayerMenu
    Menu Select func    :   MenucmdPlayerMenu
    Result func         :   N/A
*/ 
MenuBuildPlayerMenu()
{
    static Msg[128], tag[2];
    
    tag[1] = 0; tag[0] = 0x30;
    
    formatex( Msg, 127, "\y%L", LANG_SERVER, "PUG_MENU_PLTITLE" );
    g_hmPlayerMenu = menu_create( Msg, "MenucmdPlayerMenu" );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PLVOTEMAP" ); tag[0]++;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ALL );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PLVOTEKICK" ); tag[0]++;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ALL );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_RESTROUND" ); tag[0]++;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_ITEMMATCH" ); tag[0]++;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHMAP" ); tag[0]++;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHKICK" ); tag[0]++;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHTEAM" ); tag[0]++;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHSLAY" ); tag[0]++;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHBAN" ); tag[0]++;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ADMIN );
    menu_addblank( g_hmPlayerMenu, 0 );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_EXITNAME" ); tag[0] = 0x30;
    menu_additem( g_hmPlayerMenu, Msg, tag, ADMIN_ALL );
    menu_setprop( g_hmPlayerMenu, MPROP_PERPAGE, 0 );
    
    return;
}

public MenuShowPlayerMenu( id )
{
    show_menu( id, 0, "^n", 1 );
    menu_display( id, g_hmPlayerMenu );
    
    return PLUGIN_HANDLED;
}

public MenucmdPlayerMenu( id, menu, item )
{
    static info[2], name[2], _access, _callback, key;  
    
    menu_item_getinfo( menu, item, _access, info, 1, name, 1, _callback );
    key = str_to_num( info );
    
    switch( key ) {
        case 1: MenuSetVoteMap( id );
        case 2: MenuShowVoteKick( id );
        case 3: if( !StatLive() ) server_cmd( "sv_restartround 1" );
        case 4: client_cmd( id, "hp_matchmenu" );
        case 5: client_cmd( id, "amx_mapmenu" );
        case 6: client_cmd( id, "amx_kickmenu" );
        case 7: client_cmd( id, "amx_teammenu" );
        case 8: client_cmd( id, "amx_slapmenu" );
        case 9: client_cmd( id, "amx_banmenu" );
    }
    
    return;
}

//==============================================================================
//  ┌───────────────────────────┐
//  │  ADMINS' FORCE FUNCTIONS  │
//  └───────────────────────────┘
//      → ForceStart
//          └ AutoStart
//      → ForceReR3
//      → ForceHalfR3
//      → ForceStop
//      → ForceSwap
//==============================================================================

public ForceStart( id, level, cid )
{
    if( !cmd_access( id, level, cid, 1 ) ) return PLUGIN_HANDLED;
        
    static Msg[128], act, argv[16];
    new ifknife = -1;
    new argc = read_argc();
    
    if( argc == 2 ) {
        read_argv( 1, argv, 15 );
        if( equal( argv, "-knife" ) ) ifknife = 1;
        if( equal( argv, "-noknife" ) ) ifknife = 0;
    }
    
    if( StatLive() )
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_MATCHINLIVE" );
    else {
        act = get_pcvar_num( g_pcAmxShowAct );
        switch( act ) {
            case 1:
                formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCESTART1" );
            case 2: 
                formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCESTART2", g_name[id] );
        }
        ServerSay( Msg );
        set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_ACT[0], HUD_POS_ACT[1], 0, 0.0, 5.0, 0.1, 0.1 );
        show_dhudmessage( 0, Msg );
        
        AutoStart( true, ifknife );
    }
        
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public ForceReR3( id, level, cid )
{
    if( !cmd_access( id, level, cid, 1 ) ) return PLUGIN_HANDLED;
        
    static act, Msg[128];
    
    if( !StatLive() ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_MATCHNOTLIVE" );
        return PLUGIN_HANDLED;
    }
    if( g_StatusNow == STATUS_KNIFE ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTUSECMD" );
        return PLUGIN_HANDLED;
    }
    
    act = get_pcvar_num( g_pcAmxShowAct );
    switch( act ) {
        case 1:
            formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCERER31" );
        case 2:
            formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCERER32", g_name[id] );
    }
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_ACT[0], HUD_POS_ACT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, Msg );
    ServerSay( Msg );
    
    if( g_StatusNow == STATUS_S_HALF ) SwapTeam();
    EnterFirstHalf();
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public ForceHalfR3( id, level, cid )
{
    if( !cmd_access( id, level, cid, 1 ) ) return PLUGIN_HANDLED;
        
    static act, Msg[128];
    
    if( !StatLive() ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_MATCHNOTLIVE" );
        return PLUGIN_HANDLED;
    }
    if( g_StatusNow == STATUS_KNIFE ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTUSECMD" );
        return PLUGIN_HANDLED;
    }
    
    act = get_pcvar_num( g_pcAmxShowAct );
    switch( g_StatusNow ) {
        case STATUS_F_HALF, STATUS_INTER: {
            switch( act ) {
                case 1:
                    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCEFHALFR31" );
                case 2: 
                    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCEFHALFR32", g_name[id] );
            }
            
            if( g_StatusNow == STATUS_INTER ) remove_task( TASKID_SHOWREADY, 0 );
                
            EnterFirstHalf();
        }
        case STATUS_S_HALF: {
            switch( act ) {
                case 1:
                    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCESHALFR31" );
                case 2:
                    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCESHALFR32", g_name[id] );
            }      
            
            EnterSecondHalf();
        }
    }
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_ACT[0], HUD_POS_ACT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, Msg );
    ServerSay( Msg );
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public ForceStop( id, level, cid )
{
    if( !cmd_access( id, level, cid, 1 ) ) return PLUGIN_HANDLED;
        
    static act, Msg[128];
    
    if( !StatLive() ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_MATCHNOTLIVE" );
        return PLUGIN_HANDLED;
    }
    
    act = get_pcvar_num( g_pcAmxShowAct );
    switch( act ) {
        case 1:
            formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCESTOP1" );
        case 2:
            formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCESTOP2", g_name[id] );
    }
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_ACT[0], HUD_POS_ACT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, Msg );
    ServerSay( Msg );
    
    set_task( 3.0, "EnterWarm" );
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public ForceSwap( id, level, cid )
{
    if( !cmd_access( id, level, cid, 1 ) ) return PLUGIN_HANDLED;
    
    new act = get_pcvar_num( g_pcAmxShowAct );
    static Msg[128];

    switch( act ) {
        case 1:
            formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCESWAP1" );
        case 2: 
            formatex( Msg, 127, "%L", LANG_SERVER, "PUG_FORCESWAP2", g_name[id] );
    }
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_ACT[0], HUD_POS_ACT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, Msg );
    ServerSay( Msg );
    
    SwapTeam();
    
    return PLUGIN_HANDLED;
}

//==============================================================================
//  ┌───────────────────────────────────────┐
//  │  SYSTEM PREDEFINED FORWARD FUNCTIONS  │
//  └───────────────────────────────────────┘
//      → client_infochanged
//      → plugin_cfg
//      → plugin_init
//==============================================================================

/*
    This is a default forward function that called when player's info has been
    changed. Here it is used to fix display bug of readylist when player changes
    their names.
    
    @param  id      :   index of player whose info has been changed
    @return none
*/
public client_infochanged( id )
{
    static name[32];
    
    get_user_info( id, "name", name, 31 );
    if( !equal( name, g_name[id] ) ) 
        formatex( g_name[id], 31, "%s", name );
    if( !StatLive() ) RefreshReadyList();
    
    return PLUGIN_CONTINUE;
}

public plugin_cfg()
{
    set_task( 1.0, "CheckHostName" );
    
    LoadSettings();
    readMap();
    
    // pre-build some menus
    MenuBuildPickTeam();
    MenuBuildMatchMenu();
    MenuBuildPlayerMenu();
    
    // initialize all Sync HUD Objs
    g_hsyncReadyList    =   CreateHudSyncObj();
    g_hsyncScoreBoard   =   CreateHudSyncObj();
    g_hsyncNotify       =   CreateHudSyncObj();
    g_hsyncShowMoney    =   CreateHudSyncObj();
    g_hsync5Link        =   CreateHudSyncObj();
     
    EnterWarm();
    
    return;
}

public plugin_init()
{
    register_plugin( PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR );
    
    register_dictionary( "hustcommon.txt" );

    g_pcKnifeRound      = register_cvar( "hp_kniferound", "1" );
    g_pcTeamLimit       = register_cvar( "hp_teamlimit", "1" );
    g_pcShowMoney       = register_cvar( "hp_showmoney", "1" );
    g_pcIntermission    = register_cvar( "hp_intermission", "0" );
    g_pcMaxRound        = register_cvar( "hp_maxround", "15" );
    g_pcWarmCfg         = register_cvar( "hp_warmcfg", "WarmCfg.cfg" );
    g_pcMatchCfg        = register_cvar( "hp_matchcfg", "MatchCfg.cfg" );
    g_pcEnable5Link     = register_cvar( "hp_enable5link", "1" );
    g_pcLinkTime        = register_cvar( "hp_linktime", "10" );
    
    g_pcAmxShowAct      = get_cvar_pointer( "amx_show_activity" );
    g_pcHostName        = get_cvar_pointer( "hostname" );
    g_pcFreezeTime      = get_cvar_pointer( "mp_freezetime" );
    g_pcAllTalk         = get_cvar_pointer( "sv_alltalk" );
    
    register_clcmd( "say ready", "PlayerReady", ADMIN_ALL, " - use command to enter ready status" );
    register_clcmd( "say notready", "PlayerUNReady", ADMIN_ALL, " - use command to cancel ready status" );
    register_clcmd( "say_team ready", "PlayerReady", ADMIN_ALL, " - use command to enter ready status" );
    register_clcmd( "say_team notready", "PlayerUNReady", ADMIN_ALL, " - use command to cancel ready status" );
    register_clcmd( "jointeam", "clcmdJoinTeam", ADMIN_ALL, " - hook teamchange of user" );
    register_clcmd( "chooseteam", "clcmdChooseTeam", ADMIN_ALL, " - hook choose team" );
    register_clcmd( "hp_matchmenu", "MenuShowMatchMenu", PLUGIN_ACCESS, " - show admin menu" );
    register_clcmd( "say votemap", "MenuSetVoteMap", ADMIN_ALL, " - hold a vote for change map" );
    register_clcmd( "say votekick", "MenuShowVoteKick", ADMIN_ALL, " - hold a vote for kick player" );
    register_clcmd( "say menu", "MenuShowPlayerMenu", ADMIN_ALL, " - open player menu" );
    register_clcmd( "say_team menu", "MenuShowPlayerMenu", ADMIN_ALL, " - open player menu" );
    register_clcmd( "menuselect", "clcmdMenuSelect", ADMIN_ALL, " - hook player selected a menu item" );
    register_clcmd( "joinclass", "clcmdJoinClass", ADMIN_ALL, " - hook player chosen model" );
    
    register_concmd( "hp_forcestart", "ForceStart", PLUGIN_ACCESS, " - use this command to force start game" );
    register_concmd( "hp_forcerer3", "ForceReR3", PLUGIN_ACCESS, " - use this command to restart whole match" );
    register_concmd( "hp_forcehalfr3", "ForceHalfR3", PLUGIN_ACCESS, " - use this command to restart half matching" );
    register_concmd( "hp_forcestop", "ForceStop", PLUGIN_ACCESS, " - use this command to force the game stop and enter warm section" );
    register_concmd( "hp_forceswap", "ForceSwap", PLUGIN_ACCESS, " - use this command to force team swap" );
    
    register_event( "CurWeapon", "eventCurWeapon", "be", "1=0", "2=29" );
    register_event( "HLTV", "eventNewRoundStart", "a", "1=0", "2=0" );
    register_event( "ResetHUD", "eventResetHUD", "b" );
    register_event( "TeamInfo", "eventTeamInfo", "a" );
    
    g_hamPostSpawn      = RegisterHam( Ham_Spawn, "player", "hamPostPlayerSpawn", 1 );
    g_hamFwdDeath       = RegisterHam( Ham_Killed, "player", "hamFwdPlayerDeath", 0 );
    g_hamPostTouch[0]   = RegisterHam( Ham_Touch, "armoury_entity", "hamPostWeaponTouch", 1 );
    g_hamPostTouch[1]   = RegisterHam( Ham_Touch, "weaponbox", "hamPostWeaponTouch", 1 );
    g_hamPostTouch[2]   = RegisterHam( Ham_Touch, "weapon_shield", "hamPostWeaponTouch", 1 );
    g_hamPostDeath5Link = RegisterHam( Ham_Killed, "player", "hamPostDeath5Link", 1 );
    g_hamFwdSpawn5Link  = RegisterHam( Ham_Spawn, "player", "hamFwdSpawn5Link", 0 );
    
    g_msgidTeamScore    = get_user_msgid( "TeamScore" );
    g_msgidHideWeapon   = get_user_msgid( "HideWeapon" );
    g_msgidRoundTime    = get_user_msgid( "RoundTime" );
    g_msgidWeapPickup   = get_user_msgid( "WeapPickup" );
    g_msgidCurWeapon    = get_user_msgid( "CurWeapon" );
    g_msgidTextMsg      = get_user_msgid( "TextMsg" );
    g_msgidClCorpse     = get_user_msgid( "ClCorpse" );

    register_message( g_msgidTeamScore, "msgTeamScore" );
    register_message( get_user_msgid( "ShowMenu" ), "msgShowMenu" );
    
    register_menu( "#PUG_Menu_WinKnifeRound", 0x3ff, "MenucmdPickTeam", 0 );
    register_menu( "#PUG_Menu_IfAgreeToSwap", 0x3ff, "MenucmdSwapAsk", 0 );
    register_menu( "#PUG_Menu_VoteMap", 0x3ff, "MenucmdVoteMap", 0 );
    register_menu( "#PUG_Menu_VoteKick", 0x3ff, "MenucmdAskKick", 0 );
    
    return;
}
