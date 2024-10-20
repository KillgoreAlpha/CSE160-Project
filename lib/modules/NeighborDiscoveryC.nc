#include <Timer.h>
#include "../../includes/CommandMsg.h"
#include "../../includes/packet.h"
#include "../../includes/constants.h"

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

       components new HashmapC(uint16_t, MAX_NEIGHBORS) as NeighborMapC;
       NeighborDiscoveryP.NeighborMap -> NeighborMapC;
}