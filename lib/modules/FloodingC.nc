configuration FloodingC {
    provides interface Flooding;
    uses interface LinkStateRouting;
}

implementation {
    components FloodingP;
    components new SimpleSendC(AM_FLOODING);
    components new HashmapC(uint16_t, 20) as SeenPacketsMap;
    
    Flooding = FloodingP.Flooding;
    
    FloodingP.SimpleSend -> SimpleSendC.SimpleSend;
    FloodingP.Packet -> SimpleSendC;
    FloodingP.SeenPackets -> SeenPacketsMap;
    FloodingP.LinkStateRouting = LinkStateRouting;
}