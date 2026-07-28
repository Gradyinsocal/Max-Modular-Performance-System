///////////////////////////////////////////////////////////////
//
// Max Modular Performance System
// MMPS Airwaves Core Manager
//
// Script: MMPS_AirwavesCoreManager_v1_2_1.lsl
// Version: 1.2.1
//
// CLEAN STATION INTEGRATION BUILD
//
// RESPONSIBILITY
// - Preserves verified pairing, heartbeat, and streaming.
// - Tracks the selected live Gateway.
// - Accepts linked commands from the Station Menu.
// - Sends targeted SET_URL and OFF commands.
// - Requires sequence-matched acknowledgments.
// - Stores current streaming state.
// - Does not read station notecards.
//
///////////////////////////////////////////////////////////////


// ============================================================
// MMIB
// ============================================================

integer MMIB_REGISTER = 8100;
integer MMIB_EVENT = 8110;


// ============================================================
// AIRWAVES LINK API
// ============================================================

integer AIR_CORE_COMMAND = 8500;
integer AIR_CORE_REPLY = 8501;

// MMPS Console Controller API
integer MMPS_CONSOLE_SET_STATE   = 4001;
integer MMPS_CONSOLE_SET_GATEWAY = 4002;
integer MMPS_CONSOLE_SET_STATION = 4003;
integer MMPS_CONSOLE_SET_ARTIST  = 4004;
integer MMPS_CONSOLE_SET_SONG    = 4005;

// Commands:
// SET|Station Name|Stream URL
// OFF
// STATUS
//
// Replies:
// STATUS|Gateway|State|Station|URL
// RESULT|ACTIVE|Station|URL
// RESULT|READY||
// RESULT|ERROR|Station|URL


// ============================================================
// AIRWAVES NETWORK
// ============================================================

integer DISCOVERY_CHANNEL = -744923801;
integer MENU_CHANNEL = -77444001;

string PROTOCOL = "MMPS-AIRWAVES-1";

integer PAIR_WINDOW_SECONDS = 60;
integer OFFLINE_SECONDS = 25;


// ============================================================
// SYSTEM IDENTITY
// ============================================================

string gSystemID = "";
string gToken = "";
integer gPrivateChannel = 0;


// ============================================================
// LISTENERS
// ============================================================

integer gDiscoveryListen = 0;
integer gPrivateListen = 0;
integer gMenuListen = 0;


// ============================================================
// PAIRING
// ============================================================

integer gPairingOpen = FALSE;
integer gPairingEnds = 0;


// ============================================================
// GATEWAYS
// ============================================================
//
// Stride:
// 0 Gateway ID
// 1 Friendly name
// 2 Object key
// 3 Last heartbeat
// 4 State
//
list gGateways = [];
integer GATEWAY_STRIDE = 5;

string gSelectedGatewayID = "";
string gSelectedGatewayName = "";
key gSelectedGatewayKey = NULL_KEY;


// ============================================================
// STREAMING
// ============================================================

integer gSequence = 0;
integer gPendingSequence = -1;

string gPendingStation = "";
string gPendingURL = "";

string gCurrentStation = "";
string gCurrentURL = "";
string gStreamingState = "IDLE";


// ============================================================
// UTILITIES
// ============================================================

string trim(string value)
{
    return llStringTrim(value, STRING_TRIM);
}


string upper(string value)
{
    return llToUpper(trim(value));
}


string safeField(string value)
{
    return llDumpList2String(
        llParseStringKeepNulls(
            value,
            ["|"],
            []
        ),
        "/"
    );
}


string makeHex(integer length)
{
    string digest = llMD5String(
        (string)llGetUnixTime() + "|" +
        (string)llFrand(999999999.0) + "|" +
        (string)llGetKey(),
        0
    );

    return llToUpper(
        llGetSubString(
            digest,
            0,
            length - 1
        )
    );
}


integer makePrivateChannel(string source)
{
    string digest = llMD5String(source, 0);

    integer value = (integer)(
        "0x" +
        llGetSubString(
            digest,
            0,
            7
        )
    );

    if (value == -2147483648)
    {
        value = 2147483647;
    }
    else if (value < 0)
    {
        value = -value;
    }

    value = -100000 - (value % 1900000000);

    if (value == 0)
    {
        value = -915700321;
    }

    return value;
}


