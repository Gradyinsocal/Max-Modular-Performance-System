///////////////////////////////////////////////////////////////
//
// Max Modular Instrument Bus (MMIB)
// Script: MMIB_OperatingSystem_v1_0_1.lsl
// Version: 1.0.1
// Status: Development - Health Monitoring Unit Test
//
// Designed by Max Pitre
// Programming Assistance by OpenAI ChatGPT
//
///////////////////////////////////////////////////////////////


// ============================================================
// CONFIGURATION
// ============================================================

integer DEBUG_MODE = TRUE;

integer MMIB_REGISTER      = 8100;
integer MMIB_EVENT         = 8110;
integer MMIB_ROUTE         = 8111;
integer MMIB_ACK           = 8112;
integer MMIB_STATE_SET     = 8120;
integer MMIB_STATE_GET     = 8121;
integer MMIB_STATE_REPLY   = 8122;
integer MMIB_HEALTH_GET    = 8130;
integer MMIB_HEALTH_REPLY  = 8131;

float REGISTRATION_WINDOW = 1.50;


// ============================================================
// VALID SYSTEM STATES
// ============================================================

list VALID_STATES =
[
    "STOPPED",
    "READY",
    "PERFORMING",
    "PAUSED",
    "ERROR"
];

string gSystemState = "STOPPED";


// ============================================================
// EXPECTED MODULES
// ============================================================

list REQUIRED_MODULES =
[
    "Console Manager",
    "Performance Engine",
    "Animation Engine",
    "Access Manager"
];

list OPTIONAL_MODULES =
[
    "Lighting Engine",
    "MMME Music Engine"
];


// ============================================================
// REGISTRY
// Stride: Name, Version, Type, Registration Time
// ============================================================

integer REGISTRY_STRIDE = 4;

list gRegistry = [];

integer gStartupReportPrinted = FALSE;
integer gReady = FALSE;
float gBootTime = 0.0;


// ============================================================
// UTILITIES
// ============================================================

debugSay(string message)
{
    if (DEBUG_MODE)
    {
        llOwnerSay("[MMIB] " + message);
    }
}


integer findModule(string moduleName)
{
    integer count = llGetListLength(gRegistry);
    integer index;

    for (index = 0; index < count; index += REGISTRY_STRIDE)
    {
        if (llList2String(gRegistry, index) == moduleName)
        {
            return index;
        }
    }

    return -1;
}


registerModule(
    string moduleName,
    string version,
    string moduleType
)
{
    moduleName = llStringTrim(moduleName, STRING_TRIM);
    version = llStringTrim(version, STRING_TRIM);
    moduleType = llToUpper(
        llStringTrim(moduleType, STRING_TRIM)
    );

    if (moduleName == "" || version == "")
    {
        return;
    }

    if (
        moduleType != "REQUIRED" &&
        moduleType != "OPTIONAL"
    )
    {
        moduleType = "OPTIONAL";
    }

    list entry =
    [
        moduleName,
        version,
        moduleType,
        llGetTime()
    ];

    integer existing = findModule(moduleName);

    if (existing >= 0)
    {
        gRegistry = llListReplaceList(
            gRegistry,
            entry,
            existing,
            existing + REGISTRY_STRIDE - 1
        );
    }
    else
    {
        gRegistry += entry;
    }
}


integer isRegistered(string moduleName)
{
    return (findModule(moduleName) >= 0);
}


string moduleVersion(string moduleName)
{
    integer index = findModule(moduleName);

    if (index < 0)
    {
        return "";
    }

    return llList2String(gRegistry, index + 1);
}


string paddedName(string moduleName)
{
    string result = moduleName;

    while (llStringLength(result) < 26)
    {
        result += ".";
    }

    return result;
}


integer countRegistered(list expectedModules)
{
    integer registered = 0;
    integer count = llGetListLength(expectedModules);
    integer index;

    for (index = 0; index < count; ++index)
    {
        if (isRegistered(llList2String(expectedModules, index)))
        {
            ++registered;
        }
    }

    return registered;
}


list missingModules(list expectedModules)
{
    list missing = [];
    integer count = llGetListLength(expectedModules);
    integer index;

    for (index = 0; index < count; ++index)
    {
        string moduleName =
            llList2String(expectedModules, index);

        if (!isRegistered(moduleName))
        {
            missing += [moduleName];
        }
    }

    return missing;
}


string listOrNone(list values)
{
    if (llGetListLength(values) == 0)
    {
        return "NONE";
    }

    return llDumpList2String(values, ", ");
}


