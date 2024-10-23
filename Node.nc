/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface Transport;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   // Project 1
   uses interface NeighborDiscovery;
   uses interface Flooding;

   // Project 2
   uses interface LinkStateRouting;

   // Project 3

   // Project 4

}

implementation{
   pack sendPackage;
   uint8_t myProtocol;
   uint8_t myTTL;
   uint8_t mySrc;
   uint8_t myDest;


   // // Prototypes
   // void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();
      call NeighborDiscovery.start();
      call LinkStateRouting.start();
      // call Transport.start();
      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      // dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         // dbg(GENERAL_CHANNEL, "Packet Payload: %s\n", myMsg->payload);
         myProtocol = myMsg->protocol;
         // Do checks for TTL
         switch(myProtocol){
            case(PROTOCOL_NEIGHBOR):
               // Reply to Neighbor
               call NeighborDiscovery.reply(myMsg);
               break;
            case(PROTOCOL_NEIGHBOR_REPLY):
               // Read neighbor reply
               call NeighborDiscovery.readDiscovery(myMsg);
               break;
            case(PROTOCOL_FLOOD):
               // Read neighbor reply
               call Flooding.forwardFlood(myMsg);
               break;
            case(PROTOCOL_LINKSTATE):
               // Update link state and flood
               call LinkStateRouting.handleLinkState(myMsg);
               // call LinkStateRouting.routePacket(myMsg);
               break;
         }
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

   // event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
   //    dbg(GENERAL_CHANNEL, "PING EVENT \n");
   //    makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
   //    call Sender.send(sendPackage, destination);
   // }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload) {
      //call LinkStateRouting.ping(destination, payload);
      call Flooding.ping(destination, payload);
   }

   event void CommandHandler.printNeighbors() {
      dbg(GENERAL_CHANNEL, "NEIGHBOR STATUS EVENT \n");
      call NeighborDiscovery.printNeighbors();
   }

   event void CommandHandler.neighborDiscovery() {
      dbg(GENERAL_CHANNEL, "NEIGHBOR DISCOVERY EVENT \n");
      call NeighborDiscovery.start();
   }

   event void CommandHandler.flood(uint16_t destination, uint8_t *payload) {
      dbg(GENERAL_CHANNEL, "FLOOD EVENT \n");
      call Flooding.newFlood(destination, payload);
   }

   event void CommandHandler.printRouteTable(){
      dbg(GENERAL_CHANNEL, "ROUTE TABLE EVENT \n");
      call LinkStateRouting.printRouteTable();
   }

   event void CommandHandler.printLinkState(){
      dbg(GENERAL_CHANNEL, "ROUTE TABLE EVENT \n");
      call LinkStateRouting.printLinkState();
   }

   event void CommandHandler.printDistanceVector(){
      dbg(GENERAL_CHANNEL, "DISTANCE VECTOR EVENT \n");
      // call DistanceVectorRouting.printRouteTable();
   }

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   // void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
   //    Package->src = src;
   //    Package->dest = dest;
   //    Package->TTL = TTL;
   //    Package->seq = seq;
   //    Package->protocol = protocol;
   //    memcpy(Package->payload, payload, length);
   // }
}
