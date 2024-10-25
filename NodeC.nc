#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

module Node {
    uses interface Boot;
    uses interface SplitControl as AMControl;
    uses interface Receive;
    uses interface SimpleSend as Sender;
    uses interface CommandHandler;
    uses interface Transport;
    uses interface NeighborDiscovery;
    uses interface Flooding;
    uses interface LinkStateRouting;
}

configuration NodeC {
}
implementation {
    components MainC;
    components new NodeC() as Node;  // Create new instance
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components new AMSenderC(AM_PACK) as AMSend;
    components ActiveMessageC;
    components CommandHandlerC;
    components FloodingC;
    components NeighborDiscoveryC;
    components LinkStateRoutingC;
    components TransportC;

    // Wire the components
    Node -> MainC.Boot;
    Node.Receive -> GeneralReceive;
    Node.AMControl -> ActiveMessageC;
    Node.Sender -> AMSend;
    Node.CommandHandler -> CommandHandlerC;
    Node.Flooding -> FloodingC;
    Node.NeighborDiscovery -> NeighborDiscoveryC;
    Node.LinkStateRouting -> LinkStateRoutingC;
    Node.Transport -> TransportC;
    
    // Wire FloodingC 
    FloodingC.LinkStateRouting -> LinkStateRoutingC;
}