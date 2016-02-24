/* AMX Mod X based Script (for MOD Counter-Strike)
*
*   HUST Pick-Up-Game Mode Plugin
*
*   ©¦  Author  :       Chen Shi (aka. real, from China, HUST CSer & NUDT)
*   ©¦  Contact :       bigbryant@qq.com
*   ©¦  Version :       1.3
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
*   ©¦  Changelog: 2016-02-14
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

#if AMXX_VERSION_NUM < 180
    #assert "AMX MOD X 1.8.0+ is required, compiling will be terminated..."
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


new const PLUGIN_NAME[]     =   "HUST PUG";
new const PLUGIN_VERSION[]  =   "1.3";
new const PLUGIN_AUTHOR[]   =   "real";

// need flag "b" to control the plugin
new const PLUGIN_ACCESS     =   ADMIN_RESERVATION;

// max player supported
const   MAX_PLAYERS         =   32;

// vote map list item num (9 max)
const   MAP_VOTE_NUM        =   9;

// offset of taskids
const   OFFSET_HUDMSG       =   100000;
const   OFFSET_RSP          =   150000;
const   OFFSET_MENU         =   200000;
const   OFFSET_COUNT        =   250000;
const   OFFSET_SCROLL       =   300000;
const   OFFSET_SETMODEL     =   350000;
const   OFFSET_R3           =   400000;

// consts of different hudmsg task ID
const   TASKID_SHOWREADY    =   OFFSET_HUDMSG + ( 1 << 0 );
const   TASKID_SHOWNOTIFY   =   OFFSET_HUDMSG + ( 1 << 1 );
const   TASKID_SHOWSCORE    =   OFFSET_HUDMSG + ( 1 << 2 );

// HUD message channel setting
const   CH_SCOREBOARD       =   1;
const   CH_RDYLIST          =   2;
const   CH_NOTIFY           =   1;
const   CH_SHOWMONEY        =   3;
const   CH_COUNTDOWN        =   4;

// HUD message positions
new const Float: HUD_POS_RDYLIST[]      =   { 0.05, 0.2 };
new const Float: HUD_POS_NOTIFY[]       =   { -1.0, 0.0 };
new const Float: HUD_POS_SCOREBOARD[]   =   { -1.0, 0.0 };
new const Float: HUD_POS_SHOWMONEY[]    =   { 0.6, 0.2 };
new const Float: HUD_POS_COUNTDOWN[]    =   { 0.03, 0.6 };
new const Float: HUD_POS_PLRDY[]        =   { -1.0, 0.55 };
new const Float: HUD_POS_MATCHNOT[]     =   { -1.0, 0.4 };
new const Float: HUD_POS_ACT[]          =   { -1.0, 0.3 };
    
new g_HudPlRdyPosFlag[10];      // array to record available HUD display position

// consts about PUG status
enum {
    STATUS_WARM = 1,
    STATUS_KNIFE1,
    STATUS_KNIFE2,
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
new     g_pcAmxShowAct;         // amx_show_activity
new     g_pcHostName;           // hostname

// vars to save swap requests and choices
new     g_SwapRequest[MAX_PLAYERS + 1];             // player requesting states
new     g_SwapBeRQ[MAX_PLAYERS + 1];                // player requested states
new     bool: g_SwapJudge[MAX_PLAYERS + 1];         // if swap agreed
    
// some message ids
new     g_msgidTeamScore;       // message id for "TeamScore" Msg
new     g_msgidHideWeapon;      // message id for "HideWeapon" Msg
new     g_msgidRoundTime;       // message id for "RoundTime" Msg
new     g_msgidWeapPickup;      // message id for "WeapPickup" Msg

// some message handles
new     g_hmsgHideWeapon;       // handle for registered message "HideWeapon"
new     g_hmsgWeapPickup;       // handle for registered message "WeapPickup"

// some ham forward handles
new     HamHook: g_hamPostSpawn;        // handle of HookPlayerSpawnPost
new     HamHook: g_hamFwdDeath;         // handle of HookPlayerDeathFwd
new     HamHook: g_hamPostTouch[3];     // handle of Ham_Touch for weaponbox, armoury and weapon_shield

// forward handles
new     g_hfwdGetCvarFloat;
new     g_hfwdSetModel;

// Team menu hooking message
new const TEAMMENU1[]   =       "#Team_Select";
new const TEAMMENU2[]   =       "#Team_Select_Spect";

// Player menu related part
new     bool: g_bIsOnVote;              // to indicate if a vote is on now
new     Array: g_Maps, g_Mapnum;        // maps name and map num
new     g_VoteCount[MAP_VOTE_NUM], g_VoteMapid[MAP_VOTE_NUM];   // save map vote result
new     g_kickid, g_kickagree;          // player who is being vote kicked
new     g_mPickTeam;                    // pickteam menu count

new     g_hostname[32];                 // hostname of server

//====GLOBAL VAR DEFINITION FINISHED============================================



//==============================================================================
//  ©°©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©´
//  ©¦  GENERIC MESSAGE RELATED FUNCTIONS  ©¦
//  ©¸©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¼
//      ¡ú CheckHostName
//      ¡ú ClearHUDPos
//      ¡ú findHUDPos
//      ¡ú ServerSay
//          ©¸ client_print_color *
//      ¡ú ShowReadyList
//      ¡ú ShowNotification
//      ¡ú ShowHUDScore
//      ¡ú readMap
//      ¡ú SetShowMoneyTask
//          ©¸ ShowTeamMoney ¡û
//==============================================================================

/*
    Checks name of current hostname by checking CVAR "hostname"
    
    @param  none
    @return none
*/
public CheckHostName()
{
    get_pcvar_string( g_pcHostName, g_hostname, 31 );
    
    return;
}

