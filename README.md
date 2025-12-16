**ADD-HP: Automated Drug Dispenser for Hospital Pharmacies**


**📋 Project Overview**


ADD-HP is an Automated Drug Dispenser designed specifically for hospital pharmacies to enhance medication distribution efficiency. The system automates medicine dispensing using RFID-based patient authentication, a rotating carousel storage system, and cloud-integrated inventory management.

**✨KEY FEATURES**


1. RFID-Based Authentication – Secure patient identification using RFID cards

2. Automated Dispensing – Stepper motor rotates carousel; servo motor controls lid

3. 8-Compartment Storage – Dedicated compartments for different medicines

4. Real-Time Feedback – LCD display, LED indicators, and buzzer notifications

5. Cloud Integration – ESP32 Wi-Fi module uploads data to Firebase/Google Sheets

6. Inventory Management – Tracks medicine stock and generates restocking alerts

7. Patient-Specific Dispensing – Retrieves prescriptions from internal memory

**🛠️ Hardware Components**

Component	                                                Model/Specification	                                               Purpose

Microcontroller  	ESP32                         Development Board	Central processing unit

RFID Reader     	RC522 Module	              Patient authentication

Display	                16x2 LCD with I2C	      User interface

Stepper Motor	        28BYJ-48                      Rotates medicine carousel

Motor Driver	        ULN2803	                      Controls stepper motor

Servo Motor	        SG90	                      Opens/closes dispensing lid

Indicators	        LED & Buzze                   Visual/audio feedback

Power Supply	        12V DC Adapter	              System power   
