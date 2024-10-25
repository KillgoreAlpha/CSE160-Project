includes Transport;
includes AMSenderC;
includes AMReceiverC;
includes ActiveMessageC;
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

    // Remove this since Node.nc doesn't use it
    // components new MatrixC(uint16_t, uint16_t, 20, 20) as ReceivedMatrix;
    // Node.PacketsReceived -> ReceivedMatrix;

    components FloodingC;
    Node.Flooding -> FloodingC;

    components NeighborDiscoveryC;
    Node.NeighborDiscovery -> NeighborDiscoveryC;

    components LinkStateRoutingC;
    Node.LinkStateRouting -> LinkStateRoutingC;
    FloodingC.LinkStateRouting -> LinkStateRoutingC;
}