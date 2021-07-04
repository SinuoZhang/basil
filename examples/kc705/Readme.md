### 10G Ethernet example for the KC705 hardware

This example shows how to control a GPIO module and how to receive data via the Ethernet interface.

The firmware makes use of the free SiTCPXG Ethernet module ([GitHub][url1]). Clone the repository into */firmware/SiTCPXG*.
You can find build instructions in the *Firmware section* of the ([bdaq53 readme][url2]).

Connect the USER_GPIO_P/N sockets to the MGT_REF_P/N using short SMA cables.
A direct copper connection between the SFP+ slot and the Ethernet adapter in your PC is recommended, fiber modules have not been tested yet.


[url1]: https://github.com/BeeBeansTechnologies/SiTCPXG_Netlist_for_Kintex7.git
[url2]: https://gitlab.cern.ch/silab/bdaq53#firmware

1. Data transfer is started by setting a bit [0] in the GPIO.
2. FPGA starts to send data from a 64 bit counter, as fast as possible through a FIFO.
3. Python receives the data and counts bytes during a given time period.
4. At the end, the average data rate is printed and the FPGA data source is stopped by clearing bit [0].

Test for CocoTB available in */test*
