# for ros 7
# set global vars
:put "Load global variable 'set_global_varible'"
/system script run set_global_varible

# List of global variables to check
:local globalVars {
    "PingCount"; 
    "PingTargets"; 
    "MainInterface"; 
    "BackupInterface"; 
    "nameTableISP1"; 
    "nameTableISP2"; 
    "nameRouter"; 
    "tokenBot"; 
    "chatId"
}

# Check if global variables are set and get for script
:foreach var in=$globalVars do={
    :local value
    :do {
        :set value [/system script environment get [find name=$var] value]
        :if ([:len $value] = 0) do={
            :error ("Global variable " . $var . " is not set")
        }
        :put ($var . " is set to " . $value)
    } on-error={
        :error ("Error: Global variable " . $var . " is not set or not accessible.")
    }
}

# Since we're here, all variables are set
:put "All global variables are set. Proceeding with the test script."

:local PingTargets {8.8.8.8}
:global PingCount
:global MainInterface
:global BackupInterface
:global nameTableISP1
:global nameTableISP2
:global nameRouter 
:global tokenBot
:global chatId

# download functions
:put "Load functions 'functions_for_reserv'"
/system script run functions_for_reserv

:global helperOffICMP do={
    # Args
    # interfaceArg
    :put "interfaceArg $interfaceArg"
    :put "off icmp"
    :put "interfaceArg $interfaceArg"
    /ip firewall filter add chain=input place-before=0 in-interface=$interfaceArg action=drop protocol=icmp comment="Block ICMP for test Switch"
    :put "icmp been offed"
    :return true
}

:global helperOnICMP do={
    :put "on icmp"
    /ip firewall filter remove [find comment="Block ICMP for test Switch"]
    :return true
}

:global testHelperOffICMP do={
    # Args
    # interfaceArg
    
    :global helperOffICMP;
    :global helperOnICMP;
    :local count 4
    :local okPing [ping interface=$interfaceArg count=$count 8.8.8.8]

    :put "interfaceArg $interfaceArg"

    :if ($okPing!=$count) do={
        :put "Error Internet Not work testHelperOffICMP okPing!=okCount $okPing != count"
        :return "Error Internet Not work testHelperOffICMP okPing!=okCount $okPing != count"
    }
    [$helperOffICMP interfaceArg=$interfaceArg]
    set $okPing [ping interface=$interfaceArg count=$count 8.8.8.8]
    :if ($okPing=$count) do={
        :put "Error testHelperOffICMP okPing!=NotOk $okPing != 0"
        :return "Error testHelperOffICMP okPing!=NotOk $okPing != 0"
    }

    #return state!
    :put "return state helperOnICMP"
    :put [$helperOnICMP]
    :put "returned!"
    set $okPing [ping interface=$interfaceArg count=$count 8.8.8.8]
    :if ($okPing!=$count) do={
        :put "Error testHelperOffICMP not return state!!! okPing!=Ok"
        :return "Error testHelperOffICMP not return state!!! okPing!=Ok"
    }

    :return "Ok testHelperOffICMP"
    }

# TODO перенести в ROS7
:global testEnvironment do={
    #Args
    # MainInterfaceArg
    # BackupInterfaceArg

    :do {
        :put "MainInterfaceArg $MainInterfaceArg"
        :put "BackupInterfaceArg $BackupInterfaceArg"
        

        :local mainDistance [/ip dhcp-client get $MainInterfaceArg default-route-distance ];
        :put "$MainInterfaceArg default-route-distance   = $mainDistance"
        :if ( 1 != $mainDistance) do={
            :return "$MainInterfaceArg default-route-distance  must be 1!"
        }

        :local backupDistance [/ip dhcp-client get $BackupInterfaceArg default-route-distance ];
        :put "$BackupInterfaceArg default-route-distance  = $backupDistance"
        :if (2 != $backupDistance) do={
            :return "$BackupInterfaceArg default-route-distance  must be 2!"
        }
        :return "Ok! testEnvironment"
    } on-error={
            :return "Exception! Somthing wrong! \n\r mainInterface $MainInterfaceArg \n\r backupInterface $BackupInterfaceArg"
            
        };
}

