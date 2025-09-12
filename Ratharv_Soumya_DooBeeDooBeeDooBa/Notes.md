# Ratharv's LiDAR Task Documentation
I need to use a markdown file instead of notion because my notion free plan is not allowing me to make new files
## Reciever Module
Reception will be done in a SIPO format. Parallelsation is preferred here since:
* There is no restriction on hardware
* Operations are simpler to do

## Controller
The controller does the following sequentially:
* Header checking
* Once header is correct, move to next step
    * Find CT
    * Find FSA
    * Find LSA
* Using counters, sample all data and find the maximum and minimum distance and the index of them respectively
* Bitmask obs_alert
* Use a simple division algorithm to find these angles using unitary method

Note: Input was 1 byte at a time, which means that we had to take things like header, LSA, FSA and the sampled data also. Some places I have directly integrated this with a counter whilst other times I have used the microcounter which is a bit that complements itself to emulate a 2 count.

### Division Algorithm: Long Division
Long division is done the following way:
1. Take input Numerator and Denominator
    1. Numerator is 32 bit since it is (LSA-FSA)*idx
    2. Denominator is also 32 bit for the sake of symmetry

    Note: The algorithm can be further optimised to take less than half the cycles being used right now. Actually, we can go for fast division algorithms but that is simply not needed here since we indeed have alot of cycles on us. Calculations only start once all data is taken, and the controller is ready to start header checking in the meantime, So we have an even greater time on us really.

2. Left bitshift an array of 0s (A) concatenated with numerator
3. assign last bit of the updated numerator as 1 or 0 depending of the first bit of A-M
4. Accordingly update A if needed
5. Repeat until all 32 bits are done

## Transmitter Module
The transmitter is the exact opposite of the reciever. Takes input as the angles and obs_alert and outputs the serial output. We will use a 10 step counter for the same and send all the distances and obs_alert