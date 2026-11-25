import 'dart:async';

import 'dart:convert';

import 'dart:math';



import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';



class ApiService {

  // ===================================================

  // GOOGLE APPS SCRIPT

  // ===================================================






static const String baseUrl =
    'https://script.google.com/macros/s/AKfycbz5t69jO8hwuvFAECWaFwCH3fsrytTATCJ6Szfo31qW5UEb6JtoHtlSqzAmSnDJU1si/exec';




  static const Duration timeout = Duration(seconds: 30);



  // ===================================================

  // IDENTIFICAÃ‡ÃƒO DO CLIENTE E VERSÃƒO

  // ===================================================



  static const String versaoAplicativo = '2.0.0+2';



  static String get identificacaoCliente {

    final cliente = kIsWeb ? 'flutter_web' : 'flutter_app';



    return '&cliente=$cliente'

        '&versao=${Uri.encodeComponent(versaoAplicativo)}';

  }



  // ===================================================

  // CHAVES DA SESSÃƒO SALVA

  // ===================================================



  static const String _chaveCodigo = 'sessao_codigo';

  static const String _chaveSessionId = 'sessao_session_id';



  // ===================================================

  // CHAVE DA TENTATIVA DE LOGIN

  // ===================================================



  static const String _chaveTentativaLogin = 'login_tentativa_id';

  static const String _chaveTentativaCodigo =

      'login_tentativa_codigo';



  // ===================================================

  // CHAVE DO IDENTIFICADOR DO APARELHO

  // ===================================================



  static const String _chaveDeviceId = 'dispositivo_id';



  // ===================================================

  // CONTROLE DA SESSÃƒO EM MEMÃ“RIA

  // ===================================================



  static String? _codigoSessao;

  static String? _sessionId;



  static String? get codigoSessao => _codigoSessao;

  static String? get sessionId => _sessionId;



  static bool get possuiSessao =>

      _codigoSessao != null &&

      _codigoSessao!.isNotEmpty &&

      _sessionId != null &&

      _sessionId!.isNotEmpty;



  // ===================================================

  // REQUEST COM RETRY (internet lenta)

  //

  // Repete a requisiÃ§Ã£o em caso de timeout. Ã‰ seguro

  // nas chamadas de LEITURA/RENOVAÃ‡ÃƒO, porque o servidor

  // Ã© idempotente nelas (mesma tentativa/dispositivo =

  // adota a sessÃ£o; leitura nÃ£o altera nada).

  //

  // NÃƒO usamos nas ESCRITAS (salvar/cancelar) para nÃ£o

  // arriscar duplicar plantÃ£o.

  // ===================================================



  static Future<http.Response> _getComRetry(

    Uri url, {

    int tentativas = 3,

    Duration intervalo = const Duration(seconds: 2),

  }) async {

    for (int i = 0; i < tentativas; i++) {

      try {

        return await http.get(url).timeout(timeout);

      } on TimeoutException {

        debugPrint(

          'Timeout na tentativa ${i + 1}/$tentativas...',

        );



        if (i == tentativas - 1) rethrow;



        await Future.delayed(intervalo);

      }

    }



    throw Exception('Falha de conexÃ£o.');

  }



  // ===================================================

  // NORMALIZAÃ‡ÃƒO DE CÃ“DIGO

  // ===================================================



  static String _normalizarCodigo(String valor) {

    return valor.trim().replaceAll(RegExp(r'^0+'), '');

  }



  // ===================================================

  // INICIALIZAR / RECUPERAR SESSÃƒO LOCAL

  // ===================================================



  static Future<void> inicializarSessao() async {

    try {

      final prefs = await SharedPreferences.getInstance();



      final codigo = prefs.getString(_chaveCodigo);

      final sessao = prefs.getString(_chaveSessionId);



      if (codigo != null &&

          codigo.isNotEmpty &&

          sessao != null &&

          sessao.isNotEmpty) {

        _codigoSessao = codigo;

        _sessionId = sessao;

      }

    } catch (e) {

      debugPrint('Inicializar sessÃ£o: erro: $e');

      _codigoSessao = null;

      _sessionId = null;

    }

  }



  // ===================================================

  // SALVAR SESSÃƒO LOCALMENTE

  // ===================================================



