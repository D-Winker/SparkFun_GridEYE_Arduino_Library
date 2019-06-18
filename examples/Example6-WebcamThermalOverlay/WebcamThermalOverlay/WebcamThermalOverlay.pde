/*
  Visualizing the Panasonic Grid-EYE Sensor Data using Processing
  By: Nick Poole
  SparkFun Electronics
  Date: January 12th, 2018
  Modified by: Daniel Winker
  Date: May 20, 2019
  
  MIT License: Permission is hereby granted, free of charge, to any person obtaining a copy of this 
  software and associated documentation files (the "Software"), to deal in the Software without 
  restriction, including without limitation the rights to use, copy, modify, merge, publish, 
  distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the 
  Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or 
  substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING 
  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  
  Feel like supporting this work? Buy a board from SparkFun!
  https://www.sparkfun.com/products/14568
  
  This example is intended as a companion sketch to the Arduino sketch found in the same folder (Example6-1FPSProcessingHeatCam),
  but can just as well be used with Example4-ProcessingHeatCam.
  Once the accompanying code is running on your hardware, run this Processing sketch. 
  This Processing sketch will receive the comma separated values generated by the Arduino code and
  use them to generate a thermal image. That thermal image will be overlaid on a visible spectrum image 
  captured from your computer's webcam. For best results, place the Grid-EYE next to the webcam.
  
  Press 'a' on your keyboard to toggle autoscaling of temperature data.
  Press 'm' to toggle image mirroring.
*/

import processing.serial.*;
import processing.video.*;  //Library för video stuff
Capture cam;  // A variable for the frame we grab from the webcam

String myString = null;
Serial myPort;  // The serial port
float maxTemp = 40;  // Used for rescaling pixel colors
float minTemp = 20;  // Used for rescaling pixel colors
boolean autoScale = true;  // Scale the range using the current min and max temp, as opposed to fixed range.
boolean mirror = true;  // Mirror the images.
float alpha = 0.8;  // Alpha parameter for an exponentially weighted moving average filter. Cuts down on noise in the thermal image.
int xStep;
int yStep;
int[] thermalCamSize = {0, 0};  // The width and height of the pixels of the Grid-EYE

float[][] temps = new float[8][8];

float mean(float[] nums) {
  float sum = 0;
  for (int i = 0; i < 64; i++) {
    sum = sum + nums[i];
  }
  return sum / 64;
} 

float stdv(float[] nums, float mean) {  // Returns the standard deviation of nums
  float sumsq = 0;
  for (int i = 0; i < 64; i++) {
    sumsq = sumsq + sq(nums[i] - mean);
  }
  return sqrt(sumsq / 64);
}

// The statements in the setup() function 
// execute once when the program begins
void setup() {
  size(1280, 720);  // Size must be the first statement. Set this to your webcam's resolution.
  thermalCamSize[0] = width / 8;  // 8 pixels wide (thermal camera)  
  thermalCamSize[1] = height / 8;  // 8 pixels tall (thermal camera)
  String[] cameras = Capture.list();  // Get a list of available camera modes and list them
   
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }

    cam = new Capture(this, cameras[1]);  // You may need to change cameras[1] to a different number
    cam.start();     
  }  
  
  noStroke();
  frameRate(10);
  
  // Print a list of connected serial devices in the console
  printArray(Serial.list());
  // Depending on where your GridEYE falls on this list, you
  // may need to change Serial.list()[1] to a different number
  myPort = new Serial(this, Serial.list()[1], 115200);
  myPort.clear();
  // Throw out the first chunk in case we caught it in the 
  // middle of a frame
  myString = myPort.readStringUntil(13);
  myString = null;
  // change to HSB color mode, this will make it easier to color
  // code the temperature data
  colorMode(HSB, 360, 100, 100);
}

// The statements in draw() are executed until the 
// program is stopped. Each statement is executed in 
// sequence and after the last line is read, the first 
// line is executed again.
void draw() { 
  if (cam.available() == true) {
    cam.read();
  }
  if (mirror) {
    pushMatrix();
    scale(-1, 1);
    image(cam, -width, 0);
    popMatrix();
  } else {
    image(cam, 0, 0);
  }
  
  // When there is a sizeable amount of data on the serial port
  // read everything up to the first linefeed
  if(myPort.available() > 65){
    myString = myPort.readStringUntil(13);
    
    // generate an array of strings that contains each of the comma separated values
    if (myString != null) {  // Prevents a null pointer exception. (Not sure why myString was coming back null though)
      String splitString[] = splitTokens(myString, ",");
      // Generate an array of floats to hold our converted string values (so we can do some processing)
      float pixelVals[] = new float[64];
      for(int q = 0; q < 64; q++){
        if (float(splitString[q]) != Float.NaN) {
          pixelVals[q] = float(splitString[q]) * alpha + (1 - alpha) * pixelVals[q];
        }
      }
      maxTemp = max(pixelVals);
      minTemp = min(pixelVals);
      
      // Scale temperatures to +/- 1 standard deviation from the mean
      float meanTemp = mean(pixelVals);
      float stdev = stdv(pixelVals, meanTemp);
      minTemp = meanTemp - stdev;
      maxTemp = meanTemp + stdev;
      
      // for each of the 64 values, map the temperatures to the blue through red portion of the color space
      // if autoscaling, map the temperatures within +/-1 stdv to blue through red
      for (int yIter = 0; yIter < 8; yIter++) {
        for (int xIter = 0; xIter < 8; xIter++) {
          if (autoScale) {
            temps[xIter][yIter] = map(pixelVals[xIter + yIter * 8], minTemp, maxTemp, 240, 360); 
          } else {
            temps[xIter][yIter] = map(pixelVals[xIter + yIter * 8], 20, 40, 240, 360); 
          }
        }
      }
    }
  }
  
  // Draw the GridEYE data
  for (int xIter = 0; xIter < 8; xIter++) {
    for (int yIter = 0; yIter < 8; yIter++) {
      if (mirror) {
        fill(temps[7 - xIter][yIter], 100, 100, 150);  // R, G, B, Alpha
      } else {
        fill(temps[xIter][yIter], 100, 100, 150);  // R, G, B, Alpha
      }        
      rect(xIter * thermalCamSize[0],yIter * thermalCamSize[1], thermalCamSize[0], thermalCamSize[1]);
    }
  }
} 


void keyPressed() {
  if (key == 'a') {
    autoScale ^= true;
    if (autoScale) {
      println("Now autoscaling.");
    } else {
      println("Autoscaling off.");
    }
  }
  if (key == 'm') {
    mirror ^= true;
    if (mirror) {
      println("Now mirroring.");
    } else {
      println("Mirroring off.");
    }
  }
}