# TODO вынести в глобальные переменные
:local routingTableNameISP1 "ISP1"
:local routingTableNameISP2 "ISP2"
:local intefaceISP1 "ether1"
:local intefaceISP2 "lte1"

/ip firewall mangle
{
    add action=mark-routing chain=output new-routing-mark=$routingTableNameISP1 out-interface=$intefaceISP1 passthrough=yes protocol=icmp  comment="Redirect ICMP packets on $intefaceISP1 routing table"
    add action=mark-routing chain=output new-routing-mark=$routingTableNameISP1 out-interface=$intefaceISP2 passthrough=yes protocol=icmp  comment="Redirect ICMP packets on  $intefaceISP2 routing table"
}