import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MedicineDispenserApp());
}

class MedicineDispenserApp extends StatelessWidget {
  const MedicineDispenserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicine Dispenser',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
// home page
class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const UserMedicineManager(),
    const InventoryPage(),
    const PatientListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Users"),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: "Inventory",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: "Patients",
          ),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}

class UserMedicineManager extends StatefulWidget {
  const UserMedicineManager({super.key});

  @override
  State<UserMedicineManager> createState() => UserMedicineManagerState();
}

class UserMedicineManagerState extends State<UserMedicineManager> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("users");
  final DatabaseReference _invRef = FirebaseDatabase.instance.ref("inventory");

  Map<String, dynamic> usersData = {};
  Map<String, dynamic> inventoryData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
    fetchInventory();
  }

  void fetchUsers() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      setState(() {
        usersData = Map<String, dynamic>.from(snapshot.value as Map);
        isLoading = false;
      });
    }
  }

  void fetchInventory() async {
    final snapshot = await _invRef.get();
    if (snapshot.exists) {
      inventoryData = Map<String, dynamic>.from(snapshot.value as Map);
    }
  }

  void updateMedicines(String userId, List<String> newMedicines) async {
    for (String med in newMedicines) {
      final currentCount = inventoryData[med];
      if (currentCount != null && currentCount > 0) {
        inventoryData[med] = currentCount - 1;
        await _invRef.child(med).set(inventoryData[med]);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("⚠ '$med' is out of stock!")));
        }
      }
    }
    await _dbRef.child("$userId/medicines").set(newMedicines);
    fetchUsers();
  }

  void showMedicineEditor(String userId, List<dynamic> currentMeds) {
    final TextEditingController medController = TextEditingController();
    List<String> updatedMeds = List<String>.from(currentMeds);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Edit Medicines"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var med in updatedMeds)
                ListTile(
                  title: Text(med),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        updatedMeds.remove(med);
                      });
                      Navigator.of(context).pop();
                      showMedicineEditor(userId, updatedMeds);
                    },
                  ),
                ),
              TextField(
                controller: medController,
                decoration: const InputDecoration(
                  labelText: "Add new medicine",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (medController.text.trim().isNotEmpty) {
                  updatedMeds.add(medController.text.trim());
                }
                updateMedicines(userId, updatedMeds);
                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage User Medicines")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: usersData.length,
                itemBuilder: (context, index) {
                  final userId = usersData.keys.elementAt(index);
                  final user = usersData[userId];
                  final name = user['name'] ?? 'Unnamed';
                  final uid = user['uid'] ?? '';
                  final List<dynamic> medicines = user['medicines'] ?? [];

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("UID: $uid"),
                          Text("Medicines: ${medicines.join(", ")}"),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => showMedicineEditor(userId, medicines),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final DatabaseReference _invRef = FirebaseDatabase.instance.ref("inventory");
  Map<String, dynamic> inventoryData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  void fetchInventory() async {
    final snapshot = await _invRef.get();
    if (snapshot.exists) {
      setState(() {
        inventoryData = Map<String, dynamic>.from(snapshot.value as Map);
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                children:
                    inventoryData.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.key),
                        trailing: Text("Count: ${entry.value}"),
                      );
                    }).toList(),
              ),
    );
  }
}

class PatientListScreen extends StatelessWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference patientsRef = FirebaseDatabase.instance.ref(
      "patients",
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Patients")),
      body: StreamBuilder(
        stream: patientsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final patients = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map,
            );

            return ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patientId = patients.keys.elementAt(index);
                final patient = patients[patientId];
                final name = patient['name'] ?? 'Unknown Patient';

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text("ID: $patientId"),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  PatientProfilePage(patientId: patientId),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return const Center(child: Text("No patients found"));
          }
        },
      ),
    );
  }
}

class PatientProfilePage extends StatefulWidget {
  final String patientId;

  const PatientProfilePage({super.key, required this.patientId});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final DatabaseReference _patientsRef = FirebaseDatabase.instance.ref(
    "patients",
  );
  final DatabaseReference _dispenseHistoryRef = FirebaseDatabase.instance.ref(
    "dispenseHistory",
  );

