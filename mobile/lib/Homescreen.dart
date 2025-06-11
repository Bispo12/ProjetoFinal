import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'user_provider.dart';
import 'global.dart';
import 'localizacao_screen.dart';
import 'notificacoes_screen.dart';
import 'definicoes_screen.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  final String accessToken;
  const HomeScreen({Key? key, required this.accessToken}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Estado ──────────────────────────────────────────────────────────
  final List<String> _availableDevices = [];
  final List<String> _availableCategories = [];
  final Map<String, List<List<dynamic>>> _deviceData = {};

  String? _selectedDevice;
  String? _selectedCategory;

  String _selectedView = 'Gráfico';
  final List<String> _availableViews = ['Gráfico', 'Tabela'];

  bool _isLoading = false;
  String _errorMessage = '';

  // Helper do Provider
  UserProvider get _user => context.watch<UserProvider>();

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  // ── API calls ───────────────────────────────────────────────────────
  Future<void> _fetchDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/devices/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _availableDevices
          ..clear()
          ..addAll(data.whereType<String>());
        _selectedDevice =
            _availableDevices.isNotEmpty ? _availableDevices.first : null;
        if (_selectedDevice != null) await _fetchCategories(_selectedDevice!);
      } else {
        _errorMessage = 'Erro ao buscar dispositivos';
      }
    } catch (e) {
      _errorMessage = 'Erro de rede: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCategories(String deviceId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _availableCategories.clear();
      _selectedCategory = null;
    });
    try {
      final url = Uri.parse('$baseUrl/api/categorias/?iddevice=$deviceId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          _availableCategories
            ..clear()
            ..addAll(decoded.whereType<String>());
          _selectedCategory =
              _availableCategories.isNotEmpty
                  ? _availableCategories.first
                  : null;
          if (_selectedCategory != null) {
            await _fetchData(_selectedCategory!, deviceId);
          }
        } else {
          _errorMessage = 'Resposta inválida do servidor';
        }
      } else {
        _errorMessage = 'Erro ao carregar categorias';
      }
    } catch (e) {
      _errorMessage = 'Erro de rede: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData(String category, String deviceId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    if (category.isEmpty || deviceId.isEmpty) {
      setState(() {
        _errorMessage = 'Categoria ou dispositivo inválido';
        _isLoading = false;
      });
      return;
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/api/data/${Uri.encodeComponent(_normalize(category))}/?iddevice=${Uri.encodeComponent(deviceId)}',
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final data = List<List<dynamic>>.from(decoded);
          if (data.isNotEmpty) _deviceData[category] = data;
        }
      } else {
        _errorMessage = 'Erro ao carregar dados';
      }
    } catch (e) {
      _errorMessage = 'Erro de rede: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────
  String _normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll('%', 'percent')
      .replaceAll(RegExp(r'[ ()/]'), '');

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados da Natureza'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(),
      backgroundColor: Colors.green[100],
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.green[700]),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (_errorMessage.isNotEmpty) _buildErrorBanner(),
                    _buildDropdown(
                      label: 'Selecionar Dispositivo',
                      value: _selectedDevice,
                      items: _availableDevices,
                      onChanged: (v) {
                        setState(() {
                          _selectedDevice = v;
                          if (v != null) _fetchCategories(v);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      label: 'Selecionar Categoria',
                      value: _selectedCategory,
                      items: _availableCategories,
                      onChanged: (v) {
                        setState(() {
                          _selectedCategory = v;
                          if (v != null && _selectedDevice != null) {
                            _fetchData(v, _selectedDevice!);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      label: 'Visualizar como',
                      value: _selectedView,
                      items: _availableViews,
                      onChanged:
                          (v) =>
                              v != null
                                  ? setState(() => _selectedView = v)
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child:
                          (_selectedDevice == null || _selectedCategory == null)
                              ? const Center(
                                child: Text(
                                  'Selecione dispositivo e categoria',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : (_selectedView == 'Gráfico'
                                  ? _buildGraphSection()
                                  : _buildDataTable()),
                    ),
                  ],
                ),
              ),
    );
  }

  // ── Widgets auxiliares ──────────────────────────────────────────────
  Widget _buildErrorBanner() => Container(
    padding: const EdgeInsets.all(8.0),
    margin: const EdgeInsets.only(bottom: 16.0),
    decoration: BoxDecoration(
      color: Colors.red.shade100,
      border: Border.all(color: Colors.red.shade300),
      borderRadius: BorderRadius.circular(4.0),
    ),
    child: Text(_errorMessage, style: TextStyle(color: Colors.red.shade700)),
  );

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: Text('Selecione $label'),
            items:
                items
                    .map<DropdownMenuItem<String>>(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ── Drawer ──────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    final user = _user;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.green.shade700),
            currentAccountPicture: CircleAvatar(
              backgroundImage:
                  (user.fotoPath != null && user.fotoPath!.isNotEmpty)
                      ? FileImage(File(user.fotoPath!))
                      : const AssetImage('imagens/perfil.jpg') as ImageProvider,
            ),
            accountName: Text(user.nome),
            accountEmail: Text(user.email),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Dados'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Localização'),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => MapaLocalizacoesScreen(
                          accessToken: widget.accessToken,
                        ),
                  ),
                ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notificações'),
            onTap: () {
              if (_selectedDevice == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selecione um dispositivo primeiro.'),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => NotificacoesScreen(
                          accessToken: widget.accessToken,
                          deviceId: _selectedDevice!,
                        ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Definições'),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                            DefinicoesScreen(accessToken: widget.accessToken),
                  ),
                ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  // ── Gráfico e Tabela ────────────────────────────────────────────────
  Widget _buildGraphSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Gráfico de $_selectedCategory',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      const SizedBox(height: 10),
      Expanded(child: _buildGraph()),
    ],
  );

  Widget _buildDataTable() {
    final key = _selectedCategory ?? '';
    final data = _deviceData[key] ?? [];

    if (data.length <= 1) {
      return const Center(
        child: Text(
          'Sem dados disponíveis.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final header = data.first;
    int idx = header.indexWhere(
      (h) => h.toString().trim().toLowerCase() == key.trim().toLowerCase(),
    );
    if (idx == -1) idx = 1;

    final rows =
        data.skip(1).map((row) {
          final ts = row.isNotEmpty ? row[0].toString() : '';
          final val = idx < row.length ? row[idx].toString() : '';
          return DataRow(cells: [DataCell(Text(ts)), DataCell(Text(val))]);
        }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.green.shade200),
        dataRowColor: MaterialStateProperty.all(Colors.green.shade50),
        columns: [
          const DataColumn(label: Text('Timestamp')),
          DataColumn(label: Text(_selectedCategory!)),
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildGraph() {
    final key = _selectedCategory ?? '';
    final data = _deviceData[key] ?? [];

    if (data.length <= 1) {
      return const Center(child: Text('Sem dados para o gráfico.'));
    }

    // coluna da categoria
    final header = data.first;
    var idx = header.indexWhere(
      (h) => h.toString().trim().toLowerCase() == key.trim().toLowerCase(),
    );
    if (idx == -1) idx = 1;

    // pontos
    final spots = <FlSpot>[
      for (var i = 0; i < data.length - 1; i++)
        FlSpot(i.toDouble(), double.tryParse(data[i + 1][idx].toString()) ?? 0),
    ];
    if (spots.isEmpty) return const SizedBox.shrink();

    // escala e intervalos (≥1)
    final yMax = math.max(1.0, spots.map((e) => e.y).reduce(math.max) * 1.1);
    final horizInterval = math.max(1.0, yMax / 5);
    final vertInterval = math.max(1.0, (spots.length / 5).ceilToDouble());

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: spots.length.toDouble() - 1,
          minY: 0,
          maxY: yMax,
          gridData: FlGridData(
            show: true,
            horizontalInterval: horizInterval,
            verticalInterval: vertInterval,
            getDrawingHorizontalLine:
                (v) => FlLine(color: Colors.grey.shade300, strokeWidth: 1),
            getDrawingVerticalLine:
                (v) => FlLine(color: Colors.grey.shade300, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: vertInterval,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= spots.length)
                    return const SizedBox.shrink();

                  final show =
                      i == 0 || i == spots.length ~/ 2 || i == spots.length - 1;
                  return show
                      ? SideTitleWidget(
                        meta: meta,
                        angle: math.pi / 4,
                        space: 4,
                        child: Text(
                          i.toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 2,
              color: Colors.blue,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}
