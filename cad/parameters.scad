// Shared parametric dimensions — Automated Pill Dispenser
// Include from part files in this folder: include <parameters.scad>;

// ----- Global print / fit -----
layer_h         = 0.2;
nozzle_d        = 0.4;
wall            = 2.4;          // ~6 perimeters @ 0.4 mm
clearance_slip  = 0.30;         // PLA slip fit
clearance_press = 0.08;         // light press fit (servo horn hub)

// ----- Arduino Nano 33 BLE -----
nano_l = 45.0;
nano_w = 18.0;
nano_h = 7.0;
nano_usb_w = 9.0;
nano_usb_h = 4.0;

// ----- MG90S servo body -----
servo_l = 22.8;
servo_w = 12.2;
servo_h = 28.5;
servo_tab_l = 32.2;             // flange tip-to-tip (approx)
servo_tab_t = 2.5;
servo_horn_od = 7.0;            // round horn boss OD (press-fit target)
servo_shaft_clear_d = 9.0;      // plate pass-through

// ----- LiPo + TP4056 -----
lipo_l = 30.0;
lipo_w = 20.0;
lipo_h = 6.0;
tp4056_l = 26.0;
tp4056_w = 17.0;
tp4056_h = 5.0;
tp4056_usbc_w = 9.5;
tp4056_usbc_h = 4.0;

// ----- Part A main enclosure -----
base_outer_xy = 120.0;
base_outer_h  = 42.0;
chute_angle   = 45.0;
chute_w       = 22.0;
chute_len     = 40.0;

// ----- Part B base plate -----
base_plate_dia = 100.0;
base_plate_h   = 5.0;
drop_w         = 20.0;
drop_d         = 15.0;
drop_r_offset  = 32.0;          // radial distance of drop-hole center from axis

// ----- Part C carousel -----
car_dia     = 98.0;
car_h       = 25.0;
car_pockets = 8;
car_wall    = 2.0;
car_hub_od  = 18.0;
car_hub_id  = servo_horn_od - clearance_press;

// ----- Part D latch gate -----
gate_travel   = 22.0;
gate_thickness = 2.4;
gate_w        = drop_w + 6.0;
gate_l        = drop_d + gate_travel + 8.0;
