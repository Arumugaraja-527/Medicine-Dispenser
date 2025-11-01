#include <SPI.h>
#include <MFRC522.h>
#include <ESP32Servo.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Firebase_ESP_Client.h>
#include <WiFi.h>
#include <addons/TokenHelper.h>

// WiFi credentials
#define WIFI_SSID "Redmi 9 Prime"
#define WIFI_PASSWORD "00000003"

// Firebase configuration
#define API_KEY "AIzaSyD4ogjHWVi2CXRn4tRzVc8GlyHB2g1cWJc"
#define DATABASE_URL "https://medicine-15a9d-default-rtdb.firebaseio.com/"
#define USER_EMAIL "arumugaraja@gmail.com"
#define USER_PASSWORD "06042004"

// RFID & Hardware pins
#define SS_PIN 5
#define RST_PIN 4
#define SERVO_PIN 13
#define LED_PIN 12
#define BUZZER_PIN 14

// Stepper Motor Pins (IN1–IN4 of ULN2003)
#define IN1 26
#define IN2 27
#define IN3 32
#define IN4 33

const int stepsPerCompartment = 512;
const int totalCompartments = 8;
int currentCompartment = 0;

// Stepper half-step sequence for 28BYJ-48
const int stepSequence[8][4] = {
  {1, 0, 0, 0},
  {1, 1, 0, 0},
  {0, 1, 0, 0},
  {0, 1, 1, 0},
  {0, 0, 1, 0},
  {0, 0, 1, 1},
  {0, 0, 0, 1},
  {1, 0, 0, 1}
};

MFRC522 rfid(SS_PIN, RST_PIN);
Servo servo;
LiquidCrystal_I2C lcd(0x27, 16, 2);

FirebaseData fbdo, fbdoHelper;
FirebaseAuth auth;
FirebaseConfig config;
bool firebaseInitialized = false;
unsigned long lastMedicineCheck = 0;

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);
  lcd.begin(16, 2);
  lcd.backlight();

  SPI.begin();
  rfid.PCD_Init();

  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);

  servo.attach(SERVO_PIN);
  servo.write(0);

  pinMode(LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  connectToWiFi();
  initializeFirebase();

  lcd.clear();
  lcd.setCursor(0, 1);
  lcd.print("Scan RFID Card...");
}

void loop() {
  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    handleRFIDScan();
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
  } else {
    scrollText("Medicine Dispenser", 0);
  }

  if (millis() - lastMedicineCheck > 300000 && firebaseInitialized) {
    checkMedicineUpdates();
    lastMedicineCheck = millis();
  }

  delay(50);
}

void connectToWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println("\nConnected with IP: " + WiFi.localIP().toString());
}

void initializeFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectNetwork(true);

  Serial.println("Waiting for Firebase authentication...");
  while (auth.token.uid == "") {
    Serial.print(".");
    delay(300);
  }
  Serial.println("\nFirebase authenticated");
  firebaseInitialized = true;
}

String getRFIDUID() {
  String uidStr = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uidStr += "0";
    uidStr += String(rfid.uid.uidByte[i], HEX);
    if (i < rfid.uid.size - 1) uidStr += " ";
  }
  return uidStr;
}

void handleRFIDScan() {
  String uid = getRFIDUID();
  Serial.println("Scanned RFID: " + uid);

  lcd.clear();
  lcd.print("User detected");
  lcd.setCursor(0, 1);
  lcd.print("Checking...");

  String path = "users/";
  bool userFound = false;

  if (Firebase.RTDB.getJSON(&fbdo, path)) {
    FirebaseJson *json = fbdo.to<FirebaseJson *>();
    FirebaseJsonData result;
    size_t len = json->iteratorBegin();

    for (size_t i = 0; i < len; i++) {
      FirebaseJson::IteratorValue value = json->valueAt(i);
      String userPath = path + value.key + "/";

      if (Firebase.RTDB.getString(&fbdoHelper, userPath + "uid")) {
        String fetchedUid = fbdoHelper.to<String>();

        if (fetchedUid == uid) {
          userFound = true;
          String userName;
          std::vector<String> userMeds;

          if (Firebase.RTDB.getString(&fbdoHelper, userPath + "name")) {
            userName = fbdoHelper.to<String>();
          }

          if (Firebase.RTDB.getArray(&fbdoHelper, userPath + "medicines")) {
            FirebaseJsonArray arr(fbdoHelper.to<String>().c_str());
            for (size_t j = 0; j < arr.size(); j++) {
              FirebaseJsonData medData;
              arr.get(medData, j);
              userMeds.push_back(medData.to<String>());
            }
          }

          dispenseMedicines(userName, userMeds);
          break;
        }
      }
    }

    json->iteratorEnd();
  }

  if (!userFound) {
    lcd.clear();
    lcd.print("User not found");
    delay(2000);
    resetDisplay();
  }
}