integer validGatewayID(string gatewayID)
{
    gatewayID = trim(gatewayID);

    if (gatewayID == "")
    {
        return FALSE;
    }

    if (gatewayID == (string)NULL_KEY)
    {
        return FALSE;
    }

    if (llGetSubString(gatewayID, 0, 2) != "GW-")
    {
        return FALSE;
    }

    return TRUE;
}


integer validGatewayName(string gatewayName)
{
    gatewayName = trim(gatewayName);

    if (gatewayName == "")
    {
        return FALSE;
    }

    if (gatewayName == (string)NULL_KEY)
    {
        return FALSE;
    }

    if (upper(gatewayName) == "MAIN")
    {
        return FALSE;
    }

    return TRUE;
}


string selectedGatewayText()
{
    if (gSelectedGatewayName == "")
    {
        return "NONE";
    }

    return gSelectedGatewayName;
}


string currentStationText()
{
    if (gCurrentStation == "")
    {
        return "NONE";
    }

    return gCurrentStation;
}


registerModule()
{
    llMessageLinked(
        LINK_SET,
        MMIB_REGISTER,
        "REGISTER|Airwaves Core Manager|1.2.1|Optional",
        NULL_KEY
    );
}


publish(string eventName)
{
    llMessageLinked(
        LINK_SET,
        MMIB_EVENT,
        "EVENT|Airwaves Core Manager|" +
        eventName,
        NULL_KEY
    );
}


replyStatus()
{
    llMessageLinked(
        LINK_SET,
        AIR_CORE_REPLY,
        "STATUS|" +
        safeField(selectedGatewayText()) + "|" +
        gStreamingState + "|" +
        safeField(gCurrentStation) + "|" +
        gCurrentURL,
        NULL_KEY
    );
}


replyResult(
    string resultName,
    string stationName,
    string streamURL
)
{
    llMessageLinked(
        LINK_SET,
        AIR_CORE_REPLY,
        "RESULT|" +
        resultName + "|" +
        safeField(stationName) + "|" +
        streamURL,
        NULL_KEY
    );
}


sendConsoleState(string stateName)
{
    llMessageLinked(
        LINK_SET,
        MMPS_CONSOLE_SET_STATE,
        stateName,
        NULL_KEY
    );
}


sendConsoleGateway()
{
    string gatewayName =
        selectedGatewayText();

    if (gatewayName == "NONE")
    {
        gatewayName = "";
    }

    llMessageLinked(
        LINK_SET,
        MMPS_CONSOLE_SET_GATEWAY,
        gatewayName,
        NULL_KEY
    );
}


sendConsoleStation(string stationName)
{
    llMessageLinked(
        LINK_SET,
        MMPS_CONSOLE_SET_STATION,
        stationName,
        NULL_KEY
    );
}


clearConsoleMetadata()
{
    llMessageLinked(
        LINK_SET,
        MMPS_CONSOLE_SET_ARTIST,
        "",
        NULL_KEY
    );

    llMessageLinked(
        LINK_SET,
        MMPS_CONSOLE_SET_SONG,
        "",
        NULL_KEY
    );
}


syncConsole()
{
    sendConsoleGateway();
    sendConsoleStation(
        gCurrentStation
    );

    if (
        gSelectedGatewayID == "" ||
        gSelectedGatewayKey == NULL_KEY
    )
    {
        sendConsoleState("ERROR");
    }
    else if (
        gStreamingState == "ACTIVE"
    )
    {
        sendConsoleState("STREAMING");
    }
    else if (
        gStreamingState == "CHANGING"
    )
    {
        sendConsoleState("CONNECTING");
    }
    else if (
        gStreamingState == "ERROR" ||
        gStreamingState == "NO GATEWAY"
    )
    {
        sendConsoleState("ERROR");
    }
    else
    {
        sendConsoleState("READY");
    }
}


writeStreamingState()
{
    llLinksetDataWrite(
        "MMPS.AIR.STREAM_STATE",
        gStreamingState
    );

    llLinksetDataWrite(
        "MMPS.AIR.CURRENT_STATION",
        gCurrentStation
    );

    llLinksetDataWrite(
        "MMPS.AIR.CURRENT_URL",
        gCurrentURL
    );

    llLinksetDataWrite(
        "MMPS.AIR.SELECTED_GATEWAY",
        gSelectedGatewayName
    );

    syncConsole();
}