:global testifNecessarySwitchTrafficByDhcpClient do={
    #Args
    # MainInterfaceArg
    # BackupInterfaceArg

    # Testing function
    :global ifNecessarySwitchTrafficByDhcpClient
    
    :local resutlTestError false; # or string!

    :do {

        /ip dhcp-client set $MainInterfaceArg default-route-distance=2
        :put [$ifNecessarySwitchTrafficByDhcpClient interfaceToSwitch=$MainInterfaceArg mainInterface=$MainInterfaceArg backupInterface=$BackupInterfaceArg]
        :delay 2s;
        :local expected 1
        :local real [/ip dhcp-client get $MainInterfaceArg default-route-distance]
        :put [/ip dhcp-client get $MainInterfaceArg default-route-distance]
        :if ($real!=$expected) do={
            set resutlTestError "Error! ifNecessarySwitchTrafficByDhcpClient failed distance MainInterface real != expected real = $real expected = $expected \n\r interfaceToSwitch $MainInterfaceArg \n\r mainInterface $MainInterfaceArg \n\r backupInterface $BackupInterfaceArg"
        }

        /ip dhcp-client set $BackupInterfaceArg default-route-distance=2
        [$ifNecessarySwitchTrafficByDhcpClient interfaceToSwitch=$BackupInterfaceArg mainInterface=$MainInterfaceArg backupInterface=$BackupInterfaceArg]
        :delay 2s;
        :local expected 1
        :local real [/ip dhcp-client get $BackupInterfaceArg default-route-distance]
        :if ($real!=$expected) do={
            set resutlTestError "Error! ifNecessarySwitchTrafficByDhcpClient failed distance BackupInterface real != expected real = $real expected = $expected \n\r interfaceToSwitch $MainInterfaceArg \n\r mainInterface $MainInterfaceArg \n\r backupInterface $BackupInterfaceArg"
        }

    } on-error={
        set resutlTestError "Error! ifNecessarySwitchTrafficByDhcpClient failed \n\r interfaceToSwitch $MainInterfaceArg \n\r mainInterface $MainInterfaceArg \n\r backupInterface $BackupInterfaceArg"
        
    };
    
    # return state!
    /ip dhcp-client set $MainInterfaceArg default-route-distance=1
    /ip dhcp-client set $BackupInterfaceArg default-route-distance=2

    :if ($resutlTestError=false) do={
        :return "Ok! ifNecessarySwitchTrafficByDhcpClient"
    }
    :return $resutlTestError
}


:global testRenewDhcp do={
    # Args
    # interfaceArg
    # Testing function

    :global renewDhcp
    
    :local result [$renewDhcp interfaceArg=$interfaceArg]
    :if ($result=true) do={
        :return "Ok! testRenewDhcp"
    }
    :return "Error! testRenewDhcp"
}


:global testCheckInternet do={
    # Args
    # checkInterface
    # PingTargets
    # PingCount
    
    # test function
    :global checkInternet

    :local testResult "Ok! testCheckInternet";
    :do {
        :local isOkInternet [$checkInternet checkInterface=$checkInterface PingTargets=$PingTargets PingCount=$PingCount]
        :if ($isOkInternet=false) do={
            set testResult "Error! testCheckInternet isOkInternet=false!"
        }

        # Add firewall filter for ICMP packets on checkInterface
        # TODO place-before=1??? в разных кейсах разное значение?
        /ip firewall filter add chain=input place-before=0 in-interface=$checkInterface action=drop protocol=icmp comment="testCheckInternet: Block ICMP"
        :delay 2s;
        # Check that the internet connection is now blocked
        :local isBlockedInternet [$checkInternet checkInterface=$checkInterface PingTargets=$PingTargets PingCount=$PingCount]
        :if ($isBlockedInternet=true) do={
            set testResult "Error! testCheckInternet isBlockedInternet=true!"
        }

    } on-error={
        set testResult "Error! testCheckInternet"
    }

    # Remove the test firewall rule
    /ip firewall filter remove [find comment="testCheckInternet: Block ICMP"]

    :return $testResult
}



