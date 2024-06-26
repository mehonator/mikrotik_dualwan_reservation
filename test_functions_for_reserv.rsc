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
    :put "helperOffICMP interfaceArg $interfaceArg"

    /ip firewall filter add chain=input place-before=*0 in-interface=$interfaceArg action=drop protocol=icmp comment="Block ICMP for test Switch"
    :put "icmp been offed"
    :delay 5s
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
    :put "testHelperOffICMP"

    # Used functions
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


:global checkInterfaceAndDhcpClient do={
    # Args
    # ArgInterface: The name of the main interface to check
    #
    # return: Returns true if the main interface, a DHCP client for this interface, and a static DHCP client exist; otherwise, returns false

    # Check interfaces
    :put "Check exists $ArgInterface"
    :if ([:len [/interface find name=$ArgInterface]] = 0) do={
        :local errorText "Main interface $ArgInterface not found"
        :log error ($errorText)
        :return false
    }

    :put "Check exist DHCP clients for interface $ArgInterface"
    :local isExistMainDhcpClient [$checkDhcpClientExists ArgInterface=$ArgInterface]
    :if ($isExistMainDhcpClient = false) do={
        :local errorText "No DHCP client found for main interface $ArgInterface"
        :put $errorText
        :log error ($errorText)
        :return false
    }

    # Check static DHCP clients
    :put "Check static DHCP clients"
    :if ([:len [/ip dhcp-client find interface=$ArgInterface static=yes]] = 0) do={
        :local errorText "No static DHCP client found for main interface $ArgInterface"
        :log error $errorText
        :return false
    }

    :return true
}


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
        :return "PASS testEnvironment"

        # Check interfaces
        :put "Check MainInterfaceArg $MainInterfaceArg"
        :local result [$checkInterfaceAndDhcpClient ArgInterface=$MainInterfaceArg]
        :if ($result = false) do={
            :log error ("Main interface $MainInterfaceArg check failed")
            :return false
        }
        :put "Check BackupInterfaceArg $BackupInterfaceArg"
        :set result [$checkInterfaceAndDhcpClient ArgInterface=$BackupInterfaceArg]
        :if ($result = false) do={
            :log error ("Main interface $BackupInterfaceArg check failed")
            :return false
        }

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
        :put "Prepare dhcp-client set default-route-distance=2 "
        /ip dhcp-client set $MainInterfaceArg default-route-distance=2

        :put "switch to MainInterface"
        :put [$ifNecessarySwitchTrafficByDhcpClient interfaceToSwitch=$MainInterfaceArg mainInterface=$MainInterfaceArg backupInterface=$BackupInterfaceArg]
        :delay 2s;
        :local expected 1
        :local real [/ip dhcp-client get $MainInterfaceArg default-route-distance]
        :put "default-route-distance  of $MainInterfaceArg ==  $real"
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
        :return "PASS ifNecessarySwitchTrafficByDhcpClient"
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
        :return "PASS testRenewDhcp"
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

    :local testResult "PASS testCheckInternet";
    :do {
        :local isOkInternet [$checkInternet checkInterface=$checkInterface PingTargets=$PingTargets PingCount=$PingCount]
        :if ($isOkInternet=false) do={
            set testResult "Error! testCheckInternet isOkInternet=false!"
        }

        # Add firewall filter for ICMP packets on checkInterface
        # TODO place-before=1??? в разных кейсах разное значение?
        /ip firewall filter add chain=input place-before=*0 in-interface=$checkInterface action=drop protocol=icmp comment="testCheckInternet: Block ICMP"
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
    
    do {
        :local result [$fResetUSBPower]
        :if ($result=true) do={
            :return "PASS testResetUsb"
        }
        :return "ERROR! testResetUsb, result=$result"
    } on-error={
        :return "ERROR! testResetUsb on-error catch may be not found /system routerboard" 
    }
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
        set $msg  "PASS testTables Routing table $routingTable is present"
        put $msg
        return $msg
    } else={
        set $msg "ERROR! testTables Routing table $routingTable is not present"
        put $msg
        return $msg
    }
}