loadOrCreateIdentity()
{
    gSystemID = llLinksetDataRead(
        "MMPS.AIR.SYSTEM_ID"
    );

    gToken = llLinksetDataRead(
        "MMPS.AIR.TOKEN"
    );

    gPrivateChannel = (integer)llLinksetDataRead(
        "MMPS.AIR.CHANNEL"
    );

    if (
        gSystemID == "" ||
        gToken == "" ||
        gPrivateChannel == 0
    )
    {
        gSystemID = "MMPS-" + makeHex(8);
        gToken = makeHex(24);
        gPrivateChannel = makePrivateChannel(
            gSystemID + "|" + gToken
        );

        llLinksetDataWrite(
            "MMPS.AIR.SYSTEM_ID",
            gSystemID
        );

        llLinksetDataWrite(
            "MMPS.AIR.TOKEN",
            gToken
        );

        llLinksetDataWrite(
            "MMPS.AIR.CHANNEL",
            (string)gPrivateChannel
        );
    }
}


openListeners()
{
    if (gDiscoveryListen != 0)
    {
        llListenRemove(gDiscoveryListen);
    }

    if (gPrivateListen != 0)
    {
        llListenRemove(gPrivateListen);
    }

    if (gMenuListen != 0)
    {
        llListenRemove(gMenuListen);
    }

    gDiscoveryListen = llListen(
        DISCOVERY_CHANNEL,
        "",
        NULL_KEY,
        ""
    );

    gPrivateListen = llListen(
        gPrivateChannel,
        "",
        NULL_KEY,
        ""
    );

    gMenuListen = llListen(
        MENU_CHANNEL,
        "",
        llGetOwner(),
        ""
    );
}


// ============================================================
// GATEWAY REGISTRY
// ============================================================

integer findGatewayByID(string gatewayID)
{
    integer index;

    for (
        index = 0;
        index < llGetListLength(gGateways);
        index += GATEWAY_STRIDE
    )
    {
        if (
            llList2String(
                gGateways,
                index
            ) == gatewayID
        )
        {
            return index;
        }
    }

    return -1;
}


integer findGatewayByObject(key objectKey)
{
    integer index;

    for (
        index = 0;
        index < llGetListLength(gGateways);
        index += GATEWAY_STRIDE
    )
    {
        if (
            (key)llList2String(
                gGateways,
                index + 2
            ) == objectKey
        )
        {
            return index;
        }
    }

    return -1;
}


storeGateway(
    string gatewayID,
    string gatewayName,
    key objectKey,
    string stateName
)
{
    if (!validGatewayID(gatewayID))
    {
        return;
    }

    if (!validGatewayName(gatewayName))
    {
        return;
    }

    integer objectIndex = findGatewayByObject(
        objectKey
    );

    if (objectIndex >= 0)
    {
        gGateways = llDeleteSubList(
            gGateways,
            objectIndex,
            objectIndex + GATEWAY_STRIDE - 1
        );
    }

    integer idIndex = findGatewayByID(
        gatewayID
    );

    list record =
    [
        gatewayID,
        gatewayName,
        (string)objectKey,
        llGetUnixTime(),
        stateName
    ];

    if (idIndex < 0)
    {
        gGateways += record;
    }
    else
    {
        gGateways = llListReplaceList(
            gGateways,
            record,
            idIndex,
            idIndex + GATEWAY_STRIDE - 1
        );
    }

    if (
        gSelectedGatewayID == "" ||
        gSelectedGatewayID == gatewayID
    )
    {
        gSelectedGatewayID = gatewayID;
        gSelectedGatewayName = gatewayName;
        gSelectedGatewayKey = objectKey;
    }

    llLinksetDataWrite(
        "MMPS.AIR.GATEWAY_COUNT",
        (string)(
            llGetListLength(gGateways) /
            GATEWAY_STRIDE
        )
    );

    llLinksetDataWrite(
        "MMPS.AIR.GATEWAY_STATE",
        stateName
    );

    llLinksetDataWrite(
        "MMPS.AIR.GATEWAY_NAME",
        gatewayName
    );

    writeStreamingState();
}


