# AGV-UART-Task
## 📌 Brief Overview

Design a controller for a simulated version of the YDLIDAR X2 two-dimensional LiDAR sensor, which is actually present on the Mushr bot in the AGV lab, using Verilog. The controller module must comprise UART receiver and transmitter modules. The controller must receive UART packets, store the data bytes, identify different parts of the data, process the data accordingly and output the result.

## Communication Protocol

As mentioned in the overview, the standard UART serial communication protocol will be utilized by the sensor (1 start bit, 8 data bits, 0 parity bits, 1 stop bit). Consider a fixed baud rate of **115200**.

## LIDAR Message Information

The LIDAR present in the AGV Mushr Bot is YDLIDAR X2, which transmits data to the main processing system using the UART protocol. For the sake of simplicity, we are considering a reduced version of the actual LiDAR message. A single LiDAR message will be transmitted to the controller. The format for the message is:
- Header (2 bytes) - Fixed 8-bit words that Indicate the start of a singular LiDAR message (0x55 0xAA)
- CT (1 byte) - Describes the number of data samples being sent.
- FSA (2 bytes) - Represents the First Sampled Angle, with a least count of one-hundredth of a degree.
- LSA (2 bytes) - Represents the Last Sampled Angle with the same format as FSA.
- Sample Data (N x 2 bytes) - Represents the distance to obstacle at the sampled angle, in mm. Only bits 0-13 are valid, consider bits 14-15 redundant

Note: All the parts of the message apart from the header, follow a little endian arrangement of bits.

**Message Visualization:**

| Header | CT | FSA | LSA |        Sample Data        |
|--------|----|-----|-----|---------------------------|

## LiDAR Data Processing and Transmission

After storing all the bytes of the LiDAR message, the following quantities must be determined and transmitted to the testbench, again using the UART protocol:

- max_distance_angle (2 bytes)
- min_distance_angle (2 bytes)
- obs_alert (2 bytes)

Note:
- Think of bitmasking for obs_alert. A bit of obs_alert is set HIGH if the distance at the corresponding sampled angle is lower than 10 cm (or, if you like, 10.24 cm, we think you can figure out why the 0.24 is present), and we believe that max_distance_angle and min_distance_angle are pretty self explanatory :) 
- It is possible that CT > 16. If this condition is true, you may choose to ignore the remaining samples and determine obs_alert for any 16 samples of your choice (your choice of samples must be clearly documented).

## File Structure and Instructions

The controller is to be implemented in the following Verilog file: topModule.v
Strictly adhere to the boilerplate code for topModule provided here.
topModule must contain instances of the following modules:

- RxD - To receive the UART packets from the sensor and to extract the data bytes.
- distanceProcess - A FIFO to accept each unit of data and process it accordingly
- TxD - To transmit your resultant information back again via UART

You will soon be provided with a testbench for your code (you will receive only the binary file and you will not be able to view the verilog code for the testbench). The simulation of the test bench will output HIGH on a single-bit output wire isValid if the controller is implemented correctly and if the transmitted data is correct. 

## References

This task requires in-depth research as a broad range of concepts must be utilized to correctly design the controller. Refer to the following documents and resources thoroughly, and install the required softwares.

## Resources

- Digital Electronics:
  - [Digital_Electronic_Circuits_NPTEL_Lectures](https://youtube.com/playlist?list=PLbRMhDVUMnge4gDT0vBWjCb3Lz0HnYKkX&si=mDetN6DBDyLdAd-G)
    
    Important concepts in the lectures:
      - Registers and shift registers (to understand FIFOs)
      - Counter design
      - Mealy, moore machines (in general, Finite State Machines)
  - [FreeCodeChamp_Article_on_FSMs](https://www.freecodecamp.org/news/state-machines-basics-of-computer-science-d42855debc66/)
- UART:
  - [GFG_Article_on_UART](https://www.geeksforgeeks.org/computer-networks/universal-asynchronous-receiver-transmitter-uart-protocol/)
  - [Wikipedia_Page_On_UART](https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter)
- Verilog:
  - [ChipVerify - Verilog](https://www.chipverify.com/tutorials/verilog)
- Morris Mano - up to (and including) chapter 6:
  - [Digital Design by M Morris Mano](https://www.mpgcamb.com/wp-content/uploads/2024/12/M.-Morris-Mano-Digital-Design-Prentice-Hall-1995.pdf)

### Softwares and Packages Required - [Icarus Verilog](https://steveicarus.github.io/iverilog/)

The deadline for this task is 7th September. You can learn the necessary topics and build your module by then. Upload a screenshot of your simulation of the test bench here for verification.

All the best for your task, and feel free to ask us any questions. 

