# for ROS  7
# v 0.0.1
:put "set global vars"
/system/script/run set_global_varible
:put "global vars was setted"


:global PingCount
:global PingTargets
:global MainInterface
:global BackupInterface
:local isResetUsb false


:put "load functions_for_reserv"
/system/script/run functions_for_reserv
:put "loaded functions_for_reserv"
:global mainCheckInterfacesAndSwitch


[$mainCheckInterfacesAndSwitch MainInterfaceArg=$MainInterface BackupInterfaceArg=$BackupInterface PingCountArg=$PingCount PingTargetsArg=$PingTargets isResetUsb=$isResetUsb ]