/*
    This function frees the display position for PlayerReady HUD messages.
    The parameter is sent by a set_task() function
    
    @param  para[0]     :    position offsets compared to original position
    @param  para[1]     :    indicate positive/nagative offsets
    @return none
*/
public ClearHUDPos( const para[] )
{
    g_HudPlRdyPosFlag[para[0]] &= ~( 1 << para[1] );
    
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
    static i, para[2];
    
    for( i = 0; i < sizeof( g_HudPlRdyPosFlag ); i++ ) 
        if( ( g_HudPlRdyPosFlag[i] & 1 ) == 0 ) {
            g_HudPlRdyPosFlag[i] |= 1;
            para[0] = i;
            para[1] = 0;
            set_task( 7.5, "ClearHUDPos", _, para, 2 );
            
            return 0.05 * i;
        }
    for( i = 0; i < sizeof( g_HudPlRdyPosFlag ); i++ )
        if( ( g_HudPlRdyPosFlag[i] & 2 ) == 0 ) {
            g_HudPlRdyPosFlag[i] |= 2;
            para[0] = i;
            para[1] = 1;
            set_task( 7.5, "ClearHUDPos", _, para, 2 );
            
            return -0.05 * i;
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
    This function shows a list under radar to indicate "ready" and "unready"
    player list. The list uses normal HUD system.
    
    HUD params:
        ©À CHANNEL:    CH_RDYLIST
        ©À POSITION:   HUD_POS_RDYLIST[]
        ©¸ COLOR:      #00FF00 (green)
    
    @param  none
    @return none
*/
public ShowReadyList()
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
    set_hudmessage( 0x00, 0xff, 0x00, HUD_POS_RDYLIST[0], HUD_POS_RDYLIST[1], 0, 0.0, 7.8, 0.1, 0.1, CH_RDYLIST );
    show_hudmessage( 0, "%s^n%s", rdymsg, urdymsg );
    
    return;
}

/*
    This function shows a pre-defined text on the top-center of screen in warmup 
    time. The message uses normal HUD system.
    
    HUD params:
        ©À CHANNEL:    CH_NOTIFY
        ©À POSITION:   HUD_POS_NOTIFY[]
        ©¸ COLOR:      #00FFFF (cyan)
    
    @param  none
    @return none
*/
public ShowNotification()
{
    set_hudmessage( 0x00, 0xff, 0xff, HUD_POS_NOTIFY[0], HUD_POS_NOTIFY[1], 0, 0.0, 19.8, 0.1, 0.1, CH_NOTIFY );
    show_hudmessage( 0, "%L", LANG_SERVER, "PUG_WARM_NOTIFY" );
    
    return;
}

/*
    This function shows a scoreboard on the top-center of screen in match. 
    The message uses normal HUD system.
    
    HUD params:
        ©À CHANNEL:    CH_SCOREBOARD
        ©À POSITION:   HUD_POS_SCOREBOARD[]
        ©¸ COLOR:      #FFFFFF (white)
    
    @param  none
    @return none
*/
public ShowHUDScore()
{
    static Msg[256], len;
    new St = g_Score[0][0] + g_Score[0][1];
    new Sc = g_Score[1][0] + g_Score[1][1];
    new tt = g_RoundNum;
    
    switch( g_StatusNow ) {
        case STATUS_KNIFE1: len = formatex( Msg, 255, "%L", LANG_SERVER, "PUG_KNIFEROUND" );
        case STATUS_KNIFE2: len = formatex( Msg, 255, "%L", LANG_SERVER, "PUG_KNIFEROUND" );
        case STATUS_F_HALF: len = formatex( Msg, 255, "%L", LANG_SERVER, "PUG_F_HALF" );
        case STATUS_S_HALF: len = formatex( Msg, 255, "%L", LANG_SERVER, "PUG_S_HALF" );
        case STATUS_INTER: len = formatex( Msg, 255, "%L", LANG_SERVER, "PUG_INTER" );    
    }
    len += formatex( Msg[len], 255 - len, " %L", LANG_SERVER, "PUG_MATCHPROC", tt, 30 );
    len += formatex( Msg[len], 255 - len, "^n%L", LANG_SERVER, "PUG_SCOREBOARD", St, Sc );
    set_hudmessage( 0xff, 0xff, 0xff, HUD_POS_SCOREBOARD[0], HUD_POS_SCOREBOARD[1], 0, 0.0, 8.0, 0.0, 0.0, CH_SCOREBOARD );
    show_hudmessage( 0, Msg );
    
    return;
}

/*
    This function load map config files from server files. 
    
    @param  none
    @return none
*/
readMap()
{
    new maps_ini_file[64];
    
    g_Maps = ArrayCreate( 32 );
    get_configsdir( maps_ini_file, 63 );
    format( maps_ini_file, 63, "%s/maps.ini", maps_ini_file );
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
        ©À CHANNEL:    CH_SHOWMONEY
        ©À POSITION:   HUD_POS_SHOWMONEY[]
        ©¸ COLOR:      #FF0000 (red) TERRORISTs
                      #0000FF (blue) CTs
    
    @param  none
    @return none
*/
SetShowMoneyTask()
{
    if( StatLive() && get_pcvar_num( g_pcShowMoney ) == 1 ) 
        set_task( 0.1, "ShowTeamMoney" );
        
    return;
}
public ShowTeamMoney()
{
    static Playerid[32], CsTeams: team[32], MsgT[256], MsgCT[256], lenT, lenCT;
    new i, money, PlayerNum, id;
    new Float: holdtime;
    
    get_players( Playerid, PlayerNum, "h", "" );
    lenT = formatex( MsgT, 255, "%L :^n^n", LANG_SERVER, "TELL_MONEY_TITLE_T" );
    lenCT = formatex( MsgCT, 255, "%L £º^n^n", LANG_SERVER, "TELL_MONEY_TITLE_CT" );
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
    
    holdtime = get_cvar_float( "mp_freezetime" ) - 1.0;
    for( i = 0; i < PlayerNum; i++ ) {
        id = Playerid[i];
        switch( team[i] ) {
            case CS_TEAM_CT: {
                set_hudmessage( 0x00, 0x00, 0xff, HUD_POS_SHOWMONEY[0], HUD_POS_SHOWMONEY[1], 0, 0.0, holdtime, 0.5, 1.0, CH_SHOWMONEY );
                show_hudmessage( id, MsgCT );
            }
            case CS_TEAM_T:{
                set_hudmessage( 0xff, 0x00, 0x00, HUD_POS_SHOWMONEY[0], HUD_POS_SHOWMONEY[1], 0, 0.0, holdtime, 0.5, 1.0, CH_SHOWMONEY );
                show_hudmessage( id, MsgT );
            }
        }
    }
    
    return;
}

//==============================================================================
//  ©°©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©´
//  ©¦  GENERIC USEFUL FUNCTIONS  ©¦
//  ©¸©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¼
//      ¡ú SwapTeam
//          ©À swap_int ¡û
//          ©¸ ServerSay
//      ¡ú StatLive
//      ¡ú StatMatch
//      ¡ú InitPlayerInfo
//      ¡ú RefreshReadyList
//          ©¸ PutPlayer ¡û
//      ¡ú StripWeapon
//      ¡ú client_infochanged
//      ¡ú SetAllowGrens
//          ©À {*fwdSetInfiniteBuyTime*}
//          ©À {*fwdSetModel*}
//          ©¸ {*msgWeapPickup*}
//==============================================================================

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
    new i, id, CsTeams: team, wbox;
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
                g_teamHash[id] = CS_TEAM_CT;
            }
            case CS_TEAM_CT: {
                if( is_user_alive( id ) ) {
                    cs_set_user_defuse( id, 0 );
                    transid = id;
                }
                cs_set_user_team( id, CS_TEAM_T, CS_DONTCHANGE );
                g_teamHash[id] = CS_TEAM_T;
            }
        }
    }
    // finish C4 transfer if needed
    if( needtrans ) {
        set_pev( wbox, pev_flags, pev( wbox, pev_flags) | FL_ONGROUND );
        dllfunc( DLLFunc_Touch, wbox, transid );
    }   
    
    // swap scores and number of players
    swap_int( g_Score[0][0], g_Score[1][0] );
    swap_int( g_Score[0][1], g_Score[1][1] );
    swap_int( g_Tnum, g_Cnum );
    
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
    static tplayer[MAX_PLAYERS];
    new i, id, t, CsTeams: team;
    
    g_rdy = g_Tnum = g_Cnum = 0;
    arrayset( g_ready, false, sizeof( g_ready ) );
    arrayset( _:( g_teamHash ), 0, sizeof( g_teamHash ) );
    get_players( tplayer, t, "h" );
    for( i = 0; i < t; i++ ) {
        id = tplayer[i];
        team = cs_get_user_team( id );
        g_teamHash[id] = team ;
        get_user_name( id, g_name[id], 31 );
        switch( team ) {
            case CS_TEAM_T: g_Tnum++;
            case CS_TEAM_CT: g_Cnum++;
        }
    }
    
    return;
}

