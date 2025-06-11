import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'global.dart';

class MapaLocalizacoesScreen extends StatefulWidget {
  final String accessToken;

  const MapaLocalizacoesScreen({required this.accessToken});

  @override
  _MapaLocalizacoesScreenState createState() => _MapaLocalizacoesScreenState();
}

class _MapaLocalizacoesScreenState extends State<MapaLocalizacoesScreen> {
  List<Marker> _marcadores = [];
  LatLng? _posicaoAtual;
  bool _carregar = true;
  String _erro = '';

  @override
  void initState() {
    super.initState();
    _obterLocalizacaoAtual();
  }

  Future<void> _obterLocalizacaoAtual() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _erro = 'Serviço de localização desativado.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _erro = 'Permissão de localização negada.');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _posicaoAtual = LatLng(position.latitude, position.longitude);
      });

      _buscarLocalizacoes();
    } catch (e) {
      setState(() {
        _erro = 'Erro ao obter localização: $e';
        _carregar = false;
      });
    }
  }

  Future<void> _buscarLocalizacoes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/listar-localizacoes/'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        List<Marker> marcadores = [];

        for (var loc in data) {
          final lat = loc['lat'];
          final lng = loc['lng'];
          final descricao = loc['descricao'] ?? 'Localização';

          if (lat != null && lng != null) {
            marcadores.add(
              Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(descricao),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(Icons.location_on, color: Colors.red, size: 36),
                ),
              ),
            );
          }
        }

        setState(() {
          _marcadores = marcadores;
          _carregar = false;
        });
      } else {
        setState(() {
          _erro = 'Erro ao obter localizações: ${response.statusCode}';
          _carregar = false;
        });
      }
    } catch (e) {
      setState(() {
        _erro = 'Erro: $e';
        _carregar = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final centro = _posicaoAtual ?? LatLng(40.7250, -6.9026);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa de Localizações'),
        backgroundColor: Colors.green[700],
      ),
      body:
          _erro.isNotEmpty
              ? Center(child: Text(_erro, style: TextStyle(color: Colors.red)))
              : _carregar
              ? Center(child: CircularProgressIndicator())
              : FlutterMap(
                options: MapOptions(initialCenter: centro, initialZoom: 13),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.app',
                  ),
                  if (_marcadores.isNotEmpty) MarkerLayer(markers: _marcadores),
                  if (_posicaoAtual != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _posicaoAtual!,
                          width: 50,
                          height: 50,
                          child: Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                            size: 42,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
    );
  }
}
