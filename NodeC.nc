#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC {
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    Node -> MainC.Boot;
    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components new MatrixC(uint16_t, uint16_t, 20, 20) as PacketsReceived;  // Added both size parameters
    Node.PacketsReceived -> PacketsReceived;

    components FloodingC;
    Node.Flooding -> FloodingC;

    components NeighborDiscoveryC;
    Node.NeighborDiscovery -> NeighborDiscoveryC;

    components LinkStateRoutingC;
    Node.LinkStateRouting -> LinkStateRoutingC;
    FloodingC.LinkStateRouting -> LinkStateRoutingC;  // Add this connection
}