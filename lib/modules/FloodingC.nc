#include "../../includes/am_types.h"

configuration FloodingC{
   provides interface Flooding;
}

implementation{
   components new FloodingP();
   Flooding = FloodingP.Flooding;

   components new TimerMilliC() as sendTimer;
   components RandomC as Random;
   components new AMSenderC(channel);

   //Timers
   FloodingP.sendTimer -> sendTimer;
   FloodingP.Random -> Random;

   FloodingP.Packet -> AMSenderC;
   FloodingP.AMPacket -> AMSenderC;
   FloodingP.AMSend -> AMSenderC;

   //Lists
   components new PoolC(sendInfo, 20);
   components new QueueC(sendInfo*, 20);

   FloodingP.Pool -> PoolC;
   FloodingP.Queue -> QueueC;
}
