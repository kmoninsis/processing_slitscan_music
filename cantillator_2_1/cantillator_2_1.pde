import processing.video.*;

import themidibus.*;

MidiBus myBus;
Capture cam;

//Video variables
int w = 3;
PImage overlay;
int camWidth = 1280;
int camHeight = 720;
int half = camWidth/2;
int sectionLength;
String notes;
int notesLength;
int[] averageBrightness, averageSaturation, averageHue;
int[] prevValues_Vel, prevValues_S, prevValues_Pitch;

//Audio variables
boolean isPlaying = false;
int channel = 0;
int pitch, velocity;
Note[] voices;



void setup() {
  size(1920, 720);

  //Camera stuff
  String[] cameras = Capture.list();
  printArray(cameras);
  cam = new Capture(this, camWidth, camHeight, "Integrated Camera", 30);
  cam.start();

  //Midi stuff
  myBus = new MidiBus(this, 0, 3); //Connect to midi device input 0 output 3 (check with midibus.list())
  //MidiBus.list();
  overlay = createImage((width-half), height, RGB);
  notes = "ABCDEFGA";
  notesLength = notes.length();
  sectionLength = height/notesLength;
  averageBrightness = new int[notesLength];
  prevValues_Vel = new int[notesLength];
  averageSaturation = new int[notesLength];
  prevValues_S = new int[notesLength];
  averageHue = new int[notesLength];
  prevValues_Pitch = new int[notesLength];

  colorMode(HSB, 128, 128, 128);

  // Initialize voices with 0 velocity (volume) 
  voices = new Note[notesLength];
  velocity = 0;
  pitch = 36;
  for (int i = 0; i < notesLength; i++) {
    pitch += 7;
    println(pitch);
    voices[i] = new Note(i, pitch, velocity);
    myBus.sendNoteOn(voices[i]);
    prevValues_Pitch[i] = pitch;
    prevValues_Vel[i] = velocity;
  }
  blendMode(SCREEN);
}




void draw() {
  if (cam.available()) {
    cam.read();

    overlay.copy(cam, half, 0, w, camHeight, 0, 0, w, height); // get slit and put it on the left
    overlay.copy(0, 0, half, height, w, 0, half, height); // copy left half of canvas and move it to the right
    overlay.copy(half, 0, half, height, half+w, 0, half+(w*2), height); // make slit go blurry from second half to end
  }

  loadPixels();
  cam.loadPixels();

  //Camera image and ambient lines
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      int loc = x + y * width;

      if (x<half) {
        int camLoc = x + y * cam.width;
        pixels[loc] = cam.pixels[camLoc];
      } else {
        int camLoc = half + y * cam.width;
        pixels[loc] = cam.pixels[camLoc];
      }
    }
  }
  updatePixels();  
  blendMode(BLEND);
  fill(127, 127, 127);

  // Audio analysis only if new frame is available  
  int min = 0;
  int max = 0;

  for (int i = 0; i < notesLength; i++) {
    averageHue[i] = 0;
    averageSaturation[i] = 0;
    averageBrightness[i] = 0;
    for (int j = 0; j < sectionLength; j++) {
      int y = j + (i*sectionLength);
      int loc = half + y * cam.width;
      float brightness = brightness(cam.pixels[loc]);
      float saturation = saturation(cam.pixels[loc]);
      float hue = hue(cam.pixels[loc]);
      averageBrightness[i] +=  brightness;
      averageSaturation[i] += saturation;
      averageHue[i] += hue;
    }
    averageBrightness[i] /= sectionLength;
    averageSaturation[i] /= sectionLength;
    averageHue[i] /= sectionLength;

    min = max;
    max = min+7;
    int newVel = int(map(averageBrightness[i], 0, 255, 0, 127)); //Velocity --> volume
    int newS = int(map(averageSaturation[i], 0, 255, 0, 127)); //?
    int newPitch = int(map(averageHue[i], 0, 255, min, max)); //Pitch
    if (newPitch != prevValues_Pitch[i]) {
      //turn off note
      myBus.sendNoteOff(voices[i]);

      //modify note and turn back on
      voices[i].setPitch(newPitch);
      voices[i].setVelocity(newVel);
      myBus.sendNoteOn(voices[i]);
    }


    //send Control Message
    //int status_byte = 0xE0; //Pitch bend
    //int channel_byte = 4; // On channel 0 again
    //int l = int(map(mouseX, 0, width, 0, 127)); // least significant 7 bits;
    //int m = int(map(mouseY, 0, height, 0, 127)); // most significant 7 bits;

    //myBus.sendMessage(status_byte, channel_byte, l, m);

    String message = notes.charAt(i) + " H: " + newPitch + " S: " + newS + " B: " + newVel; 
    text( message, half, sectionLength*i+10);

    prevValues_Pitch[i] = newPitch;
    prevValues_S[i] = newS;
    prevValues_Vel[i] = newVel;
  }
  blendMode(SCREEN);
  image(overlay, half, 0);
}

void mousePressed() {
  for (int i = 0; i < notesLength; i++) {

    myBus.sendNoteOff(voices[i]);
  }
  if (!isPlaying) {
    isPlaying = true;
    myBus.sendNoteOn(channel, pitch, velocity); // Send a Midi noteOn
  } else {
    myBus.sendNoteOff(channel, pitch, velocity); // Send a Midi nodeOff
    isPlaying = false;
  }
}


void noteOn(int channel, int pitch, int velocity) {
  // Receive a noteOn
  println();
  println("Note On:");
  println("--------");
  println("Channel:"+channel);
  println("Pitch:"+pitch);
  println("Velocity:"+velocity);
}

void noteOff(int channel, int pitch, int velocity) {
  // Receive a noteOff
  println();
  println("Note Off:");
  println("--------");
  println("Channel:"+channel);
  println("Pitch:"+pitch);
  println("Velocity:"+velocity);
}

void controllerChange(int channel, int number, int value) {
  // Receive a controllerChange
  println();
  println("Controller Change:");
  println("--------");
  println("Channel:"+channel);
  println("Number:"+number);
  println("Value:"+value);
}

void delay(int time) {
  int current = millis();
  while (millis () < current+time) Thread.yield();
}
