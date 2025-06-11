import 'package:flutter/material.dart';

/// Modelo simples que guarda os dados do utilizador
/// e notifica os widgets que os consomem sempre que muda.
class UserProvider extends ChangeNotifier {
  String nome;
  String email;
  String? fotoPath; // caminho local da imagem
  String idioma;    // 'pt', 'en', 'es', ...

  UserProvider({
    required this.nome,
    required this.email,
    this.fotoPath,
    required this.idioma,
  });

  /// Actualiza campos fornecidos e notifica listeners.
  void update({String? nome, String? email, String? fotoPath, String? idioma}) {
    bool changed = false;
    if (nome != null && nome != this.nome) {
      this.nome = nome;
      changed = true;
    }
    if (email != null && email != this.email) {
      this.email = email;
      changed = true;
    }
    if (fotoPath != null && fotoPath != this.fotoPath) {
      this.fotoPath = fotoPath;
      changed = true;
    }
    if (idioma != null && idioma != this.idioma) {
      this.idioma = idioma;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}