/*
    This function updates the player information instantly.
    This function will be called after player using "jointeam" or "chooseteam"
    command with 0.1sec delay to fix display bug of readylist.
    
    @param  none
    @return none
*/
public RefreshReadyList()
{
    new i, id, CsTeams: oldteam, CsTeams: nowteam;
        
    for( i = 0; i < MAX_PLAYERS; i++ ) {
        id = i + 1;
        if( !is_user_connected( id ) ) continue;
        oldteam = g_teamHash[id];
        nowteam = cs_get_user_team( id );
        if( oldteam != nowteam ) PutPlayer( id, oldteam, nowteam ); 
    }
    
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

    switch( oldteam ) {
        case CS_TEAM_T: g_Tnum--;
        case CS_TEAM_CT: g_Cnum--;
    }
    
    switch( newteam ) {
        case CS_TEAM_T: {
            g_teamHash[id] = CS_TEAM_T;
            g_Tnum++;
        }
        case CS_TEAM_CT: {
            g_teamHash[id] = CS_TEAM_CT;
            g_Cnum++;
        }
        case CS_TEAM_SPECTATOR: {
            g_teamHash[id] = CS_TEAM_SPECTATOR;
            if( g_ready[id] ) {
                g_ready[id] = false;
                g_rdy--;
            }
        }
        default: {
            g_teamHash[id] = CS_TEAM_UNASSIGNED;
            if( g_ready[id] ) {
                g_ready[id] = false;
                g_rdy--;
            }
        }
    }
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
    
    return PLUGIN_CONTINUE;
}

/*
    This is function enable/disables most forwards used in warmup time.
    This is a very important function.
    
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
        // register WeapPickup message
        g_hmsgWeapPickup = register_message( g_msgidWeapPickup, "msgWeapPickup" );
    }
    
    return;
}

//==============================================================================
//  ©°©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©´
//  ©¦  WARM-UP-TIME GAME FUNCTIONS  ©¦
//  ©¸©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¼
//      ¡ú eventTeamInfo
//          ©¸ DelayRespawn ¡û
//      ¡ú hamFwdPlayerDeath
//          ©¸ DelayRespawn ¡û
//      ¡ú hamPostPlayerSpawn
//          ©À DelaySetWeaponStat ¡û
//          ©¸ RemoveProtect ¡û
//      ¡ú msgWeapPickup
//      ¡ú fwdSetModel
//          ©¸ DelayRemoveEnt ¡û
//      ¡ú hamPostWeaponTouch
//          ©¸ DelayRemoveTask ¡û
//      ¡ú SetMapObjective
//          ©¸ {*msgHideWeapon*}
//      ¡ú msgHideWeapon
//      ¡ú fwdSetInfiniteBuyTime
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
    if( StatMatch() ) return;
    
    new id = read_data( 1 );
    
    set_task( 0.5, "DelayRespawn", id + OFFSET_RSP );
    
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
    
    new CsTeams: team = cs_get_user_team( id );
        
    if( team != CS_TEAM_T && team != CS_TEAM_CT ) return;
    
    ExecuteHamB( Ham_CS_RoundRespawn, id );
    
    return;
}

/*
    This function sets the weapon status after player re-acquire their weapons
    in warmup time. Status of weapon include "silencer" and "burst mode". It is 
    usually called with a small amount of delay time to ensure the correctness
    of the result.
    
    @param  para[0]     :   index of player who is holding the weapon
    @param  para[1]     :   index of weapon that needs to be set status
    @param  para[2]     :   weapon status, see hamFwdPlayerDeath() function
    @return none
*/
public DelaySetWeaponStat( const para[] )
{
    new id = para[0];
    new wid = para[1];
    new silen = _:( ( para[2] & 2 ) != 0 );
    new burst = _:( ( para[2] & 1 ) != 0 );
    static wEnt;
    
    wEnt = find_ent_by_owner( 32, WEAPON_NAME[wid], id );

    cs_set_weapon_silen( wEnt, silen, 0 );
    cs_set_weapon_burst( wEnt, burst );
    
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
    
    static CsTeams: team, buff, para[3], wid, stat;
    
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
            para[0] = id;
            para[1] = wid;
            para[2] = stat;
            set_task( 0.1, "DelaySetWeaponStat", _, para, 3 );
        }
    }
    if( ( buff = g_WarmWeapon[id][0] ) != 0 ) {
        wid = ( buff >> 2 );
        stat = ( buff & 3 );
        give_item( id, WEAPON_NAME[wid] );
        if( ( wid == CSW_M4A1 || wid == CSW_FAMAS ) && ( stat != 0 ) ) {
            para[0] = id;
            para[1] = wid;
            para[2] = stat;
            set_task( 0.1, "DelaySetWeaponStat", _, para, 3 );
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
    if( g_WarmWeapon[id][1] == 0 ) return PLUGIN_CONTINUE;
    
    new wid = ( g_WarmWeapon[id][1] >> 2 );
    new msgwid = get_msg_arg_int( 1 );

    if( ( ( 1 << msgwid ) & CSW_SECONDARY ) != 0 && wid != msgwid )  
        return PLUGIN_HANDLED;
    
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
//  ©°©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©´
//  ©¦  READY AUTO-START SYSTEM FUNCTIONS  ©¦
//  ©¸©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¼
//      ¡ú PlayerReady
//          ©À findHUDPos
//          ©¸ AutoStart ¡û
//              ©À StopWarm
//              ©À EnterKnifeRound
//              ©À EnterFirstHalf
//              ©¸ EnterSecondHalf
//      ¡ú PlayerUNReady
//          ©¸ findHUDPos
//      ¡ú PlayerJoin
//          ©À ShowSwapMenu
//          ©¸ RefreshReadyList
//==============================================================================

/*
    This function marks player to ready status when player executed the pre-defined
    command ( say !ready or sth. else ) and function PlayerUNReady() does the
    opposite. These functions are using Director HUD message to show prompt messages.
    Function findHUDPos() is called to find a available display position.
    
    HUD params:
        ©À CHANNEL:    DIRECTOR HUD
        ©À POSITION:   HUD_POS_PLRDY[] ( will be auto-adjusted to avoid overlap )
        ©¸ COLOR:      #FFFFFF (white)
    
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
    
    set_dhudmessage( 0xff, 0xff, 0xff, HUD_POS_PLRDY[0], HUD_POS_PLRDY[1] + findHUDPos(), 2, 2.0, 4.8, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_READYMSG", g_name[id] );
        
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
    
    set_dhudmessage( 0xff, 0x55, 0x55, HUD_POS_PLRDY[0], HUD_POS_PLRDY[1] + findHUDPos(), 2, 2.0, 4.8, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_UREADYMSG", g_name[id] );
    
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

/*
    This function is used for take the place of default client command "jointeam".
    This function will check the team status before put player in corresponding
    team.
    
    @param  id      :   index of player
    @return none
*/
public PlayerJoin( id )
{
    static args[16], argn;
    new tl = get_pcvar_num( g_pcTeamLimit );
    
    if( StatLive() ) {
        new CsTeams: team = cs_get_user_team( id );
        switch( team ) {
            case CS_TEAM_T: {
                client_print( id, print_center, "%L %L", LANG_SERVER, "PUG_CANTTEAMSELECT", LANG_SERVER, "PUG_WILLOPENSWAPMENU" );
                set_task( 5.0, "ShowSwapMenu", id + OFFSET_MENU );
            }
            case CS_TEAM_CT: {
                client_print( id, print_center, "%L %L", LANG_SERVER, "PUG_CANTTEAMSELECT", LANG_SERVER, "PUG_WILLOPENSWAPMENU" );
                set_task( 5.0, "ShowSwapMenu", id + OFFSET_MENU );
            }
            default:
                client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTTEAMSELECT" );
        }
        return PLUGIN_HANDLED;
    }
    
    read_argv( 1, args, 15 );
    argn = str_to_num( args );
    
    if( argn != 1 && argn != 2 && argn != 5 && argn != 6 ) return PLUGIN_HANDLED;
    
    switch( argn ) {
        case 1:
            if( g_Tnum >= 5 && tl == 1 ) {
                client_print( id, print_center, "%L", LANG_SERVER, "PUG_MENU_CANTJOINT" );
                client_cmd( id, "chooseteam" );
                return PLUGIN_HANDLED;
            }
            else
                engclient_cmd( id, "jointeam", "1" );
        case 2:
            if( g_Cnum >= 5 && tl == 1 ) {
                client_print( id, print_center, "%L", LANG_SERVER, "PUG_MENU_CANTJOINCT" );
                client_cmd( id, "chooseteam" );
                return PLUGIN_HANDLED;
            }
            else
                engclient_cmd( id, "jointeam", "2" );
        case 6: {
            engclient_cmd( id, "jointeam", "6" );
            return PLUGIN_HANDLED;
        }
    }
    set_task( 0.1, "RefreshReadyList" );
    
    return PLUGIN_HANDLED;
}

// Update info list when someone drops
public client_disconnect( id )
{
    new CsTeams: team = g_teamHash[id];
    
    g_teamHash[id] = CS_TEAM_UNASSIGNED;
    if( g_ready[id] ) {
        g_ready[id] = false;
        g_rdy--;
    }
    switch( team ) {
        case CS_TEAM_T: g_Tnum--;
        case CS_TEAM_CT: g_Cnum--;
    }
    
    return PLUGIN_HANDLED;
}



// Warmup time game related ====================================================
// Block objective map, respawning, etc.
//
//==============================================================================

public eventResetHUD( id )
{
    if( StatMatch() )
        ShowHUDScore();
    else {        
        message_begin( MSG_ONE, g_msgidHideWeapon, _, id );
        write_byte( HW_HIDE_TIMER_FLAG );
        message_end();
    }

    return;
}

//==============================================================================
//  ©°©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©´
//  ©¦  REGULAR MATCH RELATED FUNCTIONS  ©¦
//  ©¸©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¼
//      ¡ú EnterWarm
//          ©À SetMapObjective
//          ©À SetBlockRoundTimer
//          ©¸ SetAllowGrens
//      ¡ú StopWarm
//          ©À SetMapObjective
//          ©À SetBlockRoundTimer
//          ©¸ SetAllowGrens
//==============================================================================

/*
    This function lets the plugin enter warmup status and set proper tasks for
    warmup time
    
    @param  none
    @return none
*/
public EnterWarm()
{
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
        set_task( 8.0, "ShowReadyList", TASKID_SHOWREADY, _, _, "b" );
    if( !task_exists( TASKID_SHOWNOTIFY, 0 ) )
        set_task( 20.0, "ShowNotification", TASKID_SHOWNOTIFY, _, _, "b" );
    
    server_cmd( "exec WarmCfg.cfg" );
    ServerSay( "%L", LANG_SERVER, "PUG_WARMCFG_LOADED" );
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
    // recover map objective
    SetMapObjective( true );
    SetBlockRoundTimer( false );
    // unrestrict grenades
    SetAllowGrens( true );
    
    remove_task( TASKID_SHOWREADY, 0 );
    remove_task( TASKID_SHOWNOTIFY, 0 );
    
    if( !task_exists( TASKID_SHOWSCORE, 0 ) )
        set_task( 8.0, "ShowHUDScore", TASKID_SHOWSCORE, _, _, "b" );
    
    server_cmd( "exec MatchCfg.cfg" );
    ServerSay( "%L", LANG_SERVER, "PUG_MATCHCFG_LOADED" );
    
    return;
}

//------------------------------------------------

public eventCurWeapon( id )
{
    static wpid;
    
    switch( g_StatusNow ) {
        case STATUS_KNIFE1, STATUS_KNIFE2: {
            wpid = read_data( 2 );
    
            if( wpid != CSW_KNIFE ) 
                engclient_cmd( id, "weapon_knife" );
    
            return PLUGIN_HANDLED;
        }
        case STATUS_WARM: {
            if( !is_user_alive( id ) ) return PLUGIN_CONTINUE;
            
            wpid = read_data( 2 );
            if( WEAPON_MAXAMMO[wpid] > 2 )
                cs_set_user_bpammo( id, wpid, WEAPON_MAXAMMO[wpid] );
        }
    }

    return PLUGIN_CONTINUE;
}

//------------------------------------------------

public EnterKnifeRound()
{
    g_StatusNow = STATUS_KNIFE1;
    
    g_Score[0][0] = g_Score[0][1] = g_Score[1][0] = g_Score[1][1] = 0;
    ServerSay( "%L", LANG_SERVER, "PUG_KNIFEROUND_MSG" );
    server_cmd( "sv_restartround 3" );
    set_task( 5.0, "KnifeRoundMsg" );
    
    return;
}

//------------------------------------------------

public KnifeRoundMsg()
{
    for( new i = 0; i < 4; i++ ) ServerSay( "%L", LANG_SERVER, "PUG_KNIFEROUND_STR" );
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_KNIFEROUND_HUD" );
    g_StatusNow = STATUS_KNIFE2;
    
    return;
}

//------------------------------------------------

KnifeRoundWon( CsTeams: team )
{
    static teamname[16];
    
    if( team == CS_TEAM_T )
        formatex( teamname, 15, "%L", LANG_SERVER, "PUG_TNAME" );
    else
        formatex( teamname, 15, "%L", LANG_SERVER, "PUG_CTNAME" );
    set_dhudmessage( 0xff, 0xff, 0xff, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_KNIFEWON_MSG", teamname );
    
    ShowPickTeamMenu( team );
    
    return;
}

//------------------------------------------------

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

//------------------------------------------------

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

//------------------------------------------------

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

//------------------------------------------------

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
                set_task( 8.0, "ShowReadyList", TASKID_SHOWREADY, _, _, "b" );
            g_StatusNow = STATUS_INTER;
        }
    }
    
    return;
}

