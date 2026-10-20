#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()
Info("loadServer Starting.");
if (isServer) then {
    Info("Starting Persistent Load.");
	petros allowdamage false;

	// Tell third party mods we're loading the game. Do this very early in case
	// they attempt to overwrite stuff we're loading later below.
	["saveDataPlugins"] call A3A_fnc_getStatVariable;
	private _saveDataPlugins = RETNIL(saveDataPlugins);

	if (isNil "_saveDataPlugins") then {
		_saveDataPlugins = createHashMap;
	} else {
		if (_saveDataPlugins isEqualType []) then {
			// Possible involuntary conversion from hashmap to array
			_saveDataPlugins = createHashMapFromArray _saveDataPlugins;
		};
	};

	if !assert(_saveDataPlugins isEqualType createHashMap) then {
		Error_1("Plugins save data has unexpected type ""%1""",typeName _saveDataPlugins);
		_saveDataPlugins = createHashMap;
	};

	[CBA_EVENT_SERVER_GAME_LOAD, [_saveDataPlugins]] call FUNCMAIN(triggerLocalEvent);

	// Set all main markers to occupant control by default, overridden by mrkSDK & mrkCSAT
	{
		if (sidesX getVariable _x != Occupants) then { sidesX setVariable [_x, Occupants, true] };
	} forEach (airportsX + resourcesX + factories + outposts + seaports + milbases);

	A3A_saveVersion = 0;
	{ [_x] call A3A_fnc_getStatVariable } forEach [
		"A3A_fuelAmountleftArray",
		"aapostsFIA",
		"aggressionInvaders",
		"aggressionOccupants",
		"antennas",
		"areInvadersDefeated",
		"areOccupantsDefeated",
		"areRivalsDefeated",
		"areRivalsDiscovered",
		"atpostsFIA",
		"bombRuns",
		"chopForest",
		"constructionsX",
		"controlsSDK",
		"dateX",
		"destroyedBuildings",
		"destroyedMilAdmins",
		"destroyedSites",
		"enemyResources",
		"garrison",
		"hmgpostsFIA",
		"HQKnowledge",
		"HR_Garage",
		"hr",
		"inactivityRivals",
		"invaderRadioKeys",
		"isRivalsDiscoveryQuestAssigned",
		"isTraderQuestAssigned",
		"isTraderQuestCompleted",
		"jna_dataList",
		"killZones",
		"membersX",
		"minesX",
		"mrkCSAT",
		"mrkSDK",
		"nextRivalsLocationReveal",
		"nextTick",
		"occupantsRadioKeys",
		"posHQ",
		"prestigeBLUFOR",
		"prestigeOPFOR",
		"randomizeRebelLoadoutUniforms",
		"rebelLoadouts",
		"resourcesFIA",
		"revealedZones",
		"rivalsExcludedLocations",
		"rivalsLocationsMap",
		"roadblocksFIA",
		"skillFIA",
		"staticsX",
		"supportPoints",
		"tasks",
		"testingTimerIsActive",
		"traderDiscount",
		"traderPosition",
		"unlockedVehicleTypes",
		"usesWurzelGarrison",
		"version",
		"watchpostsFIA",
		"weather",
		"wurzelGarrison"
	];

	{ publicVariable _x } forEach [
		"aapostsFIA",
		"atpostsFIA",
		"hmgpostsFIA",
        "invaderRadioKeys",
		"occupantsRadioKeys",
		"revealedZones",
		"roadblocksFIA",
		"unlockedVehicleTypes",
        "watchpostsFIA"
	];

	// PCF Resource and Factory Upgrade System Load Start
	if (PCF_EnableResourceUpgrade) then {
		Info("PCF: Loading Resource and Factory Upgrade data");
		
		// Load Resource and Factory Levels Arrays
		["A3UE_ResourceLevels"] call A3A_fnc_getStatVariable;
		["A3UE_FactoryLevels"] call A3A_fnc_getStatVariable;
		
		// Restore individual resource levels and calculate total
		private _loadedResourceLevels = missionNamespace getVariable ["A3UE_ResourceLevels", []];
		private _totalRes = 0;
		if (_loadedResourceLevels isEqualType []) then {
			{
				_x params ["_markerName", "_level"];
				missionNamespace setVariable [format ["A3UE_ResourceUpgradeLevel_%1", _markerName], _level, true];
				_totalRes = _totalRes + _level;
			} forEach _loadedResourceLevels;
			Info_1("PCF: Restored %1 resource upgrade levels from main array", count _loadedResourceLevels);
		};
		
		// Restore individual factory levels and calculate total
		private _loadedFactoryLevels = missionNamespace getVariable ["A3UE_FactoryLevels", []];
		private _totalFac = 0;
		if (_loadedFactoryLevels isEqualType []) then {
			{
				_x params ["_markerName", "_level"];
				missionNamespace setVariable [format ["A3UE_FactoryUpgradeLevel_%1", _markerName], _level, true];
				_totalFac = _totalFac + _level;
			} forEach _loadedFactoryLevels;
			Info_1("PCF: Restored %1 factory upgrade levels from main array", count _loadedFactoryLevels);
		};
		
		// Set and broadcast true totals globally to all clients
		missionNamespace setVariable ["A3UE_TotalRebelResourceUpgrades", _totalRes, true];
		missionNamespace setVariable ["A3UE_TotalRebelFactoryUpgrades", _totalFac, true];
		missionNamespace setVariable ["A3UE_TotalRebelUpgrades", _totalRes + _totalFac, true];
		
		Info("PCF: Resource and Factory Upgrade data loaded successfully");
	} else {
		Info("PCF: Resource and Factory Upgrades disabled, skipping load");
	};
	// PCF Resource and Factory Upgrade System Load End

	//===========================================================================

	//RESTORE THE STATE OF THE 'UNLOCKED' VARIABLES USING JNA_DATALIST
	private _categoriesToPublish = createHashMap;
	{
		private _arsenalTabDataArray = _x;
		private _unlockedItemsInTab = _arsenalTabDataArray select { _x select 1 == -1 } apply { _x select 0 };
		{
			private _categories = [_x, true, true] call A3A_fnc_unlockEquipment;
			_categoriesToPublish insert [true, _categories, []];
		} forEach _unlockedItemsInTab;
	} forEach jna_dataList;

	Info_1("Categories to publish: %1", keys _categoriesToPublish);

	// Publish the unlocked categories (once each)
	{ publicVariable ("unlocked" + _x) } forEach keys _categoriesToPublish;

	//Check if we have radios unlocked and update haveRadio.
	call A3A_fnc_checkRadiosUnlocked;

	// Set enemy roadblock allegiance to match nearest main marker
	private _mainMarkers = markersX - controlsX -  watchpostsFIA - roadblocksFIA - aapostsFIA - atpostsFIA - hmgpostsFIA;
    {
        if (sidesX getVariable [_x,sideUnknown] != teamPlayer) then {
            private _nearX = [_mainMarkers, markerPos _x] call BIS_fnc_nearestPosition;
            private _sideX = sidesX getVariable [_nearX,sideUnknown];
            sidesX setVariable [_x,_sideX,true];
        };
    } forEach controlsX;

    [markersX - controlsX] call A3U_fnc_mrkUpdateBulk;
    if !(milAdministrationsX isEqualTo []) then {[milAdministrationsX] call A3U_fnc_mrkUpdateBulk};
    if !(mrkAntennas isEqualTo []) then {[mrkAntennas] call A3U_fnc_mrkUpdateBulk};
    // ---------------------------

	markersX append (watchpostsFIA + roadblocksFIA + aapostsFIA + atpostsFIA + hmgpostsFIA);
	publicVariable "markersX";

	{
		if (_x in destroyedSites) then {
			sidesX setVariable [_x, Invaders, true];
			[_x] call A3A_fnc_destroyCity
		};
	} forEach citiesX;

    //Load aggro stacks and level and calculate current level
    [true] call A3A_fnc_calculateAggression;
	[true] call SCRT_fnc_rivals_calculateActivity;

	{_x setPos getMarkerPos respawnTeamPlayer} forEach ((call A3A_fnc_playableUnits) select {side _x == teamPlayer});
	_sites = markersX select {sidesX getVariable [_x,sideUnknown] == teamPlayer};

	// Move headless client logic objects near HQ so that firedNear EH etc. work more reliably
	private _hcpos = markerPos respawnTeamPlayer vectorAdd [-100, -100, 0];
	{ _x setPosATL _hcpos } forEach (entities "HeadlessClient_F");

	tierPreference = 1;
	publicVariable "tierPreference";
	// update war tier silently, calls updatePreference if changed
	[true] call A3A_fnc_tierCheck;

	if (isNil "usesWurzelGarrison") then {
		//Create the garrison new
        Info("No WurzelGarrison found, creating new!");
		[airportsX, "Airport", [0,0,0]] spawn A3A_fnc_createGarrison;	//New system
		[resourcesX, "Other", [0,0,0]] spawn A3A_fnc_createGarrison;	//New system
		[milbases, "MilitaryBase", [0,0,0]] spawn A3A_fnc_createGarrison;	//New system
		[factories, "Other", [0,0,0]] spawn A3A_fnc_createGarrison;
		[outposts, "Outpost", [1,1,0]] spawn A3A_fnc_createGarrison;
		[seaports, "Other", [1,0,0]] spawn A3A_fnc_createGarrison;

	};

    // Load all player data into A3A_playerSaveData hashmap. Works around issues with game copies
	_savedPlayers = "savedPlayers" call A3A_fnc_returnSavedStat;
	if (isNil "_savedPlayers") then { _savedPlayers = [] };
	{
		private _uid = _x;
		private _playerData = createHashMap;
		{
			_playerData set [_x, [_uid, _x] call A3A_fnc_retrievePlayerStat];
		} forEach ["moneyX", "loadoutPlayer", "scorePlayer", "rankPlayer", "personalGarage", "pluginsData"];

		if (isNil {_playerData get "moneyX"}) then { Error_1("Saved player %1 has no money var", _uid); continue };
		A3A_playerSaveData set [_uid, _playerData];
	} forEach _savedPlayers;

    Info("Persistent Load Completed.");

	[CBA_EVENT_SERVER_SPAWN_LOCATION, LINKFUNCMAIN(crewLocationStatics)] call FUNCMAIN(addEventHandler);

	statsLoaded = 0; publicVariable "statsLoaded";
	petros allowdamage true;

	{specialVarLoads deleteAt _x;} forEach (keys specialVarLoads);
	specialVarLoads = nil;
};
Info("loadServer Completed.");
