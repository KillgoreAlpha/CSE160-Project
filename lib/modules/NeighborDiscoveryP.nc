#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;
    uses interface Timer<TMilli> as delayTimer;
    uses interface Queue<sendInfo*>;
    uses interface Pool<sendInfo>;

    uses interface Timer<TMilli> as sendTimer;

    uses interface Packet;
    uses interface AMPacket;
    uses interface AMSend;

    uses interface Random;
}

implementation{
    pack NEIGHBOR_DISCOVERY_PACKET;
    pack NEIGHBOR_REPLY_PACKET;
    int SEQUENCE_NUMBER = 0;
    command void NeighborDiscovery.start(){
        call delayTimer.startPeriodic(TICKS * 3);
    }

    event void delayTimer.fired(){
        uint8_t* PAYLOAD = "";
        uint8_t TTL = 1;
        makePack(&NEIGHBOR_DISCOVERY_PACKET, TOS_NODE_ID, AM_BROADCAST_ADDR, TTL, PROTOCOL_NEIGHBOR, SEQUENCE_NUMBER, PAYLOAD, 0);
        call Sender.send(NEIGHBOR_DISCOVERY_PACKET, AM_BROADCAST_ADDR);
        SEQUENCE_NUMBER++;
    }

    command void NeighborDiscovery.reply(pack* DISCOVERY_PACKET){
        uint8_t* PAYLOAD = "";
        uint8_t TTL = 1;
        makePack(&DISCOVERY_PACKET, DISCOVERY_PACKET->src, AM_BROADCAST_ADDR, TTL, PROTOCOL_NEIGHBOR_REPLY, DISCOVERY_PACKET->seq, PAYLOAD, 0);
        call Sender.send(NEIGHBOR_REPLY_PACKET, NEIGHBOR_DISCOVERY_PACKET->src);
    }

    command void NeighborDiscovery.getReply(pack* NEIGHBOR_CONFIRMATION_PACKET){
        
        int NEIGHBOR = NEIGHBOR_CONFIRMATION_PACKET->src;

    }

}

// command error_t Flooding.start(){
//     call delayTimer.startOneShot(START_DELAY * 1000);
//     // call delayTimer.startPeriodic(START_DELAY * 1000);
// }