  Map<String, dynamic>? patientData;
  List<String> medications = [];
  bool isLoading = true;
  bool isEditing = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _nextVisitController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchPatientData();
  }

  void fetchPatientData() async {
    final patientSnapshot = await _patientsRef.child(widget.patientId).get();
    final dispenseSnapshot =
        await _dispenseHistoryRef.child(widget.patientId).get();

    if (mounted) {
      setState(() {
        patientData =
            patientSnapshot.exists
                ? Map<String, dynamic>.from(patientSnapshot.value as Map)
                : null;

        medications =
            dispenseSnapshot.exists
                ? _extractMedications(dispenseSnapshot.value)
                : [];

        _nameController.text = patientData?['name'] ?? '';
        _phoneController.text = patientData?['phone'] ?? '';
        _addressController.text = patientData?['address'] ?? '';
        _allergiesController.text =
            patientData?['allergies'] is List
                ? (patientData?['allergies'] as List).join(", ")
                : patientData?['allergies']?.toString() ?? '';
        _nextVisitController.text = patientData?['nextVisit'] ?? '';
        isLoading = false;
      });
    }
  }

  List<String> _extractMedications(dynamic dispenseData) {
    final List<String> meds = [];

    if (dispenseData is Map) {
      dispenseData.forEach((key, value) {
        if (value is Map && value['medicines'] is List) {
          meds.addAll((value['medicines'] as List).whereType<String>());
        }
      });
    }

    return meds.toSet().toList();
  }

  void toggleEdit() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  void savePatientData() async {
    final updatedData = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'allergies':
          _allergiesController.text.split(',').map((e) => e.trim()).toList(),
      'nextVisit': _nextVisitController.text,
      'diagnosis': _diagnosisController.text,
    };

    await _patientsRef.child(widget.patientId).update(updatedData);

    if (mounted) {
      setState(() {
        isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Patient data updated successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Patient Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (patientData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Patient Profile")),
        body: const Center(child: Text("Patient data not found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Profile"),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: isEditing ? savePatientData : toggleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    patientData!['name'] ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Patient ID: ${widget.patientId}",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Diagnosis",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_diagnosisController.text),
                const SizedBox(height: 8),
                Text(
                  " ${_allergiesController.text.isNotEmpty ? _allergiesController.text : 'None'}",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 30),

            const Text(
              "Medications",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            medications.isEmpty
                ? const Text("No medications dispensed")
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: medications.map((med) => Text("• $med")).toList(),
                ),
            const Divider(height: 30),

            const Text(
              "Upcoming Appointments",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            isEditing
                ? TextField(
                  controller: _nextVisitController,
                  decoration: const InputDecoration(
                    labelText: "Next Visit (YYYY-MM-DD)",
                  ),
                )
                : Text(
                  patientData!['nextVisit']?.isNotEmpty == true
                      ? patientData!['nextVisit']!
                      : "No upcoming appointments",
                ),
            const Divider(height: 30),

            const Text(
              "Contact",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            isEditing
                ? Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Name"),
                    ),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: "Phone"),
                    ),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: "Address"),
                    ),
                  ],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text
                          : 'No name',
                    ),
                    Text(
                      _phoneController.text.isNotEmpty
                          ? _phoneController.text
                          : 'No phone',
                    ),
                    Text(
                      _addressController.text.isNotEmpty
                          ? _addressController.text
                          : 'No address',
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MedicineDispenserApp());
}

class MedicineDispenserApp extends StatelessWidget {
  const MedicineDispenserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicine Dispenser',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const UserMedicineManager(),
    const InventoryPage(),
    const PatientListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Users"),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: "Inventory",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: "Patients",
          ),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}

class UserMedicineManager extends StatefulWidget {
  const UserMedicineManager({super.key});

  @override
  State<UserMedicineManager> createState() => UserMedicineManagerState();
}

class UserMedicineManagerState extends State<UserMedicineManager> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("users");
  final DatabaseReference _invRef = FirebaseDatabase.instance.ref("inventory");

  Map<String, dynamic> usersData = {};
  Map<String, dynamic> inventoryData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
    fetchInventory();
  }

  void fetchUsers() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      setState(() {
        usersData = Map<String, dynamic>.from(snapshot.value as Map);
        isLoading = false;
      });
    }
  }

  void fetchInventory() async {
    final snapshot = await _invRef.get();
    if (snapshot.exists) {
      inventoryData = Map<String, dynamic>.from(snapshot.value as Map);
    }
  }

  void updateMedicines(String userId, List<String> newMedicines) async {
    for (String med in newMedicines) {
      final currentCount = inventoryData[med];
      if (currentCount != null && currentCount > 0) {
        inventoryData[med] = currentCount - 1;
        await _invRef.child(med).set(inventoryData[med]);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("⚠ '$med' is out of stock!")));
        }
      }
    }
    await _dbRef.child("$userId/medicines").set(newMedicines);
    fetchUsers();
  }

  void showMedicineEditor(String userId, List<dynamic> currentMeds) {
    final TextEditingController medController = TextEditingController();
    List<String> updatedMeds = List<String>.from(currentMeds);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Edit Medicines"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var med in updatedMeds)
                ListTile(
                  title: Text(med),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        updatedMeds.remove(med);
                      });
                      Navigator.of(context).pop();
                      showMedicineEditor(userId, updatedMeds);
                    },
                  ),
                ),
              TextField(
                controller: medController,
                decoration: const InputDecoration(
                  labelText: "Add new medicine",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (medController.text.trim().isNotEmpty) {
                  updatedMeds.add(medController.text.trim());
                }
                updateMedicines(userId, updatedMeds);
                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage User Medicines")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: usersData.length,
                itemBuilder: (context, index) {
                  final userId = usersData.keys.elementAt(index);
                  final user = usersData[userId];
                  final name = user['name'] ?? 'Unnamed';
                  final uid = user['uid'] ?? '';
                  final List<dynamic> medicines = user['medicines'] ?? [];

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("UID: $uid"),
                          Text("Medicines: ${medicines.join(", ")}"),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => showMedicineEditor(userId, medicines),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final DatabaseReference _invRef = FirebaseDatabase.instance.ref("inventory");
  Map<String, dynamic> inventoryData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  void fetchInventory() async {
    final snapshot = await _invRef.get();
    if (snapshot.exists) {
      setState(() {
        inventoryData = Map<String, dynamic>.from(snapshot.value as Map);
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                children:
                    inventoryData.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.key),
                        trailing: Text("Count: ${entry.value}"),
                      );
                    }).toList(),
              ),
    );
  }
}

