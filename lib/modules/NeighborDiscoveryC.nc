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

       components new HashmapC(uint16_t, 20) as SeqNoMapC;
       NeighborDiscoveryP.SeqNoMap -> SeqNoMapC;
   }