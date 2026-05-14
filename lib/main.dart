import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appTitle = 'NYER GILLES JEAN BAPTISTE';
const shortAppTitle = 'NYER GILLES OPS';
const supportEmail = 'support@nyergillesjeanbaptiste.com';
const screenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

const _navy = Color(0xFF001029);
const _teal = Color(0xFF2B6B6F);
const _ice = Color(0xFFF4F8F7);
const _amber = Color(0xFFE7B65D);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(store: screenshotMode ? AppStore.sample() : null));
}

class MyApp extends StatelessWidget {
  MyApp({super.key, AppStore? store}) : store = store ?? AppStore();

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: Brightness.light,
      primary: _teal,
      secondary: _amber,
      surface: Colors.white,
    );

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return MaterialApp(
          title: appTitle,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            scaffoldBackgroundColor: _ice,
            appBarTheme: const AppBarTheme(
              backgroundColor: _ice,
              foregroundColor: _navy,
              centerTitle: false,
              titleTextStyle: TextStyle(
                color: _navy,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: _navy.withValues(alpha: 0.08)),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          home: AppShell(store: store),
        );
      },
    );
  }
}

class AppStore extends ChangeNotifier {
  AppStore({this.persistenceEnabled = true});

  factory AppStore.sample() {
    return AppStore(persistenceEnabled: false)
      .._operations = _sampleOperations()
      .._expenses = _sampleExpenses()
      .._loaded = true
      ..compactCards = false
      ..showClosedRecords = true;
  }

  static const _operationsKey = 'operations';
  static const _expensesKey = 'expenses';
  static const _compactKey = 'compact_cards';
  static const _showClosedKey = 'show_closed_records';

  final bool persistenceEnabled;
  SharedPreferences? _prefs;
  bool _loaded = false;
  bool compactCards = false;
  bool showClosedRecords = true;

  List<OperationRecord> _operations = <OperationRecord>[];
  List<ExpenseRecord> _expenses = <ExpenseRecord>[];

  bool get loaded => _loaded;
  List<OperationRecord> get operations => List.unmodifiable(_operations);
  List<ExpenseRecord> get expenses => List.unmodifiable(_expenses);

  int get openOperations =>
      _operations.where((record) => record.status != 'Closed').length;

  int get urgentOperations =>
      _operations.where((record) => record.priority == 'High').length;