void dispenseMedicines(String userName, std::vector<String> medicines) {
  lcd.clear();
  lcd.print(userName);
  lcd.setCursor(0, 1);
  lcd.print("Dispensing...");

  for (String med : medicines) {
    int compartment = getCompartmentIndex(med);
    if (compartment != -1) {
      lcd.clear();
      lcd.print("Preparing:");
      lcd.setCursor(0, 1);
      lcd.print(med);

      rotateToCompartment(compartment);
      digitalWrite(LED_PIN, HIGH);
      digitalWrite(BUZZER_PIN, HIGH);
      openLid();
      digitalWrite(LED_PIN, LOW);
      digitalWrite(BUZZER_PIN, LOW);

      logDispensing(userName, med, compartment);
      delay(1000);
    }
  }

  lcd.clear();
  lcd.print(userName);
  lcd.setCursor(0, 1);
  lcd.print("Complete!");
  delay(2000);
  resetDisplay();
}

int getCompartmentIndex(String medicineName) {
  if (!firebaseInitialized) return -1;

  for (int i = 0; i < totalCompartments; i++) {
    String path = "medicines/compartments/" + String(i);
    if (Firebase.RTDB.getString(&fbdo, path)) {
      if (fbdo.to<String>() == medicineName) {
        return i;
      }
    }
  }
  return -1;
}

void rotateToCompartment(int target) {
  int stepsToMove = (target - currentCompartment + totalCompartments) % totalCompartments;
  if (stepsToMove > totalCompartments / 2) stepsToMove -= totalCompartments;
  rotateStepper(stepsToMove * stepsPerCompartment);
  currentCompartment = target;
}

void rotateStepper(int steps) {
  int direction = steps > 0 ? 1 : -1;
  steps = abs(steps);
  for (int i = 0; i < steps; i++) {
    static int stepIndex = 0;
    stepIndex = (stepIndex + direction + 8) % 8;
    setStep(stepIndex);
    delay(2);  // Adjust for speed
  }
}

void setStep(int step) {
  digitalWrite(IN1, stepSequence[step][0]);
  digitalWrite(IN2, stepSequence[step][1]);
  digitalWrite(IN3, stepSequence[step][2]);
  digitalWrite(IN4, stepSequence[step][3]);
}

void openLid() {
  servo.write(90);
  delay(2000);
  servo.write(0);
  delay(500);
}

void logDispensing(String user, String med, int compartment) {
  if (!firebaseInitialized) return;
  FirebaseJson json;
  json.set("user", user);
  json.set("medicine", med);
  json.set("compartment", compartment);
  json.set("timestamp", millis());
  Firebase.RTDB.setJSON(&fbdo, "logs/" + String(millis()), &json);
}

void checkMedicineUpdates() {
  Serial.println("Checking for medicine updates...");
}

void resetDisplay() {
  lcd.clear();
  lcd.setCursor(0, 1);
  lcd.print("Scan RFID Card...");
}

void scrollText(String text, int row) {
  static int pos = 0;
  static unsigned long lastScroll = 0;
  const int scrollDelay = 300;
  const int displayWidth = 16;

  if (millis() - lastScroll >= scrollDelay) {
    lastScroll = millis();
    String displayText = text + "   ";
    int start = pos % displayText.length();
    String scroll = displayText.substring(start) + displayText.substring(0, start);
    lcd.setCursor(0, row);
    lcd.print(scroll.substring(0, displayWidth));
    pos++;
  }
}