:global testResetUsb do={
    # Used functions
    :global fResetUSBPower
    :put "===== testResetUsb"

    :local result [$fResetUSBPower]
    :if ($result=true) do={
        :return "OK! testResetUsb"
    }
    :return "ERROR! testResetUsb"
}

:global testMainCheckInterfacesAndSwitch do={
    # Args
    # MainInterface
    # BackupInterface
    # PingCount
    # PingTargets

    # Used function mainCheckInterfacesAndSwitch
    :global mainCheckInterfacesAndSwitch;
    :global helperOffICMP;
    :global helperOnICMP;

    :local resultTest true
    :local msg;
    :local commentBlockICMP "Block ICMP for test Switch"
    :do {
        :local mainInterfaceDistance
        :local backupInterfaceDistance
        :local isWorkFunc;
        :local onDistance 1
        :local offDistance 2

        set mainInterfaceDistance [/ip dhcp-client get [find interface=$MainInterface] default-route-distance]
        set backupInterfaceDistance [/ip dhcp-client get [find interface=$BackupInterface] default-route-distance]
        :if ($mainInterfaceDistance!=$onDistance) do={
            set resultTest "mainInterfaceDistance must be onDistance in start"
            :put $resultTest
            :error resultTest
        }
        :if ($backupInterfaceDistance!=$offDistance) do={
            set resultTest "mainInterfaceDistance must be offDistance in start"
            :put $resultTest
            :error resultTest
        }



        set msg "---------1. testMainCheckInterfacesAndSwitch Check normal case"
        :put $msg
        set isWorkFunc [$mainCheckInterfacesAndSwitch MainInterfaceArg=$MainInterface BackupInterfaceArg=$BackupInterface PingCountArg=$PingCount PingTargetsArg=$PingTargets]
        :if ($isWorkFunc!=true) do={
            set resultTest "testMainCheckInterfacesAndSwitch something erro in mainCheckInterfacesAndSwitch"
            :put $resultTest
            :error resultTest
        }

        set mainInterfaceDistance [/ip dhcp-client get [find interface=$MainInterface] default-route-distance]
        set backupInterfaceDistance [/ip dhcp-client get [find interface=$BackupInterface] default-route-distance]
        :if ($mainInterfaceDistance!=1) do={
            set resultTest "testMainCheckInterfacesAndSwitch mainInterfaceDistance!=1 $mainInterfaceDistance"
            :put $resultTest
            :error resultTest
        }
        :if ($backupInterfaceDistance!=2) do={
            set resultTest "testMainCheckInterfacesAndSwitch backupInterfaceDistance!=2 $backupInterfaceDistance"
            :put $resultTest
            :error resultTest
        }

        # TODO вынести в отделную функцию
        # return state!
        :put "return state!"
        /ip dhcp-client set $MainInterface default-route-distance=1
        /ip dhcp-client set $BackupInterface default-route-distance=2
        :put [$helperOnICMP]

        :put "---------2. testMainCheckInterfacesAndSwitch Check off main internet"
        :put [$helperOffICMP interfaceArg=$MainInterface]
        set isWorkFunc [$mainCheckInterfacesAndSwitch MainInterfaceArg=$MainInterface BackupInterfaceArg=$BackupInterface PingCountArg=$PingCount PingTargetsArg=$PingTargets]
        :if ($isWorkFunc!=true) do={
            set resultTest "isWorkFunc !=true testMainCheckInterfacesAndSwitch Check off main internet"
            :put $resultTest
            :error resultTest
        }
        set mainInterfaceDistance [/ip dhcp-client get [find interface=$MainInterface] default-route-distance]
        set backupInterfaceDistance [/ip dhcp-client get [find interface=$BackupInterface] default-route-distance]
        :if ($mainInterfaceDistance != $offDistance) do={
            set resultTest "testMainCheckInterfacesAndSwitch mainInterfaceDistance!=$offDistance $mainInterfaceDistance !=$offDistance"
            :put $resultTest
            :error resultTest
        }

        :if ($backupInterfaceDistance != $onDistance) do={
            set resultTest "testMainCheckInterfacesAndSwitch backupInterfaceDistance!=1 $backupInterfaceDistance"
            :put $resultTest
            :error resultTest
        }

        # TODO вынести в отделную функцию
        # return state!
        :put "return state!"
        /ip dhcp-client set $MainInterface default-route-distance=1
        /ip dhcp-client set $BackupInterface default-route-distance=2
        :put [$helperOnICMP]
        
        :put "---------3. testMainCheckInterfacesAndSwitch Check on and return main internet"
        [$helperOnICMP]

        # Переводим на запасной интерент
        /ip dhcp-client set $MainInterface default-route-distance=2
        /ip dhcp-client set $BackupInterface default-route-distance=1

        set isWorkFunc [$mainCheckInterfacesAndSwitch MainInterfaceArg=$MainInterface BackupInterfaceArg=$BackupInterface PingCountArg=$PingCount PingTargetsArg=$PingTargets]
        :if ($isWorkFunc!=true) do={
            set resultTest "isWorkFunc !=true testMainCheckInterfacesAndSwitch Check return main internet"
            :put $resultTest
            :error resultTest
        }
        set mainInterfaceDistance [/ip dhcp-client get [find interface=$MainInterface] default-route-distance]
        set backupInterfaceDistance [/ip dhcp-client get [find interface=$BackupInterface] default-route-distance]
        # todo Можно вынести в отдельную
        :if ($mainInterfaceDistance!=1) do={
            set resultTest "testMainCheckInterfacesAndSwitch mainInterfaceDistance!=1 $mainInterfaceDistance"
            :put $resultTest
            :error resultTest
        }
        :if ($backupInterfaceDistance!=2) do={
            set resultTest "testMainCheckInterfacesAndSwitch backupInterfaceDistance!=2 $backupInterfaceDistance"
            :put $resultTest
            :error resultTest
        }



    } on-error={
        set msg "cathc somthing ERORR $resultTest"
    }

    # return state!
    :put "return state!"
    /ip dhcp-client set $MainInterface default-route-distance=1
    /ip dhcp-client set $BackupInterface default-route-distance=2
    :put [$helperOnICMP]

    :if (([:type $resultTest]="bool") && ($resultTest=true)) do={
        set msg "succes testMainCheckInterfacesAndSwitch succes!"
        :put $msg
        :return $resultTest
    }

    set msg "Error testMainCheckInterfacesAndSwitch $resultTest!"
    :put $msg
    :return $msg
}



