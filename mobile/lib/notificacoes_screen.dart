import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'global.dart';
import 'package:easy_localization/easy_localization.dart';

class NotificacoesScreen extends StatefulWidget {
  final String accessToken;
  final String deviceId; // novo: receber o ID do dispositivo

  const NotificacoesScreen({required this.accessToken, required this.deviceId});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  List<Map<String, dynamic>> _notificacoes = [];
  List<Map<String, dynamic>> _alertas = [];
  List<String> _temasDosCsv = [];

  @override
  void initState() {
    super.initState();
    _carregarTemasParaAlertas();
    Timer.periodic(
      Duration(seconds: 10),
      (timer) => _verificarAlertasSimulados(),
    );
  }

  Future<void> _carregarTemasParaAlertas() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/categorias-por-device/?iddevice=${widget.deviceId}',
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> categorias = jsonDecode(response.body);
      setState(() {
        _temasDosCsv = categorias.map((e) => e.toString()).toList();
      });
    }
  }

  void _verificarAlertasSimulados() {
    Map<String, double> dadosAtuais = {'temperatura': 37.5};

    for (var alerta in _alertas) {
      final param = alerta['parametro'];
      final limiar = alerta['valor'];
      final direcao = alerta['direcao'];
      final valorAtual = dadosAtuais[param] ?? 0;

      bool disparar = false;
      if (direcao == 'acima' && valorAtual > limiar) disparar = true;
      if (direcao == 'abaixo' && valorAtual < limiar) disparar = true;

      if (disparar) {
        setState(() {
          _notificacoes.insert(0, {
            'mensagem':
                ' Alerta: $param ${direcao == 'acima' ? 'acima' : 'abaixo'} de $limiar (atual: $valorAtual)',
            'lida': false,
          });
        });
      }
    }
  }

  void _marcarComoLida(int index) {
    setState(() {
      _notificacoes[index]['lida'] = true;
    });
  }

  void _removerNotificacao(int index) {
    setState(() {
      _notificacoes.removeAt(index);
    });
  }

  void _abrirFormAlerta() {
    String parametro =
        _temasDosCsv.isNotEmpty ? _temasDosCsv[0] : 'temperatura';
    double valor = 0;
    String direcao = 'acima';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Criar Alerta Personalizado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: parametro,
                items:
                    _temasDosCsv
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (val) => parametro = val!,
                decoration: InputDecoration(labelText: 'Parâmetro'),
              ),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Valor limite'),
                onChanged: (val) => valor = double.tryParse(val) ?? 0,
              ),
              DropdownButtonFormField<String>(
                value: direcao,
                items:
                    ['acima', 'abaixo']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (val) => direcao = val!,
                decoration: InputDecoration(labelText: 'Direção'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text('Guardar'),
              onPressed: () {
                setState(() {
                  _alertas.add({
                    'parametro': parametro,
                    'valor': valor,
                    'direcao': direcao,
                  });
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notificacoes.titulo'.tr()),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: Icon(Icons.add_alert),
            tooltip: 'Criar Alerta',
            onPressed: _abrirFormAlerta,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _notificacoes.length,
              itemBuilder: (context, index) {
                final notif = _notificacoes[index];
                return ListTile(
                  leading: Icon(
                    notif['lida']
                        ? Icons.notifications_none
                        : Icons.notifications,
                    color: notif['lida'] ? Colors.grey : Colors.green[700],
                  ),
                  title: Text(notif['mensagem']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!notif['lida'])
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => _marcarComoLida(index),
                        ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removerNotificacao(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_alertas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔔 Alertas Personalizados:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ..._alertas.map(
                    (a) => Text(
                      '• ${a['parametro']} ${a['direcao']} de ${a['valor']}',
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
