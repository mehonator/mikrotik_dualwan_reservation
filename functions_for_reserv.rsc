# for ROS  7

:global sendMessageToAdmin do={
    # Args
    # msgText
    :global nameRouter
    :global tokenBot
    :global chatId 

    :local msg "$nameRouter $msgText"
    /tool fetch output=none url="https://api.telegram.org/bot$tokenBot/sendMessage?chat_id=$chatId&text=$msg"

}

:global fResetUSBPower do={
    # return bool
    /log warning ("Restarting USB power...")
    /system routerboard usb power-reset duration=10 
    /delay delay-time=10 
    /log warning ("Restarting USB power complite")
    /log warning ("Await linkup lte")
    /delay delay-time= 30
    /log warning ("Out Await linkup lte")
    :return true
}

:global getDhcpGateway do={
    # args
    # interfaceArg
    # return ip addres
     :local res [/ip dhcp-client get [find interface=$interfaceArg] gateway]
     :return $res 
}



:global renewDhcp do={
    # args
    # interfaceArg
    # return bool
    :local interfaceArg $interfaceArg
    /ip dhcp-client release [find interface=$interfaceArg]
    :delay 2s
    /ip dhcp-client renew [find interface=$interfaceArg]
    :delay 2s
    :return true
}

:global checkDhcpClientExists do={
    # Arguments:
    #   ArgInterface - Name of the interface to check for DHCP client (string)
    #
    # Returns:
    #   true if DHCP client exists, false otherwise

    :put "Check DHCP clients for interface: $ArgInterface";
    :log info ("Check DHCP clients for interface: $ArgInterface");
    :local countClients [:len [/ip dhcp-client find interface=$ArgInterface]]
    :if ($countClients = 0) do={
        :log error ("No DHCP client found for interface $ArgInterface");
        :return false;
    } else={
        :log info ("DHCP client found for interface $ArgInterface");
        :return true;
    }
}

# TODO add analyze ping result or return percent success?
:global checkInternet do={
    # Args
    # checkInterface
    # PingTargets
    # PingCount
    # return bool

    :put ("checkInternet $checkInterface")
    :local host
    :local sumSuccessfulPing 0
    :local success true
    :put ("PingTargets  $PingTargets")
    foreach host in=$PingTargets do={
        :put ("Ping to " . $host )
        :local res
        :do {
            :set res [/ping $host interface=$checkInterface count=$PingCount]
            :set sumSuccessfulPing ($sumSuccessfulPing + $res)
            :put ("Ping to " . $host . ": " . $res)
            :if ($res > 0) do={
                :put ("Ping to " . $host . " is successful")
                :return true
            }
        } on-error={
            :set success false
            :put ("Error pinging host: " . $host . " on interface: " . $checkInterface)
            /log error ("Error pinging host: " . $host . " on interface: " . $checkInterface)
        }
    }
    :if ($success) do={
        :return ($sumSuccessfulPing > 0)
    } else={
        :return false
    }
}


:global ifNecessarySwitchTrafficByDhcpClient do={
    # args
    # interfaceToSwitch
    # mainInterface
    # backupInterface

    # return bool

    :local onDistance 1
    :local offDistance 2


    :local mainInterfaceDistance [/ip dhcp-client get [find interface=$mainInterface] default-route-distance]
    :local backupInterfaceDistance [/ip dhcp-client get [find interface=$backupInterface] default-route-distance]
    
    :put "mainInterface $mainInterface"
    :put "backupInterface $backupInterface"
    :put "interfaceToSwitch $interfaceToSwitch"
    :put "mainInterfaceDistance $mainInterfaceDistance"
    :put "backupInterfaceDistance $backupInterfaceDistance"


    :local currentInterfaceMinDist;

    # Check correct distance and fix
    :if ($mainInterfaceDistance = $backupInterfaceDistance) do={
        :put ("mainInterfaceDistance not must same backupInterfaceDistance! set 1 and 2")
        :log warning ("mainInterfaceDistance not must same backupInterfaceDistance! set 1 and 2")
        /ip dhcp-client  set $mainInterface default-route-distance=$onDistance
        /ip dhcp-client  set $backupInterface default-route-distance=$offDistance
        :return false
    }

    :if ($mainInterfaceDistance<=$backupInterfaceDistance) do={
        set currentInterfaceMinDist $mainInterface
    } else={
        set currentInterfaceMinDist $backupInterface
    }
    
    :if ($currentInterfaceMinDist=$interfaceToSwitch) do={
        :put ("currentInterfaceMinDist=interfaceToSwitch switch not necessery")
        :return true
    }

    :put ("switch to $interfaceToSwitch")

    :local interfaceToSwitchDistance [/ip dhcp-client get [find interface=$interfaceToSwitch] default-route-distance]
    :local backupInterfaceDistance [/ip dhcp-client get [find interface=$backupInterface] default-route-distance]

    :if ($interfaceToSwitchDistance != $onDistance) do={
        /ip dhcp-client set $interfaceToSwitch default-route-distance=$onDistance
    }
    :if ($currentInterfaceMinDist != $offDistance) do={
        /ip dhcp-client set $currentInterfaceMinDist default-route-distance=$offDistance
    }
    :return true
}




