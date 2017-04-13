# FPGA Super Hexagon
FPGA Version of Super Hexagon Game

## Authors:
Zhiming (Charles) Chen

Yuan (Michael) Feng

Mingqi (Matthew) Hou

## Note
This project requires a Digilent Nexys 4 DDR development board and a PMOD 2-Axis Joystick to run.

## Repository Hierarchy
The **doc** directory contains design document, demo presentation, and video.

The **src** directory contains all source files needed to compile and run this project. Including the Vivado project and the control software.

* resource
  * start_screen.bmp: Start screen drawing
  * end_screen.bmp: End screen drawing
  * bmp2coe.py: Python script used to convert bmp files to coe format.
* software
  * superhexagon.c: Main software code
* superhexagon
  * superhexagon.xpr: Vivado project file
  * super_hexagon.ipdefs: Custom IP definitions
    * hexagon_render_2.0: Render Module (main custom IP for project)
    * joystick_1.0: Joystick Module
    * timer_2.0: Timer Module
  * super_hexagon.srcs: design sources
    * constrs_1/new/super_hexagon.xdc: Constraint file
    * sources_1:
      * start_screen.coe: Start screen memory initialization file
      * end_screen.coe: End screen memory initialization file
      * bd/block_system: Block design files
      * imports/hdl: HDL wrapper file


## How to run
1. Clone the Git repository (using “git clone”) and pull all contents.
2. Make sure Vivado 2016.2 (or higher) and SDK are properly installed on your computer, with support for Artix 7 FPGA. Only Windows platform was tested, though Linux platform should also work.
3. Open super_hexagon.xpr under src/superhexagon/.
4. Generate block design. If block design verification gives critical warnings about mismatches on block ram connection mode, ignore them. This is due to setting block ram in “standalone” mode (in order to use coe files for initialization) while connecting through AXI controller. This is not a real error.
5. Generate bitstream file. Vivado should prompt to run synthesis and implementation because they haven’t been run, click “Yes”.
6. File → Export → Export Hardware. Make sure to include bitstream file.
7. File → Launch SDK. Vivado SDK should launch.
8. Create a new application project: File → New → Application Project. Replace the main C file with the provided C file under src/software/superhexagon.c. You may need to rename it to the recognized file name by the project (e.g. helloworld.c or memorytest.c) or add it to the source file tree of the project.
9. Make sure the Nexys 4 DDR board is connected to your computer, then programe the FPGA: Xilinx Tools → Program FPGA → click “Program”.
10. Compile project: Project → Build Project (or select “Build Automatically” and just save the C file. This will automatically build your project every time you save).
11. Run project: Run → Run (or ctrl + F11).
