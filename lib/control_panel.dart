import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class ControlPanelPage extends StatefulWidget {
  const ControlPanelPage({super.key});

  @override
  _ControlPanelPageState createState() => _ControlPanelPageState();
}



class _ControlPanelPageState extends State<ControlPanelPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  double aquariumPh = 0.0;
  double treatmentPh = 0.0;
  double temperature = 0.0;
  bool aquariumPumpOn = false;
  bool treatmentPumpOn = false;
  bool filterPumpOn = false; // Added filter pump state
  int selectedRecyclingInterval = 30;
  int selectedLightingInterval = 12;

  bool _dualTankCirculation = false;
  double _waterLevelCm = 15.0; // Updated from Firebase
  double _treatmentWaterLevelCm = 15.0; // Updated from Firebase
  double _pHContainerLevelCm = 0.0; // Liquid level inside the pH container
  bool _lightOn = false; // Light state

  List<String> _dualCirculationTimes = []; // Store scheduled times
  int _circulationDuration = 2; // Default duration in minutes

  Timer? _schedulerTimer;
  bool _manualOverride = false;

  bool _lightManualOverride = false; // Tracks if the user has manually overridden the schedule


  List<Map<String, String>> _lightingSchedules = [
  ]; // Store lighting schedules with start and end times

  bool _automaticPHControl = true; // Default to automatic

  DateTime? _nextDoseTime;
  bool _dosingPumpOn = false;


  // Initialize properties at class level
  double _lowerPHRange = 6.8;
  double _upperPHRange = 7.2;
  Timer? _circulationTimer;


  @override
  void initState() {
    super.initState();

    _fetchPumpStatus();
    _fetchLightStatus();
    _fetchWaterLevel();
    _fetchPHContainerLevel();
    _fetchTreatmentWaterLevel(); // Fetch treatment tank water level
    _fetchSchedules();
    _startScheduleTimer();
    _fetchLightingSchedules();
    _fetchPHData();


    // Add listeners for pH range values
    _database.child('settings/lowerPHRange').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _lowerPHRange = double.parse(event.snapshot.value.toString());
        });
      }
    });

    _database.child('settings/upperPHRange').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _upperPHRange = double.parse(event.snapshot.value.toString());
        });
      }
    });

    // Enhanced pH monitoring to trigger dosing and circulation
    _database.child('sensors/ph').onValue.listen((event) {
      if (event.snapshot.value != null && _automaticPHControl) {
        final currentPH = double.parse(event.snapshot.value.toString());

        // If pH is higher than the upper range, activate dosing pump
        if (currentPH > _upperPHRange) {
          _activateDosingPumpSequence();
          _activateDualTankCirculation();
        }
      }
    });
  }

//then the functions and the rest of the code
  // Fetch water level from Firebase path "sensors/ultra3"
  void _fetchWaterLevel() {
    _database
        .child('sensors/ultra3')
        .onValue
        .listen((event) {
      final data = event.snapshot.value as num?;
      if (data != null) {
        setState(() {
          _waterLevelCm = data.toDouble(); // Update water level from Firebase
        });
      }
    });
  }

  /// Fetch pH Container Liquid Level from `sensors/ultra1`
  void _fetchPHContainerLevel() {
    _database
        .child('sensors/ultra2')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          _pHContainerLevelCm = (data as num).toDouble();
        });
      }
    });
  }

  void _fetchTreatmentWaterLevel() {
    _database
        .child('sensors/ultra1')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          _treatmentWaterLevelCm = (data as num).toDouble();
        });
      }
    });
  }

  // Updated method to fetch pump status from Firebase
  void _fetchPumpStatus() {
    // Listen to changes in pump1 (main tank) and pump2 (treatment tank)
    _database
        .child('pumps/pump1')
        .onValue
        .listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          aquariumPumpOn = data == 1; // If value is 1, pump is ON, else OFF
        });
      }
    });

    _database
        .child('pumps/pump2')
        .onValue
        .listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          treatmentPumpOn = data == 1; // If value is 1, pump is ON, else OFF
        });
      }
    });

    // Listen to filter pump status
    _database
        .child('pumps/filterpump2')
        .onValue
        .listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          filterPumpOn = data == 1; // If value is 1, pump is ON, else OFF
        });
      }
    });
  }

  void _togglePump(String pump, bool status) {
    // Convert the boolean status into 1 or 0 (ON or OFF)
    int pumpStatus = status ? 1 : 0;
    _database.child('pumps/$pump').set(
        pumpStatus); // Save the status to Firebase
  }

