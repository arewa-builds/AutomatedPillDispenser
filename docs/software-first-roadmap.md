# Software-First Roadmap (No Hardware Purchased Yet)

You can complete a large share of Weeks 2–5 before the Arduino kit arrives. Use your **laptop camera (index 0)** and a **mock serial dispenser**.

## Do now (highest ROI)

| Priority | Workstream | Needs hardware? | Outcome |
| ---: | :--- | :---: | :--- |
| 1 | MediaPipe face presence gate | No (laptop cam) | Week 2 face milestone |
| 2 | OpenCV pill count on candy/dummy pills | No (laptop cam + candy) | Week 2 pill verify |
| 3 | Mock Arduino + Serial command protocol | No | Week 3 integration without board |
| 4 | Telemetry JSON contract + local log writer | No | Feeds Week 4 Bronze |
| 5 | Compile-ready Nano 33 BLE firmware | No (flash later) | Week 1 code ready on day parts arrive |
| 6 | Synthetic Bronze → Silver transforms | No | Week 4 pipeline logic |
| 7 | Synthetic adherence drift → MLflow baseline | No | Week 5 model skeleton |

## Defer until parts arrive

- Physical servo tuning / PWM pulse calibration  
- LiPo + TP4056 wiring validation  
- Real BLE pairing on Nano 33 BLE  
- Dispense repeatability with the 3D-printed carousel  

## Suggested daily loop (pre-purchase)

1. Run `edge/pipeline.py --mode mock` and confirm face → mock dispense → tray verify.  
2. Tune HSV/contour thresholds for your candy under desk lighting.  
3. Review `firmware/pill_dispenser/pill_dispenser.ino` pin map against the BOM you will order.  
4. Generate a week of synthetic telemetry and run `databricks/local_medallion.py`.  

## Parts order (when ready)

See BOM in `docs/project-context.md`. Prefer **laptop camera** to keep hardware near **~$73**.
