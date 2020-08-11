/**
 * 
 * PixelFlow | Copyright (C) 2016 Thomas Diewald - http://thomasdiewald.com
 * 
 * A Processing/Java library for high performance GPU-Computing (GLSL).
 * MIT License: https://opensource.org/licenses/MIT
 * 
 */





import java.util.Locale;

import com.thomasdiewald.pixelflow.java.DwPixelFlow;
import com.thomasdiewald.pixelflow.java.dwgl.DwGLSLProgram;
import com.thomasdiewald.pixelflow.java.fluid.DwFluid2D;
import com.thomasdiewald.pixelflow.java.imageprocessing.DwOpticalFlow;
import com.thomasdiewald.pixelflow.java.imageprocessing.filter.DwFilter;

import controlP5.Accordion;
import controlP5.ControlP5;
import controlP5.Group;
import controlP5.RadioButton;
import controlP5.Toggle;
import processing.core.*;
import processing.opengl.PGraphics2D;
import processing.sound.*;

import org.openkinect.freenect.*;
import org.openkinect.processing.*;
 

Kinect sensor_colour_cam;

boolean ir = false;
boolean colorDepth = false;
boolean mirror = false;

  //
  // This Demo-App combines Optical Flow (based on Kinect V2 HD color camera) and Fluid 
  // simulation.
  // The resulting velocity vectors of the Optical Flow are used to change the
  // velocity of the Fluid. The Movie Frames are the source for the Fluid_density.
  // 
  // This effect works best, when the movie background is not chaanging too much,
  // e.g. when the camera is not moving.
  // 
// dimensions
int view_w = 1280;
int view_h = 780;
int view_x = 230;
int view_y = 0;
 
int gui_w = 200;
int gui_x = view_w - gui_w;
int gui_y = 0;

int pg_movie_w = view_w;
int pg_movie_h = view_h;


//main library context
DwPixelFlow context;

// optical flow
DwOpticalFlow opticalflow;


// fluid stuff
int fluidgrid_scale = 1;
DwFluid2D fluid;


// render targets
PGraphics2D pg_movie; 
PGraphics2D pg_temp; 
PGraphics2D pg_oflow;

// some state variables for the GUI/display
int     BACKGROUND_COLOR = 0;
boolean DISPLAY_SOURCE   = false;
boolean APPLY_GRAYSCALE  = false;
boolean APPLY_BILATERAL  = false;
int     VELOCITY_LINES   = 6;
boolean UPDATE_FLUID = true;
boolean DISPLAY_FLUID_TEXTURES  = true;
boolean DISPLAY_FLUID_VECTORS   = !true;
boolean DISPLAY_PARTICLES       = !true;
int     DISPLAY_fluid_texture_mode = 3;

AudioIn in;
Reverb reverb;
      
public void settings() {
  size(view_w, view_h, P2D);
  smooth(8);
}

public void setup() {
  
  //surface.setLocation(view_x, view_y); detault screen
  
  // main library context
  context = new DwPixelFlow(this);
  context.print();
  context.printGL();
  sensor_colour_cam = new Kinect(this);

  sensor_colour_cam.initVideo();

  sensor_colour_cam.enableColorDepth(colorDepth);
 
  // optical flow object
  opticalflow = new DwOpticalFlow(context, pg_movie_w, pg_movie_h);
  opticalflow.param.display_mode = 3; // set on vaild opticflow displayMode
  
  // fluid object
  fluid = new DwFluid2D(context, pg_movie_w, pg_movie_h, fluidgrid_scale);
  // initial fluid parameters
  fluid.param.dissipation_density     = 0.95f;
  fluid.param.dissipation_velocity    = 0.80f;
  fluid.param.dissipation_temperature = 0.70f;
  fluid.param.vorticity               = 0.55f;
  // callback for adding fluid data
  fluid.addCallback_FluiData(new MyFluidData());
 
  // init render targets
  pg_movie = (PGraphics2D) createGraphics(pg_movie_w, pg_movie_h, P2D);
  pg_movie.smooth(0);
  pg_movie.beginDraw();
  pg_movie.background(0);
  pg_movie.endDraw();
  
  pg_temp = (PGraphics2D) createGraphics(pg_movie_w, pg_movie_h, P2D);
  pg_temp.smooth(0);
  
  pg_oflow = (PGraphics2D) createGraphics(pg_movie_w, pg_movie_h, P2D);
  pg_oflow.smooth(0);
  
  createGUI();
  
  in = new AudioIn (this, 0);
  in.play();
  reverb = new Reverb(this);
  reverb.process(in);
  
  background(0);
  frameRate(60);
}


  

  