// Modify the _fetchLightStatus method to also get the override status:
  void _fetchLightStatus() {
    _database
        .child('lights')
        .onValue
        .listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          _lightOn = data == 1; // If value is 1, light is ON, else OFF
        });
      }
    });

    // Also fetch manual override status
    _database
        .child('settings/light_manual_override')
        .onValue
        .listen((event) {
      final data = event.snapshot.value as bool?;
      if (data != null) {
        setState(() {
          _lightManualOverride = data;
        });
      }
    });
  }


// Update the _toggleLight method to include manual override:
  void _toggleLight(bool status, bool isManual) {
    // Convert boolean to 1 (ON) or 0 (OFF)
    int lightStatus = status ? 1 : 0;

    // Update Firebase with new light status
    _database.child('lights').set(lightStatus).then((_) {
      setState(() {
        _lightOn = status; // Update UI immediately
      });

      // If this is a manual toggle, set the manual override flag
      if (isManual) {
        setState(() {
          _lightManualOverride = true;
        });

        // Save override status to Firebase
        _database.child('settings/light_manual_override').set(true);

        String actionText = status ? "turned ON" : "turned OFF";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Light manually $actionText. Schedule paused."),
            backgroundColor: status ? Colors.green : Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }


  void _updateInterval(String type, int value) {
    _database.child('settings').update({type: value});
  }

  void dispose() {
    _schedulerTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

// Update _startScheduleTimer to also check for midnight reset
  void _startScheduleTimer() {
    // Cancel any existing timer
    _schedulerTimer?.cancel();

    // Create a new timer that fires every minute
    _schedulerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkScheduledTimes();
      _checkMidnightReset(); // Add midnight reset check
    });

    // Also check immediately when the app starts
    _checkScheduledTimes();
  }


  // Check if current time matches any scheduled time
  void _checkScheduledTimes() {
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute
        .toString().padLeft(2, '0')}';

    // Only proceed if the scheduled time matches and no manual override is in effect
    if (_dualCirculationTimes.contains(currentTime) && !_manualOverride) {
      print(
          'Scheduled time matched: $currentTime - Activating dual circulation');

      // Only activate if not already active
      if (!_dualTankCirculation) {
        setState(() {
          _dualTankCirculation = true;
        });

        _database.child('settings').update({'dual_tank_circulation': true});

        _togglePump('pump1', true); // Main tank pump
        _togglePump('pump2', true); // Treatment tank pump
        _togglePump('filterpump2', true); // Filter pump

        // Schedule a timer to turn off after the specified duration
        Timer(Duration(minutes: _circulationDuration), () {
          setState(() {
            _dualTankCirculation = false;
            // Reset the manual override after the scheduled cycle completes.
            _manualOverride = false;
          });

          _database.child('settings').update({'dual_tank_circulation': false});

          _togglePump('pump1', false);
          _togglePump('pump2', false);
          _togglePump('filterpump2', false);

          print('Scheduled circulation completed - turning off');
        });
      }
    }

    _checkLightSchedule();
  }

  // Update the _checkLightSchedule method to respect manual override:
  void _checkLightSchedule() {
    // If manual override is active, don't change light status based on schedule
    if (_lightManualOverride) {
      return;
    }

    final now = DateTime.now();
    final currentTimeString = '${now.hour.toString().padLeft(2, '0')}:${now
        .minute.toString().padLeft(2, '0')}';

    bool shouldLightBeOn = false;

    for (var schedule in _lightingSchedules) {
      final startTime = schedule['startTime'] ?? '';
      final endTime = schedule['endTime'] ?? '';

      // Convert times to minutes since midnight
      final startMinutes = _timeStringToMinutes(startTime);
      final endMinutes = _timeStringToMinutes(endTime);
      final currentMinutes = _timeStringToMinutes(currentTimeString);

      // Handle time comparisons using numerical values
      if (startMinutes <= currentMinutes && currentMinutes <= endMinutes) {
        shouldLightBeOn = true;
        break;
      }
    }

    // Only change if needed (and not manually overridden)
    if (shouldLightBeOn != _lightOn) {
      _toggleLight(shouldLightBeOn,
          false); // Pass false to indicate schedule-based change
    }
  }


  // Add a method to reset manual override at end of day (midnight)
  void _checkMidnightReset() {
    final now = DateTime.now();

    // If it's midnight (00:00), reset the manual override
    if (now.hour == 0 && now.minute == 0) {
      if (_lightManualOverride) {
        setState(() {
          _lightManualOverride = false;
        });
        _database.child('settings/light_manual_override').set(false);
      }
    }
  }

  int _timeStringToMinutes(String timeString) {
    if (timeString.isEmpty || !timeString.contains(':')) return 0;

    final parts = timeString.split(':');
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    return hours * 60 + minutes;
  }


  void _fetchPHData() {
    // Listen for aquarium pH sensor data
    _database.child('sensors/ph2').onValue.listen((event) {
      final data = event.snapshot.value as num?;
      if (data != null) {
        setState(() {
          aquariumPh = data.toDouble();
        });
      }
    });

    // Fetch the pH range settings
    _database.child('settings/lowerPHRange').once().then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        setState(() {
          _lowerPHRange = double.parse(event.snapshot.value.toString());
        });
      }
    });

    _database.child('settings/upperPHRange').once().then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        setState(() {
          _upperPHRange = double.parse(event.snapshot.value.toString());
        });
      }
    });

    // Listen for pH range setting changes
    _database.child('settings/lowerPHRange').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _lowerPHRange = double.parse(event.snapshot.value.toString());
        });
      }
    });

    _database.child('settings/upperPHRange').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _upperPHRange = double.parse(event.snapshot.value.toString());
        });
      }
    });

    // Listen for pH changes to trigger dosing and circulation when in automatic mode
    _database.child('sensors/ph2').onValue.listen((event) {
      if (event.snapshot.value != null && _automaticPHControl) {
        final currentPH = double.parse(event.snapshot.value.toString());

        // If pH is higher than the upper range, activate dosing pump and circulation
        if (currentPH > _upperPHRange) {
          _activateDosingPumpSequence();
          _activateDualTankCirculation();
        }
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD4F1E8),
      body: Stack(
        children: [
          _buildBubbleLayout(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildMainSection(),
                        const SizedBox(height: 30),
                        _buildOtherSection(),
                        const SizedBox(height: 30),
                        _buildPHSection(),
                        const SizedBox(height: 30),
                        _buildScheduleSection(),
                      ],
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              "Control Panel",
              style: TextStyle(
                fontSize: 28,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w900,
                color: Color(0xFF0A2A71),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.notifications, size: 30,
                  color: Color(0xFF0A2A71)),
              onPressed: () {}, // Implement notification modal
            ),
          ],
        ),
        _buildBackButton(context),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51), // 0.2 * 255 ≈ 51

            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back, size: 24, color: Color(0xFF0A2A71)),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildBubbleLayout() {
    return Stack(
      children: [
        Positioned(top: 50, left: -30, child: _buildBubble(120)),
        Positioned(top: 250, right: -40, child: _buildBubble(180)),
        Positioned(bottom: 100, left: -50, child: _buildBubble(200)),
        Positioned(bottom: 30, right: -60, child: _buildBubble(150)),
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


  /// MAIN SECTION
  Widget _buildMainSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Main"),
        Center(
          child: Container(
            width: 450,
            height: 650, // Adjusted for arrows
            decoration: BoxDecoration(
              color: Colors.teal[400],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [

                    /// Dual Tank Circulation Row
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 20, left: 20, right: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Dual Tank Circulation",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          _buildDualTankToggle(), // Uses your existing toggle
                        ],
                      ),
                    ),

                    const SizedBox(height: 20), // Spacing

                    /// Aquarium Tank
                    _buildAquariumTank(),

                    const SizedBox(height: 20), // Increased spacing for arrow

                    /// pH Container
                    _buildPHContainer(context),

                    const SizedBox(height: 20), // Increased spacing for arrow

                    /// Treatment Tank
                    _buildTreatmentTank(),
                  ],
                ),

                /// Left Arrow (Aquarium → Treatment)
                Positioned(
                  left: 40,
                  top: 300, // Positioning between Aquarium and Treatment
                  child: _buildArrow(isLeft: true),
                ),

                /// Right Arrow (Treatment → Aquarium)
                Positioned(
                  right: 40,
                  top: 300, // Positioning between Treatment and Aquarium
                  child: _buildArrow(isLeft: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  /// AQUARIUM TANK WIDGET
  Widget _buildAquariumTank() {
    double maxTankHeight = 150.0; // Maximum tank height in UI
    double maxWaterLevel = 30.0; // Maximum water level in cm
    double waterHeight = (_waterLevelCm / maxWaterLevel) *
        maxTankHeight; // Scaled height

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Aquarium Tank Border
            Container(
              width: 280,
              height: maxTankHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(10),
                color: Colors.transparent,
              ),
            ),

// Modify the Horizontal Light widget in _buildAquariumTank():
            Positioned(
              top: 10,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  // Toggle light state (pass true to indicate manual toggle)
                  _toggleLight(!_lightOn, true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _lightOn ? Colors.yellow : Colors.grey[600],
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: _lightOn
                        ? [
                      BoxShadow(
                        color: Colors.yellow.withAlpha(178),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                        : [],
                  ),
                ),
              ),
            ),

            // Water Level (Animated)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 280,
              height: waterHeight.clamp(0, maxTankHeight),
              // Ensures water stays within the tank
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(178),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10), // Spacing

        // Water Level CM Display
        Text(
          "${_waterLevelCm.toStringAsFixed(1)} cm", // Display water level
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// pH CONTAINER WIDGET
  Widget _buildPHContainer(BuildContext context) {
    double maxContainerHeight = 100.0; // Maximum UI height
    double minLevel = 0.0,
        maxLevel = 20.0; // Min & max container level (adjust as needed)

    // Calculate liquid height based on `_pHContainerLevelCm`
    double liquidHeight = ((_pHContainerLevelCm - minLevel) /
        (maxLevel - minLevel)) * maxContainerHeight;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Container Border
            Container(
              width: 60,
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
              width: 60,
              height: liquidHeight.clamp(10, maxContainerHeight),
              // Ensure within bounds
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(204),
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            // Down Arrow Button
            Positioned(
              top: 30,
              child: GestureDetector(
                onTap: () => _showPHDecreaseConfirmation(context),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_downward,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10), // Spacing

        // Display Liquid Level
        Text(
          "${_pHContainerLevelCm.toStringAsFixed(1)} cm",
          // Display actual level
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// SHOW CONFIRMATION MODAL FOR LOWERING pH
  void _showPHDecreaseConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Text(
            "Decrease pH Level",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
              "Are you sure you want to decrease the pH level?"),
          actions: [
            // Cancel Button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the modal
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),

            // OK Button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the modal
                _decreasePHLevel(); // Call function to decrease pH
              },
              child: const Text("OK", style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// FUNCTION TO DECREASE pH LEVEL AND ACTIVATE DOSING PUMP
  void _decreasePHLevel() {
    // Activate the dosing pump
    _database.child('pumps/dosingpump').set(1).then((_) {
      // Set UI state
      setState(() {
        _dosingPumpOn = true;
      });

      // After 1 second, turn it off
      Future.delayed(const Duration(seconds: 1), () {
        _database.child('pumps/dosingpump').set(0);
        setState(() {
          _dosingPumpOn = false;
          _pHContainerLevelCm = (_pHContainerLevelCm - 0.25).clamp(0.0, 20.0); // Simulated decrease
        });
      });
    });
  }

  /// TREATMENT TANK WIDGET
  Widget _buildTreatmentTank() {
    double maxTankHeight = 150.0; // Maximum tank height in UI
    double maxWaterLevel = 30.0; // Maximum water level in cm
    double waterHeight = (_treatmentWaterLevelCm / maxWaterLevel) *
        maxTankHeight; // Scaled height

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Treatment Tank Border
            Container(
              width: 180,
              height: maxTankHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(10),
                color: Colors.transparent,
              ),
            ),

            // Water Level (Animated)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 180,
              height: waterHeight.clamp(0, maxTankHeight),
              // Ensures water stays within the tank
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(178),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10), // Spacing

        // Water Level CM Display
        Text(
          "${_treatmentWaterLevelCm.toStringAsFixed(1)} cm",
          // Display water level
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// DUAL TANK CIRCULATION TOGGLE
  /// DUAL TANK CIRCULATION TOGGLE
  Widget _buildDualTankToggle() {
    return GestureDetector(
      onTap: () {
        if (_dualTankCirculation) {
          // Manual override: turn the circulation off and prevent scheduled reactivation.
          setState(() {
            _dualTankCirculation = false;
            _manualOverride = true;
          });

          _database.child('settings').update({'dual_tank_circulation': false});

          _togglePump('pump1', false);
          _togglePump('pump2', false);
          _togglePump('filterpump2', false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Dual Tank Circulation manually turned off"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // If turning it on manually, reset any manual override flag.
          setState(() {
            _dualTankCirculation = true;
            _manualOverride = false;
          });

          _database.child('settings').update({'dual_tank_circulation': true});

          _togglePump('pump1', true);
          _togglePump('pump2', true);
          _togglePump('filterpump2', true);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _dualTankCirculation ? Colors.blue : Colors.grey[400],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: _dualTankCirculation
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.recycling,
                  color: _dualTankCirculation ? Colors.blue : Colors.grey[600],
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// FUNCTION TO BUILD ARROWS (Thick and Light-up Effect)
  Widget _buildArrow({required bool isLeft}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Icon(
        isLeft ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
        size: 50, // Thick arrow
        color: _dualTankCirculation ? Colors.yellow : Colors.white.withAlpha(
            128), // Lights up when ON

      ),
    );
  }


  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2A71),
            ),
          ),
          GestureDetector(
            onTap: () {
              _showInfoModal(title);
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }


  void _showInfoModal(String section) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$section Info', style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          content: Text(
            section == "Main"
                ? "This section contains core functionalities of the system."
                : "This section provides additional system settings and controls.",
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOtherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Pumps"),
        Center(
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.teal[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [

                _buildSwitchRow("Aquarium Pump:", aquariumPumpOn, (value) {
                  setState(() {
                    aquariumPumpOn = value;
                  });
                  _togglePump("pump1", value); // Update the main tank pump
                }),
                _buildSwitchRow("Treatment Pump:", treatmentPumpOn, (value) {
                  setState(() {
                    treatmentPumpOn = value;
                  });
                  _togglePump("pump2", value); // Update the treatment tank pump
                }),
                _buildSwitchRow("Filter Pump:", filterPumpOn, (value) {
                  setState(() {
                    filterPumpOn = value;
                  });
                  _togglePump("filterpump", value); // Update the filter pump
                }),

                const SizedBox(height: 15), // Space before dropdowns

                // Recycling Interval Dropdown

                const SizedBox(height: 5),

                // Lighting Interval Dropdown

              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPHSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("pH Control"),
        Center(
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.teal[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Auto/Manual toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("pH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _automaticPHControl = !_automaticPHControl;
                        });
                        _database.child('settings/pHControlMode').set(_automaticPHControl ? "auto" : "manual");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _automaticPHControl ? Colors.green : Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        _automaticPHControl ? "Automatic" : "Manual",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // pH Meter
                _buildPHMeter(),
                const SizedBox(height: 15),

                // Automatic mode controls
                if (_automaticPHControl) ...[
                  _buildInfoRow("Aquarium pH:", aquariumPh.toStringAsFixed(2)),
                  _buildPHRangeRow(),
                  _buildInfoRow("Next dose:", _nextDoseTime != null
                      ? "${_nextDoseTime!.day}/${_nextDoseTime!.month} ${_nextDoseTime!.hour}:${_nextDoseTime!.minute.toString().padLeft(2, '0')}"
                      : "Not scheduled"),
                  _buildInfoRow("Pump status:", _dosingPumpOn ? "ON" : "OFF"),
                ]
                // Manual mode controls
                else ...[
                  _buildManualPHControls(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPHMeter() {
    // Calculate actual width of the meter component
    final meterWidth = 400.0; // Adjust based on your container width minus padding

    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          // pH scale indicators
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(11, (index) {
                final ph = 4.0 + (index * 0.6); // Scale from 4.0 to 10.0
                return Container(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    ph.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              }),
            ),
          ),

          // Current pH indicator - fixed positioning
          if (aquariumPh >= 4.0 && aquariumPh <= 10.0)
            Positioned(
              left: ((aquariumPh - 4.0) / 6.0 * meterWidth).clamp(0.0, meterWidth),
              child: Container(
                height: 50,
                width: 3,
                color: Colors.black,
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.arrow_drop_down, color: Colors.black),
                ),
              ),
            ),

          // Lower pH range indicator
          if (_lowerPHRange >= 4.0 && _lowerPHRange <= 10.0)
            Positioned(
              left: ((_lowerPHRange - 4.0) / 6.0 * meterWidth).clamp(0.0, meterWidth),
              child: Container(
                height: 50,
                width: 3,
                color: Colors.white,
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.arrow_drop_down, color: Colors.white),
                ),
              ),
            ),

          // Upper pH range indicator
          if (_upperPHRange >= 4.0 && _upperPHRange <= 10.0)
            Positioned(
              left: ((_upperPHRange - 4.0) / 6.0 * meterWidth).clamp(0.0, meterWidth),
              child: Container(
                height: 50,
                width: 3,
                color: Colors.white,
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.arrow_drop_down, color: Colors.white),
                ),
              ),
            ),

          // pH range shaded area
          if (_lowerPHRange >= 4.0 && _upperPHRange <= 10.0)
            Positioned(
              left: ((_lowerPHRange - 4.0) / 6.0 * meterWidth).clamp(0.0, meterWidth),
              child: Container(
                height: 50,
                width: (((_upperPHRange - _lowerPHRange) / 6.0) * meterWidth).clamp(0.0, meterWidth),
                color: Colors.white.withOpacity(0.3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPHRangeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("pH Range:", style: TextStyle(fontSize: 16)),
          InkWell(
            onTap: () {
              _showPHRangeDialog();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Text(
                "${_lowerPHRange.toStringAsFixed(2)} - ${_upperPHRange.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 16, color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPHRangeDialog() {
    TextEditingController lowerController = TextEditingController(text: _lowerPHRange.toString());
    TextEditingController upperController = TextEditingController(text: _upperPHRange.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set pH Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lowerController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Lower pH (6.0-8.5)',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: upperController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Upper pH (6.5-9.0)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final lowerValue = double.tryParse(lowerController.text);
              final upperValue = double.tryParse(upperController.text);

              if (lowerValue != null && upperValue != null &&
                  lowerValue >= 6.0 && lowerValue <= 8.5 &&
                  upperValue >= 6.5 && upperValue <= 9.0 &&
                  lowerValue < upperValue) {
                setState(() {
                  _lowerPHRange = lowerValue;
                  _upperPHRange = upperValue;
                });
                _database.child('settings/lowerPHRange').set(lowerValue);
                _database.child('settings/upperPHRange').set(upperValue);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid pH values between 6.0-9.0 with lower < upper')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }


  void _activateDosingPumpSequence() {
    // Activate dosing pump 4 times with 5 second gap
    _decreasePHLevel();

    Future.delayed(const Duration(seconds: 5), () {
      _decreasePHLevel();

      Future.delayed(const Duration(seconds: 5), () {
        _decreasePHLevel();

        Future.delayed(const Duration(seconds: 5), () {
          _decreasePHLevel();
        });
      });
    });
  }

  void _activateDualTankCirculation() {
    // Cancel any existing timer
    _circulationTimer?.cancel();

    // Turn on circulation
    setState(() {
      _dualTankCirculation = true;
      _manualOverride = false;
    });

    _database.child('settings').update({'dual_tank_circulation': true});
    _togglePump('pump1', true);
    _togglePump('pump2', true);
    _togglePump('filterpump2', true);

    // Set timer to turn off after 3 minutes
    _circulationTimer = Timer(const Duration(minutes: 3), () {
      setState(() {
        _dualTankCirculation = false;
      });

      _database.child('settings').update({'dual_tank_circulation': false});
      _togglePump('pump1', false);
      _togglePump('pump2', false);
      _togglePump('filterpump2', false);
    });
  }


  Widget _buildManualPHControls() {
    return Column(
      children: [
        // Display current pH
        _buildInfoRow("Aquarium pH:", aquariumPh.toStringAsFixed(2)),

        // Display pump status
        _buildInfoRow("Dosing Pump:", _dosingPumpOn ? "ON" : "OFF"),

        const SizedBox(height: 15),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                _showDosingConfirmationDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[300],
              ),
              child: const Text("Lower pH"),
            ),

          ],
        ),
      ],
    );
  }

  void _showDosingConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm pH Dosing'),
        content: const Text('Are you sure you want to dose 10ml of pH down solution?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Show a confirmation message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dosing sequence initiated (4 doses with 5-second intervals)')),
                );

                // Use the same dosing sequence as automatic mode
                _activateDosingPumpSequence();
                _activateDualTankCirculation();
              },
              child: const Text('Confirm')
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool isOn, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 200,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Switch(
          value: isOn,
          onChanged: onChanged,
          activeColor: Colors.green,
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.grey[300],
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Schedule"),
        Center(
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.teal[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Dual Circulation Row with Add Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Dual Circulation",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                      onPressed: () => _showAddTimeModal(context),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Times and Duration Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Times with Show All button
                    Row(
                      children: [
                        const Text(
                          "Times: ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showAllTimesModal(context),
                          child: const Text(
                            "Show All",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Duration input field
                    Row(
                      children: [
                        const Text(
                          "Duration: ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          height: 40,
                          child: TextField(
                            controller: TextEditingController(
                                text: _circulationDuration.toString()),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixText: 'min',
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                setState(() {
                                  _circulationDuration = int.parse(value);
                                });
                                _database
                                    .child('settings/circulation_duration')
                                    .set(_circulationDuration);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // Set Lighting Row with Add Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Set Lighting",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                      onPressed: () => _showAddLightingScheduleModal(context),
                    ),
                  ],
                ),

                // Manual Override Status (below Set Lighting)
                if (_lightManualOverride) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Manual Override Active",
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _lightManualOverride = false;
                          });
                          _database
                              .child('settings/light_manual_override')
                              .set(false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Schedule resumed"),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Text(
                          "Resume Schedule",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 15),

                // Lighting Times Row
                Row(
                  children: [
                    const Text(
                      "Times: ",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showAllLightingSchedulesModal(context),
                      child: const Text(
                        "Show All",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }



// Improved Add Time Modal with debugging to identify why times aren't being added
  void _showAddTimeModal(BuildContext context) {
    // Start with current time
    TimeOfDay selectedTime = TimeOfDay.now();
    // State variable to track if user has selected a time
    bool hasSelectedTime = false;

    showDialog(
      context: context,
      builder: (context) {
        // Using StatefulBuilder to update dialog content when time changes
        return StatefulBuilder(
            builder: (context, setDialogState) {
              // Format time for display
              String timeText = hasSelectedTime
                  ? '${selectedTime.hour.toString().padLeft(
                  2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'
                  : '${TimeOfDay
                  .now()
                  .hour
                  .toString()
                  .padLeft(2, '0')}:${TimeOfDay
                  .now()
                  .minute
                  .toString()
                  .padLeft(2, '0')}';

              return AlertDialog(
                title: const Text(
                  'Add Circulation Time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Select time to start dual circulation:'),
                    const SizedBox(height: 20),

                    // Display selected time prominently
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 30),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.teal),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.teal.withOpacity(0.1),
                      ),
                      child: Text(
                        timeText,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: () async {
                        final TimeOfDay? timeOfDay = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Colors.teal,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (timeOfDay != null) {
                          // Update the time in the dialog
                          setDialogState(() {
                            selectedTime = timeOfDay;
                            hasSelectedTime = true;
                          });
                        }
                      },
                      child: const Text(
                          'Select Time', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                        'Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () {
                      // Format the time to HH:MM format
                      final String formattedTime =
                          '${selectedTime.hour.toString().padLeft(
                          2, '0')}:${selectedTime.minute.toString().padLeft(
                          2, '0')}';

                      // Create a copy of the current list and add the new time
                      List<String> updatedTimes = List<String>.from(
                          _dualCirculationTimes);
                      updatedTimes.add(formattedTime);

                      // Update the state with the new list
                      setState(() {
                        _dualCirculationTimes = updatedTimes;
                      });


                      // Save to Firebase
                      _database.child('schedules/dual_circulation').set(
                          _dualCirculationTimes)
                          .then((_) {
                        // Show confirmation that the time was added
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Time $formattedTime added to schedule'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      })
                          .catchError((error) {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving schedule: $error'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      });

                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Add',
                      style: TextStyle(
                          color: Colors.teal, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            }
        );
      },
    );
  }

// Show All Times Modal
  void _showAllTimesModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Scheduled Times',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),


          content: SizedBox(
            width: 300,
            height: 300,
            child: _dualCirculationTimes.isEmpty
                ? const Center(
              child: Text(
                "No scheduled times yet",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
                : ListView.builder(
              itemCount: _dualCirculationTimes.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white, // Optional: set a background color
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_dualCirculationTimes[index]),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _dualCirculationTimes.removeAt(index);
                          });
                          // Update Firebase
                          _database.child('schedules/dual_circulation').set(
                              _dualCirculationTimes);
                          Navigator.of(context).pop();
                          // Reopen the modal to show updated list
                          _showAllTimesModal(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

          ),
        );
      },
    );
  }

// Also check your _fetchSchedules method for issues
  void _fetchSchedules() {
    _database
        .child('schedules/dual_circulation')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        try {
          List<String> times = [];

          if (data is List) {
            // Handle list format
            for (var item in data) {
              if (item != null) {
                times.add(item.toString());
              }
            }
          } else if (data is Map) {
            // Handle map format
            data.values.forEach((value) {
              if (value != null) {
                times.add(value.toString());
              }
            });
          }


          setState(() {
            _dualCirculationTimes = times;
          });
        } catch (e) {

        }
      } else {
        // Initialize with empty list if no data
        setState(() {
          _dualCirculationTimes = [];
        });
      }
    });

    _database
        .child('settings/circulation_duration')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          _circulationDuration = (data as num).toInt();
        });
      }
    });
  }

  // Add this after _fetchSchedules() method in your class:
  void _fetchLightingSchedules() {
    _database
        .child('schedules/lighting')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        try {
          List<Map<String, String>> schedules = [];

          if (data is List) {
            for (var item in data) {
              if (item != null && item is Map) {
                schedules.add({
                  'startTime': item['startTime'].toString(),
                  'endTime': item['endTime'].toString(),
                });
              }
            }
          } else if (data is Map) {
            data.forEach((key, value) {
              if (value != null && value is Map) {
                schedules.add({
                  'startTime': value['startTime'].toString(),
                  'endTime': value['endTime'].toString(),
                });
              }
            });
          }

          setState(() {
            _lightingSchedules = schedules;
          });
        } catch (e) {
          print("Error parsing lighting schedules: $e");
        }
      } else {
        setState(() {
          _lightingSchedules = [];
        });
      }
    });
  }

// Add these new methods for lighting schedule modals:
  void _showAddLightingScheduleModal(BuildContext context) {
    // Start with current time for both start and end
    TimeOfDay startTime = TimeOfDay.now();
    // End time 12 hours after start time by default
    TimeOfDay endTime = TimeOfDay(
      hour: (startTime.hour + 12) % 24,
      minute: startTime.minute,
    );

    bool hasSelectedStartTime = false;
    bool hasSelectedEndTime = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              // Format times for display
              String startTimeText = hasSelectedStartTime
                  ? '${startTime.hour.toString().padLeft(2, '0')}:${startTime
                  .minute.toString().padLeft(2, '0')}'
                  : '${TimeOfDay
                  .now()
                  .hour
                  .toString()
                  .padLeft(2, '0')}:${TimeOfDay
                  .now()
                  .minute
                  .toString()
                  .padLeft(2, '0')}';

              String endTimeText = hasSelectedEndTime
                  ? '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute
                  .toString().padLeft(2, '0')}'
                  : '${(TimeOfDay
                  .now()
                  .hour + 12) % 24}:${TimeOfDay
                  .now()
                  .minute
                  .toString()
                  .padLeft(2, '0')}';

              return AlertDialog(
                title: const Text(
                  'Add Lighting Schedule',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Set when lights should turn ON and OFF:'),
                    const SizedBox(height: 20),

                    // Start Time Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Lights ON:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.amber),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.amber.withOpacity(0.1),
                          ),
                          child: Text(
                            startTimeText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                              Icons.access_time, color: Colors.amber),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Colors.amber,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (picked != null) {
                              setDialogState(() {
                                startTime = picked;
                                hasSelectedStartTime = true;
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // End Time Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Lights OFF:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.indigo),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.indigo.withOpacity(0.1),
                          ),
                          child: Text(
                            endTimeText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                              Icons.access_time, color: Colors.indigo),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Colors.indigo,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (picked != null) {
                              setDialogState(() {
                                endTime = picked;
                                hasSelectedEndTime = true;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                        'Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // Format the times to HH:MM format
                      final String formattedStartTime =
                          '${startTime.hour.toString().padLeft(
                          2, '0')}:${startTime.minute.toString().padLeft(
                          2, '0')}';
                      final String formattedEndTime =
                          '${endTime.hour.toString().padLeft(2, '0')}:${endTime
                          .minute.toString().padLeft(2, '0')}';

                      // Create a copy and add the new schedule
                      List<Map<String, String>> updatedSchedules = List<
                          Map<String, String>>.from(_lightingSchedules);
                      updatedSchedules.add({
                        'startTime': formattedStartTime,
                        'endTime': formattedEndTime,
                      });

                      // Update state
                      setState(() {
                        _lightingSchedules = updatedSchedules;
                      });

                      // Save to Firebase
                      _database.child('schedules/lighting').set(
                          _lightingSchedules)
                          .then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Lighting schedule added: ON at $formattedStartTime, OFF at $formattedEndTime'),
                            backgroundColor: Colors.amber,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      })
                          .catchError((error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving schedule: $error'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      });

                      Navigator.of(context).pop();
                    },
                    child: const Text('Add Schedule'),
                  ),
                ],
              );
            }
        );
      },
    );
  }

