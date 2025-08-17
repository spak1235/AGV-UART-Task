# AGV Embedded Task

## **Brief Overview**

Design a controller for a simulated version of the YDLIDAR X2 two-dimensional LiDAR sensor, which is actually present on the Mushr bot in the AGV lab, using Verilog. The controller module must comprise UART receiver and transmitter modules. It must receive UART packets fro the simulated LiDAR (a Verilog testbench file), store the data bytes, identify different parts of the LiDAR message, process it accordingly and output the result.

## **Communication Protocol**

As mentioned in the overview, the standard UART serial communication protocol will be utilized by the sensor (1 start bit, 8 data bits, 0 parity bits, 1 stop bit). Consider a fixed baud rate of 115200.

## **LIDAR Message Information**

The LIDAR present in the AGV Mushr Bot is YDLIDAR X2, which transmits data to the main processing system via the UART protocol. For the sake of simplicity, we are considering a reduced version of the actual LiDAR message. A single LiDAR message will be transmitted to the controller. The format for the message is:

1. Header (2 bytes) - Fixed 8-bit words that Indicate the start of a singular LiDAR message (0x55 0xAA)
2. CT (1 byte) - Describes the number of data samples being sent.
3. FSA (2 bytes) - Represents the First Sampled Angle, with a **least count of one-hundredth of a degree**, i.e. 0x8000 corresponds to 0.01 degrees, not 1 degree.
4. LSA (2 bytes) - Represents the Last Sampled Angle with the same format as FSA.
5. Sample Data (N x 2 bytes) - Represents the distance to obstacle at the sampled angle, in mm. 

Note that all the parts of the message other thann the header, follow a **little endian** arrangement of bits.

**Message Visualization:**

| Header | CT | FSA | LSA | Sample Data |
| --- | --- | --- | --- | --- |

A detailed understanding of the functioning of LiDAR is not required. One must only understand that the lidar samples distance-to-obstacle or range data for discrete, uniformly spaced angles between *angle_min* and *angle_max.*

## **LiDAR Data Processing and Transmission**

After storing all the bytes of the LiDAR message, the following quantities must be determined and transmitted to the testbench, again using the UART protocol:

1. max_distance_angle (2 bytes)
2. min_distance_angle (2 bytes)
3. obs_alert (2 bytes)

Note -

1. Think of bitmasking for obs_alert. A bit of obs_alert is set HIGH if the distance at the corresponding sampled angle is lower than 10.24 cm (we think you can figure out why the 0.24 is present), and we believe that max_distance_angle and min_distance_angle are pretty self explanatory :)
2. If CT > 16, let *obs_alert* correspond to the first 16 samples.

## **File Structure and Instructions**

The controller is to be implemented in the following Verilog file: *topModule.v*

Strictly adhere to the boilerplate code for topModule provided [here](https://drive.google.com/file/d/113U90ZFKcZvJ_euyyFYGzhbW_c_KtBh4/view?usp=sharing).

*topModule* must contain instances of the following modules:

1. RxD - To receive the UART packets from the sensor and to extract the data bytes.
2. distanceProcess - A FIFO to accept each unit of data and process it accordingly
3. TxD - To transmit your resultant information back again via UART

It is recommended that you build your own testbenches based on your understanding of the problem statement, to test and verify your controller designs. The final evaluation of your designs will be performed by our own testbenches. This will happen post-submission. Your submission must include all the design files that are instantiatied and used in *topModule.v*, and obviously, *topModule.v* itself.

## **References**

This task requires in-depth research as a broad range of concepts must be utilized to correctly design the controller. Refer to the following documents and resources thoroughly, and install the required softwares. Your research must not be limited only to the provided sources and all additional resources used must be well-documented.

### **Resources**

- Digital Electronics:
    - [Digital_Electronic_Circuits_NPTEL_Lectures](https://youtube.com/playlist?list=PLbRMhDVUMnge4gDT0vBWjCb3Lz0HnYKkX&si=mDetN6DBDyLdAd-G)
        
        Important concepts in the lectures:
        
        - Registers and shift registers (to understand FIFOs)
        - Counter design
        - Mealy, moore machines (in general, Finite State Machines)
    - [FreeCodeChamp_Article_on_FSMs](https://www.freecodecamp.org/news/state-machines-basics-of-computer-science-d42855debc66/)
    - [Digital Design - Morris Mano - 4th Edition](https://www.srecwarangal.ac.in/ece-downloads/Digital%20Electronics.pdf) (Relevant Chapters: 5,6 and 7)
- UART:
    - [GFG_Article_on_UART](https://www.geeksforgeeks.org/computer-networks/universal-asynchronous-receiver-transmitter-uart-protocol/)
    - [Wikipedia_Page_On_UART](https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter)
- Verilog:
    - [ChipVerify - Verilog](https://www.chipverify.com/tutorials/verilog)

### **Software and Packages Required:**

- [icarus (iverilog)](https://steveicarus.github.io/iverilog/)
- [GTKWave](https://gtkwave.sourceforge.net/)

The tentative deadline for this task is 7th September. You can learn the necessary topics and build your module by then. Upload a screenshot of your simulation of the test bench here for verification. Each member of the team must be well-versed with all the aspects of their controller design, regardless of the whether they worked on all subparts or not.

All the best for your task, and feel free to ask us any questions.