public void draw() {  
    PImage mymovie = sensor_colour_cam.getVideoImage(); 
    // compute movie display size to fit the best
    int movie_w = 1280;
    int movie_h = 780;
    
    float mov_w_fit = pg_movie_w;
    float mov_h_fit = (pg_movie_w/(float)movie_w) * movie_h;
    
    if(mov_h_fit > pg_movie_h){
      mov_h_fit = pg_movie_h;
      mov_w_fit = (pg_movie_h/(float)movie_h) * movie_w;
    }
    
    // render to offscreenbuffer
    pg_movie.beginDraw();
    pg_movie.background(0);
    pg_movie.imageMode(CENTER);
    pg_movie.pushMatrix();
    pg_movie.translate(pg_movie_w/2f, pg_movie_h/2f);
    pg_movie.scale(0.95f);
    pg_movie.image(mymovie, 0, 0, mov_w_fit, mov_h_fit);
    pg_movie.popMatrix();
    pg_movie.endDraw();
    
    // apply filters (not necessary)
    if(APPLY_GRAYSCALE){
      DwFilter.get(context).luminance.apply(pg_movie, pg_movie);
    }
    if(APPLY_BILATERAL){
      DwFilter.get(context).bilateral.apply(pg_movie, pg_temp, 5, 0.10f, 4);
      swapCamBuffer();
    }
    
    // update Optical Flow
    opticalflow.update(pg_movie);
  
  if(UPDATE_FLUID){
    fluid.update();
  }

  // render Optical Flow
  pg_oflow.beginDraw();
  pg_oflow.background(BACKGROUND_COLOR);
  if(DISPLAY_SOURCE){
    pg_oflow.image(pg_movie, 0, 0);
  }
  pg_oflow.endDraw();
  
  // add fluid stuff to rendering
  if(DISPLAY_FLUID_TEXTURES){
    fluid.renderFluidTextures(pg_oflow, DISPLAY_fluid_texture_mode);
  }
  
  if(DISPLAY_FLUID_VECTORS){
    fluid.renderFluidVectors(pg_oflow, 10);
  }
  
  // add flow-vectors to the image
  if(opticalflow.param.display_mode == 2){
    opticalflow.renderVelocityShading(pg_oflow);
  }
  opticalflow.renderVelocityStreams(pg_oflow, VELOCITY_LINES);
  
  // display result
  background(0);
  image(pg_oflow, 0, 0);
  
  //timeline.draw(mouseX, mouseY);
  
  // info
  String txt_fps = String.format(getClass().getName()+ "   [size %d/%d]   [frame %d]   [fps %6.2f]", view_w, view_h, opticalflow.UPDATE_STEP, frameRate);
  surface.setTitle(txt_fps);
  
   float roomSize = map(mouseX, 0, width, 0, 0.5);
  reverb.room(roomSize);

  // Change the high frequency dampening parameter
  float damping = map(mouseX, 0, width, 0, 0.8);
  reverb.damp(damping);

  // Change the wet/dry relation of the effect
  float effectStrength = map(mouseY, 0, height, 0, 1.0);
  reverb.wet(effectStrength);
 
}

  

void swapCamBuffer(){
  PGraphics2D tmp = pg_movie;
  pg_movie = pg_temp;
  pg_temp = tmp;
}
  
  

  

  
public void fluid_resizeUp(){
  fluid.resize(width, height, fluidgrid_scale = max(1, --fluidgrid_scale));
}
public void fluid_resizeDown(){
  fluid.resize(width, height, ++fluidgrid_scale);
}
public void fluid_reset(){
  fluid.reset();
  opticalflow.reset();
}
public void fluid_togglePause(){
  UPDATE_FLUID = !UPDATE_FLUID;
}
public void fluid_displayMode(int val){
  DISPLAY_fluid_texture_mode = val;
  DISPLAY_FLUID_TEXTURES = DISPLAY_fluid_texture_mode != -1;
}
public void fluid_displayVelocityVectors(int val){
  DISPLAY_FLUID_VECTORS = val != -1;
}
public void fluid_displayParticles(int val){
  DISPLAY_PARTICLES = val != -1;
}
public void opticalFlow_setDisplayMode(int val){
  opticalflow.param.display_mode = val;
}
public void activeFilters(float[] val){
  APPLY_GRAYSCALE = (val[0] > 0);
  APPLY_BILATERAL = (val[1] > 0);
}
public void setOptionsGeneral(float[] val){
  DISPLAY_SOURCE = (val[0] > 0);
}
 
  
public void mouseReleased(){
  //if(timeline.inside(mouseX, mouseY)){
  //  timeline.jumpToMoviePos();
  //  opticalflow.reset();
  //}
}

 
public void keyReleased(){
  if(key == 'p') fluid_togglePause(); // pause / unpause simulation
  if(key == '+') fluid_resizeUp();    // increase fluid-grid resolution
  if(key == '-') fluid_resizeDown();  // decrease fluid-grid resolution
  if(key == 'r') fluid_reset();       // restart simulation
  
  if(key == '3') DISPLAY_fluid_texture_mode = 2; // pressure
  if(key == '4') DISPLAY_fluid_texture_mode = 3; // velocity
  
  if(key == 'q') DISPLAY_FLUID_TEXTURES = !DISPLAY_FLUID_TEXTURES;
  if(key == 'w') DISPLAY_FLUID_VECTORS  = !DISPLAY_FLUID_VECTORS;
  if(key == 'e') DISPLAY_PARTICLES      = !DISPLAY_PARTICLES;
}
  


  

 
