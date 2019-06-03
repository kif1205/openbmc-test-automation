*** Settings ***
Documentation  Utilities for eSEL testing.

Resource            ../lib/ipmi_client.robot
Resource            ../lib/utils.robot
Resource            ../lib/logging_utils.robot
Variables           ../data/variables.py


*** Variables ***

${RAW_PREFIX}       raw 0x3a 0xf0 0x

${RESERVE_ID}       raw 0x0a 0x42

${RAW_SUFFIX}       0x00 0x00 0x00 0x00 0x00 0x01 0x00 0x00
...  0xdf 0x00 0x00 0x00 0x00 0x20 0x00 0x04 0x12 0x65 0x6f 0xaa 0x00 0x00

${RAW_SEL_COMMIT}   raw 0x0a 0x44 0x00 0x00 0x02 0x00 0x00 0x00 0x00 0x20
...  0x00 0x04 0x12 0xA6 0x6f 0x02 0x00 0x01


*** Keywords ***

Create eSEL
    [Documentation]  Create an eSEL.
    Open Connection And Log In
    ${Resv_id}=  Run Inband IPMI Standard Command  ${RESERVE_ID}
    ${cmd}=  Catenate
    ...  ${RAW_PREFIX}${Resv_id.strip().rsplit(' ', 1)[0]}  ${RAW_SUFFIX}
    Run Inband IPMI Standard Command  ${cmd}
    Run Inband IPMI Standard Command  ${RAW_SEL_COMMIT}


Count eSEL Entries
    [Documentation]  Count eSEL entries logged.
    ${resp}=  OpenBMC Get Request  ${BMC_LOGGING_ENTRY}
    Should Be Equal As Strings  ${resp.status_code}  ${HTTP_OK}
    ${jsondata}=  To JSON  ${resp.content}
    ${count}=  Get Length  ${jsondata["data"]}
    [Return]  ${count}


Verify eSEL Entries
    [Documentation]  Verify eSEL entries logged.

    # {
    #    "@odata.context": "/redfish/v1/$metadata#LogEntry.LogEntry",
    #    "@odata.id": "/redfish/v1/Systems/system/LogServices/EventLog/Entries/2",
    #    "@odata.type": "#LogEntry.v1_4_0.LogEntry",
    #    "Created": "2019-06-03T14:47:31+00:00",
    #    "EntryType": "Event",
    #    "Id": "2",
    #    "Message": "org.open_power.Host.Error.Event",
    #    "Name": "System DBus Event Log Entry",
    #    "Severity": "Critical"
    # }

    ${elog_entry}=  Get Event Logs
    Should Be Equal  ${elog_entry[0]["Message"]}  org.open_power.Host.Error.Event
    Should Be Equal  ${elog_entry[0]["Severity"]}  Critical
