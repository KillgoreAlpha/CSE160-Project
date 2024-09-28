configuration NeighborDiscoveryC{
   provides interface NeighborDiscovery;
}

implementation{
    components NeighborDiscoveryP;
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    components new TimerMilliC() as sendTimer;
    NeighborDiscoveryP.sendTimer -> sendTimer;

    components new SimpleSendC(AM_PACK);
    NeighborDiscoveryP.SimpleSend -> SimpleSendC;
}