//------------------------------------------------

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

// Match Result related=========================================================
//
//
//==============================================================================

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

//------------------------------------------------

MatchDraw()
{
    set_dhudmessage( 0xff, 0x00, 0x00, HUD_POS_MATCHNOT[0], HUD_POS_MATCHNOT[1], 0, 0.0, 5.0, 0.1, 0.1 );
    show_dhudmessage( 0, "%L", LANG_SERVER, "PUG_MATCHDRAW_HUD", 15, 15 );
    ServerSay( "%L", LANG_SERVER, "PUG_MATCHDRAW_MSG", 15, 15 );
    
    set_task( 5.0, "EnterWarm" );
    
    return;
}

//------------------------------------------------

UpdateScore( status, CsTeams: team, score )
{
    new tid = _:( team ) - 1;
    
    switch( status ) {
        case STATUS_F_HALF: {
            g_Score[tid][0] += ( score - g_scorebuff[tid] > 0 ) ? 1 : 0;
            if( g_Score[0][0] + g_Score[1][0] == 15 ) EnterIntermission();
        }
        case STATUS_S_HALF: {
            g_Score[tid][1] += ( score - g_scorebuff[tid] > 0 ) ? 1 : 0;
            if( g_Score[tid][0] + g_Score[tid][1] == 16 ) MatchWin( team );                
            if( g_Score[0][0] + g_Score[0][1] == 15 && g_Score[1][0] + g_Score[1][1] == 15 ) 
                MatchDraw();
        }
    }
    g_scorebuff[_:( team ) - 1] = score;
    
    return;
}
   
//------------------------------------------------
    
