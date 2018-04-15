
#define USE_ARDUINO_INTERRUPTS true    // Set-up low-level interrupts for most acurate BPM math.
#include <PulseSensorPlayground.h>     // Includes the PulseSensorPlayground Library.   
#include <SoftwareSerial.h>

//  Variables
const int PIN_RX = 7;
const int PIN_TX = 8;
const int PulseWire = 0;       // PulseSensor PURPLE WIRE connected to ANALOG PIN 0
                              
PulseSensorPlayground pulseSensor;  // Creates an instance of the PulseSensorPlayground object called "pulseSensor"
SoftwareSerial ourSerial(PIN_RX, PIN_TX);

void setup() {   

  ourSerial.begin(115200);
  pulseSensor.analogInput(PulseWire);   
  pulseSensor.begin()) {
  
}


void loop() {

  int amp = analogRead(PulseWire);
  ourSerial.write(amp);
  delay(20);                    // considered best practice in a simple sketch.

}

  
