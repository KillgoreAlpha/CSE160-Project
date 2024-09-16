module NeighborDiscoveryP{
    provides interface NeighborDiscovery;
    // uses interface Timer<TMilli> as delayTimer;

}

implementation{
    command void NeighborDiscovery.pass(){}
}

// command error_t Flooding.start(){
//     call delayTimer.startOneShot(START_DELAY * 1000);
//     // call delayTimer.startPeriodic(START_DELAY * 1000);
// }

// even void delayTimer.fired(){
    
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