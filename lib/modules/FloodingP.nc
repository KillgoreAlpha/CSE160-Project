#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

module FloodingP{
   provides interface Flooding;
   uses interface Packet;
   uses interface SimpleSend;
//    uses interface Timer<TMilli> as sendTimer;

}

implementation{
    uint16_t SEQUENCE_NUMBER;


    command void Flooding.newFlood(uint16_t TARGET){
        uint8_t TTL = MAX_TTL;
        uint8_t* PAYLOAD = "";
        pack* FLOOD_PACKET;
        dbg(FLOODING_CHANNEL, "NEW FLOOD SENT \n");
        makePack(&FLOOD_PACKET, TOS_NODE_ID, TARGET, TTL, PROTOCOL_FLOOD, SEQUENCE_NUMBER, PAYLOAD, 0);
        call SimpleSend.send(FLOOD_PACKET, AM_BROADCAST_ADDR);
    }

    command void Flooding.forwardFlood(pack* FLOOD_PACKET){
        uint8_t TTL = (FLOOD_PACKET->TTL) - 1;
        uint8_t* PAYLOAD = "";
        SEQUENCE_NUMBER = (FLOOD_PACKET->seq) + 1;
        dbg(FLOODING_CHANNEL, "FLOOD PACKET RECIEVED \n");
        makePack(&FLOOD_PACKET, TOS_NODE_ID, FLOOD_PACKET->dest, TTL, PROTOCOL_FLOOD, SEQUENCE_NUMBER, PAYLOAD, 0);
        call SimpleSend.send(FLOOD_PACKET, AM_BROADCAST_ADDR);
    }   
}