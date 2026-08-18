// Shared parametric dimensions for Automated Pill Dispenser CAD
// Include from part files: include <parameters.scad>;

// ----- Global print / fit -----
layer_h        = 0.2;
nozzle_d       = 0.4;
clearance_slip = 0.25;   // PLA slip fit
clearance_press = 0.05;  // light press fit

// ----- Arduino Nano 33 BLE -----
nano_l = 45.0;
nano_w = 18.0;
nano_h = 7.0;

// ----- MG90S servo body -----
servo_l = 22.8;
servo_w = 12.2;
servo_h = 28.5;

// ----- LiPo + TP4056 -----
lipo_l = 30.0;
lipo_w = 20.0;
lipo_h = 6.0;

// ----- Part B base plate -----
base_plate_dia = 100.0;
base_plate_h   = 5.0;
drop_w         = 20.0;
drop_d         = 15.0;

// ----- Part C carousel -----
car_dia = 98.0;
car_h   = 25.0;
car_pockets = 8;