public eventTeamScore()
{
    static name[16], score, CsTeams: team;
    
    read_data( 1, name, 15 );
    score = read_data( 2 );
    
    if( name[0] == 'C' )
        team = CS_TEAM_CT;
    else
        team = CS_TEAM_T;
    
    switch( g_StatusNow ) {
        case STATUS_KNIFE2: if( score > 0 ) KnifeRoundWon( team );
        case STATUS_F_HALF: UpdateScore( g_StatusNow, team, score );
        case STATUS_S_HALF: UpdateScore( g_StatusNow, team, score );
    }
    if( StatLive() ) ShowHUDScore();
    
    return PLUGIN_CONTINUE;
}

//------------------------------------------------

public MsgTeamScore()
{
    if( !StatLive() ) return PLUGIN_CONTINUE;
    
    static teamname[16], buff[2], tindex;
    
    get_msg_arg_string( 1, teamname, 15 );
    if( g_StatusNow == STATUS_S_HALF ) {
        buff[0] = g_Score[0][1];
        buff[1] = g_Score[1][1];
    }
    else {
        buff[0] = g_Score[0][0];
        buff[1] = g_Score[1][0];
    }
    tindex = _:( teamname[0] == 'C' );
    set_msg_arg_int( 2, ARG_SHORT, buff[tindex] );
    
    return PLUGIN_CONTINUE;
}

//------------------------------------------------

public eventNewRoundStart()
{
    // update round num
    UpdateRoundNum();
    // Show Team Money at round start
    SetShowMoneyTask();
    
    return;
}

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
    
    return;
}

// MENU part====================================================================
//
//
//==============================================================================

// function to show menu count-down message
ShowMenuCountDown( t )
{
    set_hudmessage( 0xff, 0xff, 0xff, HUD_POS_COUNTDOWN[0], HUD_POS_COUNTDOWN[1], 0, 0.0, 1.0, 0.0, 0.0, CH_COUNTDOWN );
    show_hudmessage( 0, "%L %d", LANG_SERVER, "PUG_MENU_COUNTDOWNPROMPT", t );
    
    return;
}

// task to show a count down menu-off time
public TaskMenuCountDown( tskid )
{
    static bool: firstcall;
    static time;
    
    if( !firstcall ) {
        firstcall = true;
        time = tskid - OFFSET_COUNT - 1;
    }
    
    if( time > 0 ) {
        ShowMenuCountDown( time );
        time--;
    }
    else
        firstcall = false;
    
    return;
}

//------------------------------------------------

ShowPickTeamMenu( CsTeams: team )
{
    const   SHOWTIME = 8;
    static szMenu[256], len;
    new i, id, CsTeams: t;
    
    len = formatex( szMenu, 255, "\y%L^n^n", LANG_SERVER, "PUG_MENU_PICKTEAMTITLE" );
    len += formatex( szMenu[len], 255 - len, "\r1.  \w%L^n", LANG_SERVER, "PUG_MENU_PICKTEAMOP1" );
    len += formatex( szMenu[len], 255 - len, "\r2.  \w%L", LANG_SERVER, "PUG_MENU_PICKTEAMOP2" );
    
    g_mPickTeam = 0;
    for( i = 0; i < MAX_PLAYERS; i++ ) {
        id = i + 1;
        if( !is_user_connected( id ) ) continue;
        
        t = cs_get_user_team( id );
        if( t == team ) show_menu( id, 3, szMenu, SHOWTIME, "KnifeRound Won Menu" );
    }
    ShowMenuCountDown( SHOWTIME );
    set_task( 1.0, "TaskMenuCountDown", SHOWTIME + OFFSET_COUNT, _, _, "a", SHOWTIME - 1 );
    
    set_task( float( SHOWTIME ), "PickTeamVoteJudge" );
    set_task( float( SHOWTIME + 1 ), "EnterFirstHalf" );
   
    return;
}

//------------------------------------------------

public cmdPickTeamMenu( id, key )
{
    static name[32], Msg[128];
    
    get_user_name( id, name, 31 );
    if( key == 0 ) {
        g_mPickTeam++;
        formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PICKTEAMOP1RES", name );
    }
    else
        formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PICKTEAMOP2RES", name );
    ServerSay( Msg );
    
    return;
}

//------------------------------------------------

public PickTeamVoteJudge()
{
    if( g_mPickTeam > 2 ) {
        ServerSay( "%L", LANG_SERVER, "PUG_VOTESWAP" );
        SwapTeam();
    }
    else
        ServerSay( "%L", LANG_SERVER, "PUG_VOTENOTSWAP" );
    
    return;
}

//------------------------------------------------

public SwapCenterCountDown( const szpara[] )
{
    static bool: first;
    static time;
    new id = szpara[1];
    
    if( !first ) {
        time = szpara[0] - 1;
        first = true;
    }
    client_print( id, print_center, "%L %L", LANG_SERVER, "PUG_CANTTEAMSELECT", LANG_SERVER, "PUG_WILLOPENSWAPMENU", time );
    if( time > 0 ) 
        time--;
    else 
        first = false;
        
    return;
}