:global testTables do={
    # Args
    # routingTable

    :local resultTest true
    :local msg;
    :local isRoutingTablePresent [/routing/table/find name=$routingTable]

    :if ($isRoutingTablePresent != "") do={
        set $msg  "OK! testTables Routing table $routingTable is present"
    } else={
        set $msg "ERROR! testTables Routing table $routingTable is not present"
    }
}


:global testScriptDHCPclient do={
    # Args
    # interfaceArg 
    # scriptSource

    :local resultTest true
    :local msg;
    :local dhcpClientID [/ip/dhcp-client find interface=$interfaceArg]
    if ([:len $dhcpClientID] > 0) do={
        :put 111
        :local resultScriptDHCPClient [/ip/dhcp-client get [find interface=$interfaceArg] script]
        :put 222
        :if ($resultScriptDHCPClient != "") do={
            :put 333
            :if ($resultScriptDHCPClient = $scriptSource) do={
                set $msg "OK! The script in DHCP client on interface $interfaceArg matches the expected script."
            } else={
                set $msg "WARNING! The script in DHCP client on interface $interfaceArg does not match the expected script."
                set $resultTest false
            }
        } else={
            set $msg "ERROR! No script found in DHCP client on interface $interfaceArg."
            set $resultTest false
        }
    } else={
        set $msg "ERROR! No DHCP client found on interface $interfaceArg."
        set $resultTest false
    }

    :put $msg
    :return $msg
}
:local scriptDHCPISP1 "# bound 
# lease-address
# gateway-address
:local dstAddress \"0.0.0.0/0\"
:local routingTableName \"ISP1\"

