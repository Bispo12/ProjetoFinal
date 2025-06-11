import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'global.dart';
import 'user_provider.dart';

class DefinicoesScreen extends StatefulWidget {
  final String accessToken;
  const DefinicoesScreen({super.key, required this.accessToken});

  @override
  State<DefinicoesScreen> createState() => _DefinicoesScreenState();
}

class _DefinicoesScreenState extends State<DefinicoesScreen> {
  File? _imagem;
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();

  /// Guardamos sempre algum idioma válido — default "pt".
  String _idiomaSelecionado = 'pt';

  bool _loading = true;

  /// Mapa fixo para o dropdown.
  final idiomas = const {'pt': 'Português', 'es': 'Español', 'en': 'English'};

  @override
  void initState() {
    super.initState();
    _carregarPreferencias(); // sem usar context aqui
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se ainda não foi carregado das prefs, usa o locale actual.
    _idiomaSelecionado =
        context.locale.languageCode.isNotEmpty
            ? context.locale.languageCode
            : _idiomaSelecionado;
  }

  Future<void> _carregarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();

    _idiomaSelecionado = prefs.getString('idioma') ?? _idiomaSelecionado;
    _nomeController.text = prefs.getString('nome') ?? 'Amelinha';
    _emailController.text = prefs.getString('email') ?? 'amelinha@exemplo.com';

    final fotoPath = prefs.getString('foto');
    if (fotoPath != null) _imagem = File(fotoPath);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _guardarLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome', _nomeController.text);
    await prefs.setString('email', _emailController.text);
    await prefs.setString('idioma', _idiomaSelecionado);
    if (_imagem != null) await prefs.setString('foto', _imagem!.path);
  }

  Future<void> _guardarAlteracoes() async {
    setState(() => _loading = true);

    await _guardarLocal();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/settings/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode({
          'idioma': _idiomaSelecionado,
          'nome': _nomeController.text,
          'email': _emailController.text,
          'foto':
              _imagem != null ? base64Encode(_imagem!.readAsBytesSync()) : null,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        context.setLocale(Locale(_idiomaSelecionado));
        try {
          context.read<UserProvider>().update(
            nome: _nomeController.text,
            email: _emailController.text,
            fotoPath: _imagem?.path,
            idioma: _idiomaSelecionado,
          );
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Definições sincronizadas com sucesso!'),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar (HTTP ${response.statusCode}).'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro de rede: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _escolherImagem() async {
    final picker = ImagePicker();
    final imagem = await picker.pickImage(source: ImageSource.gallery);
    if (imagem == null) return;

    setState(() => _imagem = File(imagem.path));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('foto', imagem.path);

    await _guardarAlteracoes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('definicoes.titulo'.tr()),
        backgroundColor: Colors.green.shade700,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _escolherImagem,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage:
                            _imagem != null ? FileImage(_imagem!) : null,
                        child:
                            _imagem == null
                                ? const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 40,
                                )
                                : null,
                        backgroundColor: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nomeController,
                    decoration: InputDecoration(
                      labelText: 'definicoes.nome'.tr(),
                    ),
                    onChanged: (value) {
                      try {
                        context.read<UserProvider>().update(nome: value);
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'definicoes.email'.tr(),
                    ),
                    onChanged: (value) {
                      try {
                        context.read<UserProvider>().update(email: value);
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _idiomaSelecionado,
                    items:
                        idiomas.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                    onChanged: (valor) {
                      if (valor == null) return;
                      setState(() => _idiomaSelecionado = valor);
                      context.setLocale(Locale(valor));
                      try {
                        context.read<UserProvider>().update(idioma: valor);
                      } catch (_) {}
                    },
                    decoration: InputDecoration(
                      labelText: 'definicoes.idioma'.tr(),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _guardarAlteracoes,
                    icon: const Icon(Icons.save),
                    label: Text('definicoes.guardar'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
    );
  }
}
