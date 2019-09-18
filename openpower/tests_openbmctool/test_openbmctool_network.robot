*** Settings ***
Documentation  Verify OBMC tool's network fuctionality.


Library                 String
Library                 OperatingSystem
Library                 ../../lib/gen_print.py
Library                 ../../lib/gen_robot_print.py
Library                 ../../lib/openbmctool_utils.py
Library                 ../../lib/gen_misc.py
Library                 ../../lib/gen_robot_valid.py
Resource                ../../syslib/utils_os.robot
Resource                ../../lib/resource.robot
Resource                ../../lib/bmc_network_utils.robot
Resource                ../../lib/utils.robot
Resource                ../../lib/common_utils.robot


Suite Setup             Suite Setup Execution
Test Setup              Printn

*** Variables ***

${ip}                   10.5.5.5
${dns_ip}               10.10.10.10
${domain_name}          randomName.com
${mac_address}          76:e2:84:14:87:91
${ntp_server}           pool.ntp.org
${parser}               |grep "ipv4"|awk -F/ 'NR==1{print$5}'
${eth0_resource_path}   /xyz/openbmc_project/network/eth0
${ignore_err}           ${0}


*** Test Cases ***

Verify GetIP
     [Documentation]  Verify that openbmctool can run the getIP command.
     [Tags]  Verify_GetIP

     ${ip_records}=  Network  getIP  I=eth0
     ${addresses}=  Nested Get  Address  ${ip_records}
     Verify IP On BMC  ${addresses}[${0}]


Verify AddIP
    [Documentation]  Verify that openbmctool can run the addIP command.
    [Tags]  Verify_AddIP

    Network  addIP  I=${interface}  a=${ip}  l=24  p=ipv4
    Wait And Verify IP On BMC  ${ip}


Verify GetDefaultGW
    [Documentation]  Verify that openbmctool can run the getDefaultGW command.
    [Tags]  Verify_GetDefaultGW

    ${default_gw}=  Network  getDefaultGW
    Verify Gateway On BMC  ${default_gw}


Verify RemoveIP
    [Documentation]  Verify that openbmctool can run the rmIP command.
    [Tags]  Verify_RemoveIP

    Network  addIP  I=${interface}  a=${ip}  l=24  p=ipv4
    Wait And Verify IP On BMC  ${ip}
    Network  rmIP  I=${interface}  a=${ip}
    ${status}=  Run Keyword And Return Status  Wait And Verify IP On BMC  ${ip}
    Should Be Equal  ${status}  ${False}


Verify SetDNS
     [Documentation]  Verify that openbmctool can run the setDNS command.
     [Tags]  Verify_SetDNS

     Network  setDNS  I=eth0  d=${dns_ip}
     ${dns_config}=  CLI Get Nameservers
     Should Contain  ${dns_config}  ${dns_ip}


Verify GetDNS
     [Documentation]  Verify that openbmctool can run the getDNS command.
     [Tags]  Verify_GetDNS

     Network  setDNS  I=eth0  d=${dns_ip}
     ${dns_data}=  Network  getDNS  I=eth0
     ${dns_config}=  CLI Get Nameservers
     Should Contain  ${dns_config}  ${dns_data}[${0}]


Verify SetHostName
     [Documentation]  Verify that openbmctool can run the setHostName command.
     [Tags]  Verify_SetHostName

     Network  setHostName  H=randomName
     ${bmc_hostname}=  Get BMC Hostname
     Should Be Equal As Strings  ${bmc_hostname}  randomName


Verify GetHostName
     [Documentation]  Verify that openbmctool can run the getHostName command.
     [Tags]  Verify_GetHostName

     ${tool_hostname}=  Network  getHostName
     ${bmc_hostname}=  Get BMC Hostname
     Should Be Equal As Strings  ${bmc_hostname}  ${tool_hostname}


Verify SetMACAddress
     [Documentation]  Verify that openbmctool can set a new MAC address.
     [Tags]  Verify_SetMACAddress

     Network  setMACAddress  I=eth0  MA=${mac_address}
     Validate MAC On BMC  ${mac_address}


Verify GetMACAddress
     [Documentation]  Verify that openbmctool can get the MAC address.
     [Tags]  Verify_GetMACAddress

     ${mac_addr}=  Network  getMACAddress  I=eth0
     Validate MAC On BMC  ${mac_addr}


Verify SetNTP
     [Documentation]  Verify that openbmctool can run the setNTP command.
     [Tags]  Verify_SetNTP

     Network  setNTP  I=eth0  N=${ntp_server}
     # Get NTP server details via REST.
     ${eth0}=  Read Properties  ${eth0_resource_path}  quiet=1
     Rprint Vars  eth0
     Valid Value  eth0['NTPServers'][0]  ['${ntp_server}']


Verify GetNTP
     [Documentation]  Verify that openbmctool can run the getNTP command.
     [Tags]  Verify_GetNTP

     Network  setNTP  I=eth0  N=${ntp_server}
     # Get NTP server details via REST method.
     ${eth0}=  Read Properties  ${eth0_resource_path}  quiet=1
     Rprint Vars  eth0
     ${tool_ntp}=  Network  getNTP  I=eth0
     Valid Value  eth0['NTPServers'][0]  ['${tool_ntp}']


*** Keywords ***

Suite Setup Execution
    [Documentation]  Verify connectivity to run openbmctool commands.

    Valid Value  OPENBMC_HOST
    Valid Value  OPENBMC_USERNAME
    Valid Value  OPENBMC_PASSWORD

    # Verify connectivity to the BMC host.
    ${bmc_version}=  Get BMC Version

    # Verify can find the openbmctool.
    ${openbmctool_file_path}=  which  openbmctool.py
    Printn
    Rprint Vars  openbmctool_file_path

    # Get the version number from openbmctool.
    ${openbmctool_version}=  Get Openbmctool Version

    ${rc}  ${res}=  Openbmctool Execute Command  network view-config${parser}
    Set Suite Variable  ${interface}  ${res.strip()}

    Rprint Vars  openbmctool_version  OPENBMC_HOST  bmc_version[1]


Validate Non Existence Of IP On BMC
    [Documentation]  Verify that IP address is not present in set of IP addresses.
    [Arguments]  ${ip_address}  ${ip_data}

    # Description of argument(s):
    # ip_address  IP address to check (e.g. xx.xx.xx.xx).
    # ip_data     Set of the IP addresses present.

    Should Not Contain Match  ${ip_data}  ${ip_address}/*
    ...  msg=${ip_address} found in the list provided.


Wait And Verify IP On BMC
    [Documentation]  Wait and verify if system IP exists.
    [Arguments]  ${ip}

    # Description of argument(s):
    # ip  IP address to verify (e.g. xx.xx.xx.xx).

    # Note:Network restart takes around 15-18s after network-config with openbmctool.

    Sleep  ${NETWORK_TIMEOUT}s
    Wait For Host To Ping  ${OPENBMC_HOST}  ${NETWORK_TIMEOUT}

    Verify IP On BMC  ${ip}