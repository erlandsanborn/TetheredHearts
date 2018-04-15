#include <StandardCplusplus.h>
#include <system_configuration.h>
#include <unwind-cxx.h>
#include <utility.h>
#include <list>
#include <iterator>
#include "FastLED.h"
#include <SoftwareSerial.h>

#define numLeds 120 // Longer strips may need less "dust" in order to avoid a stack overflow
#define ledPin 8 
#define buttonPin 2 
#define pulsePin 0 
#define debugPin 13 // Arduino on-board LED. Will flash if pulse sensor is not found.

CRGB leds[numLeds];
#define USE_ARDUINO_INTERRUPTS true
#include <PulseSensorPlayground.h>
using namespace std;
PulseSensorPlayground pulseSensor;

const int PIN_RX = 6;
const int PIN_TX = 7;
SoftwareSerial ourSerial(PIN_RX, PIN_TX);

const int outputType = SERIAL_PLOTTER;
int buttonState = 0;
bool buttonHold = 0; // Checks for/Throws out any extra button inputs that are in sequence(to keep from calling button logic more than once per press).
long randNumber; // Used in dust creation. More can be added for more random fine-tuning.
int patternState = 1; // Keeps track of what the current light pattern is.

int threshold = 500; // Pulse sensor signal threshold. Change in increments of 5-10 to test.
int delayVal = 24; // How long the program waits between loops. Lower this to raise the speed.
int meteorSpacing = 5; // How far apart paired beats appear.
int meteorHue = 210; // Default meteor color is set to pink/purple.
int meteorVal = 160; // Default meteor brightness. 
int dustHue = 210; // Default dust color.
int dustVal = 210; // Default dust value.
int maxDust = 35; // Hardcap on the amount of dust that can be created. If too high, may cause stack overflow.
int dustValLimit = 26; // Brightness level below which dusts "despawns".
int randCap = 90; // randNumber will be anything between 0 and this value.
int dustFrequency = 25; // If randNumber is below this value, dust is created.
int fadeVal = 8;  // Amount dust brightness fades every loop.
int hueShift = 4; // Amount dust color changes every loop.
int backHue = 210;
int backVal = 160;

struct meteor {
  int pos; // Each meteor saves it's own position.
  bool parent; // Ensures only one extra meteor is created each pulse.
  meteor() {
    pos = 1;
    parent = 1;
  }
  int getPos() {
    return pos;
  }
  void movePos() {
    pos++;
  }
  bool isParent() {
    return parent;
  }
  void flipParent() { // Used on secondary meteors to ensure they don't make any more.
    parent = 0;
  }
};

struct dust {
  int pos;
  int val;
  int hue;
  int shift;
  dust() {
    val = dustVal;
    hue = dustHue;
    shift = 0;
  }
  int getVal() {
    return val;
  }
  void setVal(int v) {
    val = v;
  }
  int getHue() {
    return hue;
  }
  void setShift(int s) {
    shift = s;
  }
  int getShift(){
    return shift;
  }
  void shiftHue(int x) {
    if (patternState != 0){
     hue -= x; 
    }
  }
  int getPos() {
    return pos;
  }
  void setPos(int p) {
    pos = p;
  }
  void fade(int f) {
    if (patternState != 0){
     val -= f; 
    }
    else {
      val += f;
    }
  }
};

list<meteor> meteors;
list<dust> dusties;

void onButtonPress(){
  patternState++;
  if (patternState >= 4)
  {
    patternState = 0;
    meteorHue = backHue;
    meteorVal = 0;
    dustHue = backHue;
    dustVal = 0;
    dustValLimit = 210;
  }
  else if (patternState == 1)
  {
    meteorHue = 210;
    meteorVal = 160;
    dustHue = 210;
    dustVal = 210;
    dustValLimit = 26;
  }
  else if (patternState == 2)
  {
    meteorHue = 90;
    meteorVal = 160;
    dustHue = 90;
    dustVal = 210;
  }
  else if (patternState == 3)
  {
    meteorHue = 170;
    meteorVal = 210;
    dustHue = 100;
    dustVal = 210;
  }
}

void setup() {
  randomSeed(analogRead(3));
  //FastLED.addLeds<NEOPIXEL, ledPin>(leds, numLeds);
  //FastLED.addLeds<WS2811, ledPin, GRB>(leds, numLeds).setCorrection( TypicalLEDStrip );
  FastLED.addLeds<WS2812B, ledPin, GRB>(leds, numLeds);
  Serial.begin(115200);
  
  ourSerial.begin(115200);

  pulseSensor.analogInput(pulsePin);
  pulseSensor.blinkOnPulse(debugPin);
  pulseSensor.setSerial(Serial);
  pulseSensor.setOutputType(outputType);
  pulseSensor.setThreshold(threshold);
  pinMode(buttonPin, INPUT);
  if (!pulseSensor.begin()) {
    for (;;) {
      digitalWrite(debugPin, LOW);
      delay(50);
      digitalWrite(debugPin, HIGH);
      delay(50);
    }
  }
}

void loop() {
  delay(delayVal);
  
  int amp = analogRead(pulsePin);
  ourSerial.println(amp);
  
  pulseSensor.outputSample();
  if (patternState != 0){
    FastLED.clear(); 
  }
  else {
    for (int i = 0; i < numLeds; i++){
      leds[i].setHSV(backHue, 255, backVal);
    }
  }
  if (pulseSensor.sawStartOfBeat()){
    pulseSensor.outputBeat();
    meteor newMeteor;
    meteors.push_front(newMeteor);
  }
  for (list<meteor>::iterator it = meteors.begin(); it != meteors.end(); ++it){
    if (it->getPos() >= numLeds - 1)
      {
        meteors.pop_back();
      }
      else {
        if (it->getPos() >= 1) {
          leds[it->getPos()-1].setHSV(meteorHue, 255, meteorVal);
          if (patternState == 0)
          {
            leds[it->getPos()].setHSV(meteorHue, 255, meteorVal);
          }
          if (dusties.size() < maxDust) {
            randNumber = random(randCap);
            if (it->getPos() >= 1 && randNumber <= dustFrequency) {
              dust newDust;
              newDust.setPos(it->getPos() - 1);
              int shiftDust = randNumber*2;
              newDust.setShift(shiftDust+shiftDust);
              dusties.push_front(newDust);
             }
          }
        }
        it->movePos();
        if (it->getPos() == meteorSpacing && it->isParent()) {
          meteor secondMeteor;
          secondMeteor.flipParent();
          meteors.push_front(secondMeteor);
         }
      }
      
  }
  for (list<dust>::iterator it = dusties.begin(); it != dusties.end(); ++it) {
      if (it->getVal() - it->getShift() <= dustValLimit) {
         dusties.erase(it);
      }
      else {
         leds[it->getPos()].setHSV(it->getHue(), 255, it->getVal()-it->getShift());
         it->fade(fadeVal);
         it->shiftHue(hueShift);
      }
    }
/*  buttonState = digitalRead(buttonPin);
  if (buttonState == HIGH){
    if (buttonHold == 0){
      buttonHold = 1;
      onButtonPress();
    }
  }
  else {
    buttonHold = 0;
  }*/
  FastLED.show();
}

