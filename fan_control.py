#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import RPi.GPIO as GPIO
import time

FAN_PIN = 15  # Number based on the numbering system you have specified (BOARD or BCM)
PWM_FREQ = 1000  # [Hz] Frequency of PWM
DUTY_CYCLE_0 = 10  # Minimal D_C value to prevent fan noise without load
CPU_TEMP_1, DUTY_CYCLE_1 = 50, 50  # [C] Temperature on which fan will be work with D_C = 50
CPU_TEMP_2, DUTY_CYCLE_2 = 60, 75  # [C] Temperature on which fan will be work with D_C = 75
CPU_TEMP_3, DUTY_CYCLE_3 = 70, 100  # [C] Temperature on which fan will be work with D_C = 100
TEMP_CHECK = 5  # [s] Temperature checking interval


def temp_checking() -> int:
    """Checking temperature of CPU"""
    with open(r"/sys/class/thermal/thermal_zone0/temp") as file:
        for line in file:
            temp = int(int(line) / 1000)
    return temp


if __name__ == "__main__":
    """Check https://sourceforge.net/p/raspberry-gpio-python/wiki/Examples/ for information"""
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(FAN_PIN, GPIO.OUT, initial=GPIO.HIGH)
    fan = GPIO.PWM(FAN_PIN, PWM_FREQ)
    fan.start(0)  # Starting fan with duty cycle 0

    while True:
        current_cpu_temp = temp_checking()

        if current_cpu_temp >= CPU_TEMP_1:
            fan.ChangeDutyCycle(DUTY_CYCLE_1)
        elif current_cpu_temp >= CPU_TEMP_2:
            fan.ChangeDutyCycle(DUTY_CYCLE_2)
        elif current_cpu_temp >= CPU_TEMP_3:
            fan.ChangeDutyCycle(DUTY_CYCLE_3)
        else:
            fan.ChangeDutyCycle(DUTY_CYCLE_0)
        time.sleep(TEMP_CHECK)
