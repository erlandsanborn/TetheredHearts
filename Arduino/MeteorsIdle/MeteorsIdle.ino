#include <StandardCplusplus.h>
#include <system_configuration.h>
#include <unwind-cxx.h>
#include <utility.h>
#include <list>
#include <iterator>
#include "FastLED.h"
#include <SoftwareSerial.h>

#define numLeds 60 // Longer strips may need less "dust" in order to avoid a stack overflow
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
int patternState = 0; // Keeps track of what the current light pattern is.

int threshold = 500; // Pulse sensor signal threshold. Change in increments of 5-10 to test.
int delayVal = 24; // How long the program waits between loops. Lower this to raise the speed.
int meteorSpacing = 5; // How far apart paired beats appear.
int meteorHue = 210; // Default meteor color is set to pink/purple.
int meteorVal = 160; // Default meteor brightness. 
int dustHue = 230; // Default dust color.
int dustVal = 210; // Default dust value.
int maxDust = 35; // Hardcap on the amount of dust that can be created. If too high, may cause stack overflow.
int dustValLimit = 26; // Brightness level below which dusts "despawns".
int randCap = 90; // randNumber will be anything between 0 and this value.
int dustFrequency = 25; // If randNumber is below this value, dust is created.
int fadeVal = 8;  // Amount dust brightness fades every loop.
int hueShift = 5; // Amount dust color changes every loop.
int idleHue = 213; // Color during idleState/loadState.
int idleSat = 255; // Saturation during idleState/loadState.
int idleVal = 180; // Value during idleState/loadState.
bool idleShift = 0; // Tells the idleState which way to fade (brighter/darker).
bool loadSweep = 0; // Lets the current meteors play out before fading in idleState.

struct meteor {
  int pos; // Each meteor saves it's own position.
  bool parent; // Ensures only one extra meteor is created each pulse.
  meteor() {
    pos = 0;
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
     val -= f; 

  }
};

list<meteor> meteors;
list<dust> dusties;

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
//  pinMode(buttonPin, INPUT);
  if (!pulseSensor.begin()) {
    for (;;) {
      digitalWrite(debugPin, LOW);
      delay(50);
      digitalWrite(debugPin, HIGH);
      delay(50);
    }
  }
}

void onButtonPress(){
  if (patternState >= 4)
  {
    patternState = 0;
    meteors.clear();
    dusties.clear();
  }
  else if (patternState == 0)
  {
    patternState++;
    meteors.clear();
    dusties.clear();
  }
  else if (patternState == 2)
  {
    patternState++;
  }
}

void idleState(){ //runs if patternState is 0. Searches for a button input to move to patternState 1.
  delay(10);
  for (int i = 0; i < numLeds; i++){
      leds[i].setHSV(idleHue, idleSat, idleVal);
  }
  if (!idleShift){
    idleVal += 3;
    if (idleVal >= 180){
      idleShift = 1;
    }
  }
  else {
    idleVal -= 3;
    if (idleVal <= 70){
      idleShift = 0;
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
}

void loadState(){ //If patternState is 1, fades out of the idleState then goes to patternState 2. If patternState is 3 it lets  fades into idleState then goes to patternState 0
  if (patternState == 1){
      for (int i = 0; i < numLeds; i++){
         leds[i].setHSV(idleHue, idleSat, idleVal);
      }
      idleVal -= 5;
      if (idleVal <= 0)
      {
        idleVal = 0;
        patternState++;
      }
  }
  else if (patternState == 3){
    if (!loadSweep){
      for (list<meteor>::iterator it = meteors.begin(); it != meteors.end(); ++it){
    if (it->getPos() >= numLeds)
      {
        meteors.pop_back();
      }
      else {
        if (it->getPos() >= 0) {
          leds[it->getPos()].setHSV(meteorHue, 255, meteorVal);
          if (dusties.size() < maxDust) {
            randNumber = random(randCap);
            if (it->getPos() >= 0 && randNumber <= dustFrequency) {
              dust newDust;
              newDust.setPos(it->getPos());
              int shiftDust = randNumber;
              newDust.setShift(shiftDust+shiftDust+shiftDust);
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
         leds[it->getPos()].setHSV(it->getHue(), 255, it->getVal() - it->getShift());
         it->fade(fadeVal);
         it->shiftHue(hueShift);
      }
  }
      if (meteors.empty() && dusties.empty()){
        loadSweep = 1;
      }
    }
    else if (loadSweep = 1){
      for (int i = 0; i < numLeds; i++){
         leds[i].setHSV(idleHue, idleSat, idleVal);
      }
      idleVal += 5;
      if (idleVal >= 210)
      {
        idleVal = 210;
        loadSweep = 0;
        patternState = 0;
      }
    }
  }
}

void playState(){
  pulseSensor.outputSample();
  if (pulseSensor.sawStartOfBeat()){
    pulseSensor.outputBeat();
    meteor newMeteor;
    meteors.push_front(newMeteor);
  }
  for (list<meteor>::iterator it = meteors.begin(); it != meteors.end(); ++it){
    if (it->getPos() >= numLeds)
      {
        meteors.pop_back();
      }
      else {
        if (it->getPos() >= 0) {
          leds[it->getPos()].setHSV(meteorHue, 255, meteorVal);
          if (dusties.size() < maxDust) {
            randNumber = random(randCap);
            if (it->getPos() >= 0 && randNumber <= dustFrequency) {
              dust newDust;
              newDust.setPos(it->getPos());
              int shiftDust = randNumber;
              newDust.setShift(shiftDust+shiftDust+shiftDust);
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
         leds[it->getPos()].setHSV(it->getHue(), 255, it->getVal() - it->getShift());
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
}

void loop() {
  delay(delayVal);
  
  int amp = analogRead(pulsePin);
  ourSerial.println(amp);
  
  FastLED.clear();
  if (patternState == 0){
    idleState();
  }
  else if (patternState == 1 || patternState == 3){
    loadState(); 
  }
  else if (patternState == 2){
    playState();
  }
  FastLED.show();
}