  static Future<void> _salvarSessaoLocal() async {

    if (!possuiSessao) return;



    try {

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_chaveCodigo, _codigoSessao!);

      await prefs.setString(_chaveSessionId, _sessionId!);

    } catch (e) {

      debugPrint('Salvar sessÃ£o local: erro: $e');

    }

  }



  // ===================================================

  // APAGAR SESSÃƒO LOCAL

  // ===================================================



  static Future<void> limparSessao() async {

    _codigoSessao = null;

    _sessionId = null;



    try {

      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_chaveCodigo);

      await prefs.remove(_chaveSessionId);

    } catch (e) {

      debugPrint('Limpar sessÃ£o: erro: $e');

    }

  }



  // ===================================================

  // GERAR IDENTIFICADOR ALEATÃ“RIO

  // ===================================================



  static String _gerarTentativaId() {

    final agora = DateTime.now().microsecondsSinceEpoch;



    final aleatorio =

        Random.secure().nextInt(0x7fffffff).toRadixString(16);



    return '$agora-$aleatorio';

  }



  // ===================================================

  // OBTER / CRIAR IDENTIFICADOR DO APARELHO

  // ===================================================



  static Future<String> _obterDeviceId() async {

    try {

      final prefs = await SharedPreferences.getInstance();



      var id = prefs.getString(_chaveDeviceId);



      if (id == null || id.trim().isEmpty) {

        id = _gerarTentativaId();

        await prefs.setString(_chaveDeviceId, id);

      }



      return id;

    } catch (e) {

      debugPrint('Obter device id: erro: $e');

      return _gerarTentativaId();

    }

  }



  // ===================================================

  // OBTER / CRIAR TENTATIVA DE LOGIN

  // ===================================================



  static Future<String> _obterTentativaLogin(

    String codigo,

  ) async {

    final prefs = await SharedPreferences.getInstance();



    final codigoTentativa =

        prefs.getString(_chaveTentativaCodigo);

    final tentativaExistente = prefs.getString(_chaveTentativaLogin);



    if (codigoTentativa == codigo &&

        tentativaExistente != null &&

        tentativaExistente.trim().isNotEmpty) {

      return tentativaExistente;

    }



    final novaTentativa = _gerarTentativaId();



    await prefs.setString(_chaveTentativaCodigo, codigo);

    await prefs.setString(_chaveTentativaLogin, novaTentativa);



    return novaTentativa;

  }



  // ===================================================

  // LIMPAR TENTATIVA DE LOGIN

  // ===================================================



  static Future<void> _limparTentativaLogin() async {

    try {

      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_chaveTentativaLogin);

      await prefs.remove(_chaveTentativaCodigo);

    } catch (e) {

      debugPrint('Limpar tentativa de login: erro: $e');

    }

  }



  // ===================================================

  // LOGIN

  // ===================================================



  static Future<Map<String, dynamic>> buscarAgente(

    String codigo, {

    bool forcar = false,

  }) async {

    try {

      final codigoNormalizado = _normalizarCodigo(codigo);



      if (codigoNormalizado.isEmpty) {

        return {

          'success': false,

          'mensagem': 'CÃ³digo nÃ£o informado.',

        };

      }



      final tentativaId =

          await _obterTentativaLogin(codigoNormalizado);

      final deviceId = await _obterDeviceId();



      debugPrint('========================================');

      debugPrint('INICIANDO LOGIN');

      debugPrint('CÃ³digo: $codigoNormalizado');

      debugPrint('Tentativa ID: $tentativaId');

      debugPrint('Device ID: $deviceId');

      debugPrint('ForÃ§ar: $forcar');

      debugPrint('========================================');



      final url = Uri.parse(

        '$baseUrl'

        '?tipo=agente'

        '&codigo=${Uri.encodeComponent(codigoNormalizado)}'

        '&tentativaId=${Uri.encodeComponent(tentativaId)}'

        '&deviceId=${Uri.encodeComponent(deviceId)}'

        '&forcar=${forcar ? 1 : 0}'

        '$identificacaoCliente'

        '&t=${DateTime.now().millisecondsSinceEpoch}',

      );



      // Retry: em internet lenta o login INSISTE.

      // Como o servidor reconhece a mesma tentativa/

      // dispositivo, ele ADOTA a sessÃ£o jÃ¡ criada.

      final response = await _getComRetry(url);



      debugPrint('Login HTTP: ${response.statusCode}');

      debugPrint('Login resposta: ${response.body}');



      if (response.statusCode != 200) {

        throw Exception('Erro de conexÃ£o.');

      }



      final body = jsonDecode(response.body);



      if (body is! Map) {

        throw Exception('Resposta invÃ¡lida do servidor.');

      }



      final resultado = Map<String, dynamic>.from(body);



      if (resultado['success'] == true) {

        final novaSessao = resultado['sessionId'];



        if (novaSessao == null ||

            novaSessao.toString().trim().isEmpty) {

          return {

            'success': false,

            'mensagem':

                'O servidor nÃ£o forneceu uma sessÃ£o vÃ¡lida.',

          };

        }



        _codigoSessao = codigoNormalizado;

        _sessionId = novaSessao.toString();



        await _salvarSessaoLocal();

        await _limparTentativaLogin();



        debugPrint('Login autorizado. Session ID: $_sessionId');



        return resultado;

      }



      debugPrint(

        'Login nÃ£o autorizado: '

        '${resultado['mensagem'] ?? 'sem mensagem'}',

      );



      return resultado;

    } on TimeoutException {

      debugPrint('LOGIN: timeout. Tentativa preservada.');

      throw Exception('Tempo de conexÃ£o esgotado.');

    } catch (e) {

      debugPrint('Buscar agente: erro: $e');

      throw Exception('Erro ao buscar agente.\n$e');

    }

  }



  // ===================================================

  // RECUPERAR SESSÃƒO

  // ===================================================



  static Future<Map<String, dynamic>> recuperarSessao() async {

    try {

      await inicializarSessao();



      if (!possuiSessao) {

        return {

          'success': false,

          'sessaoExpirada': true,

          'mensagem': 'Nenhuma sessÃ£o salva neste dispositivo.',

        };

      }



      final codigo = _codigoSessao!;

      final sessao = _sessionId!;



      final url = Uri.parse(

        '$baseUrl'

        '?tipo=recuperarSessao'

        '&codigo=${Uri.encodeComponent(codigo)}'

        '&sessionId=${Uri.encodeComponent(sessao)}'

        '$identificacaoCliente'

        '&t=${DateTime.now().millisecondsSinceEpoch}',

      );



      // Retry tambÃ©m aqui: abrir o app em rede lenta

      // nÃ£o deve travar.

      final response = await _getComRetry(url);



      if (response.statusCode != 200) {

        return {

          'success': false,

          'erroConexao': true,

          'mensagem': 'NÃ£o foi possÃ­vel verificar a sessÃ£o.',

        };

      }



      final body = jsonDecode(response.body);



      if (body is! Map) {

        return {

          'success': false,

          'erroConexao': true,

          'mensagem': 'Resposta invÃ¡lida do servidor.',

        };

      }



      final resultado = Map<String, dynamic>.from(body);



      if (resultado['success'] == true &&

          resultado['sessaoRecuperada'] == true) {

        _codigoSessao = codigo;

        _sessionId = sessao;



        await _salvarSessaoLocal();



        resultado['sessionId'] = sessao;

        resultado['sessaoRecuperada'] = true;



        return resultado;

      }



      if (resultado['sessaoExpirada'] == true) {

        await limparSessao();

        return resultado;

      }



      return {

        ...resultado,

        'success': false,

        'erroConexao': false,

      };

    } on TimeoutException {

      return {

        'success': false,

        'erroConexao': true,

        'mensagem':

            'Tempo de conexÃ£o esgotado. A sessÃ£o local foi preservada.',

      };

    } catch (e) {

      debugPrint('Recuperar sessÃ£o: erro: $e');

      return {

        'success': false,

        'erroConexao': true,

        'mensagem': 'NÃ£o foi possÃ­vel verificar a sessÃ£o.',

      };

    }

  }



  // ===================================================

  // BUSCAR VAGAS

  // ===================================================



  static Future<List<dynamic>> buscarVagas({

    required String ano,

    required String mes,

  }) async {

    try {

      if (!possuiSessao) {

        throw Exception(

          'SessÃ£o nÃ£o encontrada. FaÃ§a login novamente.',

        );

      }



      final parametros = StringBuffer(

        '$baseUrl'

        '?tipo=vagas'

        '&ano=${Uri.encodeComponent(ano)}'

        '&mes=${Uri.encodeComponent(mes)}'

        '&codigo=${Uri.encodeComponent(_codigoSessao!)}'

        '&sessionId=${Uri.encodeComponent(_sessionId!)}',

      );



      parametros.write(identificacaoCliente);

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}');



      final url = Uri.parse(parametros.toString());



      final response = await _getComRetry(url);



      if (response.statusCode != 200) {

        throw Exception('Erro ao buscar vagas.');

      }



      final body = jsonDecode(response.body);



      if (body is List) {

        return List<dynamic>.from(body);

      }



      if (body is Map) {

        final resultado = Map<String, dynamic>.from(body);



        if (resultado['sessaoExpirada'] == true) {

          await limparSessao();

          throw Exception(

            resultado['mensagem']?.toString() ??

                'SessÃ£o invÃ¡lida ou encerrada.',

          );

        }



        throw Exception(

          resultado['mensagem']?.toString() ??

              'Erro ao buscar vagas.',

        );

      }



      throw Exception('Resposta invÃ¡lida ao buscar vagas.');

    } on TimeoutException {

      throw Exception('Tempo de conexÃ£o esgotado.');

    } catch (e) {
      if (e.toString().contains('Falha de conexÃ£o.')) {
        throw Exception('Falha de conexÃ£o.');
      }

      debugPrint('Buscar vagas: erro: $e');

      throw Exception('Erro ao buscar vagas.\n$e');

    }

  }



  // ===================================================

  // SALVAR INSCRIÃ‡ÃƒO

  //

  // SEM retry de propÃ³sito: repetir uma escrita pode

  // duplicar plantÃ£o. O servidor Ã© idempotente (recusa

  // "jÃ¡ tem plantÃ£o no dia"), mas por seguranÃ§a a

  // escrita fica com tentativa Ãºnica.

  // ===================================================



  static Future<Map<String, dynamic>> salvarInscricao({

    required String ano,

    required String mes,

    required String codigo,

    required String matricula,

    required String nome,

    required List<Map<String, dynamic>> datas,

  }) async {

    try {

      if (!possuiSessao) {

        return {

          'success': false,

          'sessaoExpirada': true,

          'mensagem':

              'SessÃ£o nÃ£o encontrada. FaÃ§a login novamente.',

        };

      }



      final jsonDatas = jsonEncode(datas);



      final parametros = StringBuffer(

        '$baseUrl'

        '?tipo=salvarInscricao'

        '&ano=${Uri.encodeComponent(ano)}'

        '&mes=${Uri.encodeComponent(mes)}'

        '&codigo=${Uri.encodeComponent(codigo)}'

        '&matricula=${Uri.encodeComponent(matricula)}'

        '&nome=${Uri.encodeComponent(nome)}'

        '&datas=${Uri.encodeComponent(jsonDatas)}'

        '&sessionId=${Uri.encodeComponent(_sessionId!)}',

      );



      parametros.write(identificacaoCliente);

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}');



      final response = await http

          .get(Uri.parse(parametros.toString()))

          .timeout(timeout);



      if (response.statusCode != 200) {

        throw Exception('Erro ao salvar inscriÃ§Ã£o.');

      }



      final body = jsonDecode(response.body);



      if (body is! Map) {

        throw Exception('Resposta invÃ¡lida ao salvar inscriÃ§Ã£o.');

      }



      final resultado = Map<String, dynamic>.from(body);



      if (resultado['sessaoExpirada'] == true) {

        await limparSessao();

      }



      return resultado;

    } on TimeoutException {

      throw Exception('Tempo de conexÃ£o esgotado.');

    } catch (e) {
      if (e.toString().contains('Falha de conexÃ£o.')) {
        throw Exception('Falha de conexÃ£o.');
      }

      throw Exception('Erro ao salvar inscriÃ§Ã£o.\n$e');

    }

  }



  // ===================================================

  // CANCELAR INSCRIÃ‡ÃƒO

  //

  // Cancelamento Ã© idempotente no servidor (sÃ³ apaga o

  // que existe), mas mantemos tentativa Ãºnica por

  // simplicidade e previsibilidade.

  // ===================================================



  static Future<Map<String, dynamic>> cancelarInscricao({

    required String codigo,

    required List<Map<String, dynamic>> datas,

  }) async {

    try {

      if (!possuiSessao) {

        return {

          'success': false,

          'sessaoExpirada': true,

          'mensagem':

              'SessÃ£o nÃ£o encontrada. FaÃ§a login novamente.',

        };

      }



      final jsonDatas = jsonEncode(datas);



      final parametros = StringBuffer(

        '$baseUrl'

        '?tipo=cancelarInscricao'

        '&codigo=${Uri.encodeComponent(codigo)}'

        '&datas=${Uri.encodeComponent(jsonDatas)}'

        '&sessionId=${Uri.encodeComponent(_sessionId!)}',

      );



      parametros.write(identificacaoCliente);

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}');



      final response = await http

          .get(Uri.parse(parametros.toString()))

          .timeout(timeout);



      if (response.statusCode != 200) {

        throw Exception('Erro ao cancelar inscriÃ§Ã£o.');

      }



      final body = jsonDecode(response.body);



      if (body is! Map) {

        throw Exception('Resposta invÃ¡lida ao cancelar inscriÃ§Ã£o.');

      }



      final resultado = Map<String, dynamic>.from(body);



      if (resultado['sessaoExpirada'] == true) {

        await limparSessao();

      }



      return resultado;

    } on TimeoutException {

      throw Exception('Tempo de conexÃ£o esgotado.');

    } catch (e) {

      throw Exception('Erro ao cancelar inscriÃ§Ã£o.\n$e');

    }

  }



  // ===================================================

  // MINHAS INSCRIÃ‡Ã•ES

  // ===================================================



  static Future<List<Map<String, dynamic>>> buscarMinhasInscricoes(

    String codigo,

  ) async {

    try {

      if (!possuiSessao) return [];



      final parametros = StringBuffer(

        '$baseUrl'

        '?tipo=minhas'

        '&codigo=${Uri.encodeComponent(codigo)}'

        '&sessionId=${Uri.encodeComponent(_sessionId!)}',

      );



      parametros.write(identificacaoCliente);

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}');



      final response = await _getComRetry(

        Uri.parse(parametros.toString()),

      );



      if (response.statusCode != 200) {

        throw Exception('Erro ao buscar inscriÃ§Ãµes.');

      }



      final body = jsonDecode(response.body);



      if (body is Map) {

        final resultado = Map<String, dynamic>.from(body);



        if (resultado['sessaoExpirada'] == true) {

          await limparSessao();

        }



        throw Exception(

          resultado['mensagem'] ?? 'Erro ao buscar inscriÃ§Ãµes.',

        );

      }



      if (body is! List) {

        throw Exception('Resposta invÃ¡lida ao buscar inscriÃ§Ãµes.');

      }



      final dados = List<dynamic>.from(body);



      return dados

          .map((e) => Map<String, dynamic>.from(e))

          .toList();

    } on TimeoutException {

      throw Exception('Tempo de conexÃ£o esgotado.');

    } catch (e) {
      if (e.toString().contains('Falha de conexÃ£o.')) {
        throw Exception('Falha de conexÃ£o.');
      }

      throw Exception('Erro ao buscar inscriÃ§Ãµes.\n$e');

    }

  }



  // ===================================================

  // DADOS INICIAIS

  // ===================================================



  static Future<Map<String, dynamic>> buscarInicial({

    required String codigo,

  }) async {

    try {

      if (!possuiSessao) {

        return {

          'success': false,

          'sessaoExpirada': true,

          'mensagem':

              'SessÃ£o nÃ£o encontrada. FaÃ§a login novamente.',

        };

      }



      final parametros = StringBuffer(

        '$baseUrl'

        '?tipo=inicial'

        '&codigo=${Uri.encodeComponent(codigo)}'

        '&sessionId=${Uri.encodeComponent(_sessionId!)}',

      );



      parametros.write(identificacaoCliente);

      parametros.write('&t=${DateTime.now().millisecondsSinceEpoch}');



      final response = await _getComRetry(

        Uri.parse(parametros.toString()),

      );



      if (response.statusCode != 200) {

        throw Exception('Erro ao buscar dados iniciais.');

      }



      final body = jsonDecode(response.body);



      if (body is! Map) {

        throw Exception('Resposta invÃ¡lida ao buscar dados iniciais.');

      }



      final resultado = Map<String, dynamic>.from(body);



      if (resultado['sessaoExpirada'] == true) {

        await limparSessao();

      }



      return resultado;

    } on TimeoutException {

      throw Exception('Tempo de conexÃ£o esgotado.');

    } catch (e) {
      if (e.toString().contains('Falha de conexÃ£o.')) {
        throw Exception('Falha de conexÃ£o.');
      }

      throw Exception('Erro ao buscar dados iniciais.\n$e');

    }

  }



  // ===================================================

  // RELATÃ“RIO ADMINISTRATIVO

  // ===================================================



  static Future<List<dynamic>> buscarInscricoesPDF() async {

    try {

      await inicializarSessao();



      if (!possuiSessao) {

        throw Exception(

          'SessÃ£o do administrador nÃ£o encontrada. '

          'FaÃ§a login novamente.',

        );

      }



      final codigo = _codigoSessao!;

      final sessionId = _sessionId!;



      final url = Uri.parse(

        '$baseUrl'

        '?tipo=relatorio'

        '&codigo=${Uri.encodeComponent(codigo)}'

        '&sessionId=${Uri.encodeComponent(sessionId)}'

        '$identificacaoCliente'

        '&t=${DateTime.now().millisecondsSinceEpoch}',

      );



      final response = await _getComRetry(url);



      if (response.statusCode != 200) {

        throw Exception(

          'Erro ao buscar relatÃ³rio. CÃ³digo HTTP: ${response.statusCode}',

        );

      }



      final body = jsonDecode(response.body);



      if (body is List) {

        return List<dynamic>.from(body);

      }



      if (body is Map) {

        final resultado = Map<String, dynamic>.from(body);



        if (resultado['sessaoExpirada'] == true) {

          await limparSessao();

          throw Exception(

            resultado['mensagem']?.toString() ??

                'SessÃ£o do administrador invÃ¡lida ou encerrada.',

          );

        }



        const possiveisChaves = [

          'dados',

          'inscricoes',

          'lista',

          'resultado',

          'data',

        ];



        for (final chave in possiveisChaves) {

          final valor = resultado[chave];

          if (valor is List) {

            return List<dynamic>.from(valor);

          }

        }



        final mensagem = resultado['mensagem'] ??

            resultado['erro'] ??

            resultado['error'];



        if (mensagem != null) {

          throw Exception(mensagem.toString());

        }



        throw Exception(

          'O servidor retornou uma resposta inesperada ao buscar o relatÃ³rio.',

        );

      }



      throw Exception('Resposta invÃ¡lida ao buscar relatÃ³rio.');

    } on TimeoutException {

      throw Exception('Tempo de conexÃ£o esgotado.');

    } catch (e) {

      debugPrint('ERRO RELATÃ“RIO: $e');

      throw Exception('Erro ao buscar relatÃ³rio.\n$e');

    }

  }

  // ===================================================
  // TRAVA DE TESTE â€” ADMINISTRADOR
  // HEARTBEAT

  // ===================================================



  static Future<bool> heartbeat() async {

    if (!possuiSessao) return false;



    try {

      final url = Uri.parse(

        '$baseUrl'

        '?tipo=heartbeat'

        '&codigo=${Uri.encodeComponent(_codigoSessao!)}'

        '&sessionId=${Uri.encodeComponent(_sessionId!)}'

        '$identificacaoCliente'

        '&t=${DateTime.now().millisecondsSinceEpoch}',

      );



      final response = await http.get(url).timeout(timeout);



      if (response.statusCode != 200) return true;



      final body = jsonDecode(response.body);



      if (body is! Map) return true;



      final resultado = Map<String, dynamic>.from(body);



      if (resultado['success'] == true) return true;



      if (resultado['sessaoExpirada'] == true) {

        await limparSessao();

        return false;

      }



      return true;

    } catch (e) {

      debugPrint('Heartbeat: erro de conexÃ£o: $e');

      return true;

    }

  }



  // ===================================================

  // LOGOUT

  // ===================================================



  static Future<bool> logout() async {

    final codigo = _codigoSessao;

    final sessao = _sessionId;



    // SEMPRE limpa o local primeiro.

    await limparSessao();

    await _limparTentativaLogin();



    if (codigo == null ||

        codigo.isEmpty ||

        sessao == null ||

        sessao.isEmpty) {

      return true;

    }



    // Avisa o servidor em melhor esforÃ§o.

    try {

      final deviceId = await _obterDeviceId();



      final url = Uri.parse(

        '$baseUrl'

        '?tipo=logout'

        '&codigo=${Uri.encodeComponent(codigo)}'

        '&sessionId=${Uri.encodeComponent(sessao)}'

        '&deviceId=${Uri.encodeComponent(deviceId)}'

        '$identificacaoCliente'

        '&t=${DateTime.now().millisecondsSinceEpoch}',

      );



      final response = await http

          .get(url)

          .timeout(const Duration(seconds: 10));



      return response.statusCode == 200;

    } catch (e) {

      debugPrint('Logout: falha ao avisar o servidor: $e');

      return false;

    }

  }

}

