configuration FloodingC {
    provides interface Flooding;
    uses {
        interface Packet;
        interface SimpleSend;
        interface Hashmap<uint16_t> as SeenPackets;
        interface LinkStateRouting;
    }
}


implementation {
    components FloodingP;
    components new SimpleSendC(AM_FLOODING);  // Make sure AM_FLOODING is defined
    components new HashmapC(uint16_t, 20) as SeenPackets;
    
    // Provide the Flooding interface
    Flooding = FloodingP.Flooding;
    
    // Wire the used interfaces
    FloodingP.Packet -> SimpleSendC;
    FloodingP.SimpleSend -> SimpleSendC.SimpleSend;  // Make sure to wire to .SimpleSend
    FloodingP.SeenPackets -> SeenPackets;
    FloodingP.LinkStateRouting = LinkStateRouting;
}