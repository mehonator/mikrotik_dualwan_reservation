# bound 
# lease-address
# gateway-address
:local dstAddress "0.0.0.0/0"
:local routingTableName "ISP1"

:if ($bound = 1) do={
    # Check if such a route already exists
    :local existingRouteId [/ip route find dst-address=$dstAddress routing-table=$routingTableName]
    
    # If the route does not exist, create it
    :if ([:len $existingRouteId] = 0) do={
        /ip route add dst-address=$dstAddress gateway=$"gateway-address" routing-table=$routingTableName
    }
} else={
    # If the lease is removed, delete the corresponding route
    /ip route remove [find dst-address=$dstAddress routing-table=$routingTableName]
}