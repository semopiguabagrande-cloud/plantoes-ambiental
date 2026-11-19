# Plantões RET — Guarda Civil Ambiental de Iguaba Grande

## O que foi adaptado
- Identidade visual trocada para o escudo da Guarda Civil Ambiental.
- Tela de login/splash mantém a estrutura do projeto-base, usando o novo escudo.
- Interface de seleção apresenta uma única modalidade por data; não há escolha de turno noturno nem rótulo "dia".
- Lista de presença em PDF consolidada em uma lista por data.
- O endpoint da API foi substituído por um marcador para não usar acidentalmente a planilha/backend do aplicativo anterior.

## Importante: integração ainda precisa ser configurada
O ZIP recebido contém apenas a pasta `lib/` e não inclui o código-fonte do Google Apps Script que atende a API nem as plataformas nativas completas. Por isso, para o aplicativo realmente autenticar e gravar inscrições em uma planilha NOVA, é necessário:
1. Criar a planilha nova (modelo abaixo).
2. Criar/publicar um Google Apps Script que implemente as mesmas operações esperadas por `lib/services/api_service.dart`.
3. Colar a URL da implantação em `baseUrl` nesse arquivo.

Não reutilize o endpoint do aplicativo anterior se a intenção é manter os dados separados. O escudo e a interface estão no projeto; a API não pode ser recriada com segurança apenas a partir do arquivo Flutter.

## Criar/abrir o projeto no VS Code (Windows)
1. Instale Flutter SDK e Android Studio (para o SDK Android); no VS Code instale as extensões Flutter e Dart.
2. Abra o terminal do VS Code e execute:
   ```powershell
   flutter create --platforms=android,web,windows guarda_ambiental_ret
   ```
3. Copie a pasta `lib` deste pacote para dentro da pasta criada, substituindo a pasta `lib` original.
4. Copie `assets` e `pubspec.yaml` para a raiz do projeto criado (substitua o `pubspec.yaml`).
5. Execute:
   ```powershell
   flutter pub get
   flutter analyze
   flutter run -d chrome
   ```
   Para Android, conecte o aparelho/emulador e rode `flutter run`.
6. Configure o endpoint do Apps Script antes de testar login, inscrições ou relatórios.

## Planilha Google Sheets sugerida
Crie uma planilha chamada `RET - Guarda Civil Ambiental`. Crie as abas abaixo com os cabeçalhos na linha 1 (use estes nomes, sem acentos, para facilitar a API):

### AGENTES
`codigo | matricula | nome | tipo | ferias | ativo`

- `codigo`: código que o agente digita para entrar; deve ser único.
- `matricula`: matrícula funcional.
- `nome`: nome completo.
- `tipo`: `AGENTE` ou `ADMIN`.
- `ferias`: `SIM` ou `NAO`.
- `ativo`: `SIM` ou `NAO`.

### VAGAS
`data | vagasTotais | vagasOcupadas | ativo`

- Uma linha por data disponível.
- `data`: formato `dd/MM/yyyy`.
- `vagasTotais`: total de vagas autorizadas nessa data.
- `vagasOcupadas`: quantidade confirmada; pode ser calculada pela API a partir das inscrições.
- `ativo`: `SIM` ou `NAO`.
- Não crie colunas de vagas noturnas.

### INSCRICOES
`id | data | codigo | matricula | nome | status | criadoEm | atualizadoEm`

- `status`: `CONFIRMADA`, `CANCELADA` ou `PENDENTE`.
- Uma inscrição por agente/data. Não deve haver campo de turno.
- A API deve validar limites por agente e vagas restantes antes de confirmar.

### SESSOES
`sessionId | codigo | dispositivo | cliente | versao | criadoEm | ultimoAcesso | ativa`

- Usada para controlar sessão, impedir logins conflitantes e validar heartbeat.
- `ativa`: `SIM` ou `NAO`.

### CONFIG
`chave | valor`
- Use para parâmetros gerais, como limite padrão de plantões por agente e mês de inscrições aberto.

## Preenchimento inicial recomendado
1. Na aba `AGENTES`, inclua primeiro os administradores e agentes autorizados.
2. Na aba `VAGAS`, crie uma linha por data com vagas autorizadas.
3. Deixe `INSCRICOES` e `SESSOES` apenas com os cabeçalhos; os registros serão gravados pela API.
4. Proteja as abas contra edição acidental e restrinja o acesso à planilha.
5. Teste com uma conta de agente e uma de administrador antes de distribuir o app.

## Gerar APK
Depois que a API estiver configurada e o app testado:
```powershell
flutter build apk --release
```
O APK costuma ficar em `build/app/outputs/flutter-apk/app-release.apk`.

## Observações técnicas
- O código recebido tinha alguns arquivos Dart vazios e não incluía os assets/fontes referenciados originalmente. Os assets de imagem deste pacote incluem o escudo e fundos simples para que os caminhos do login existam.
- A estrutura da planilha acima é um modelo de organização, não um Apps Script funcional. A API precisa implementar os contratos usados pelo Flutter e ser implantada como Web App com permissões adequadas.