printModuleLines(list expectedModules)
{
    integer count = llGetListLength(expectedModules);
    integer index;

    for (index = 0; index < count; ++index)
    {
        string moduleName =
            llList2String(expectedModules, index);

        if (isRegistered(moduleName))
        {
            debugSay(
                paddedName(moduleName) +
                " OK (v" +
                moduleVersion(moduleName) +
                ")"
            );
        }
        else
        {
            debugSay(
                paddedName(moduleName) +
                " NOT REGISTERED"
            );
        }
    }
}


string overallHealth()
{
    integer requiredExpected =
        llGetListLength(REQUIRED_MODULES);

    integer requiredReady =
        countRegistered(REQUIRED_MODULES);

    integer optionalExpected =
        llGetListLength(OPTIONAL_MODULES);

    integer optionalReady =
        countRegistered(OPTIONAL_MODULES);

    if (requiredReady < requiredExpected)
    {
        return "CRITICAL";
    }

    if (optionalReady < optionalExpected)
    {
        return "DEGRADED";
    }

    return "HEALTHY";
}


printStartupReport()
{
    if (gStartupReportPrinted)
    {
        return;
    }

    gStartupReportPrinted = TRUE;

    integer requiredExpected =
        llGetListLength(REQUIRED_MODULES);

    integer requiredReady =
        countRegistered(REQUIRED_MODULES);

    integer optionalExpected =
        llGetListLength(OPTIONAL_MODULES);

    integer optionalReady =
        countRegistered(OPTIONAL_MODULES);

    gReady = (requiredReady == requiredExpected);
    gBootTime = llGetTime();

    if (gReady)
    {
        gSystemState = "READY";
    }
    else
    {
        gSystemState = "ERROR";
    }

    if (!DEBUG_MODE)
    {
        return;
    }

    debugSay("");
    debugSay("Module Registration Report");
    debugSay("--------------------------------");

    printModuleLines(REQUIRED_MODULES);
    printModuleLines(OPTIONAL_MODULES);

    debugSay("--------------------------------");

    debugSay(
        "Required Modules: " +
        (string)requiredReady +
        " / " +
        (string)requiredExpected
    );

    debugSay(
        "Optional Modules: " +
        (string)optionalReady +
        " / " +
        (string)optionalExpected
    );

    debugSay(
        "Missing Required: " +
        listOrNone(
            missingModules(REQUIRED_MODULES)
        )
    );

    debugSay(
        "Missing Optional: " +
        listOrNone(
            missingModules(OPTIONAL_MODULES)
        )
    );

    debugSay(
        "Boot Time: " +
        (string)gBootTime +
        " seconds"
    );

    debugSay("STATE: " + gSystemState);
    debugSay("HEALTH: " + overallHealth());
    debugSay("--------------------------------");
}


routeEvent(
    string sourceModule,
    string eventName,
    string payload
)
{
    sourceModule = llStringTrim(
        sourceModule,
        STRING_TRIM
    );

    eventName = llToUpper(
        llStringTrim(
            eventName,
            STRING_TRIM
        )
    );

    if (
        sourceModule == "" ||
        eventName == ""
    )
    {
        return;
    }

    if (!gReady)
    {
        llMessageLinked(
            LINK_SET,
            MMIB_ACK,
            "ACK|" +
            eventName +
            "|" +
            sourceModule +
            "|BUS_NOT_READY",
            NULL_KEY
        );

        return;
    }

    string routePacket =
        "ROUTE|" +
        eventName +
        "|" +
        sourceModule;

    if (payload != "")
    {
        routePacket += "|" + payload;
    }

    llMessageLinked(
        LINK_SET,
        MMIB_ROUTE,
        routePacket,
        NULL_KEY
    );

    llMessageLinked(
        LINK_SET,
        MMIB_ACK,
        "ACK|" +
        eventName +
        "|" +
        sourceModule +
        "|OK",
        NULL_KEY
    );

    if (DEBUG_MODE)
    {
        debugSay(
            "Routed " +
            eventName +
            " from " +
            sourceModule
        );
    }
}


integer validState(string stateName)
{
    return (
        llListFindList(
            VALID_STATES,
            [stateName]
        ) >= 0
    );
}


