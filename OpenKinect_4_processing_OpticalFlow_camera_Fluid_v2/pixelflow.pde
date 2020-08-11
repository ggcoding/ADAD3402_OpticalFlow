 private class MyFluidData implements DwFluid2D.FluidData{


@Override
// this is called during the fluid-simulation update step.
public void update(DwFluid2D fluid) {

  float px, py, vx, vy, radius, vscale;

  boolean mouse_input = !cp5.isMouseOver() && mousePressed;
  if(mouse_input ){

    vscale = 15;
    px     = mouseX;
    py     = height-mouseY;
    vx     = (mouseX - pmouseX) * +vscale;
    vy     = (mouseY - pmouseY) * -vscale;
    
    if(mouseButton == LEFT){
      radius = 20;
      fluid.addVelocity(px, py, radius, vx, vy);
    }
    if(mouseButton == CENTER){
      radius = 50;
      fluid.addDensity (px, py, radius, 1.0f, 0.0f, 0.40f, 1f, 1);
    }
    if(mouseButton == RIGHT){
      radius = 15;
      fluid.addTemperature(px, py, radius, 15f);
    }
    
  }

  addDensityTexture_cam(fluid, opticalflow);
  addVelocityTexture   (fluid, opticalflow);
//      addTemperatureTexture(fluid, opticalflow);
}


public void addDensityTexture_cam(DwFluid2D fluid, DwOpticalFlow opticalflow){
  int[] pg_tex_handle = new int[1];
  
  if( !pg_movie.getTexture().available() ) {
    System.out.println("no tex");
    return;
  }
  
  float mix = opticalflow.UPDATE_STEP > 1 ? 0.05f : 1.0f;
  
  context.begin();
  context.getGLTextureHandle(pg_movie, pg_tex_handle);
  context.beginDraw(fluid.tex_density.dst);
  DwGLSLProgram shader = context.createShader("data/addDensityCam.frag");
  shader.begin();
  shader.uniform2f     ("wh"        , fluid.fluid_w, fluid.fluid_h);                                                                   
  shader.uniform1i     ("blend_mode", 6);   
  shader.uniform1f     ("mix_value" , mix);     
  shader.uniform1f     ("multiplier", 1f);     
//      shader.uniformTexture("tex_ext"   , opticalflow.tex_frames.src);
  shader.uniformTexture("tex_ext"   , pg_tex_handle[0]);
  shader.uniformTexture("tex_src"   , fluid.tex_density.src);
  shader.drawFullScreenQuad();
  shader.end();
  context.endDraw();
  context.end("app.addDensityTexture");
  fluid.tex_density.swap();
}


// custom shader, to add temperature from a texture (PGraphics2D) to the fluid.
public void addTemperatureTexture(DwFluid2D fluid, DwOpticalFlow opticalflow){
  context.begin();
  context.beginDraw(fluid.tex_temperature.dst);
  DwGLSLProgram shader = context.createShader("data/addTemperature.frag");
  shader.begin();
  shader.uniform2f     ("wh"        , fluid.fluid_w, fluid.fluid_h);                                                                   
  shader.uniform1i     ("blend_mode", 1);   
  shader.uniform1f     ("mix_value" , 0.1f);     
  shader.uniform1f     ("multiplier", 0.01f);     
  shader.uniformTexture("tex_ext"   , opticalflow.frameCurr.velocity);
  shader.uniformTexture("tex_src"   , fluid.tex_temperature.src);
  shader.drawFullScreenQuad();
  shader.end();
  context.endDraw();
  context.end("app.addTemperatureTexture");
  fluid.tex_temperature.swap();
}


// custom shader, to add density from a texture (PGraphics2D) to the fluid.
public void addVelocityTexture(DwFluid2D fluid, DwOpticalFlow opticalflow){
    context.begin();
    context.beginDraw(fluid.tex_velocity.dst);
    DwGLSLProgram shader = context.createShader("data/addVelocity.frag");
    shader.begin();
    shader.uniform2f     ("wh"             , fluid.fluid_w, fluid.fluid_h);                                                                   
    shader.uniform1i     ("blend_mode"     , 2);    
    shader.uniform1f     ("multiplier"     , 0.5f);   
    shader.uniform1f     ("mix_value"      , 0.1f);
    shader.uniformTexture("tex_opticalflow", opticalflow.frameCurr.velocity);
    shader.uniformTexture("tex_velocity_old", fluid.tex_velocity.src);
    shader.drawFullScreenQuad();
    shader.end();
    context.endDraw();
    context.end("app.addDensityTexture");
    fluid.tex_velocity.swap();
  }
}