:if (\$bound = 1) do={
    # Check if such a route already exists
    :local existingRouteId [/ip route find dst-address=\$dstAddress routing-table=\$routingTableName]
    
    # If the route does not exist, create it
    :if ([:len \$existingRouteId] = 0) do={
        /ip route add dst-address=\$dstAddress gateway=\$\"gateway-address\" routing-table=\$routingTableName
    }
} else={
    # If the lease is removed, delete the corresponding route
    /ip route remove [find dst-address=\$dstAddress routing-table=\$routingTableName]
}"

:local scriptDHCPISP2 "# bound 
# lease-address
# gateway-address
:local dstAddress \"0.0.0.0/0\"
:local routingTableName \"ISP2\"

:if (\$bound = 1) do={
    # Check if such a route already exists
    :local existingRouteId [/ip route find dst-address=\$dstAddress routing-table=\$routingTableName]
    
    # If the route does not exist, create it
    :if ([:len \$existingRouteId] = 0) do={
        /ip route add dst-address=\$dstAddress gateway=\$\"gateway-address\" routing-table=\$routingTableName
    }
} else={
    # If the lease is removed, delete the corresponding route
    /ip route remove [find dst-address=\$dstAddress routing-table=\$routingTableName]
}"

:put "\n\n"

:put "====== 0 testHelperOffICMP"
:put "MainInterface $MainInterface"
:local resultTestHelperOffICMP [$testHelperOffICMP interfaceArg=$MainInterface]
:put $resultTestHelperOffICMP
:put "\n\n"


:put "====== 1 test Environment"
:local resultTestEnvironment [$testEnvironment MainInterfaceArg=$MainInterface BackupInterfaceArg=$BackupInterface]
:put $resultTestEnvironment
:put "\n\n"



:put "====== 2 testifNecessarySwitchTrafficByDhcpClient"
:local resultTestifNecessarySwitchTrafficByDhcpClient [$testifNecessarySwitchTrafficByDhcpClient MainInterfaceArg=$MainInterface BackupInterfaceArg=$BackupInterface]
:put $resultTestifNecessarySwitchTrafficByDhcpClient
:put "\n\n"


:put "====== 3 testRenewDhcp"
:local resultTestRenewDhcp [$testRenewDhcp interfaceArg=$MainInterface]
:put $resultTestRenewDhcp
:put "\n\n"

:put "====== 4 testCheckInternet"
:local resultTestCheckInternet [$testCheckInternet checkInterface=$MainInterface PingTargets=$PingTargets PingCount=$PingCount]
:put $resultTestCheckInternet
:put "\n\n"

:put "====== 5 testMainCheckInterfacesAndSwitch"
:local resultTestMainCheckInterfacesAndSwitch [$testMainCheckInterfacesAndSwitch MainInterface=$MainInterface BackupInterface=$BackupInterface PingTargets=$PingTargets PingCount=$PingCount]
:put $resultTestMainCheckInterfacesAndSwitch
:put "\n\n"

:put "====== 6 testScriptDHCPclient"
:put $MainInterface
:local resultTestScriptDHCPclient1 [$testScriptDHCPclient interfaceArg=$MainInterface scriptSource=$scriptDHCPISP1]
:local resultTestScriptDHCPclient2 [$testScriptDHCPclient interfaceArg=$BackupInterface scriptSource=$scriptDHCPISP2]
:put "\n\n"

:put "====== 7 testTables"
:local resultTestTablesISP1 [$testTables routingTable=$nameTableISP1]
:local resultTestTablesISP2 [$testTables routingTable=$nameTableISP2]
:put "\n\n"

:put "====== 8 testResetUsb"
:local resultTestResetUsb [$testResetUsb]
:put $resultTestResetUsb
:put "\n\n"

:put "======summary"
:put $resultTestHelperOffICMP
:put $resultTestifNecessarySwitchTrafficByDhcpClient
:put $resultTestRenewDhcp
:put $resultTestCheckInternet
:put $resultTestMainCheckInterfacesAndSwitch
:put $resultTestScriptDHCPclient2
:put $resultTestTablesISP1
:put $resultTestTablesISP2
:put $resultTestResetUsb