#include <Timer.h>
#include "../../includes/CommandMsg.h"
#include "../../includes/packet.h"
#include "../../includes/constants.h"

configuration LinkStateRoutingC {
    provides interface LinkStateRouting;
}

implementation {
    components LinkStateRoutingP;
    LinkStateRouting = LinkStateRoutingP.LinkStateRouting;

    components new SimpleSendC(AM_PACK);
    LinkStateRoutingP.Sender -> SimpleSendC;

    components new MatrixC(uint16_t, uint16_t, LINK_STATE_MAX_ROUTES, 32);
    LinkStateRoutingP.PacketsReceived -> MatrixC;

    components NeighborDiscoveryC;
    LinkStateRoutingP.NeighborDiscovery -> NeighborDiscoveryC;    

    components FloodingC;
    LinkStateRoutingP.Flooding -> FloodingC;

    components new TimerMilliC() as LSRTimer;
    LinkStateRoutingP.LSRTimer -> LSRTimer;

    components RandomC as Random;
    LinkStateRoutingP.Random -> Random;
}