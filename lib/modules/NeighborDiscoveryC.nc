#include <Timer.h>
#include "../../includes/CommandMsg.h"
#include "../../includes/packet.h"

configuration NeighborDiscoveryC {
       provides interface NeighborDiscovery;
}

implementation {
       components NeighborDiscoveryP;
       NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

       components new TimerMilliC() as sendTimer;
       NeighborDiscoveryP.sendTimer -> sendTimer;

       components new SimpleSendC(AM_PACK);
       NeighborDiscoveryP.SimpleSend -> SimpleSendC;

       components new HashmapC(uint16_t, 20) as NeighborMapC;
       NeighborDiscoveryP.NeighborMap -> NeighborMapC;

        components LinkStateRoutingC;
        NeighborDiscoveryP.LinkStateRouting -> LinkStateRoutingC;
}