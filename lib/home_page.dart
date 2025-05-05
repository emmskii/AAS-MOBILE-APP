import 'package:flutter/material.dart';
import 'control_panel.dart';
import 'main.dart'; // Import Login Page
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HomePage extends StatefulWidget {
  final String fullName;
  final String email;
  final String password;

  const HomePage({
    super.key,
    required this.fullName,
    required this.email,
    required this.password,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Constants for tank dimensions (in inches)
  final double AQUARIUM_LENGTH = 24.0;    // ultra3
  final double AQUARIUM_WIDTH = 12.0;
  final double AQUARIUM_HEIGHT = 10.0;
  final double TREATMENT_LENGTH = 12.0;   // ultra1
  final double TREATMENT_WIDTH = 10.0;
  final double TREATMENT_HEIGHT = 8.0;
  final double PH_CONTAINER_LENGTH = 3.0;  // ultra2
  final double PH_CONTAINER_WIDTH = 3.5;
  final double PH_CONTAINER_HEIGHT = 9.0;

  double _waterLevelTank1Liters = 0.0; // Main Tank volume in liters
  double _waterLevelTank2Liters = 0.0; // Treatment Tank volume in liters
  double _pHContainerLevelLiters = 0.0; // pH container volume in liters

  double _phLevelMainTank = 0; // Initial pH value
  double _phLevelTreatmentTank = 0;
  double _temperature = 0; // Initial temperature (°C)

  double _waterLevelTank1 = 0; // Initial water level for Tank 1 (Main Tank)
  double _waterLevelTank2 = 0; // Initial water level for Tank 2 (Treatment Tank)
  double _pHContainerLevelCm = 0.0; // Liquid level inside the pH container

  String recyclingTimeLeft = "5:30 min left"; // Example initial time
  bool lightStatus = true; // Example: true = ON, false = OFF

  // Constants for normal ranges
  final double minPhLevel = 6.5;
  final double maxPhLevel = 8.5;
  final double minTemperature = 15.0;
  final double maxTemperature = 33.0;

  // Variables to track if notifications have been shown
  bool _phNotificationShown = false;
  bool _tempNotificationShown = false;

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Notifications plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _fetchSensorData(); // Fetch pH and temperature data
    _fetchWaterLevel(); // Fetch main tank water level
    _fetchTreatmentWaterLevel(); // Fetch treatment tank water level
    _fetchPHContainerLevel(); // Fetch pH container level
  }

  // Initialize notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  // Show notification when values are out of range
  Future<void> _showNotification({
    required String title,
    required String body,
    required int id,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'aquaponics_alerts', // Channel ID
      'Aquaponics Alerts', // Channel name
      channelDescription: 'Alerts for out-of-range sensor values',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // Check if pH is within normal range and show notification if needed
  void _checkPhLevel(double phValue) {
    if ((phValue < minPhLevel || phValue > maxPhLevel) && !_phNotificationShown) {
      _phNotificationShown = true;
      _showNotification(
        title: 'pH Level Alert',
        body: 'pH level (${phValue.toStringAsFixed(1)}) is outside the normal range (6.5-8.5)',
        id: 1,
      );

      // Show a snackbar as well for immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('pH level (${phValue.toStringAsFixed(1)}) is outside the normal range!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } else if (phValue >= minPhLevel && phValue <= maxPhLevel) {
      // Reset the notification flag when pH returns to normal range
      _phNotificationShown = false;
    }
  }

  // Check if temperature is within normal range and show notification if needed
  void _checkTemperature(double temp) {
    if ((temp < minTemperature || temp > maxTemperature) && !_tempNotificationShown) {
      _tempNotificationShown = true;
      _showNotification(
        title: 'Temperature Alert',
        body: 'Temperature (${temp.toStringAsFixed(1)}°C) is outside the normal range (15-33°C)',
        id: 2,
      );

      // Show a snackbar as well for immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Temperature (${temp.toStringAsFixed(1)}°C) is outside the normal range!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } else if (temp >= minTemperature && temp <= maxTemperature) {
      // Reset the notification flag when temperature returns to normal range
      _tempNotificationShown = false;
    }
  }

  void _fetchSensorData() {
    // Listen for pH values
    _database.child('sensors').onValue.listen((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        setState(() {
          // Update pH values
          _phLevelMainTank = (data["ph2"] as num?)?.toDouble() ?? 0.0;
          _phLevelTreatmentTank = (data["ph1"] as num?)?.toDouble() ?? 0.0;
        });
      }
    });

    // Listen specifically for temperature
    _database.child('sensors/temperature').onValue.listen((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        setState(() {
          _temperature = (event.snapshot.value as num).toDouble();
          _checkTemperature(_temperature);
        });
      }
    });
  }

// Fetch water level from Firebase and convert to liters (Main Tank)
  void _fetchWaterLevel() {
    _database.child('sensors/ultra3').onValue.listen((event) {
      final data = event.snapshot.value as num?;
      if (data != null) {
        setState(() {
          // The data is already in liters based on the Arduino code
          _waterLevelTank1Liters = data.toDouble();
        });
      }
    });
  }

// Fetch treatment tank water level from "sensors/ultra1"
  void _fetchTreatmentWaterLevel() {
    _database.child('sensors/ultra1').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          // The data is already in liters based on the Arduino code
          _waterLevelTank2Liters = (data as num).toDouble();
        });
      }
    });
  }

  /// Fetch pH Container Liquid Level from sensors/ultra2
  void _fetchPHContainerLevel() {
    _database.child('sensors/ultra2').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          // The data is already in liters based on the Arduino code
          _pHContainerLevelLiters = (data as num).toDouble();
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showProfileModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title & Close Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "User Profile",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.white),
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildProfileField("Full Name", widget.fullName),
                _buildProfileField("Email", widget.email),
                _buildProfileField("Password", widget.password, obscureText: true),
                const SizedBox(height: 20),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close modal
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()), // Redirect to Login Page
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Logout", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileField(String label, String value, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        readOnly: true,
        obscureText: obscureText,
        controller: TextEditingController(text: value),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildPhGauge(double phValue) {
    // Determine if pH is out of range
    bool isOutOfRange = phValue < minPhLevel || phValue > maxPhLevel;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Gradient Bar
            Container(
              width: 200,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.purple,
                  ],
                  stops: [0.0, 0.166, 0.333, 0.5, 0.666, 1.0],
                ),
              ),
            ),
            // Indicator
            Positioned(
              left: max(0, min((phValue / 14.0) * 200 - 1, 198)), // Keep it within bounds
              child: Container(
                width: 2,
                height: 30,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'pH Level: ${phValue.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: isOutOfRange ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isOutOfRange)
              const Icon(Icons.warning, color: Colors.amber, size: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildTemperatureGauge(double temperature, double gaugeWidth) {
    // Determine if temperature is out of range
    bool isOutOfRange = temperature < minTemperature || temperature > maxTemperature;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Evenly distributed scale numbers
        SizedBox(
          width: gaugeWidth, // Scale spans entire gauge width
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return Text(
                '${index * 10}', // 0, 10, 20, 30, 40, 50
                style: const TextStyle(fontSize: 12, color: Colors.white),
              );
            }),
          ),
        ),

        const SizedBox(height: 5),

        // Gauge with tick marks and temperature fill
        Stack(
          children: [
            // Gauge background
            Container(
              width: gaugeWidth,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.white, // Dark background for better contrast
              ),
            ),

            // Temperature fill (Red bar up to the measured temperature)
            Positioned(
              left: 0,
              child: Container(
                width: (temperature.clamp(0, 50) / 50) * gaugeWidth,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isOutOfRange ? Colors.orange : Colors.red,
                ),
              ),
            ),

            // Evenly spaced tick marks
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Container(
                    width: 1,
                    height: 15,
                    color: Colors.black,
                  );
                }),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        // Display temperature value
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Temperature: ${temperature.toStringAsFixed(1)}°C',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: isOutOfRange ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isOutOfRange)
              const Icon(Icons.warning, color: Colors.amber, size: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildWaterTankGauge(double waterLevelLiters, String tankName) {
    // Calculate max volume for scaling visualization
    double maxTankHeight = tankName == "Main Tank" ? 120 : 80; // Main tank is larger in UI
    double maxTankWidth = tankName == "Main Tank" ? 160 : 80; // Treatment tank is smaller in UI

    // Calculate max volume in liters
    double maxVolumeLiters;
    if (tankName == "Main Tank") {
      // Max volume of main tank in liters
      maxVolumeLiters = (AQUARIUM_LENGTH * AQUARIUM_WIDTH * AQUARIUM_HEIGHT * 2.54 * 2.54 * 2.54) / 1000.0;
    } else {
      // Max volume of treatment tank in liters
      maxVolumeLiters = (TREATMENT_LENGTH * TREATMENT_WIDTH * TREATMENT_HEIGHT * 2.54 * 2.54 * 2.54) / 1000.0;
    }

    // Scale water level for visualization
    double waterHeight = (waterLevelLiters / maxVolumeLiters) * maxTankHeight;

    // Cap the waterHeight to prevent overflow in UI
    waterHeight = waterHeight.clamp(0, maxTankHeight);

    return Column(
      children: [
        Text(
          tankName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Tank Container (Outline)
            Container(
              width: maxTankWidth,
              height: maxTankHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // Water Level (Dynamic)
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              width: maxTankWidth,
              height: waterHeight,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 0, 255, 0.5), // Semi-transparent blue
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Display Water Level Value in Liters
        Text(
          "${waterLevelLiters.toStringAsFixed(1)} L",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }


  /// Green pH Container Widget (Without Arrow)
  Widget _buildGreenPhContainerLevel(double pHContainerLevelLiters, String label) {
    double maxContainerHeight = 80.0; // Maximum UI height

    // Calculate max volume of pH container in liters
    double maxVolumeLiters = (PH_CONTAINER_LENGTH * PH_CONTAINER_WIDTH * PH_CONTAINER_HEIGHT * 2.54 * 2.54 * 2.54) / 1000.0;

    // Calculate liquid height based on volume in liters
    double liquidHeight = (pHContainerLevelLiters / maxVolumeLiters) * maxContainerHeight;

    return Column(
      children: [
        // Label (optional)
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 5), // Spacing

        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Container Border
            Container(
              width: 30,
              height: maxContainerHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
            ),

            // Green Liquid (Animated)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 30,
              height: liquidHeight.clamp(0, maxContainerHeight), // Ensure within bounds
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(204),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10), // Spacing

        // Display Liquid Level in Liters
        Text(
          "${pHContainerLevelLiters.toStringAsFixed(1)} L", // Display in liters
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }


  Widget _buildBubble(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(76),
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD4F1E8),
      body: Stack(
        children: [
          // Bubble Background
          Positioned(top: 50, left: -30, child: _buildBubble(120)),
          Positioned(top: 250, right: -40, child: _buildBubble(180)),
          Positioned(bottom: 100, left: -50, child: _buildBubble(200)),
          Positioned(bottom: 30, right: -60, child: _buildBubble(150)),

          // Main Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Dashboard",
                      style: TextStyle(
                        fontSize: 35,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0A2A71),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle, size: 45),
                      onPressed: () => _showProfileModal(context),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                Center(
                  child: Container(
                    width: 330,
                    height: 380,
                    decoration: BoxDecoration(
                      color: Colors.teal[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // Add spacing
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal, // Allows horizontal scrolling if needed
                        child: Row(
                          mainAxisSize: MainAxisSize.min, // Prevents unnecessary stretching
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Side - Tanks
                            Column(
                              children: [
                                _buildWaterTankGauge(_waterLevelTank1Liters, "Main Tank"),
                                const SizedBox(height: 5),
                                _buildWaterTankGauge(_waterLevelTank2Liters, "Treatment Tank"),
                              ],
                            ),

                            const SizedBox(width: 10), // Reduced spacing

                            // Middle - Main Tank pH and Temperature
                            Column(
                              children: [
                                const SizedBox(height: 30),
                                _buildPhGauge(_phLevelMainTank), // Make sure to use Main Tank pH variable
                                const SizedBox(height: 20), // Reduced spacing
                                _buildTemperatureGauge(_temperature, 200), // Gauge width = 200 pixels

                                const SizedBox(height: 20),
                                // Replace treatment pH gauge with green pH container level
                                _buildGreenPhContainerLevel(_pHContainerLevelLiters, "pH down Container")

                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Small Rounded Square
                Center(
                  child: Container(
                    width: 450,
                    height: 125,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.teal[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Recycling Timer (Side by Side)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Recycling Timer:",
                              style: TextStyle(fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                            ),
                            Container(
                              width: 120, // Fixed width for alignment
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF74D8A8),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Text(
                                recyclingTimeLeft, // Countdown Timer
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Light Status (Side by Side)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Light Status:",
                              style: TextStyle(fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                            ),
                            Container(
                              width: 120, // Fixed width for alignment
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: lightStatus ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Text(
                                lightStatus ? "ON" : "OFF", // Display ON/OFF
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                const Center(
                  child: Text(
                    "Go to",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
                  ),
                ),
                const SizedBox(height: 5),

                // Control Panel Button
                Center(
                  child: SizedBox(
                    width: 450,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ControlPanelPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF97ABDA),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        "Control Panel",
                        style: TextStyle(fontSize: 18, color: Color(0xFF0A2A71), fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}