class PatientListScreen extends StatelessWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference patientsRef = FirebaseDatabase.instance.ref(
      "patients",
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Patients")),
      body: StreamBuilder(
        stream: patientsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final patients = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map,
            );

            return ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patientId = patients.keys.elementAt(index);
                final patient = patients[patientId];
                final name = patient['name'] ?? 'Unknown Patient';

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text("ID: $patientId"),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  PatientProfilePage(patientId: patientId),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return const Center(child: Text("No patients found"));
          }
        },
      ),
    );
  }
}

class PatientProfilePage extends StatefulWidget {
  final String patientId;

  const PatientProfilePage({super.key, required this.patientId});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final DatabaseReference _patientsRef = FirebaseDatabase.instance.ref(
    "patients",
  );
  final DatabaseReference _dispenseHistoryRef = FirebaseDatabase.instance.ref(
    "dispenseHistory",
  );

  Map<String, dynamic>? patientData;
  List<String> medications = [];
  bool isLoading = true;
  bool isEditing = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _nextVisitController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchPatientData();
  }

  void fetchPatientData() async {
    final patientSnapshot = await _patientsRef.child(widget.patientId).get();
    final dispenseSnapshot =
        await _dispenseHistoryRef.child(widget.patientId).get();

    if (mounted) {
      setState(() {
        patientData =
            patientSnapshot.exists
                ? Map<String, dynamic>.from(patientSnapshot.value as Map)
                : null;

        medications =
            dispenseSnapshot.exists
                ? _extractMedications(dispenseSnapshot.value)
                : [];

        _nameController.text = patientData?['name'] ?? '';
        _phoneController.text = patientData?['phone'] ?? '';
        _addressController.text = patientData?['address'] ?? '';
        _allergiesController.text =
            patientData?['allergies'] is List
                ? (patientData?['allergies'] as List).join(", ")
                : patientData?['allergies']?.toString() ?? '';
        _nextVisitController.text = patientData?['nextVisit'] ?? '';
        isLoading = false;
      });
    }
  }

  List<String> _extractMedications(dynamic dispenseData) {
    final List<String> meds = [];

    if (dispenseData is Map) {
      dispenseData.forEach((key, value) {
        if (value is Map && value['medicines'] is List) {
          meds.addAll((value['medicines'] as List).whereType<String>());
        }
      });
    }

    return meds.toSet().toList();
  }

  void toggleEdit() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  void savePatientData() async {
    final updatedData = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'allergies':
          _allergiesController.text.split(',').map((e) => e.trim()).toList(),
      'nextVisit': _nextVisitController.text,
      'diagnosis': _diagnosisController.text,
    };

    await _patientsRef.child(widget.patientId).update(updatedData);

    if (mounted) {
      setState(() {
        isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Patient data updated successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Patient Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (patientData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Patient Profile")),
        body: const Center(child: Text("Patient data not found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Profile"),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: isEditing ? savePatientData : toggleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    patientData!['name'] ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Patient ID: ${widget.patientId}",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Diagnosis",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_diagnosisController.text),
                const SizedBox(height: 8),
                Text(
                  " ${_allergiesController.text.isNotEmpty ? _allergiesController.text : 'None'}",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 30),

            const Text(
              "Medications",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            medications.isEmpty
                ? const Text("No medications dispensed")
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: medications.map((med) => Text("• $med")).toList(),
                ),
            const Divider(height: 30),

            const Text(
              "Upcoming Appointments",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            isEditing
                ? TextField(
                  controller: _nextVisitController,
                  decoration: const InputDecoration(
                    labelText: "Next Visit (YYYY-MM-DD)",
                  ),
                )
                : Text(
                  patientData!['nextVisit']?.isNotEmpty == true
                      ? patientData!['nextVisit']!
                      : "No upcoming appointments",
                ),
            const Divider(height: 30),

            const Text(
              "Contact",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            isEditing
                ? Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Name"),
                    ),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: "Phone"),
                    ),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: "Address"),
                    ),
                  ],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text
                          : 'No name',
                    ),
                    Text(
                      _phoneController.text.isNotEmpty
                          ? _phoneController.text
                          : 'No phone',
                    ),
                    Text(
                      _addressController.text.isNotEmpty
                          ? _addressController.text
                          : 'No address',
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}