pruneGateways()
{
    integer now = llGetUnixTime();

    list fresh = [];

    integer selectedStillFresh = FALSE;
    integer index;

    for (
        index = 0;
        index < llGetListLength(gGateways);
        index += GATEWAY_STRIDE
    )
    {
        integer lastHeartbeat = llList2Integer(
            gGateways,
            index + 3
        );

        if (
            now - lastHeartbeat <=
            OFFLINE_SECONDS
        )
        {
            fresh += llList2List(
                gGateways,
                index,
                index + GATEWAY_STRIDE - 1
            );

            if (
                llList2String(
                    gGateways,
                    index
                ) == gSelectedGatewayID
            )
            {
                selectedStillFresh = TRUE;
            }
        }
    }

    gGateways = fresh;

    if (!selectedStillFresh)
    {
        gSelectedGatewayID = "";
        gSelectedGatewayName = "";
        gSelectedGatewayKey = NULL_KEY;

        if (
            llGetListLength(gGateways) >=
            GATEWAY_STRIDE
        )
        {
            gSelectedGatewayID = llList2String(
                gGateways,
                0
            );

            gSelectedGatewayName = llList2String(
                gGateways,
                1
            );

            gSelectedGatewayKey = (key)llList2String(
                gGateways,
                2
            );
        }
    }

    llLinksetDataWrite(
        "MMPS.AIR.GATEWAY_COUNT",
        (string)(
            llGetListLength(gGateways) /
            GATEWAY_STRIDE
        )
    );

    writeStreamingState();
}


// ============================================================
// PAIRING
// ============================================================

startPairing()
{
    gPairingOpen = TRUE;

    gPairingEnds = llGetUnixTime() +
        PAIR_WINDOW_SECONDS;

    publish("AIR.PAIRING.OPEN");

    llOwnerSay(
        "[AIRWAVES] Pairing is open for 60 seconds. Touch the Streaming Gateway."
    );
}


stopPairing()
{
    if (!gPairingOpen)
    {
        return;
    }

    gPairingOpen = FALSE;
    gPairingEnds = 0;

    publish("AIR.PAIRING.CLOSED");
}


sendPairOffer(
    key gatewayObject,
    string gatewayID
)
{
    ++gSequence;

    llRegionSayTo(
        gatewayObject,
        DISCOVERY_CHANNEL,
        PROTOCOL + "|PAIR_OFFER|" +
        (string)gSequence + "|" +
        gatewayID + "|" +
        gSystemID + "|" +
        (string)gPrivateChannel + "|" +
        gToken
    );
}


// ============================================================
// STREAMING COMMANDS
// ============================================================

sendSetURL(
    string stationName,
    string streamURL
)
{
    pruneGateways();

    if (
        gSelectedGatewayID == "" ||
        gSelectedGatewayKey == NULL_KEY
    )
    {
        gStreamingState = "NO GATEWAY";
        writeStreamingState();
        replyStatus();
        return;
    }

    ++gSequence;

    gPendingSequence = gSequence;
    gPendingStation = stationName;
    gPendingURL = streamURL;

    clearConsoleMetadata();
    sendConsoleStation(
        stationName
    );

    gStreamingState = "CHANGING";
    writeStreamingState();

    llRegionSayTo(
        gSelectedGatewayKey,
        gPrivateChannel,
        PROTOCOL + "|SET_URL|" +
        (string)gSequence + "|" +
        gSelectedGatewayID + "|" +
        gSystemID + "|" +
        safeField(stationName) + "|" +
        streamURL + "|" +
        gToken
    );

    publish("AIR.STREAM.REQUESTED");
}


sendOff()
{
    pruneGateways();

    if (
        gSelectedGatewayID == "" ||
        gSelectedGatewayKey == NULL_KEY
    )
    {
        gStreamingState = "NO GATEWAY";
        writeStreamingState();
        replyStatus();
        return;
    }

    ++gSequence;

    gPendingSequence = gSequence;
    gPendingStation = "OFF";
    gPendingURL = "";

    clearConsoleMetadata();
    sendConsoleStation("");

    gStreamingState = "CHANGING";
    writeStreamingState();

    llRegionSayTo(
        gSelectedGatewayKey,
        gPrivateChannel,
        PROTOCOL + "|OFF|" +
        (string)gSequence + "|" +
        gSelectedGatewayID + "|" +
        gSystemID + "|" +
        gToken
    );

    publish("AIR.STREAM.REQUESTED");
}


// ============================================================
// PACKETS
// ============================================================