public HookChooseTeam( id )
{
    const TSWAP = 5;
    static szt[2];
    new tl = get_pcvar_num( g_pcTeamLimit );
    new CsTeams: team = cs_get_user_team( id );
    new bool: flag;
    
    if( tl == 1 ) {
        switch( team ) {
            case CS_TEAM_T: flag = g_Cnum >= 5;
            case CS_TEAM_CT: flag = g_Tnum >= 5;
            case CS_TEAM_SPECTATOR: flag = ( g_Cnum >= 5 && g_Tnum >= 5 );
        }
        if( StatLive() && flag ) {
            if( team == CS_TEAM_CT || team == CS_TEAM_T ) {
                set_task( float( TSWAP ), "ShowSwapMenu", id + OFFSET_MENU );
                client_print( id, print_center, "%L %L", LANG_SERVER, "PUG_CANTTEAMSELECT", LANG_SERVER, "PUG_WILLOPENSWAPMENU", TSWAP );
                szt[0] = TSWAP;
                szt[1] = id;
                set_task( 1.0, "SwapCenterCountDown", id + OFFSET_COUNT, szt, 2, "a", TSWAP );
            }
            else
                client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTTEAMSELECT" );
        }
        else
            ShowTeamMenu( id );
    }
    else
        ShowTeamMenu( id );
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public HookTeamMenu( msgid, idest, id )
{
    static MenuCode[64];
    
    get_msg_arg_string( 4, MenuCode, 63 );
    if( !equal( MenuCode, TEAMMENU1 ) && !equal( MenuCode, TEAMMENU2 ) ) 
        return PLUGIN_CONTINUE;
        
    ShowTeamMenu( id );
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public HookVGuiTeamMenu( msgid, idest, id )
{
    if( get_msg_arg_int( 1 ) != 2 ) return PLUGIN_CONTINUE;
    
    ShowTeamMenu( id );
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

ShowTeamMenu( id )
{
    static szMenu[256], len;
    new key = 0, CsTeams: team = cs_get_user_team( id );
    new tl = get_pcvar_num( g_pcTeamLimit );
    
    len = formatex( szMenu, 255, "\y%L^n^n", LANG_SERVER, "PUG_MENU_TEAMTITLE" );
    if( team == CS_TEAM_T || ( tl == 1 && g_Tnum >= 5 ) )
        len += formatex( szMenu[len], 255 - len, "\r1.  \d%L^n", LANG_SERVER, "PUG_TNAME" );
    else {
        len += formatex( szMenu[len], 255 - len, "\r1.  \w%L^n", LANG_SERVER, "PUG_TNAME" );
        key |= ( 1 << 0 );
    }
    if( team == CS_TEAM_CT || ( tl == 1 && g_Cnum >= 5 ) )
        len += formatex( szMenu[len], 255 - len, "\r2.  \d%L^n^n", LANG_SERVER, "PUG_CTNAME" );
    else {
        len += formatex( szMenu[len], 255 - len, "\r2.  \w%L^n^n", LANG_SERVER, "PUG_CTNAME" );
        key |= ( 1 << 1 );
    }
    if( team == CS_TEAM_T || team == CS_TEAM_CT || ( tl == 1 && g_Tnum >=5 && g_Cnum >= 5 ) )
        len += formatex( szMenu[len], 255 - len, "\r5.  \d%L^n", LANG_SERVER, "PUG_MENU_AUTOTEAM" );
    else {
        len += formatex( szMenu[len], 255 - len, "\r5.  \w%L^n", LANG_SERVER, "PUG_MENU_AUTOTEAM" );
        key |= ( 1 << 4 );
    }
    if( team == CS_TEAM_SPECTATOR || ( StatLive() && team != CS_TEAM_UNASSIGNED ) )
        len += formatex( szMenu[len], 255 - len, "\r6.  \d%L^n^n", LANG_SERVER, "PUG_SPECNAME" );
    else {
        len += formatex( szMenu[len], 255 - len, "\r6.  \w%L^n^n", LANG_SERVER, "PUG_SPECNAME" );
        key |= ( 1 << 5 );
    }

    len += formatex( szMenu[len], 255 - len, "\r0.  \w%L", LANG_SERVER, "PUG_MENU_CANCEL" );
    key |= ( 1 << 9 );
    
    show_menu( id, key, szMenu, -1, "PUG Team Menu" );
    
    return;
}

//------------------------------------------------

public cmdPUGTeamMenu( id, key )
{
    new CsTeams: team = cs_get_user_team( id ), ts[2], CsTeams: t;
        
    switch( key ) {
        case 0:
            if( team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED ) 
                engclient_cmd( id, "jointeam", "1" );
            else {
                user_kill( id );
                cs_set_user_team( id, CS_TEAM_T, CS_DONTCHANGE );
            }
        case 1:
            if( team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED )
                engclient_cmd( id, "jointeam", "2" );
            else {
                user_kill( id );
                cs_set_user_team( id, CS_TEAM_CT, CS_DONTCHANGE );
            }
        case 4: {
            if( g_Tnum < g_Cnum ) {
                ts[0] = '1';
                ts[1] = 0;
                t = CS_TEAM_T;
            }
            else {
                ts[0] = '2';
                ts[1] = 0;
                t = CS_TEAM_CT;
            }
            if( team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED )
                engclient_cmd( id, "jointeam", ts );
            else {
                user_kill( id );
                cs_set_user_team( id, t, CS_DONTCHANGE );
            }
        }
        case 5:
            if( team == CS_TEAM_UNASSIGNED )
                engclient_cmd( id, "jointeam", "6" );
            else {
                user_kill( id );
                cs_set_user_team( id, CS_TEAM_SPECTATOR, CS_DONTCHANGE );
            }
    }
    
    set_task( 0.1, "RefreshReadyList" );
    
    return;
}

//------------------------------------------------

public ShowSwapMenu( tskid )
{
    new id = tskid - OFFSET_MENU;
    new CsTeams: team = cs_get_user_team( id );
    new i, tid, hSwapMenu;
    static szMenuTitle[64], name[32], szid[3], Msg[128];
    
    if( g_SwapRequest[id] != 0 ) {
        client_print( id, print_chat, "%L", LANG_SERVER, "PUG_MENU_ALRDYRQSWAP" );
        return PLUGIN_HANDLED;
    }
    
    formatex( szMenuTitle, 63, "\y%L", LANG_SERVER, "PUG_MENU_SWAPTITLE" );
    hSwapMenu = menu_create( szMenuTitle, "cmdSwapMenu" );
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
    menu_display( id, hSwapMenu, 0 );
    
    return PLUGIN_CONTINUE;
}

//------------------------------------------------

public cmdSwapMenu( id, menu, item )
{
    static szBuffer[8], tid, szName[8];
    new _access, item_callback;
    
    menu_item_getinfo( menu, item, _access, szBuffer, 7, szName, 7, item_callback );
    menu_destroy( menu );
    tid = str_to_num( szBuffer );
    
    if( item == MENU_EXIT ) return;
    
    if( g_SwapBeRQ[tid] != 0 ) {
        client_print( id, print_chat, "%L", LANG_SERVER, "PUG_MENU_SWAPCHOICEINVALID" );
        return;
    }
    
    g_SwapRequest[id] = tid;
    g_SwapBeRQ[tid] = id;
    ShowSwapAsk( tid );
    
    return;
}

//------------------------------------------------

ShowSwapAsk( tid )
{
    static szMenu[256], len, name1[32], name2[32], tn[16];
    new id = g_SwapBeRQ[tid], CsTeams: team;
    
    get_user_name( id, name1, 31 );
    get_user_name( tid, name2, 31 );
    team = g_teamHash[id];
    switch( team ) {
        case CS_TEAM_T: formatex( tn, 15, "%L", LANG_SERVER, "PUG_TNAME" );
        case CS_TEAM_CT: formatex( tn, 15, "%L", LANG_SERVER, "PUG_CTNAME" );
    }
    
    ServerSay( "%L", LANG_SERVER, "PUG_MENU_SWAPRQMSG", name1, name2 );
    
    len = formatex( szMenu, 255, "\y%L^n^n", LANG_SERVER, "PUG_MENU_SWAPASKTITLE", tn, name1 );
    len += formatex( szMenu[len], 255 - len, "\r1.  \w%L^n", LANG_SERVER, "PUG_MENU_AGREESWAP" );
    len += formatex( szMenu[len], 255 - len, "\r2.  \w%L", LANG_SERVER, "PUG_MENU_REJSWAP" );
    show_menu( tid, 3, szMenu, 8, "Agree to swap?" );
    
    set_task( 8.0, "SwapAskJudge", tid + OFFSET_MENU );
    
    return;
}

//------------------------------------------------

public cmdSwapAsk( id, key )
{
    switch( key ) {
        case 0: g_SwapJudge[id] = true;
        case 1: g_SwapJudge[id] = false;
    }
    
    return;
}

//------------------------------------------------

public SwapAskJudge( tskid )
{
    new tid = tskid - OFFSET_MENU;
    new id = g_SwapBeRQ[tid];
    new CsTeams: team1 = g_teamHash[id];
    new CsTeams: team2 = g_teamHash[tid];
    static tn[2], name1[32], name2[32];
    
    tn[1] = 0;
    if( team1 == CS_TEAM_CT )
        tn[0] = '2';
    else
        tn[0] = '1';
    
    if( g_SwapJudge[tid] ) {
        if( team2 == CS_TEAM_SPECTATOR ) {
            user_kill( id );
            engclient_cmd( tid, "jointeam", tn );
        }
        else
            cs_set_user_team( tid, team1, CS_DONTCHANGE );
        cs_set_user_team( id, team2, CS_DONTCHANGE );
        
        g_teamHash[id] = team2;
        g_teamHash[tid] = team1;
        
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
    
    g_SwapRequest[id] = 0;
    g_SwapBeRQ[tid] = 0;
    g_SwapJudge[tid] = false;
    
    return;
}

//------------------------------------------------

public ShowMatchMenu( id, level, cid )
{
    if( !cmd_access( id, level, cid, 1 ) ) return PLUGIN_HANDLED;

    static szMenu[512], len;
    
    len = formatex( szMenu, 511, "\y%L^n^n", LANG_SERVER, "PUG_MENU_MATCHTITLE" );
    len += formatex( szMenu[len], 511 - len, "\r1.  \w%L^n", LANG_SERVER, "PUG_MENU_MATCHSTARTKNIFE" );
    len += formatex( szMenu[len], 511 - len, "\r2.  \w%L^n", LANG_SERVER, "PUG_MENU_MATCHSTARTNOKNIFE" );
    len += formatex( szMenu[len], 511 - len, "\r3.  \w%L^n", LANG_SERVER, "PUG_MENU_MATCHHALFR3" );
    len += formatex( szMenu[len], 511 - len, "\r4.  \w%L^n", LANG_SERVER, "PUG_MENU_MATCHRER3" );
    len += formatex( szMenu[len], 511 - len, "\r5.  \w%L^n", LANG_SERVER, "PUG_MENU_MATCHSTOP" );
    len += formatex( szMenu[len], 511 - len, "\r6.  \w%L^n", LANG_SERVER, "PUG_MENU_MATCHPAUSE" );
    len += formatex( szMenu[len], 511 - len, "^n\r0.  \w%L^n", LANG_SERVER, "PUG_MENU_EXITNAME" );
    
    show_menu( id, 0x23f, szMenu, -1, "PUG Admin Menu" );
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public cmdMatchMenu( id, key )
{       
    switch( key ) {
        case 0: client_cmd( id, "hp_forcestart -knife" );
        case 1: client_cmd( id, "hp_forcestart -noknife" );
        case 2: client_cmd( id, "hp_forcehalfr3" );
        case 3: client_cmd( id, "hp_forcerer3" );
        case 4: client_cmd( id, "hp_forcestop" );
        case 5: client_cmd( id, "amx_pause" );
    }
    
    return;
}

//------------------------------------------------

public ShowVoteMap( id )
{
    if( g_bIsOnVote ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_MENU_ALRDYVOTE" );
        return PLUGIN_HANDLED;
    }
    if( StatLive() ) {
        client_print( id, print_center, "%L", LANG_SERVER, "PUG_CANTUSECMD" );
        return PLUGIN_HANDLED;
    }
    
    static Msg[512], len, mapname[32], nowmap[32];
    new smap = MAP_VOTE_NUM, i, j, k, bool: MapChosen[32];
    
    get_mapname( nowmap, 31 );
    if( smap > g_Mapnum - 1 ) smap = g_Mapnum - 1;
    k = smap;
    for( i = 0; i < g_Mapnum; i++ ) {
        ArrayGetString( g_Maps, i, mapname, 31 );
        if( equal( mapname, nowmap ) ) {
            MapChosen[i] = true;
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
        g_VoteMapid[smap - k] = j;
        g_VoteCount[smap - k] = 0;
        k--;
    }
    show_menu( 0, 0x1f, Msg, 10, "Vote Map Menu" );
    set_task( 10.0, "VoteMapJudge" );
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public cmdVoteMap( id, key )
{
    static mapname[32], name[32];
    new pos = g_VoteMapid[key];
    
    get_user_name( id, name, 31 );
    ArrayGetString( g_Maps, pos, mapname, 31 );
    g_VoteCount[key]++;
    client_print( 0, print_chat, "%L", LANG_SERVER, "PUG_MENU_VOTEDMSG", name, mapname );
    
    return;
}

//------------------------------------------------

public VoteMapJudge()
{
    new i, mapname[32], max = 0, pos;
    
    for( i = 0; i < 5; i++ )
        if( g_VoteCount[i] > max ) {
            max = g_VoteCount[i];
            pos = g_VoteMapid[i];
        }
    
    if( max == 0 ) {
        client_print( 0, print_chat, "%L", LANG_SERVER, "PUG_MENU_INVALIDVOTE" );
        return;
    }
    
    ArrayGetString( g_Maps, pos, mapname, 31 );
    client_print( 0, print_chat, "%L", LANG_SERVER, "PUG_MENU_VOTEMAPRES", mapname );
    set_task( 3.0, "DelayChangelevel", _, mapname, 31 );
    g_bIsOnVote = false;
    
    return;
}

//------------------------------------------------

public DelayChangelevel( const mapname[] )
{
    server_cmd( "amx_map %s", mapname );
    
    return;
}

//------------------------------------------------

public ShowVoteKick( tid )
{
    if( g_bIsOnVote ) {
        client_print( tid, print_center, "%L", LANG_SERVER, "PUG_MENU_ALRDYVOTE" );
        return PLUGIN_HANDLED;
    }
    
    static Msg[128], teamname[32], name[32], szid[3];
    new hMenu, i, id, CsTeams: team;
    
    g_bIsOnVote = true;
    formatex( Msg, 127, "\y%L", LANG_SERVER, "PUG_MENU_VOTEKICKTITLE" );
    hMenu = menu_create( Msg, "cmdVoteKick" );
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
    menu_display( tid, hMenu, 0 );
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public cmdVoteKick( id, menu, item )
{
    static voted[32], tid, kicker[32], teamname[32], szMenu[256], len;
    new _access, item_callback, CsTeams: team;
    
    menu_item_getinfo( menu, item, _access, voted, 31, kicker, 31, item_callback );
    menu_destroy( menu );
    tid = str_to_num( voted );
    
    if( item == MENU_EXIT ) {
        g_bIsOnVote = false;
        return;
    }
    
    g_kickid = tid;
    g_kickagree = 0;
    get_user_name( tid, voted, 31 );
    get_user_name( id, kicker, 31 );
    team = cs_get_user_team( tid );
    switch( team ) {
        case CS_TEAM_T: formatex( teamname, 31, "%L", LANG_SERVER, "PUG_TNAME" );
        case CS_TEAM_CT: formatex( teamname, 31, "%L", LANG_SERVER, "PUG_CTNAME" );
        case CS_TEAM_SPECTATOR: formatex( teamname, 31, "%L", LANG_SERVER, "PUG_SPECNAME" );
    }
    len = formatex( szMenu, 255, "\y%L^n^n", LANG_SERVER, "PUG_MENU_KICKASKTITLE", kicker, teamname, voted );
    len += formatex( szMenu[len], 255 - len, "\r1.  \w%L^n", LANG_SERVER, "PUG_MENU_KICKAGREE" );
    len += formatex( szMenu[len], 255 - len, "\r2.  \w%L", LANG_SERVER, "PUG_MENU_KICKREJ" );
    show_menu( 0, 3, szMenu, 10, "Ask for Kick" );
    set_task( 10.0, "AskMenuJudge" );
    
    return;
}

//------------------------------------------------

public cmdAskMenu( id, key )
{
    static name[32];
    
    get_user_name( id, name, 31 );
    if( key == 0 ) {
        g_kickagree++;
        client_print( 0, print_chat, "%L", LANG_SERVER, "PUG_MENU_AGREEKICKMSG", name );
    }
    else
        client_print( 0, print_chat, "%L", LANG_SERVER, "PUG_MENU_REJKICKMSG", name );
        
    return;
}

//------------------------------------------------

public AskMenuJudge()
{
    new tot = get_playersnum( 0 );
    new Float: ratio;
    static name[32];
        
    ratio = float( g_kickagree ) / float( tot );
    if( ratio >= 0.5 ) {
        client_print( 0, print_chat, "%L", LANG_SERVER, "PUG_MENU_KICKRESAGREE" );
        get_user_name( g_kickid, name, 31 );
        server_cmd( "kick ^"%s^"", name );
    }
    else
        client_print( 0, print_chat, "%L", LANG_SERVER, "PUG_MENU_KICKRESREJ" );
    g_bIsOnVote = false;
    
    return;
}

//------------------------------------------------

public ShowPlayerMenu( id )
{
    static Msg[128], szid[2];
    new hMenu;
    
    formatex( Msg, 127, "\y%L", LANG_SERVER, "PUG_MENU_PLTITLE" );
    hMenu = menu_create( Msg, "cmdPlayerMenu" );
    szid[1] = 0;
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PLVOTEMAP" );
    szid[0] = 0x30 + 1;
    menu_additem( hMenu, Msg, szid, ADMIN_ALL );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PLVOTEKICK" );
    szid[0] = 0x30 + 2;
    menu_additem( hMenu, Msg, szid, ADMIN_ALL );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_RESTROUND" );
    szid[0] = 0x30 + 3;
    menu_additem( hMenu, Msg, szid, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_ITEMMATCH" );
    szid[0] = 0x30 + 4;
    menu_additem( hMenu, Msg, szid, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHMAP" );
    szid[0] = 0x30 + 5;
    menu_additem( hMenu, Msg, szid, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHKICK" );
    szid[0] = 0x30 + 6;
    menu_additem( hMenu, Msg, szid, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHTEAM" );
    szid[0] = 0x30 + 7;
    menu_additem( hMenu, Msg, szid, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHSLAY" );
    szid[0] = 0x30 + 8;
    menu_additem( hMenu, Msg, szid, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_MATCHBAN" );
    szid[0] = 0x30 + 9;
    menu_additem( hMenu, Msg, szid, ADMIN_ADMIN );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_EXITNAME" );
    menu_setprop( hMenu, MPROP_EXITNAME, Msg );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_NEXTPAGE" );
    menu_setprop( hMenu, MPROP_NEXTNAME, Msg );
    formatex( Msg, 127, "%L", LANG_SERVER, "PUG_MENU_PREVPAGE" );
    menu_setprop( hMenu, MPROP_BACKNAME, Msg );
    menu_display( id, hMenu, 0 );
    
    return PLUGIN_HANDLED;
}

//------------------------------------------------

public cmdPlayerMenu( id, menu, item )
{
    static voted[32], tid, kicker[32];  
    new _access, item_callback;
    
    menu_item_getinfo( menu, item, _access, voted, 31, kicker, 31, item_callback );
    menu_destroy( menu );
    tid = str_to_num( voted );
    
    if( item == MENU_EXIT ) return;
    
    switch( tid ) {
        case 1: ShowVoteMap( id );
        case 2: ShowVoteKick( id );
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

// FORCE Command Part===========================================================
//
//
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
    if( g_StatusNow == STATUS_KNIFE1 || g_StatusNow == STATUS_KNIFE2 ) {
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
    if( g_StatusNow == STATUS_KNIFE1 || g_StatusNow == STATUS_KNIFE2 ) {
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

//------------------------------------------------

public ForceRefreshInfo( id, level, cid )
{
    if( !cmd_access( id, level, cid, 1 ) ) return PLUGIN_HANDLED;
    
    RefreshReadyList();
    
    return PLUGIN_HANDLED;
}


// PLUGIN INIT function=========================================================
//
//
//==============================================================================

public plugin_cfg()
{
    g_HudPlRdyPosFlag[0] = 2;
    set_task( 1.0, "CheckHostName" );
    
    readMap();
    
    EnterWarm();
    
    return;
}

public plugin_init()
{
    register_plugin( PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR );
    
    register_dictionary( "hustcommon.txt" );

    g_pcKnifeRound = register_cvar( "hp_kniferound", "1" );
    g_pcTeamLimit = register_cvar( "hp_teamlimit", "1" );
    g_pcShowMoney = register_cvar( "hp_showmoney", "1" );
    g_pcIntermission = register_cvar( "hp_intermission", "0" );
    g_pcAmxShowAct = get_cvar_pointer( "amx_show_activity" );
    g_pcHostName = get_cvar_pointer( "hostname" );
    
    register_clcmd( "say !ready", "PlayerReady", ADMIN_ALL, " - use command to enter ready status" );
    register_clcmd( "say !notready", "PlayerUNReady", ADMIN_ALL, " - use command to cancel ready status" );
    register_clcmd( "jointeam", "PlayerJoin", ADMIN_ALL, " - hook teamchange of user" );
    register_clcmd( "chooseteam", "HookChooseTeam", ADMIN_ALL, " - hook choose team" );
    register_clcmd( "hp_matchmenu", "ShowMatchMenu", PLUGIN_ACCESS, " - show admin menu" );
    register_clcmd( "say !votemap", "ShowVoteMap", ADMIN_ALL, " - hold a vote for change map" );
    register_clcmd( "say !votekick", "ShowVoteKick", ADMIN_ALL, " - hold a vote for kick player" );
    register_clcmd( "say !menu", "ShowPlayerMenu", ADMIN_ALL, " - open player menu" );
    register_clcmd( "say menu", "ShowPlayerMenu", ADMIN_ALL, " - open player menu" );
    
    register_concmd( "hp_forcestart", "ForceStart", PLUGIN_ACCESS, " - use this command to force start game" );
    register_concmd( "hp_forcerer3", "ForceReR3", PLUGIN_ACCESS, " - use this command to restart whole match" );
    register_concmd( "hp_forcehalfr3", "ForceHalfR3", PLUGIN_ACCESS, " - use this command to restart half matching" );
    register_concmd( "hp_forcestop", "ForceStop", PLUGIN_ACCESS, " - use this command to force the game stop and enter warm section" );
    register_concmd( "hp_forceswap", "ForceSwap", PLUGIN_ACCESS, " - use this command to force team swap" );
    register_concmd( "hp_forcerefreshinfo", "ForceRefreshInfo", PLUGIN_ACCESS, " - use this command to force refresh player info" );
    
    register_event( "TeamScore", "eventTeamScore", "a" );
    register_event( "CurWeapon", "eventCurWeapon", "be" );
    register_event( "HLTV", "eventNewRoundStart", "a", "1=0", "2=0" );
    register_event( "ResetHUD", "eventResetHUD", "b" );
    register_event( "TeamInfo", "eventTeamInfo", "a" );
    
    g_hamPostSpawn = RegisterHam( Ham_Spawn, "player", "hamPostPlayerSpawn", 1 );
    g_hamFwdDeath = RegisterHam( Ham_Killed, "player", "hamFwdPlayerDeath", 0 );
    g_hamPostTouch[0] = RegisterHam( Ham_Touch, "armoury_entity", "hamPostWeaponTouch", 1 );
    g_hamPostTouch[1] = RegisterHam( Ham_Touch, "weaponbox", "hamPostWeaponTouch", 1 );
    g_hamPostTouch[2] = RegisterHam( Ham_Touch, "weapon_shield", "hamPostWeaponTouch", 1 );
    
    g_msgidTeamScore = get_user_msgid( "TeamScore" );
    g_msgidHideWeapon = get_user_msgid( "HideWeapon" );
    g_msgidRoundTime = get_user_msgid( "RoundTime" );
    g_msgidWeapPickup = get_user_msgid( "WeapPickup" );
    
    register_message( get_user_msgid( "ShowMenu" ), "HookTeamMenu" );
    register_message( get_user_msgid( "VGUIMenu" ), "HookVGuiTeamMenu" );
    register_message( g_msgidTeamScore, "MsgTeamScore" );
    
    register_menu( "KnifeRound Won Menu", 0x3ff, "cmdPickTeamMenu", 0 );
    register_menu( "PUG Team Menu", 0x3ff, "cmdPUGTeamMenu", 0 );
    register_menu( "Agree to swap?", 0x3ff, "cmdSwapAsk", 0 );
    register_menu( "PUG Admin Menu", 0x3ff, "cmdMatchMenu", 0 );
    register_menu( "Vote Map Menu", 0x3ff, "cmdVoteMap", 0 );
    register_menu( "Ask for Kick", 0x3ff, "cmdAskMenu", 0 );
    
    return;
}
