configuration FloodingC {
    provides interface Flooding;
    uses interface LinkStateRouting;
}

implementation {
    components FloodingP;
    components SimpleSendC;
    components new HashmapC(uint16_t, 20) as SeenPackets;
    
    Flooding = FloodingP.Flooding;
    
    FloodingP.Packet -> SimpleSendC;
    FloodingP.SimpleSend -> SimpleSendC;
    FloodingP.SeenPackets -> SeenPackets;
    FloodingP.LinkStateRouting = LinkStateRouting;
}