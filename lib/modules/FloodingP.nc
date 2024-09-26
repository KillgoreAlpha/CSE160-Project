#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

generic module FloodingP(){
   provides interface Flooding;

   uses interface Queue<sendInfo*>;
   uses interface Pool<sendInfo>;

   uses interface Timer<TMilli> as sendTimer;

   uses interface Packet;
   uses interface AMPacket;
   uses interface AMSend;

   uses interface Random;
}

implementation{
    
}