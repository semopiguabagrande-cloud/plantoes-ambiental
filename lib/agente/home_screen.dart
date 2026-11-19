import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final String codigo;
  final String nome;
  final String matricula;
  final bool ferias;

  const HomeScreen({
    super.key,
    required this.codigo,
    required this.nome,
    required this.matricula,
    this.ferias = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  String mesAberto = '';

  List<dynamic> vagas = [];

  final List<Map<String, dynamic>> meusDias = [];

  List<Map<String, dynamic>> confirmadas = [];

  bool _carregandoInicial = true;

  bool enviando = false;

  Timer? _heartbeat;

  // Férias vem do servidor (sempre atualizado).
  bool _ferias = false;

  int get limitePlantao => _ferias ? 10 : 8;

  List<Map<String, dynamic>> get confirmadasVisiveis {
    final lista = List<Map<String, dynamic>>.from(confirmadas);

    lista.sort(
      (a, b) => _compararData(
        a['data']?.toString() ?? '',
        b['data']?.toString() ?? '',
      ),
    );

    return lista;
  }

  int get totalEscolhido =>
      confirmadasVisiveis.length + meusDias.length;

  bool get limiteAtingido => totalEscolhido >= limitePlantao;

  // ===================================================
  // INIT
  // ===================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    carregarTudo();
    _iniciarHeartbeat();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ===================================================
  // HEARTBEAT
  // ===================================================

  void _iniciarHeartbeat() {
    _heartbeat?.cancel();

    _heartbeat = Timer.periodic(
      const Duration(seconds: 60),
      (_) async {
        if (!ApiService.possuiSessao) {
          await _reloginSilencioso();
          return;
        }

        final ok = await ApiService.heartbeat();

        if (!ok) {
          await _reloginSilencioso();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ApiService.heartbeat();
      _iniciarHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _heartbeat?.cancel();
    }
  }

  // ===================================================
  // REAUTENTICAÇÃO SILENCIOSA
  // ===================================================

  Future<bool> _reloginSilencioso() async {
    try {
      var r = await ApiService.buscarAgente(widget.codigo);

      if (r['success'] == true) return true;

      if (r['codigoConflito'] == true) {
        r = await ApiService.buscarAgente(
          widget.codigo,
          forcar: true,
        );

        return r['success'] == true;
      }

      return false;
    } catch (e) {
      debugPrint('Relogin silencioso falhou: $e');
      return false;
    }
  }

  // ===================================================
  // MENSAGENS
  // ===================================================

  void _mostrarErro(Object erro) {
    if (!mounted) return;

    var msg = erro.toString();
    msg = msg.replaceFirst('Exception: ', '');
    msg = msg.replaceFirst('Erro ao buscar vagas.\n', '');
    msg = msg.replaceFirst('Erro ao buscar inscrições.\n', '');
    msg = msg.replaceFirst('Erro ao salvar inscrição.\n', '');
    msg = msg.replaceFirst('Erro ao cancelar inscrição.\n', '');
    msg = msg.replaceFirst('Erro ao buscar dados iniciais.\n', '');
    msg = msg.replaceFirst('Erro ao buscar agente.\n', '');
    msg = msg.replaceFirst(
      'Tempo de conexão esgotado.',
      'Tempo esgotado. Tente novamente.',
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarSucesso(String texto) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(
          texto,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ===================================================
  // LOGOUT
  // ===================================================

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sair'),
          content: const Text(
            'Deseja realmente encerrar a sessão?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    _heartbeat?.cancel();

    await ApiService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ===================================================
  // CARREGAR
  // ===================================================

  Future<void> carregarTudo({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() => _carregandoInicial = true);
    }

    try {
      var resultado =
          await ApiService.buscarInicial(codigo: widget.codigo);

      if (resultado['success'] != true &&
          resultado['sessaoExpirada'] == true) {
        final reok = await _reloginSilencioso();

        if (reok) {
          resultado =
              await ApiService.buscarInicial(codigo: widget.codigo);
        }
      }

      if (!mounted) return;

      if (resultado['success'] == true) {
        final vagasLista = resultado['vagas'];
        final minhasLista = resultado['minhas'];

        // Férias — lê do servidor.
        final agenteResp = resultado['agente'];

        if (agenteResp is Map) {
          _ferias = _lerFerias(agenteResp['ferias']);
        }

        debugPrint(
          'Férias do agente: $_ferias → limite $limitePlantao',
        );

        setState(() {
          mesAberto = (resultado['mesAberto'] ?? '').toString();

          vagas = vagasLista is List
              ? List<dynamic>.from(vagasLista)
              : [];

          confirmadas = (minhasLista is List)
              ? minhasLista.whereType<Map>().map((e) {
                  // Algumas linhas antigas da planilha foram gravadas
                  // com os campos deslocados. Se "data" não for uma
                  // data válida, tenta recuperar a data de "timestamp".
                  final dataBruta = _dataInscricao(e);
                  final data = normalizarData(dataBruta);
                  final turno = _turnoInscricao(e['turno']);

                  return <String, dynamic>{
                    'data': data,
                    'turno': turno,
                  };
                }).where((e) => _paraData(e['data'].toString()) != null)
                    .toList()
              : [];

          if (mesAberto.isEmpty) {
            if (vagas.isNotEmpty) {
              mesAberto = _mesDaData(
                normalizarData(vagas.first['data']),
              );
            } else if (confirmadas.isNotEmpty) {
              mesAberto = _mesDaData(
                confirmadas.first['data']?.toString() ?? '',
              );
            }
          }

          _carregandoInicial = false;
        });

        debugPrint('=== HOME ===');
        debugPrint('Mês aberto: $mesAberto');
        debugPrint('Vagas: ${vagas.length}');
        debugPrint('Confirmadas: ${confirmadas.length}');
        debugPrint('============');

        // =================================================
        // RECONCILIA A SELEÇÃO
        //
        // Desmarca automaticamente qualquer dia "A confirmar"
        // que já não tenha vaga (ou que já foi confirmado).
        // =================================================
        _reconciliarSelecao();

        return;
      }

      setState(() => _carregandoInicial = false);
      _mostrarErro(
        resultado['mensagem']?.toString() ??
            'Não foi possível carregar os dados.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _carregandoInicial = false);
      _mostrarErro(e);
    }
  }

  // ===================================================
  // RECONCILIAÇÃO DA SELEÇÃO
  //
  // Remove de "A confirmar" os dias que:
  //   - já não têm vaga; ou
  //   - já estão confirmados.
  //
  // É isso que desmarca automaticamente o dia que o
  // agente perdeu na corrida.
  // ===================================================

  void _reconciliarSelecao() {
    if (!mounted || meusDias.isEmpty) return;

    final remover = <String>[];

    for (final item in meusDias) {
      final data = item['data'].toString();
      final turno = item['turno'].toString();

      final chave = '$data|$turno';

      // Já confirmado por este agente?
      if (_confirmadaDoDia(data) != null) {
        remover.add(chave);
        continue;
      }

      final vaga = _vagaDoDia(data);

      // Dia sumiu da lista de vagas?
      if (vaga == null) {
        remover.add(chave);
        continue;
      }

      // Sem vaga no turno escolhido?
      if (_restantesDoTurno(vaga, turno) <= 0) {
        remover.add(chave);
      }
    }

    if (remover.isNotEmpty) {
      debugPrint('Reconciliação: removendo $remover');

      setState(() {
        meusDias.removeWhere(
          (m) => remover.contains('${m['data']}|${m['turno']}'),
        );
      });
    }
  }

  // ===================================================
  // HELPERS
  // ===================================================

  Map<String, dynamic>? _vagaDoDia(String data) {
    for (final v in vagas) {
      if (normalizarData(v['data']) == data) {
        return Map<String, dynamic>.from(v);
      }
    }
    return null;
  }

  int _restantesDoTurno(
    Map<String, dynamic> vaga,
    String turno,
  ) {
    final t = turno.toUpperCase();

    if (t == 'NOITE') {
      return int.tryParse(
            vaga['restantesNoite']?.toString() ?? '',
          ) ??
          0;
    }

    return int.tryParse(
          vaga['restantesDia']?.toString() ?? '',
        ) ??
        0;
  }

  // Aceita true, "SIM", "TRUE".
  bool _lerFerias(dynamic valor) {
    if (valor == true) return true;

    final t = valor.toString().trim().toUpperCase();

    return t == 'SIM' || t == 'TRUE';
  }

  // "dd/MM/yyyy" → "yyyy-MM"
  String _mesDaData(String data) {
    final partes = data.split('/');

    if (partes.length != 3) return '';

    return '${partes[2]}-${partes[1]}';
  }

  String _formatarMesAberto(String chave) {
    if (chave.length < 7) return chave;

    final partes = chave.split('-');
    if (partes.length != 2) return chave;

    final ano = partes[0];
    final mesNum = int.tryParse(partes[1]);

    if (mesNum == null || mesNum < 1 || mesNum > 12) return chave;

    const nomes = [
      'JANEIRO',
      'FEVEREIRO',
      'MARÇO',
      'ABRIL',
      'MAIO',
      'JUNHO',
      'JULHO',
      'AGOSTO',
      'SETEMBRO',
      'OUTUBRO',
      'NOVEMBRO',
      'DEZEMBRO',
    ];

    return '${nomes[mesNum - 1]}/$ano';
  }

  // Normaliza datas vindas da API/Google Sheets para dd/MM/yyyy.
  // Aceita yyyy-MM-dd, yyyy-MM-ddTHH:mm:ss e dd/MM/yyyy.
  String normalizarData(dynamic valor) {
    final texto = (valor ?? '').toString().trim();
    if (texto.isEmpty) return '';

    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})')
        .firstMatch(texto);

    if (iso != null) {
      return '${iso.group(3)}/${iso.group(2)}/${iso.group(1)}';
    }

    final brasileira =
        RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto);

    if (brasileira != null) {
      return '${brasileira.group(1)}/${brasileira.group(2)}/${brasileira.group(3)}';
    }

    return texto;
  }

  // Recupera a data de uma inscrição. A planilha antiga teve alguns
  // registros gravados com os valores deslocados: nesses casos, a data
  // pode ter ficado na coluna timestamp.
  String _dataInscricao(Map registro) {
    final data = (registro['data'] ?? '').toString().trim();
    if (_pareceData(data)) return data;

    final timestamp = (registro['timestamp'] ?? '').toString().trim();
    if (_pareceData(timestamp)) return timestamp;

    return '';
  }

  bool _pareceData(String valor) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(valor) ||
        RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(valor);
  }

  String _turnoInscricao(dynamic valor) {
    final turno = (valor ?? '').toString().trim().toUpperCase();

    // O sistema da Guarda Ambiental usa uma única modalidade de plantão.
    if (turno == 'DIA' || turno == 'NOITE' || turno == 'UNICO') {
      return 'UNICO';
    }

    // Linhas antigas podem conter CONFIRMADA na coluna turno.
    return 'UNICO';
  }

  DateTime? _paraData(String texto) {
    final partes = texto.split('/');

    if (partes.length != 3) return null;

    final dia = int.tryParse(partes[0]);
    final mesNum = int.tryParse(partes[1]);
    final anoNum = int.tryParse(partes[2]);

    if (dia == null || mesNum == null || anoNum == null) {
      return null;
    }

    return DateTime(anoNum, mesNum, dia);
  }

  int _compararData(String a, String b) {
    final da = _paraData(a);
    final db = _paraData(b);

    if (da == null || db == null) return 0;

    return da.compareTo(db);
  }

  String _rotuloTurno(String turno) {
    final t = turno.toUpperCase();
    if (t == 'UNICO') return 'Plantão';
    return t;
  }

  Map<String, dynamic>? _confirmadaDoDia(String data) {
    for (final e in confirmadas) {
      if (e['data'] == data) return e;
    }
    return null;
  }

  bool estaSelecionado(String data, String turno) {
    return meusDias.any(
      (item) =>
          item['data'] == data && item['turno'] == turno,
    );
  }

  // ===================================================
  // SELEÇÃO
  // ===================================================

  void selecionarPlantao(String data, String turno) {
    if (enviando) return;

    final confirmada = _confirmadaDoDia(data);

    if (confirmada != null) {
      _mostrarErro(
        'Você já tem plantão confirmado em $data. '
        'Desmarque o confirmado (X no chip verde) para trocar.',
      );
      return;
    }

    if (estaSelecionado(data, turno)) {
      setState(() {
        meusDias.removeWhere(
          (item) =>
              item['data'] == data && item['turno'] == turno,
        );
      });
      return;
    }

    final jaTemNoDia =
        meusDias.any((item) => item['data'] == data);

    if (!jaTemNoDia && totalEscolhido >= limitePlantao) {
      _mostrarErro(
        'Você já atingiu o limite de $limitePlantao '
        'plantões neste mês.\n\n'
        'Para escolher outro dia, cancele um já '
        'confirmado (X no chip verde) ou desmarque '
        'um da lista "A confirmar".',
      );
      return;
    }

    setState(() {
      meusDias.removeWhere((item) => item['data'] == data);

      meusDias.add({
        'data': data,
        'turno': turno,
      });
    });
  }

  // ===================================================
  // SALVAR
  // ===================================================

  Future<void> confirmarPlantao() async {
    if (meusDias.isEmpty) {
      _mostrarErro('Selecione ao menos um plantão.');
      return;
    }

    setState(() => enviando = true);

    final preferencias = meusDias.map((item) {
      return <String, dynamic>{
        'data': item['data'],
        'turno': item['turno'],
      };
    }).toList();

    try {
      final partesMesAberto = mesAberto.split('-');
      final anoPlantao = partesMesAberto.length == 2
          ? partesMesAberto[0]
          : DateTime.now().year.toString();
      final mesPlantao = partesMesAberto.length == 2
          ? partesMesAberto[1]
          : DateTime.now().month.toString().padLeft(2, '0');

      var resposta = await ApiService.salvarInscricao(
        ano: anoPlantao,
        mes: mesPlantao,
        codigo: widget.codigo,
        matricula: widget.matricula,
        nome: widget.nome,
        datas: preferencias,
      );

      if (resposta['success'] != true &&
          resposta['sessaoExpirada'] == true) {
        final reok = await _reloginSilencioso();

        if (reok) {
          resposta = await ApiService.salvarInscricao(
            ano: anoPlantao,
            mes: mesPlantao,
            codigo: widget.codigo,
            matricula: widget.matricula,
            nome: widget.nome,
            datas: preferencias,
          );
        }
      }

      if (!mounted) return;

      final sucesso = resposta['success'] == true ||
          resposta['sucesso'] == true;

      // =================================================
      // FALHOU (ex.: perdeu a corrida da última vaga)
      // =================================================

      if (!sucesso) {
        // Se o servidor indicar QUAL dia falhou, desmarca
        // ele imediatamente para o usuário ver na hora.
        final dataConflito =
            (resposta['data'] ?? '').toString().trim();

        if (dataConflito.isNotEmpty) {
          setState(() {
            meusDias.removeWhere(
              (item) => item['data'] == dataConflito,
            );
          });
        }

        _mostrarErro(
          resposta['mensagem']?.toString() ??
              'Não foi possível salvar a inscrição.',
        );

        // Recarrega as vagas e RECONCILIA (desmarca o que
        // ficou sem vaga — inclusive sem o campo "data").
        await carregarTudo(silencioso: true);
        return;
      }

      // =================================================
      // SUCESSO
      // =================================================

      _mostrarSucesso(
        resposta['mensagem']?.toString() ??
            'Inscrição salva com sucesso.',
      );

      setState(() => meusDias.clear());

      await carregarTudo(silencioso: true);
    } catch (e) {
      if (!mounted) return;
      _mostrarErro(e);
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  // ===================================================
  // CANCELAR
  // ===================================================

  Future<void> _cancelarPlantao(
    String data,
    String turno,
  ) async {
    if (enviando) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar plantão'),
          content: Text(
            'Deseja cancelar o plantão de $data '
            '(${_rotuloTurno(turno)})?\n\n'
            'A vaga voltará a ficar disponível.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('NÃO'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('CANCELAR PLANTÃO'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    setState(() => enviando = true);

    try {
      var resposta = await ApiService.cancelarInscricao(
        codigo: widget.codigo,
        datas: [
          {
            'data': data,
            'turno': turno,
          }
        ],
      );

      if (resposta['success'] != true &&
          resposta['sessaoExpirada'] == true) {
        final reok = await _reloginSilencioso();

        if (reok) {
          resposta = await ApiService.cancelarInscricao(
            codigo: widget.codigo,
            datas: [
              {
                'data': data,
                'turno': turno,
              }
            ],
          );
        }
      }

      if (!mounted) return;

      final sucesso = resposta['success'] == true ||
          resposta['sucesso'] == true;

      if (!sucesso) {
        _mostrarErro(
          resposta['mensagem']?.toString() ??
              'Não foi possível cancelar o plantão.',
        );
        return;
      }

      _mostrarSucesso(
        'Plantão de $data cancelado. Vaga liberada.',
      );

      await carregarTudo(silencioso: true);
    } catch (e) {
      if (!mounted) return;
      _mostrarErro(e);
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  // ===================================================
  // COMPONENTES
  // ===================================================

  Widget _badge(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: cor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _chipsHorizontal({
    required List<Widget> chips,
    double altura = 40,
  }) {
    return SizedBox(
      height: altura,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),

        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _bannerMesAberto() {
    final definido = mesAberto.isNotEmpty;

    return Card(
      color: definido
          ? Colors.blue.withValues(alpha: 0.12)
          : Colors.orange.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: definido
              ? Colors.lightBlueAccent
              : Colors.orangeAccent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              definido ? Icons.event_available : Icons.event_busy,
              color: definido
                  ? Colors.lightBlueAccent
                  : Colors.orangeAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MÊS ABERTO',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    definido
                        ? _formatarMesAberto(mesAberto)
                        : 'Não definido',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardContador() {
    final atingiu = limiteAtingido;

    return Card(
      color: atingiu ? Colors.red.withValues(alpha: 0.15) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: atingiu
            ? const BorderSide(color: Colors.redAccent)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ferias
                      ? 'Plantões escolhidos (FÉRIAS)'
                      : 'Plantões escolhidos',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (atingiu)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'LIMITE MÁXIMO ATINGIDO',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              '$totalEscolhido/$limitePlantao',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: atingiu
                    ? Colors.redAccent
                    : Colors.amberAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoConfirmados() {
    final lista = confirmadasVisiveis;

    final chips = lista.map((e) {
      final data = e['data'].toString();
      final turno = e['turno'].toString();

      return Chip(
        visualDensity: VisualDensity.compact,
        avatar: const Icon(
          Icons.event_available,
          size: 18,
          color: Colors.greenAccent,
        ),
        label: Text('$data · ${_rotuloTurno(turno)}'),
        backgroundColor: Colors.white10,
        deleteIconColor: Colors.redAccent,
        onDeleted: enviando
            ? null
            : () => _cancelarPlantao(data, turno),
      );
    }).toList();

    return Card(
      color: Colors.green.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Plantões confirmados (${lista.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.swipe,
                  size: 16,
                  color: Colors.white38,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Deslize para o lado · toque no X para cancelar.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 10),
            _chipsHorizontal(chips: chips),
          ],
        ),
      ),
    );
  }

  Widget _secaoPendentes() {
    final chips = meusDias.map((e) {
      return Chip(
        visualDensity: VisualDensity.compact,
        label: Text(
          '${e['data']} · ${_rotuloTurno(e['turno']?.toString() ?? 'DIA')}',
        ),
        backgroundColor: Colors.white10,
        onDeleted: enviando
            ? null
            : () {
                setState(() {
                  meusDias.removeWhere(
                    (item) =>
                        item['data'] == e['data'] &&
                        item['turno'] == e['turno'],
                  );
                });
              },
      );
    }).toList();

    return Card(
      color: Colors.amber.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.pending_actions,
                  color: Colors.amberAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'A confirmar (${meusDias.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.swipe,
                  size: 16,
                  color: Colors.white38,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _chipsHorizontal(chips: chips),
          ],
        ),
      ),
    );
  }

  Widget construirOpcaoTurno({
    required String data,
    required String turno,
    required int restantes,
  }) {
    final selecionado = estaSelecionado(data, turno);
    final indisponivel = restantes <= 0;

    final jaTemNoDia =
        meusDias.any((item) => item['data'] == data);

    final bloqueadoPorLimite =
        !selecionado && !jaTemNoDia && limiteAtingido;

    String subtitulo;

    if (indisponivel) {
      subtitulo = 'Sem vagas disponíveis';
    } else if (bloqueadoPorLimite) {
      subtitulo = 'Limite de $limitePlantao plantões atingido';
    } else {
      subtitulo = '$restantes vaga(s) disponível(is)';
    }

    return CheckboxListTile(
      value: selecionado,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        _rotuloTurno(turno),
        style: bloqueadoPorLimite
            ? const TextStyle(color: Colors.white38)
            : null,
      ),
      subtitle: Text(
        subtitulo,
        style: bloqueadoPorLimite
            ? const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              )
            : null,
      ),
      onChanged: indisponivel || enviando
          ? null
          : (_) => selecionarPlantao(data, turno),
    );
  }

  Widget construirCartaoVaga(dynamic vaga) {
    final data = normalizarData(vaga['data']);

    final restantesDia =
        int.tryParse(vaga['restantesDia']?.toString() ?? '') ?? 0;

    // Guarda Ambiental: existe apenas uma modalidade de plantão por data.
    final confirmada = _confirmadaDoDia(data);
    final semVaga = confirmada == null && restantesDia <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (confirmada != null)
                    _badge('CONFIRMADO', Colors.greenAccent)
                  else if (semVaga)
                    _badge('LOTADO', Colors.redAccent),
                ],
              ),
            ),

            if (confirmada != null)
              CheckboxListTile(
                value: true,
                dense: true,
                controlAffinity:
                    ListTileControlAffinity.leading,
                title: const Text('Plantão'),
                subtitle: const Text(
                  'Confirmado — desmarque para cancelar',
                ),
                onChanged: enviando
                    ? null
                    : (_) => _cancelarPlantao(
                          data,
                          confirmada['turno']?.toString() ?? 'DIA',
                        ),
              )
            else ...[
              construirOpcaoTurno(
                data: data,
                turno: 'UNICO',
                restantes: restantesDia,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===================================================
  // BUILD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PLANTÕES RET • GUARDA AMBIENTAL'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: enviando ? null : _sair,
          ),
        ],
        bottom: enviando
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: _carregandoInicial
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando plantões...'),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => carregarTudo(silencioso: true),
                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(15),
                      children: [
                        Text(
                          widget.nome,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Matrícula: ${widget.matricula}',
                        ),
                        const SizedBox(height: 16),

                        _bannerMesAberto(),

                        const SizedBox(height: 12),

                        _cardContador(),

                        if (confirmadasVisiveis.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _secaoConfirmados(),
                        ],

                       const SizedBox(height: 12),
if (meusDias.isNotEmpty)
  _secaoPendentes()
else
  const Card(
    color: Colors.white10,
    child: Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            Icons.touch_app,
            color: Colors.amberAccent,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Selecione os plantões desejados. '
              'Eles aparecerão aqui como "A confirmar".',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    ),
  ),

                        const SizedBox(height: 22),

                        const Text(
                          'Plantões disponíveis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (vagas.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'Nenhuma vaga encontrada para o mês aberto.',
                              ),
                            ),
                          )
                        else
                          ...vagas.map(
                            (vaga) => construirCartaoVaga(vaga),
                          ),
                      ],
                    ),
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      15,
                      0,
                      15,
                      15,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed:
                            enviando ? null : confirmarPlantao,
                        child: enviando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('CONFIRMAR PLANTÕES'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