  double get openExpenseTotal => _expenses
      .where((expense) => expense.status != 'Reconciled')
      .fold<double>(0, (total, expense) => total + expense.amount);

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    if (!persistenceEnabled) {
      _operations = _sampleOperations();
      _expenses = _sampleExpenses();
      _loaded = true;
      notifyListeners();
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    compactCards = _prefs?.getBool(_compactKey) ?? false;
    showClosedRecords = _prefs?.getBool(_showClosedKey) ?? true;
    final operationRaw = _prefs?.getString(_operationsKey);
    final expenseRaw = _prefs?.getString(_expensesKey);

    if (operationRaw == null || expenseRaw == null) {
      _operations = _starterOperations();
      _expenses = _starterExpenses();
      await _persist();
    } else {
      _operations = _decodeList(
        operationRaw,
        (json) => OperationRecord.fromJson(json),
      );
      _expenses = _decodeList(
        expenseRaw,
        (json) => ExpenseRecord.fromJson(json),
      );
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> addOperation(OperationRecord record) async {
    _operations = <OperationRecord>[record, ..._operations];
    await _persist();
    notifyListeners();
  }

  Future<void> updateOperationStatus(String id, String status) async {
    _operations = _operations
        .map(
          (record) =>
              record.id == id ? record.copyWith(status: status) : record,
        )
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> addExpense(ExpenseRecord record) async {
    _expenses = <ExpenseRecord>[record, ..._expenses];
    await _persist();
    notifyListeners();
  }

  Future<void> updateExpenseStatus(String id, String status) async {
    _expenses = _expenses
        .map(
          (record) =>
              record.id == id ? record.copyWith(status: status) : record,
        )
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> setCompactCards(bool value) async {
    compactCards = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setShowClosedRecords(bool value) async {
    showClosedRecords = value;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (!persistenceEnabled) {
      return;
    }
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(
      _operationsKey,
      jsonEncode(_operations.map((record) => record.toJson()).toList()),
    );
    await prefs.setString(
      _expensesKey,
      jsonEncode(_expenses.map((record) => record.toJson()).toList()),
    );
    await prefs.setBool(_compactKey, compactCards);
    await prefs.setBool(_showClosedKey, showClosedRecords);
  }
}

class OperationRecord {
  OperationRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.owner,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.notes,
  });

  factory OperationRecord.fromJson(Map<String, dynamic> json) {
    return OperationRecord(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      location: json['location'] as String,
      owner: json['owner'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      dueDate: DateTime.parse(json['dueDate'] as String),
      notes: json['notes'] as String,
    );
  }

  final String id;
  final String type;
  final String title;
  final String location;
  final String owner;
  final String priority;
  final String status;
  final DateTime dueDate;
  final String notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'location': location,
      'owner': owner,
      'priority': priority,
      'status': status,
      'dueDate': dueDate.toIso8601String(),
      'notes': notes,
    };
  }

  OperationRecord copyWith({String? status}) {
    return OperationRecord(
      id: id,
      type: type,
      title: title,
      location: location,
      owner: owner,
      priority: priority,
      status: status ?? this.status,
      dueDate: dueDate,
      notes: notes,
    );
  }
}

class ExpenseRecord {
  ExpenseRecord({
    required this.id,
    required this.vendor,
    required this.category,
    required this.amount,
    required this.status,
    required this.date,
    required this.notes,
  });

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      id: json['id'] as String,
      vendor: json['vendor'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String,
    );
  }

  final String id;
  final String vendor;
  final String category;
  final double amount;
  final String status;
  final DateTime date;
  final String notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'vendor': vendor,
      'category': category,
      'amount': amount,
      'status': status,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  ExpenseRecord copyWith({String? status}) {
    return ExpenseRecord(
      id: id,
      vendor: vendor,
      category: category,
      amount: amount,
      status: status ?? this.status,
      date: date,
      notes: notes,
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({required this.store, super.key});

  final AppStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.store.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = <Widget>[
      DashboardPage(store: widget.store, onSelectTab: _selectTab),
      WorkPage(store: widget.store),
      ExpensesPage(store: widget.store),
      SettingsPage(store: widget.store),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(shortAppTitle)),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Work',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  void _selectTab(int value) {
    setState(() => _index = value);
  }

  Widget? _buildFab(BuildContext context) {
    if (_index == 1) {
      return FloatingActionButton.extended(
        key: const Key('addOperationFab'),
        onPressed: () => _openOperationForm(context),
        icon: const Icon(Icons.add_task),
        label: const Text('New task'),
      );
    }
    if (_index == 2) {
      return FloatingActionButton.extended(
        key: const Key('addExpenseFab'),
        onPressed: () => _openExpenseForm(context),
        icon: const Icon(Icons.add_card),
        label: const Text('Add cost'),
      );
    }
    return null;
  }

  Future<void> _openOperationForm(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OperationFormPage(store: widget.store),
      ),
    );
  }