handleDiscovery(
    key sender,
    string message
)
{
    list fields = llParseStringKeepNulls(
        message,
        ["|"],
        []
    );

    if (
        llGetListLength(fields) <
        4
    )
    {
        return;
    }

    if (
        llList2String(
            fields,
            0
        ) != PROTOCOL
    )
    {
        return;
    }

    if (
        upper(
            llList2String(
                fields,
                1
            )
        ) != "PAIR_REQUEST"
    )
    {
        return;
    }

    if (!gPairingOpen)
    {
        return;
    }

    string gatewayID = llList2String(
        fields,
        2
    );

    string gatewayName = llList2String(
        fields,
        3
    );

    if (!validGatewayID(gatewayID))
    {
        return;
    }

    if (!validGatewayName(gatewayName))
    {
        return;
    }

    sendPairOffer(
        sender,
        gatewayID
    );
}


handlePrivate(
    key sender,
    string message
)
{
    list fields = llParseStringKeepNulls(
        message,
        ["|"],
        []
    );

    if (
        llGetListLength(fields) <
        7
    )
    {
        return;
    }

    if (
        llList2String(
            fields,
            0
        ) != PROTOCOL
    )
    {
        return;
    }

    string packetType = upper(
        llList2String(
            fields,
            1
        )
    );

    string gatewayID = llList2String(
        fields,
        2
    );

    string packetSystemID = llList2String(
        fields,
        3
    );

    if (packetSystemID != gSystemID)
    {
        return;
    }

    if (
        packetType == "PAIR_ACCEPTED" ||
        packetType == "HEARTBEAT"
    )
    {
        string gatewayName = llList2String(
            fields,
            4
        );

        string stateName = llList2String(
            fields,
            5
        );

        string packetToken = llList2String(
            fields,
            6
        );

        if (packetToken != gToken)
        {
            return;
        }

        storeGateway(
            gatewayID,
            gatewayName,
            sender,
            stateName
        );

        if (
            packetType ==
            "PAIR_ACCEPTED"
        )
        {
            stopPairing();

            publish(
                "AIR.GATEWAY.PAIRED"
            );

            llOwnerSay(
                "[AIRWAVES] Gateway paired: " +
                gatewayName
            );
        }

        return;
    }

    if (packetType == "ACK")
    {
        if (
            llGetListLength(fields) <
            9
        )
        {
            return;
        }

        integer sequence = llList2Integer(
            fields,
            4
        );

        string resultName = upper(
            llList2String(
                fields,
                5
            )
        );

        string stationName = llList2String(
            fields,
            6
        );

        string streamURL = llList2String(
            fields,
            7
        );

        string packetToken = llList2String(
            fields,
            8
        );

        if (packetToken != gToken)
        {
            return;
        }

        if (
            gatewayID !=
            gSelectedGatewayID ||
            sequence !=
            gPendingSequence
        )
        {
            return;
        }

        if (resultName == "ACTIVE")
        {
            gCurrentStation = stationName;
            gCurrentURL = streamURL;
            gStreamingState = "ACTIVE";

            sendConsoleStation(
                stationName
            );

            publish(
                "AIR.STREAM.ACTIVE"
            );

            replyResult(
                "ACTIVE",
                stationName,
                streamURL
            );
        }
        else if (resultName == "READY")
        {
            gCurrentStation = "";
            gCurrentURL = "";
            gStreamingState = "IDLE";

            sendConsoleStation("");
            clearConsoleMetadata();

            publish(
                "AIR.STREAM.READY"
            );

            replyResult(
                "READY",
                "",
                ""
            );
        }
        else
        {
            gStreamingState = "ERROR";

            publish(
                "AIR.STREAM.ERROR"
            );

            replyResult(
                "ERROR",
                stationName,
                streamURL
            );
        }

        gPendingSequence = -1;
        gPendingStation = "";
        gPendingURL = "";

        writeStreamingState();
    }
}


// ============================================================
// OWNER MENU
// ============================================================

showMenu()
{
    llDialog(
        llGetOwner(),
        "MMPS AIRWAVES CORE\n\n" +
        "Gateway: " +
        selectedGatewayText() + "\n" +
        "State: " +
        gStreamingState + "\n" +
        "Station: " +
        currentStationText(),
        [
            "Pair Gateway",
            "Gateway Report",
            "Stream Report",
            "Close"
        ],
        MENU_CHANNEL
    );
}