:global testScriptDHCPclient do={
    # Args
    # interfaceArg 
    # scriptSource


    :local msg;
    :local dhcpClientID [/ip/dhcp-client find interface=$interfaceArg]
    if ([:len $dhcpClientID] > 0) do={
        :local resultScriptDHCPClient [/ip/dhcp-client get [find interface=$interfaceArg] script]
        :if ($resultScriptDHCPClient != "") do={
            :if ($resultScriptDHCPClient = $scriptSource) do={
                set $msg "OK! The script in DHCP client on interface $interfaceArg matches the expected script."
                :put $msg
                :return $msg
            } else={
                set $msg "WARNING! The script in DHCP client on interface $interfaceArg does not match the expected script."
                :return $msg
            }
        } else={
            set $msg "ERROR! No script found in DHCP client on interface $interfaceArg."
            :put $msg
            :return $msg
        }
    } else={
        set $msg "ERROR! No DHCP client found on interface $interfaceArg."
        :put $msg
        :return $msg
    }
    :put $msg
    :return $msg
}


:global testDhcpClientExists do={
    # Args 
    # ArgInterface: The interface to check DHCP client existence.

    # Used functions
    :global checkDhcpClientExists

    :local resultMsg ""
    :put "Testing DHCP Client existence on interface $ArgInterface"
    :local isExistDHCPClient [$checkDhcpClientExists ArgInterface=$ArgInterface]
    :put "DHCP Client Exists: $isExistDHCPClient"
    
    # Checking the type of isExistDHCPClient to ensure it is a boolean.
    :if ([:typeof $isExistDHCPClient] != "bool") do={
        :set resultMsg "ERROR: Unexpected type for isExistDHCPClient. Expected 'bool', got '[:typeof $isExistDHCPClient]'."
    } else={
        :if ($isExistDHCPClient = true)  do={
            :set resultMsg ("PASS: DHCP client absence on $ArgInterface matches expected result.")
        } else={
            :set resultMsg ("FAIL: Expected DHCP client not to exist on $ArgInterface.")
        }
    }

    :return $resultMsg
}
:global testDhcpClientNotExists do={
    # Args 
    # ArgInterface

    # Used functions
    :global checkDhcpClientExists

    :local resultMsg ""
    :put "testDhcpClientNotExists ArgInterface $ArgInterface"
    :local isExistDHCPClient [$checkDhcpClientExists ArgInterface=$ArgInterface]
    :put "isExistDHCPClient $isExistDHCPClient"
    # Checking the type of isExistDHCPClient to ensure it is a boolean.
    :if ([:typeof $isExistDHCPClient] != "bool") do={
        :set resultMsg "ERROR: Unexpected type for isExistDHCPClient. Expected 'bool', got '[:typeof $isExistDHCPClient]'."
    } else={
    :if ($isExistDHCPClient = false)  do={
        :set resultMsg ("PASS: No DHCP client on $ArgInterface as expected.")
    } else={
        :set resultMsg ("FAIL: Expected no DHCP client presence on $ArgInterface, but found one.")
    }}

    :return $resultMsg
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



:put "====== 8 testDhcpClientExists"
:local resultTestDhcpClientExists [$testDhcpClientExists ArgInterface=$MainInterface]
:put $resultTestDhcpClientExists
:put "\n\n"

:put "====== 9 testDhcpClientNotExists"
:local resultTestDhcpClientNotExists [$testDhcpClientNotExists ArgInterface="ether5"]
:put $resultTestDhcpClientNotExists


:put "====== 10 testResetUsb"
:local resultTestResetUsb [$testResetUsb]
:put $resultTestResetUsb
:put "\n\n"

:put "======summary"
:put "====== 0 testHelperOffICMP"
:put $resultTestHelperOffICMP
:put "====== 2 testifNecessarySwitchTrafficByDhcpClient"
:put $resultTestifNecessarySwitchTrafficByDhcpClient
:put "====== 3 testRenewDhcp"
:put $resultTestRenewDhcp
:put "====== 4 testCheckInternet"
:put $resultTestCheckInternet
:put "====== 5 testMainCheckInterfacesAndSwitch"
:put $resultTestMainCheckInterfacesAndSwitch
:put "====== 6 testScriptDHCPclient"
:put $resultTestScriptDHCPclient1
:put $resultTestScriptDHCPclient2
:put "====== 7 testTables"
:put $resultTestTablesISP1
:put $resultTestTablesISP2
:put "====== 8 testDhcpClientExists"
:put $resultTestDhcpClientExists
:put "====== 9 testDhcpClientNotExists"
:put $resultTestDhcpClientNotExists
:put "====== 10 testResetUsb"
:put $resultTestResetUsb