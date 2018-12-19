/*o*
/*************************************************************************
 *
 * SerialOregon.ino : Arduino sketch to decode Oregon Scientific weather sensors.
 *
 * Copyleft 2018 Nicolas Agius <nicolas.agius@lps-it.fr>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * ***********************************************************************/

/*
 * This sketch make use of cheap 433Mhz receiver to decode Oregon Scientific 
 * weather sensors and send the data over serial port in JSON format.
 * 
 * Basic wiring would be like : 
 * Arduino <-- (PIN 2) --> 433Mhz receiver <=======> Oregon sensors
 *
 * For more information on the Oregon protocol and how to decode it, 
 * see : https://github.com/robwlakes/ArduinoWeatherOS
 * 
 * See README.md for more information of the use of this sketch
 * 
 */


#include <EEPROM.h>
#include <Oregon.h>

#define RECEIVER_PIN 2  // Pi attached to the 433Mhz receiver

void setup ()
{
  Serial.begin(9600);
  Serial.println("SerialOregon v1.0 started.");
  pinMode(LED_BUILTIN, OUTPUT);

  //Say hello
  digitalWrite(LED_BUILTIN, HIGH);
  delay(300);
  digitalWrite(LED_BUILTIN, LOW);
  delay(100);
  digitalWrite(LED_BUILTIN, HIGH);
  delay(100);
  digitalWrite(LED_BUILTIN, LOW);
  delay(100);
  digitalWrite(LED_BUILTIN, HIGH);
  delay(300);
  digitalWrite(LED_BUILTIN, LOW);
  
  
  // Setup interrupt handler
  attachInterrupt(digitalPinToInterrupt(RECEIVER_PIN), ext_int_1, CHANGE);
}

void loop () {
    String json;
    
    // Start process new data from Oregon sensors
    cli();
    word p = pulse;
    pulse = 0;
    sei();
    
    if (p != 0)
    {
        if (orscV2.nextPulse(p))
        {
            // Decode Hex 
            const byte* DataDecoded = DataToDecoder(orscV2);

            json = "{ \"channel\": \"";
            json += channel(DataDecoded);
            json += "\", \"temp\": \"";
            json += temperature(DataDecoded);
            json += "\", \"hum\": \"";
            json += humidity(DataDecoded);
            json += "\" }";
            Serial.println(json);
        }
    }
}
