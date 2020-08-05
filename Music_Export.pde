/**
  * This sketch demonstrates two ways to accomplish offline (non-realtime) analysis of an audio file.<br>
  * The first method, which uses an AudioSample, is what you see running.<br>
  * The second method, which uses an AudioRecordingStream and is only available in Minim Beta 2.1.0 and beyond,<br>
  * can be viewed by looking at the offlineAnalysis.pde file.
  * <p>
  * For more information about Minim and additional features, visit http://code.compartmental.net/minim/
  *
  */

import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.spi.*;

Minim minim;
float[][] spectra;
float max = 0;
int sampleRate = 44100;

void setup()
{
  size(1400, 850);
  minim = new Minim(this);
  analyzeUsingAudioSample();
  pixelDensity(2);
}

void analyzeUsingAudioSample()
{
   AudioSample song = minim.loadSample("SEE SOME OK.mp3", 2048);
   
  // get the left channel of the audio as a float array
  // getChannel is defined in the interface BuffereAudio, 
  // which also defines two constants to use as an argument
  // BufferedAudio.LEFT and BufferedAudio.RIGHT
  float[] leftChannel = song.getChannel(AudioSample.LEFT);
  
  // then we create an array we'll copy sample data into for the FFT object
  // this should be as large as you want your FFT to be. generally speaking, 1024 is probably fine.
  int fftSize = 1024;
  float[] fftSamples = new float[fftSize];
  FFT fft = new FFT( fftSize, song.sampleRate() );
  System.out.println(song.sampleRate());
  
  // now we'll analyze the samples in chunks
  int totalChunks = (leftChannel.length / fftSize) + 1;
  
  // allocate a 2-dimentional array that will hold all of the spectrum data for all of the chunks.
  // the second dimension if fftSize/2 because the spectrum size is always half the number of samples analyzed.
  spectra = new float[totalChunks][fftSize/2];
  
  for(int chunkIdx = 0; chunkIdx < totalChunks; ++chunkIdx)
  {
    int chunkStartIndex = chunkIdx * fftSize;
   
    // the chunk size will always be fftSize, except for the 
    // last chunk, which will be however many samples are left in source
    int chunkSize = min( leftChannel.length - chunkStartIndex, fftSize );
   
    // copy first chunk into our analysis array
    System.arraycopy( leftChannel, // source of the copy
               chunkStartIndex, // index to start in the source
               fftSamples, // destination of the copy
               0, // index to copy to
               chunkSize // how many samples to copy
              );
      
    // if the chunk was smaller than the fftSize, we need to pad the analysis buffer with zeroes        
    if ( chunkSize < fftSize )
    {
      // we use a system call for this
      java.util.Arrays.fill( fftSamples, chunkSize, fftSamples.length - 1, 0.0 );
    }
    
    // now analyze this buffer
    fft.forward( fftSamples );
   
    // and copy the resulting spectrum into our spectra array
    for(int i = 0; i < 512; ++i)
    {
      spectra[chunkIdx][i] = fft.getBand(i);
      if ( spectra[chunkIdx][i] > max) {
        max = spectra[chunkIdx][i];
      }
    }
  }
  
  System.out.println(max);
  System.out.println(spectra.length);
  System.out.println(spectra[0].length);
  
  song.close(); 
}

int side = 1;
int xPos = 0;
float mult = 0.2;

void draw() {
  background(255);
  
  
  for(int s = Math.max(xPos, 0); s < Math.min(spectra.length - 1, xPos + width); s++) {
    float[] spectrum = spectra[s];
    
    // draw raw signals
    for(int i = 0; i < spectrum.length-1; ++i ) {
         noStroke();
         fill(Math.max(0, 255 - (spectrum[i] * mult * 255.0)));
         //System.out.println(range[i]* 255.0);
         rect((s - xPos) * side, 512 - (i * side), side, side);
      }
    
    if(s < spectra.length - 1) {
      float[] nextSpectrum = spectra[s + 1];
      float[] averages = computeAverages(spectrum);
      float[] nextAverages = computeAverages(nextSpectrum);
      for (int i = 0; i < averages.length; i++) {
        colorMode(HSB, 255);
        color c = color(255 * i / averages.length - 1, 255, 255);
        stroke(c);
        float x1 = (s - xPos) * side;
        float x2 = (s + 1 - xPos) * side;
        float height = 5;
        float spacing = 15;
        float maxY = 512 + 100 + (i * side * height) + i * spacing;
        float minY = maxY + height;
        float y1 = averages[i] * mult * (maxY - minY) + minY;
        float y2 = nextAverages[i] * mult * (maxY - minY) + minY;
        line(x1, y1, x2, y2);
      }
    }
  }
}

void keyPressed() {
  if(key == CODED) {
    if (keyCode == LEFT) {
      xPos -= 30;
    }
    if(keyCode == RIGHT) {
       xPos += 30;
    }
    if (keyCode == UP) {
      mult += 0.02;
      System.out.println(mult);
    }
    if(keyCode == DOWN) {
       mult -= 0.02;
       System.out.println(mult);
    }
  }
}

float[] computeAverages(float[] spectrum) {
  float[] averages = new float[12];
  
  for (int i = 0; i < 12; i++){
    float avg = 0;
    int lowFreq;
    
    if ( i == 0 ) {
      lowFreq = 0;
    } else {
      lowFreq = (int)((sampleRate/2) / (float)Math.pow(2, 12 - i));
    }
    
    int hiFreq = (int)((sampleRate/2) / (float)Math.pow(2, 11 - i));
    int lowBound = freqToIndex(lowFreq);
    int hiBound = freqToIndex(hiFreq);
    for (int j = lowBound; j <= hiBound; j++) {
      avg += spectrum[j];
    }
    // line has been changed since discussion in the comments
    // avg /= (hiBound - lowBound);
    avg /= (hiBound - lowBound + 1);
    averages[i] = avg;
  }
  
  return averages;
}

public float getBandWidth() {
  return (2f/(float)511) * (sampleRate / 2f);
}
 
public int freqToIndex(int freq)
{
  // special case: freq is lower than the bandwidth of spectrum[0]
  if ( freq < getBandWidth()/2 ) return 0;
  // special case: freq is within the bandwidth of spectrum[512]
  if ( freq < sampleRate/2 - getBandWidth()/2 ) return 511;
  // all other cases
  float fraction = (float)freq/(float) sampleRate;
  int i = Math.round(511 * fraction);
  return i;
}
