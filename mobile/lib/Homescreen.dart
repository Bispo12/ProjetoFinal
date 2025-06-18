import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';

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
        title: Text('home.dados_natureza'.tr()),
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
                      label: 'home.selecionar_dispositivo'.tr(),
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
                      label: 'home.selecionar_categoria'.tr(),
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
                      label: 'home.visualizar_como'.tr(),
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
                  (user.fotoPath != null &&
                          user.fotoPath!.isNotEmpty &&
                          File(user.fotoPath!).existsSync())
                      ? FileImage(File(user.fotoPath!))
                      : const AssetImage('imagens/perfil.jpg') as ImageProvider,
            ),
            accountName: Text(user.nome),
            accountEmail: const SizedBox.shrink(),
          ),

          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text('menu.dados'.tr()),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: Text('menu.localizacao'.tr()),
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
            title: Text('menu.notificacoes'.tr()),
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
            title: Text('menu.definicoes'.tr()),
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
            title: Text('menu.logout'.tr()),
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
        'home.grafico_de'.tr(namedArgs: {'categoria': _selectedCategory ?? ''}),
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

    // Limita a 500 linhas visíveis na tabela para não pesar UI
    final rows =
        data.skip(1).take(500).map((row) {
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

    final header = data.first;
    var idx = header.indexWhere(
      (h) => h.toString().trim().toLowerCase() == key.trim().toLowerCase(),
    );
    if (idx == -1) idx = 1;

    double _limiteMaximo(String cat) {
      final nome = cat.toLowerCase();
      if (nome.contains('humidity')) return 100.0;
      if (nome.contains('temperature')) return 60.0;
      if (nome.contains('pressure')) return 1100.0;
      if (nome.contains('precipitation')) return 500.0;
      return double.infinity;
    }

    final limiteY = _limiteMaximo(key);

    // Guardar timestamps
    final rawSpots = <FlSpot>[];
    final timestamps = <double, String>{};
    for (var i = 0; i < data.length - 1; i++) {
      final row = data[i + 1];
      final val = double.tryParse(row[idx].toString());
      if (val != null && val >= 0 && val <= limiteY) {
        final x = i.toDouble();
        rawSpots.add(FlSpot(x, val));
        timestamps[x] = row[0].toString(); // timestamp na coluna 0
      }
    }

    if (rawSpots.isEmpty) {
      return const Center(child: Text('Sem dados válidos para o gráfico.'));
    }

    // Limitar número de pontos (auto ajustável)
    int maxPontosVisiveis;
    if (rawSpots.length > 20000) {
      maxPontosVisiveis = 100;
    } else if (rawSpots.length > 10000) {
      maxPontosVisiveis = 150;
    } else if (rawSpots.length > 5000) {
      maxPontosVisiveis = 200;
    } else {
      maxPontosVisiveis = 300;
    }

    final passo = (rawSpots.length / maxPontosVisiveis).ceil();

    final spots = <FlSpot>[
      for (var i = 0; i < rawSpots.length; i += passo) rawSpots[i],
    ];

    final yMaxRaw = spots.map((e) => e.y).reduce(math.max);
    final yMinRaw = spots.map((e) => e.y).reduce(math.min);
    final padding = (yMaxRaw - yMinRaw).abs() * 0.1;
    final minY = (yMinRaw - padding).clamp(0.0, double.infinity);
    final maxY = math.min((yMaxRaw + padding), limiteY);

    final horizInterval = math.max(1.0, (maxY - minY) / 5);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 350,
        child: LineChart(
          LineChartData(
            minX: spots.first.x,
            maxX: spots.last.x,
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(show: true, horizontalInterval: horizInterval),
            borderData: FlBorderData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    final first = spots.first.x;
                    final last = spots.last.x;
                    final mid = first + (last - first) / 2;

                    if ((value - first).abs() < 1e-3 ||
                        (value - mid).abs() < 1e-3 ||
                        (value - last).abs() < 1e-3) {
                      final ts = timestamps[value] ?? '';
                      final partes = ts.split(' ');
                      return Transform.rotate(
                        angle: math.pi / 4,
                        child: Text(
                          partes.length == 2 ? partes[1] : ts,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final ts = timestamps[spot.x] ?? '';
                    return LineTooltipItem(
                      '$ts\nValor: ${spot.y.toStringAsFixed(1)}',
                      const TextStyle(fontSize: 12, color: Colors.black),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                barWidth: 2,
                color: Colors.blue,
                dotData: FlDotData(show: true),
                showingIndicators: List.generate(spots.length, (i) => i),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
