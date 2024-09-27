#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

generic module FloodingP(){
   provides interface Flooding;

   uses interface Queue<sendInfo*>;
   uses interface Pool<sendInfo>;

    uses interface Timer<TMilli> as sendTimer;

    uses interface Packet;
    uses interface AMPacket;
    uses interface AMSend;
}

implementation{
    pack FLOOD_PACKET;
    uint16_t SEQUENCE_NUMBER = 0;

    command void Flooding.newFlood(uint16_t TARGET){
        uint8_t TTL = MAX_TTL;
        dbg(FLOODING_CHANNEL, "NEW FLOOD SENT \n");
        makePack(&FLOOD_PACKET, TOS_NODE_ID, TARGET, TTL, PROTOCOL_FLOOD, SEQUENCE_NUMBER, PAYLOAD, 0);
        call SimpleSend.send(FLOOD_PACKET, AM_BROADCAST_ADDR);
    }

    command void Flooding.forwardFlood(pack* FLOOD_PACKET){
        uint8_t TTL = (FLOOD_PACKET->TTL) - 1;
        SEQUENCE_NUMBER = (FLOOD_PACKET->seq) + 1;
        dbg(FLOODING_CHANNEL, "FLOOD PACKET RECIEVED \n");
        makePack(&FLOOD_PACKET, TOS_NODE_ID, FLOOD_PACKET->dest, TTL, PROTOCOL_FLOOD, SEQUENCE_NUMBER, PAYLOAD, 0);
        call SimpleSend.send(FLOOD_PACKET, AM_BROADCAST_ADDR);
    }   
}