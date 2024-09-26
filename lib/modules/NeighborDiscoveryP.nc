#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;
    // uses interface Timer<TMilli> as delayTimer;
    uses interface Queue<sendInfo*>;
    uses interface Pool<sendInfo>;

    uses interface Timer<TMilli> as sendTimer;

    uses interface Packet;
    uses interface AMPacket;
    uses interface AMSend;

    uses interface Random;
}

implementation{
    command void NeighborDiscovery.pass(){}
}

// command error_t Flooding.start(){
//     call delayTimer.startOneShot(START_DELAY * 1000);
//     // call delayTimer.startPeriodic(START_DELAY * 1000);
// }

// event void delayTimer.fired(){
//     // makePack()
//     // call SimpleSend.send()
//     // delayTimerSeq++
// }

// void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
//     Package->src = src;
//     Package->dest = dest;
//     Package->TTL = TTL;
//     Package->seq = seq;
//     Package->protocol = protocol;
//     memcpy(Package->payload, payload, length);
// }

// // AM_BROADCAST_ADDR