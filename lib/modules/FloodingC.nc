configuration FloodingC {
   provides interface Flooding;
}

implementation {
   components FloodingP;
   Flooding = FloodingP.Flooding;

   components new SimpleSendC(AM_PACK);
   FloodingP.SimpleSend -> SimpleSendC;

   components new HashmapC(uint16_t, 64) as SeenPacketsC;
   FloodingP.SeenPackets -> SeenPacketsC;
}