showGatewayReport()
{
    pruneGateways();

    llOwnerSay(
        "MMPS AIRWAVES GATEWAY REPORT\n" +
        "============================\n" +
        "System ID........... " +
        gSystemID + "\n" +
        "Private Channel..... " +
        (string)gPrivateChannel + "\n" +
        "Paired Gateways..... " +
        (string)(
            llGetListLength(gGateways) /
            GATEWAY_STRIDE
        )
    );

    integer index;

    for (
        index = 0;
        index < llGetListLength(gGateways);
        index += GATEWAY_STRIDE
    )
    {
        llOwnerSay(
            llList2String(
                gGateways,
                index + 1
            ) +
            " | " +
            llList2String(
                gGateways,
                index
            ) +
            " | " +
            llList2String(
                gGateways,
                index + 4
            )
        );
    }
}


showStreamReport()
{
    llOwnerSay(
        "MMPS AIRWAVES STREAM REPORT\n" +
        "============================\n" +
        "Selected Gateway.... " +
        selectedGatewayText() + "\n" +
        "Streaming State..... " +
        gStreamingState + "\n" +
        "Current Station..... " +
        currentStationText() + "\n" +
        "Current URL......... " +
        gCurrentURL
    );
}


// ============================================================
// DEFAULT
// ============================================================

default
{
    state_entry()
    {
        sendConsoleState("BOOTING");

        loadOrCreateIdentity();
        openListeners();
        registerModule();

        gCurrentStation = llLinksetDataRead(
            "MMPS.AIR.CURRENT_STATION"
        );

        gCurrentURL = llLinksetDataRead(
            "MMPS.AIR.CURRENT_URL"
        );

        gStreamingState = llLinksetDataRead(
            "MMPS.AIR.STREAM_STATE"
        );

        if (gStreamingState == "")
        {
            gStreamingState = "IDLE";
        }

        writeStreamingState();

        llSetTimerEvent(
            2.0
        );
    }


    on_rez(integer startParameter)
    {
        llResetScript();
    }


    changed(integer change)
    {
        if (
            change &
            CHANGED_OWNER
        )
        {
            llLinksetDataReset();
            llResetScript();
        }
    }


    touch_start(integer totalNumber)
    {
        if (
            llDetectedKey(0) ==
            llGetOwner()
        )
        {
            showMenu();
        }
    }


    listen(
        integer channel,
        string detectedName,
        key sender,
        string message
    )
    {
        if (
            channel ==
            DISCOVERY_CHANNEL
        )
        {
            handleDiscovery(
                sender,
                message
            );
        }
        else if (
            channel ==
            gPrivateChannel
        )
        {
            handlePrivate(
                sender,
                message
            );
        }
        else if (
            channel ==
            MENU_CHANNEL &&
            sender ==
            llGetOwner()
        )
        {
            if (
                message ==
                "Pair Gateway"
            )
            {
                startPairing();
            }
            else if (
                message ==
                "Gateway Report"
            )
            {
                showGatewayReport();
                showMenu();
            }
            else if (
                message ==
                "Stream Report"
            )
            {
                showStreamReport();
                showMenu();
            }
        }
    }


    link_message(
        integer senderNumber,
        integer number,
        string message,
        key id
    )
    {
        if (
            number !=
            AIR_CORE_COMMAND
        )
        {
            return;
        }

        list fields = llParseStringKeepNulls(
            message,
            ["|"],
            []
        );

        string commandName = upper(
            llList2String(
                fields,
                0
            )
        );

        if (
            commandName == "SET" &&
            llGetListLength(fields) >= 3
        )
        {
            sendSetURL(
                llList2String(
                    fields,
                    1
                ),
                llList2String(
                    fields,
                    2
                )
            );
        }
        else if (
            commandName ==
            "OFF"
        )
        {
            sendOff();
        }
        else if (
            commandName ==
            "STATUS"
        )
        {
            replyStatus();
        }
    }


    timer()
    {
        registerModule();
        pruneGateways();

        if (
            gPairingOpen &&
            llGetUnixTime() >=
            gPairingEnds
        )
        {
            stopPairing();

            llOwnerSay(
                "[AIRWAVES] Pairing window closed."
            );
        }
    }
}