setSystemState(
    string sourceModule,
    string requestedState
)
{
    requestedState = llToUpper(
        llStringTrim(
            requestedState,
            STRING_TRIM
        )
    );

    if (!validState(requestedState))
    {
        llMessageLinked(
            LINK_SET,
            MMIB_STATE_REPLY,
            "STATE|INVALID|" +
            gSystemState + "|" +
            sourceModule,
            NULL_KEY
        );

        return;
    }

    gSystemState = requestedState;

    llMessageLinked(
        LINK_SET,
        MMIB_STATE_REPLY,
        "STATE|SET|" +
        gSystemState + "|" +
        sourceModule,
        NULL_KEY
    );

    if (DEBUG_MODE)
    {
        debugSay(
            "State changed to " +
            gSystemState +
            " by " +
            sourceModule
        );
    }
}


replyWithState(string requestingModule)
{
    llMessageLinked(
        LINK_SET,
        MMIB_STATE_REPLY,
        "STATE|CURRENT|" +
        gSystemState + "|" +
        requestingModule,
        NULL_KEY
    );
}


replyWithHealth(string requestingModule)
{
    integer requiredExpected =
        llGetListLength(REQUIRED_MODULES);

    integer requiredReady =
        countRegistered(REQUIRED_MODULES);

    integer optionalExpected =
        llGetListLength(OPTIONAL_MODULES);

    integer optionalReady =
        countRegistered(OPTIONAL_MODULES);

    string packet =
        "HEALTH|" +
        overallHealth() + "|" +
        gSystemState + "|" +
        (string)requiredReady + "|" +
        (string)requiredExpected + "|" +
        (string)optionalReady + "|" +
        (string)optionalExpected + "|" +
        listOrNone(
            missingModules(REQUIRED_MODULES)
        ) + "|" +
        listOrNone(
            missingModules(OPTIONAL_MODULES)
        ) + "|" +
        (string)gBootTime + "|" +
        requestingModule;

    llMessageLinked(
        LINK_SET,
        MMIB_HEALTH_REPLY,
        packet,
        NULL_KEY
    );
}


// ============================================================
// DEFAULT STATE
// ============================================================

default
{
    state_entry()
    {
        llResetTime();

        gRegistry = [];
        gStartupReportPrinted = FALSE;
        gReady = FALSE;
        gSystemState = "STOPPED";
        gBootTime = 0.0;

        if (DEBUG_MODE)
        {
            debugSay("Booting MMIB Operating System v1.0.1...");
        }

        llSetTimerEvent(REGISTRATION_WINDOW);
    }


    on_rez(integer startParameter)
    {
        llResetScript();
    }


    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }


    link_message(
        integer senderNumber,
        integer number,
        string message,
        key id
    )
    {
        list fields =
            llParseStringKeepNulls(
                message,
                ["|"],
                []
            );

        if (number == MMIB_REGISTER)
        {
            if (llGetListLength(fields) < 4)
            {
                return;
            }

            if (
                llToUpper(
                    llList2String(fields, 0)
                ) != "REGISTER"
            )
            {
                return;
            }

            registerModule(
                llList2String(fields, 1),
                llList2String(fields, 2),
                llList2String(fields, 3)
            );
        }
        else if (number == MMIB_EVENT)
        {
            if (llGetListLength(fields) < 3)
            {
                return;
            }

            if (
                llToUpper(
                    llList2String(fields, 0)
                ) != "EVENT"
            )
            {
                return;
            }

            string payload = "";

            if (llGetListLength(fields) > 3)
            {
                payload =
                    llDumpList2String(
                        llList2List(
                            fields,
                            3,
                            -1
                        ),
                        "|"
                    );
            }

            routeEvent(
                llList2String(fields, 1),
                llList2String(fields, 2),
                payload
            );
        }
        else if (number == MMIB_STATE_SET)
        {
            if (llGetListLength(fields) < 3)
            {
                return;
            }

            if (
                llToUpper(
                    llList2String(fields, 0)
                ) != "SET_STATE"
            )
            {
                return;
            }

            setSystemState(
                llList2String(fields, 1),
                llList2String(fields, 2)
            );
        }
        else if (number == MMIB_STATE_GET)
        {
            if (llGetListLength(fields) < 2)
            {
                return;
            }

            if (
                llToUpper(
                    llList2String(fields, 0)
                ) != "GET_STATE"
            )
            {
                return;
            }

            replyWithState(
                llList2String(fields, 1)
            );
        }
        else if (number == MMIB_HEALTH_GET)
        {
            if (llGetListLength(fields) < 2)
            {
                return;
            }

            if (
                llToUpper(
                    llList2String(fields, 0)
                ) != "GET_HEALTH"
            )
            {
                return;
            }

            replyWithHealth(
                llList2String(fields, 1)
            );
        }
    }


    timer()
    {
        llSetTimerEvent(0.0);
        printStartupReport();
    }
}