// Update the schedules display to show active status
  void _showAllLightingSchedulesModal(BuildContext context) {
    // Get current time in minutes for comparison
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Lighting Schedules',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            height: 300,
            child: Column(
              children: [
                // Show manual override status if active
                if (_lightManualOverride)
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange)
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Manual override active. Schedules paused.",
                            style: TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _lightManualOverride = false;
                            });
                            _database.child('settings/light_manual_override')
                                .set(false);
                            Navigator.of(context).pop();
                            _showAllLightingSchedulesModal(context);
                          },
                          child: Text("Resume", style: TextStyle(
                              color: Colors.blue)),
                        )
                      ],
                    ),
                  ),

                Expanded(
                  child: _lightingSchedules.isEmpty
                      ? const Center(
                    child: Text(
                      "No lighting schedules yet",
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                      : ListView.builder(
                    itemCount: _lightingSchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _lightingSchedules[index];
                      final startTime = schedule['startTime'] ?? '';
                      final endTime = schedule['endTime'] ?? '';

                      // Check if this schedule is currently active
                      final startMinutes = _timeStringToMinutes(startTime);
                      final endMinutes = _timeStringToMinutes(endTime);
                      final isActive = !_lightManualOverride &&
                          startMinutes <= currentMinutes &&
                          currentMinutes <= endMinutes;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12,
                            vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: isActive ? Colors.green : Colors.amber
                                  .withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(8),
                          color: isActive
                              ? Colors.green.withOpacity(0.1)
                              : Colors.amber.withOpacity(0.1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb,
                                color: isActive ? Colors.green : Colors.amber),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ON: $startTime\nOFF: $endTime',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  if (isActive)
                                    Container(
                                      margin: EdgeInsets.only(top: 4),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "Active Now",
                                        style: TextStyle(
                                            color: Colors.green[800],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _lightingSchedules.removeAt(index);
                                });
                                // Update Firebase
                                _database.child('schedules/lighting').set(
                                    _lightingSchedules);
                                Navigator.of(context).pop();
                                // Reopen the modal to show updated list
                                _showAllLightingSchedulesModal(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}