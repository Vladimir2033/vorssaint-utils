# Syntex Utils (fork do Vorssaint com widgets na mesa)

Fork pessoal e **não oficial** do [Vorssaint](https://github.com/vorssaint/vorssaint-utils),
um app de barra de menu para macOS em Swift (GPL-3.0-or-later). Aqui ele vira o
**Syntex Utils**: um app só no lugar do Vorssaint oficial e do Vorssaint
(Developer) que rodavam lado a lado, com **cartões independentes na mesa do Mac**
(sistema, calendário, relógio mundial, tempo, acessórios, bateria), desenhados
pelo próprio app, sem o sistema de Widgets do macOS.

Conversa, este arquivo e o que se explica ao dono: **em português**. Código,
comentários e commits seguem o padrão do repo original (inglês no código, 15
idiomas na interface). Este arquivo é versionado com `git add -f` (o
`.gitignore` do original ignora `CLAUDE.md`).

## Onde está cada coisa

| | |
|---|---|
| Pasta no Mac | `~/ClaudeCode/Tool` (o clone `~/ClaudeCode/vorssaint-utils` não se mexe) |
| GitHub (fork) | `Vladimir2033/vorssaint-utils` (`origin`) |
| Original | `vorssaint/vorssaint-utils` (`upstream`): **nunca** dar push nem abrir PR lá |
| Ramo de trabalho | **`syntex-utils`** (saiu do `widgets-mesa`; o `main` do fork está parado) |
| App | `/Applications/Syntex Utils.app`, bundle `com.syntropylabs.syntex.utils` |
| Base do original | v3.4.4 (merge `498dc7ef`) |

## Comandos

```bash
cd ~/ClaudeCode/Tool
git pull                                  # traz o que foi feito em outra máquina
./build.sh --test                         # suíte inteira (termina em TESTS OK)
./build.sh --test-suite=syntex            # só os testes do fork
./build.sh --test-suite=widgets           # só os testes dos cartões
./build.sh --syntex --install             # gera e instala o Syntex Utils
./Tools/migrar-para-syntex.sh --dry-run   # mostra a migração, sem gravar
```

- Precisa das Command Line Tools (`xcode-select --install`) e do certificado
  **Apple Development** do time `LXV5T4G4XZ` no chaveiro (o mesmo que o
  `--widgets` usava). Sem ele, `--syntex` para com erro em vez de assinar de
  outro jeito (`SYNTEX_SIGNING_IDENTITY` escolhe um certificado à mão).
- `--syntex` não combina com `--dev` nem com `--widgets`.
- Mensagens `sandbox_extension_consume failed` durante os testes são ruído do
  macOS. O que vale é o `TESTS OK` no fim.
- Trazer uma versão nova do original: `git fetch upstream --tags` e
  `git merge vX.Y.Z` no `syntex-utils` (merge, nunca rebase), depois
  `./build.sh --test`. Os textos do original não foram editados no repo
  (ver "Troca de nome"), então o merge raramente conflita.

## O que o `--syntex` faz (e o porquê)

| Item | Valor | Onde |
|---|---|---|
| Nome, executável | `Syntex Utils`, `SyntexUtils` | `build.sh` |
| Bundle id | `com.syntropylabs.syntex.utils`; helpers com o mesmo prefixo | `build.sh` |
| Assinatura | Apple Development, time `LXV5T4G4XZ`, runtime endurecido | `build.sh` |
| Compilação | release (`-O`), **sem** `VORSSAINT_DEVELOPMENT` | `build.sh` |
| Ícone e marca | "S" original, gerado por código; nada da arte do Vorssaint | `Tools/MakeSyntexIcon.swift` |
| Textos visíveis | "Vorssaint" vira "Syntex Utils" **na hora do build** | `Tools/syntex-branding.pl` |
| Atualização | desligada: nunca consulta nem instala o feed oficial | `SyntexFork`, `UpdateService` |
| Feedback e links temporários | desligados (iam para os servidores do original) | `SyntexFork` e serviços |
| Módulos | todos instalados por padrão, menos controle de ventoinha | `SyntexFork.availabilityDefaults` |
| Sobre | mostra "Fork não oficial do Vorssaint, sob GPL-3.0" e o commit do build | `SettingsView` |

- **O código reconhece o fork pelo bundle id** (`SyntexFork.isRunning`), como o
  Developer pelo sufixo `.dev`. O mesmo código gera os três apps; fora do fork
  nada muda.
- **Troca de nome no build, não no repo.** São ~1.400 textos em 15 idiomas;
  editar no repo faria quase todo merge do original conflitar. O build copia
  só os arquivos que mudam para `build/objects/SyntexUtils/branded/` e compila
  as cópias. Ficam de fora: comentários, identificadores, copyright (©),
  "Vorssaint Utils"/"Vorssaint.app" (nomes antigos que o app procura),
  `SyntexFork.swift` (crédito ao original) e `ReleaseNotes.swift` (compara o
  texto oficial). O teste `Tests/SyntexBrandingTests.sh` falha se um texto novo
  do original escapar.
- **Controle de ventoinha fica desinstalado:** o helper só aceita a assinatura
  do time oficial (`FanControlXPC`), então no fork nunca funcionaria.
- **Módulos ligados não quer dizer funções ligadas:** "instalado" mostra o
  módulo; cada um continua com o próprio interruptor (desligado por padrão
  nos opcionais). A checagem de hardware continua valendo.
- **Pastas e tipos continuam `Vorssaint`** (`Sources/Vorssaint`, módulos,
  símbolos): renomear só criaria conflito em cada merge.

## Migração do Mac Studio (fase 2, feita com o dono)

`Tools/migrar-para-syntex.sh`, com os três apps **fechados**:
- backup de `com.vorssaint.utils`, `com.vorssaint.utils.dev` e do domínio atual
  do Syntex em `~/Desktop/vorssaint-backup-<data>/`;
- preferências: base = domínio oficial inteiro; por cima, do Developer, só
  `desktopWidget*`, `monitorSysCPU` e `appAppearance`; todo `featureAvailable.*`
  vira true (menos `fanControl`); fora: `commandBarQueryHabitKey`,
  `commandBarQueryHabits`, `updateLastInstallFailure`;
- dados: copia `~/Library/Application Support/com.vorssaint.utils` para a
  pasta do novo bundle id (o app não usa Keychain, então a cópia basta).

Depois: abrir o Syntex Utils, aprovar de novo as permissões (é app novo para o
macOS), conferir cartões nas mesmas posições, Dynamic Island, monitores na
barra, clipboard com histórico; só então trocar os itens de login e mover os
dois Vorssaint para `_to_delete` (não apagar). Medir:
`top -l 30 -s 10 -pid <PID> -stats pid,cpu,mem,idlew`.

## Os cartões

| Cartão | Tamanho | De onde vêm os dados |
|---|---|---|
| Sistema | médio | `SystemMonitor` (CPU com linha, memória, temperatura, rede, disco, GPU) |
| Sistema compacto | pequeno | idem, em anéis |
| Sistema detalhado | grande | idem, com quatro gráficos ao vivo |
| Agenda | grande | calendário do Mac via `NotchCalendarReader` |
| Próximo evento | pequeno | idem |
| Calendário do mês | 364×470 | idem; setas, Hoje, clique no dia lista os eventos |
| Relógio mundial | médio | só local (fusos escolhidos nos Ajustes) |
| Tempo | grande | **Open-Meteo**, até 4 cidades |
| Acessórios | pequeno | baterias de teclado, trackpad, mouse, fone |
| Bateria | pequeno | bateria do Mac |

Onde ligar: **Ajustes > Monitor > Widgets na mesa**. Arrastar move o cartão; a
posição fica só neste Mac (`desktopWidgetOrigins`).

## Arquivos

- Fork: `Sources/Vorssaint/Core/SyntexFork.swift`, `Tools/syntex-branding.pl`,
  `Tools/MakeSyntexIcon.swift`, `Tools/migrar-para-syntex.sh`; testes
  `Tests/SyntexForkTests.swift` (grupo `syntex`) e `Tests/SyntexBrandingTests.sh`.
- Cartões: `Sources/Vorssaint/Services/Widgets/` (`WidgetSnapshot*`, `WidgetAgenda`,
  `DesktopWidgetPlacement`, `DesktopWidgetsService`, `DesktopWorldClock`,
  `DesktopWeather*`), `UI/DesktopWidgets/DesktopWidgetViews.swift`,
  `UI/Settings/DesktopWidgetsCard.swift`, `Core/DesktopWidgetsStrings.swift`;
  testes `Tests/Widget*Tests.swift`, `Tests/Desktop*Tests.swift`.
- Ícone amarelo na barra: `BlackHoleGlyph.idleTint` em `App/StatusItemController.swift`.
- WidgetKit antigo (fora do `--syntex`): `Sources/VorssaintWidgets/`,
  `Resources/Widgets/`, flag `--widgets`.

## Regras do repo original (valem aqui)

- Todo arquivo novo começa com o cabeçalho SPDX + Copyright; manter `LICENSE`,
  avisos de copyright, `CHANGELOG.md` histórico e créditos ao Vorssaint.
- Textos de interface nos **15 idiomas** (`AppLanguage.allCases`). Sem travessão
  (—), apóstrofo tipográfico (’), francês com espaço inseparável antes de `: ; ! ?`.
- Arquivo puro novo usado nos testes entra em `TEST_SOURCES` no `build.sh`.
- Teste novo tem que falhar sem o conserto. Build sem warnings novos.
- Commits em inglês no formato `type(scope): frase`, explicando causa, conserto
  e o que foi ou não conferido. Nunca declarar verificado o que só compilou.
- Uso pessoal, sem distribuição. Se um dia distribuir, o código-fonte vai junto.

## Relação com o Syntex

O navegador Syntex (`Vladimir2033/syntex-v2`) tem um botão fixo na barra
lateral que abre este app (branch `claude/ecstatic-brown-2wptpw`). Ele procura
primeiro `Syntex Utils.app` e depois os dois Vorssaint.