##################check env###############
# chek inteface and dhcp client
# TODO добавить проверку статичности dhcp client, иначе скрипт не работает
:global checkEnvironment do={
    # args
    # MainInterfaceArg
    # BackupInterfaceArg
   



    # Check necessary script functions
    :put "Check necessary script functions"
    :foreach func in={"checkInternet", "ifNecessarySwitchTrafficByDhcpClient", "renewDhcp", "getDhcpGateway", "fResetUSBPower"} do={
        :if ([:len [/system script environment find name=$func]] = "") do={

            :log error ("Script function $func not found")
            :return false
        }
    }

    :log info ("Environment check passed")
    :return true
}


###################  start main ##########################################
:global mainCheckInterfacesAndSwitch do={
    # args
    # MainInterfaceArg
    # BackupInterfaceArg
    # PingCountArg
    # PingTargetsArg
    # isResetUsb

    # return bool
    # Used function
    :global checkInternet;
    :global ifNecessarySwitchTrafficByDhcpClient;
    :global sendMessageToAdmin;
    :global fResetUSBPower;

    # Used global Vars
    :global isSendToAdminMainISPDown;
    :global isSendToAdminMainISPUP;

    :if ([:typeof $isSendToAdminMainISPDown]="nothing") do={
        :global isSendToAdminMainISPDown false;
    }

    :if ([:typeof $isSendToAdminMainISPUP]="nothing") do={
        :global isSendToAdminMainISPUP false;
    }


    # Check main provider
    :put ($checkInternet checkInterface=$MainInterfaceArg PingCount=$PingCountArg PingTargets=$PingTargetsArg)
    :local isOkMainISP [$checkInternet checkInterface=$MainInterfaceArg PingCount=$PingCountArg PingTargets=$PingTargetsArg]
    :if ($isOkMainISP) do={
        :put "Main provider is online"
        [$ifNecessarySwitchTrafficByDhcpClient interfaceToSwitch=$MainInterfaceArg mainInterface=$MainInterfaceArg backupInterface=$BackupInterfaceArg]
        :if ($isSendToAdminMainISPUP=false) do={
            [$sendMessageToAdmin msgText="Main provider is online"]
            /log warning ("Main provider is online")
            set isSendToAdminMainISPDown false;
            set isSendToAdminMainISPUP true;
        }
        :return true
    }

    /log warning ("Main provider is offline. Trying to renew IP...")
    :put "Main provider is offline. Trying to renew IP..."
    $renewDhcp interfaceArg=$MainInterfaceArg
    /delay 10s 

    # Check main provider again after DHCP renew
    :put "Check main provider again after DHCP renew"
    set isOkMainISP [$checkInternet checkInterface=$MainInterfaceArg PingCount=$PingCountArg PingTargets=$PingTargetsArg]
    :if ($isOkMainISP) do={
        /log warning ("Main provider is back online")
        [$ifNecessarySwitchTrafficByDhcpClient interfaceToSwitch=$MainInterfaceArg mainInterface=$MainInterfaceArg backupInterface=$BackupInterfaceArg]
        :put "Main provider is back online"
        :return true
    }
    :put "Main provider is  offline"

    # Check backup provider
    :put "Check backup provider"
    :local isOkBackupISP [$checkInternet checkInterface=$BackupInterfaceArg PingCount=$PingCountArg PingTargets=$PingTargetsArg]
    :if ($isOkBackupISP) do={
        :put "Backup provider is online"
        [$ifNecessarySwitchTrafficByDhcpClient interfaceToSwitch=$BackupInterfaceArg mainInterface=$MainInterfaceArg backupInterface=$BackupInterfaceArg]
        
        :if ($isSendToAdminMainISPDown=false) do={
            [$sendMessageToAdmin msgText="ERROR Fail Main internet! switch to Backup provider"]
            set isSendToAdminMainISPDown true;
            set isSendToAdminMainISPUP false;
        }

        :return true
    }

    :if ($isResetUsb=true) do={
        :put "Backup provider is offline. Restarting USB power..."
        /log warning ("Backup provider is offline. Restarting USB power...")
        [$fResetUSBPower]
        /delay 15s  
    }

    # Check backup provider again after
    :put "Check backup provider again after restart usb"
    /log warning ("Check backup provider again after restart usb")
    set isOkBackupISP [$checkInternet checkInterface=$BackupInterfaceArg PingCount=$PingCountArg PingTargets=$PingTargetsArg]
    :if ($isOkBackupISP) do={
        /log warning ("Backup provider is back online")
        :put "swithc to backup"
        [$ifNecessarySwitchTrafficByDhcpClient interfaceToSwitch=$BackupInterfaceArg mainInterface=$MainInterfaceArg backupInterface=$BackupInterfaceArg]
        :return true
    }

    /log warning ("Both main and backup providers are offline even after DHCP renew and USB reset")
   :put ("Both main and backup providers are offline even after DHCP renew and USB reset")
   :return true
}

:put "'functions_for_reserv' Loaded!"