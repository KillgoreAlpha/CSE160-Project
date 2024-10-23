from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("circle.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);

    s.runTime(20);
    # s.flood(1, 7, "I'm Flooding!")

    # After sending a ping, simulate a little to prevent collision.
    s.ping(1,10, "test");
    s.runTime(1000);

    s.routeDMP(1);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(2);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(3);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(4);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(5);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(6);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(7);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(8);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(9);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(10);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(11);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(12);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(13);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(14);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(15);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(16);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(17);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(18);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(19);
    s.runTime(5);
    s.moteOn(5);

    s.ping(1,10, "test");
    s.runTime(1000);

    s.routeDMP(1);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(2);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(3);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(4);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(5);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(6);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(7);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(8);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(9);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(10);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(11);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(12);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(13);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(14);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(15);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(16);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(17);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(18);
    s.runTime(5);
    s.moteOn(5);

    s.routeDMP(19);
    s.runTime(5);
    s.moteOn(5);


if __name__ == '__main__':
    main()