  Future<void> _openExpenseForm(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseFormPage(store: widget.store),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.store,
    required this.onSelectTab,
    super.key,
  });

  final AppStore store;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final nextOperation =
        store.operations.where((record) => record.status != 'Closed').toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const SectionHeader(
          title: 'Operations ready',
          subtitle:
              'Track bookings, reports, supplies, and costs in one place.',
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.32,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            KpiCard(
              label: 'Open tasks',
              value: '${store.openOperations}',
              icon: Icons.fact_check,
              color: _teal,
            ),
            KpiCard(
              label: 'High priority',
              value: '${store.urgentOperations}',
              icon: Icons.priority_high,
              color: _amber,
            ),
            KpiCard(
              label: 'Costs pending',
              value: formatMoneyCompact(store.openExpenseTotal),
              icon: Icons.payments,
              color: const Color(0xFF3A5872),
            ),
            KpiCard(
              label: 'Records saved',
              value: '${store.operations.length + store.expenses.length}',
              icon: Icons.inventory_2,
              color: _navy,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, color: _teal),
                    const SizedBox(width: 8),
                    Text(
                      'Next operational action',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (nextOperation.isEmpty)
                  const Text('No open actions. Add a task from the work queue.')
                else
                  OperationSummary(record: nextOperation.first),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => onSelectTab(1),
                  icon: const Icon(Icons.assignment),
                  label: const Text('Review work queue'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily control board',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    StatusPill(label: 'Facility bookings', color: _teal),
                    StatusPill(label: 'Compliance reports', color: _amber),
                    StatusPill(
                      label: 'Supply orders',
                      color: Color(0xFF3A5872),
                    ),
                    StatusPill(label: 'Expense tracking', color: _navy),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WorkPage extends StatefulWidget {
  const WorkPage({required this.store, super.key});

  final AppStore store;

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final records = widget.store.operations.where((record) {
      final typeMatches = _filter == 'All' || record.type == _filter;
      final closedMatches =
          widget.store.showClosedRecords || record.status != 'Closed';
      return typeMatches && closedMatches;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const SectionHeader(
          title: 'Work queue',
          subtitle: 'Prioritize facility requests and operating controls.',
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', ...operationTypes].map((type) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type),
                  selected: _filter == type,
                  onSelected: (_) => setState(() => _filter = type),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No records found',
            body:
                'Create a booking, report, or supply order to fill this queue.',
          )
        else
          ...records.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OperationCard(
                record: record,
                compact: widget.store.compactCards,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OperationDetailPage(
                        store: widget.store,
                        recordId: record.id,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({required this.store, super.key});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const SectionHeader(
          title: 'Expense desk',
          subtitle: 'Log operating costs and track reimbursement status.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Open expense total'),
                      const SizedBox(height: 4),
                      Text(
                        formatMoney(store.openExpenseTotal),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: _navy,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExpenseFormPage(store: store),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_card),
                  label: const Text('Add cost'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...store.expenses.map(
          (expense) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ExpenseCard(store: store, expense: expense),
          ),
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.store, super.key});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SectionHeader(
          title: 'Settings and privacy',
          subtitle: 'Configure the local workspace and review data handling.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: store.compactCards,
                onChanged: store.setCompactCards,
                title: const Text('Compact work cards'),
                subtitle: const Text(
                  'Show tighter task rows in the work queue.',
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: store.showClosedRecords,
                onChanged: store.setShowClosedRecords,
                title: const Text('Show closed work'),
                subtitle: const Text(
                  'Keep completed tasks visible in filters.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.lock_outline, color: _teal),
                SizedBox(height: 10),
                Text(
                  'Local data only',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  'Bookings, reports, supply orders, expenses, and preferences stay on this device. The app does not use accounts, cloud sync, analytics, ads, location, contacts, microphone, photos, payments, or external APIs.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  appTitle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text('Support contact'),
                SizedBox(height: 4),
                Text(
                  supportEmail,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OperationDetailPage extends StatelessWidget {
  const OperationDetailPage({
    required this.store,
    required this.recordId,
    super.key,
  });

  final AppStore store;
  final String recordId;

  @override
  Widget build(BuildContext context) {
    final record = store.operations.firstWhere((item) => item.id == recordId);
    return Scaffold(
      appBar: AppBar(title: const Text('Task detail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(
                      label: record.type,
                      color: colorForType(record.type),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      record.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900, color: _navy),
                    ),
                    const SizedBox(height: 16),
                    InfoRow(label: 'Location', value: record.location),
                    InfoRow(label: 'Owner', value: record.owner),
                    InfoRow(label: 'Due', value: formatDate(record.dueDate)),
                    InfoRow(label: 'Priority', value: record.priority),
                    InfoRow(label: 'Status', value: record.status),
                    const SizedBox(height: 12),
                    Text(record.notes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Move status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: operationStatuses.map((status) {
                        return ActionChip(
                          label: Text(status),
                          avatar: status == record.status
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onPressed: () async {
                            await store.updateOperationStatus(
                              record.id,
                              status,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Status set to $status'),
                                ),
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OperationFormPage extends StatefulWidget {
  const OperationFormPage({required this.store, super.key});

  final AppStore store;

  @override
  State<OperationFormPage> createState() => _OperationFormPageState();
}

class _OperationFormPageState extends State<OperationFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _owner;
  late final TextEditingController _notes;
  String _type = operationTypes.first;
  String _priority = 'Medium';
  int _dueOffset = 2;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: screenshotMode ? 'Loading dock inspection' : '',
    );
    _location = TextEditingController(
      text: screenshotMode ? 'Warehouse B' : '',
    );
    _owner = TextEditingController(text: screenshotMode ? 'Shift lead' : '');
    _notes = TextEditingController(
      text: screenshotMode
          ? 'Check access log, lighting, and safety signage.'
          : '',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _owner.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New work task')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            key: const Key('saveOperationButton'),
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save task'),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Task type'),
                items: operationTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('operationTitleField'),
                controller: _title,
                decoration: const InputDecoration(labelText: 'Task title'),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location or vendor',
                ),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _owner,
                decoration: const InputDecoration(
                  labelText: 'Responsible owner',
                ),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['Low', 'Medium', 'High']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _priority = value ?? _priority),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _dueOffset,
                decoration: const InputDecoration(labelText: 'Due window'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Today')),
                  DropdownMenuItem(value: 1, child: Text('Tomorrow')),
                  DropdownMenuItem(value: 2, child: Text('In two days')),
                  DropdownMenuItem(value: 7, child: Text('Next week')),
                ],
                onChanged: (value) =>
                    setState(() => _dueOffset = value ?? _dueOffset),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    await widget.store.addOperation(
      OperationRecord(
        id: 'op-${now.microsecondsSinceEpoch}',
        type: _type,
        title: _title.text.trim(),
        location: _location.text.trim(),
        owner: _owner.text.trim(),
        priority: _priority,
        status: 'Scheduled',
        dueDate: DateTime(
          now.year,
          now.month,
          now.day,
        ).add(Duration(days: _dueOffset)),
        notes: _notes.text.trim().isEmpty
            ? 'No additional notes.'
            : _notes.text.trim(),
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({required this.store, super.key});

  final AppStore store;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vendor;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  String _category = expenseCategories.first;

  @override
  void initState() {
    super.initState();
    _vendor = TextEditingController(
      text: screenshotMode ? 'Metro Office Supply' : '',
    );
    _amount = TextEditingController(text: screenshotMode ? '218.40' : '');
    _notes = TextEditingController(
      text: screenshotMode ? 'Paper, safety labels, and storage bins.' : '',
    );
  }

  @override
  void dispose() {
    _vendor.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add expense')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save expense'),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextFormField(
                controller: _vendor,
                decoration: const InputDecoration(labelText: 'Vendor or payee'),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: expenseCategories
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    await widget.store.addExpense(
      ExpenseRecord(
        id: 'ex-${now.microsecondsSinceEpoch}',
        vendor: _vendor.text.trim(),
        category: _category,
        amount: double.parse(_amount.text.trim()),
        status: 'Submitted',
        date: DateTime(now.year, now.month, now.day),
        notes: _notes.text.trim().isEmpty
            ? 'No additional notes.'
            : _notes.text.trim(),
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: _navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _navy.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class OperationCard extends StatelessWidget {
  const OperationCard({
    required this.record,
    required this.compact,
    required this.onTap,
    super.key,
  });

  final OperationRecord record;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(
                    label: record.type,
                    color: colorForType(record.type),
                  ),
                  const Spacer(),
                  Text(
                    formatDate(record.dueDate),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                record.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: _navy,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Text('${record.location} - ${record.owner}'),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  StatusPill(label: record.status, color: _teal),
                  const SizedBox(width: 8),
                  StatusPill(
                    label: record.priority,
                    color: priorityColor(record.priority),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OperationSummary extends StatelessWidget {
  const OperationSummary({required this.record, super.key});

  final OperationRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          record.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${record.type} - ${record.location} - due ${formatDate(record.dueDate)}',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: record.priority,
              color: priorityColor(record.priority),
            ),
            StatusPill(label: record.status, color: _teal),
          ],
        ),
      ],
    );
  }
}

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({required this.store, required this.expense, super.key});

  final AppStore store;
  final ExpenseRecord expense;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense.vendor,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _navy,
                    ),
                  ),
                ),
                Text(
                  formatMoney(expense.amount),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${expense.category} - ${formatDate(expense.date)}'),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusPill(label: expense.status, color: _teal),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Change status',
                  onSelected: (status) =>
                      store.updateExpenseStatus(expense.id, status),
                  itemBuilder: (context) => expenseStatuses
                      .map(
                        (status) =>
                            PopupMenuItem(value: status, child: Text(status)),
                      )
                      .toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == _amber ? const Color(0xFF6E4700) : color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 42, color: _teal),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

const operationTypes = <String>[
  'Facility booking',
  'Compliance report',
  'Supply order',
];

const operationStatuses = <String>[
  'Scheduled',
  'In progress',
  'Waiting approval',
  'Ordered',
  'Reported',
  'Closed',
];

const expenseCategories = <String>[
  'Facilities',
  'Supplies',
  'Travel',
  'Maintenance',
];

const expenseStatuses = <String>[
  'Draft',
  'Submitted',
  'Approved',
  'Reconciled',
];

String? requiredField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

Color colorForType(String type) {
  return switch (type) {
    'Facility booking' => _teal,
    'Compliance report' => _amber,
    'Supply order' => const Color(0xFF3A5872),
    _ => _navy,
  };
}

Color priorityColor(String priority) {
  return switch (priority) {
    'High' => const Color(0xFFB84A3A),
    'Medium' => _amber,
    _ => _teal,
  };
}

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String formatMoney(double amount) => '\$${amount.toStringAsFixed(2)}';

String formatMoneyCompact(double amount) {
  if (amount >= 1000) {
    return '\$${(amount / 1000).toStringAsFixed(1)}k';
  }
  return '\$${amount.round()}';
}

List<T> _decodeList<T>(
  String raw,
  T Function(Map<String, dynamic> json) fromJson,
) {
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded
      .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
}

List<OperationRecord> _starterOperations() =>
    _sampleOperations().take(3).toList();

List<ExpenseRecord> _starterExpenses() => _sampleExpenses().take(2).toList();

List<OperationRecord> _sampleOperations() {
  final today = DateTime.now();
  final base = DateTime(today.year, today.month, today.day);
  return [
    OperationRecord(
      id: 'sample-facility-booking',
      type: 'Facility booking',
      title: 'North Wing training room booking',
      location: 'North Wing 2A',
      owner: 'Front desk',
      priority: 'High',
      status: 'Scheduled',
      dueDate: base.add(const Duration(days: 1)),
      notes: 'Reserve seating, projector, key access, and cleaning window.',
    ),
    OperationRecord(
      id: 'sample-compliance-report',
      type: 'Compliance report',
      title: 'Fire extinguisher inspection report',
      location: 'Main floor',
      owner: 'Safety coordinator',
      priority: 'Medium',
      status: 'In progress',
      dueDate: base.add(const Duration(days: 2)),
      notes: 'Collect tags, note blocked units, and prepare closeout summary.',
    ),
    OperationRecord(
      id: 'sample-supply-order',
      type: 'Supply order',
      title: 'Breakroom supply reorder',
      location: 'Operations pantry',
      owner: 'Office manager',
      priority: 'Low',
      status: 'Ordered',
      dueDate: base.add(const Duration(days: 4)),
      notes: 'Restock cups, labels, gloves, paper towels, and storage bags.',
    ),
    OperationRecord(
      id: 'sample-vendor-check',
      type: 'Compliance report',
      title: 'Vendor insurance certificate review',
      location: 'Vendor file',
      owner: 'Admin desk',
      priority: 'High',
      status: 'Waiting approval',
      dueDate: base.add(const Duration(days: 5)),
      notes: 'Confirm coverage dates before next service visit.',
    ),
  ];
}

List<ExpenseRecord> _sampleExpenses() {
  final today = DateTime.now();
  final base = DateTime(today.year, today.month, today.day);
  return [
    ExpenseRecord(
      id: 'sample-expense-cleaning',
      vendor: 'Atlas Cleaning Supply',
      category: 'Supplies',
      amount: 284.75,
      status: 'Submitted',
      date: base.subtract(const Duration(days: 1)),
      notes: 'Sanitizer, liners, gloves, and floor pads.',
    ),
    ExpenseRecord(
      id: 'sample-expense-service',
      vendor: 'Summit Elevator Service',
      category: 'Maintenance',
      amount: 640,
      status: 'Approved',
      date: base.subtract(const Duration(days: 3)),
      notes: 'Preventive service visit and door sensor adjustment.',
    ),
    ExpenseRecord(
      id: 'sample-expense-parking',
      vendor: 'City Center Parking',
      category: 'Travel',
      amount: 38.5,
      status: 'Reconciled',
      date: base.subtract(const Duration(days: 6)),
      notes: 'Client site operations meeting.',
    ),
  ];
}
