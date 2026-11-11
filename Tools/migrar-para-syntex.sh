#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
# Syntex Utils: unofficial personal fork of Vorssaint, under the same license.
#
# Leva as configurações e os dados dos dois Vorssaint que rodavam lado a lado
# (o oficial, com módulos e barra de menu configurados, e o Developer, com os
# cartões de mesa) para o Syntex Utils, que os substitui.
#
#   ./Tools/migrar-para-syntex.sh --dry-run   mostra o que faria, não grava nada
#   ./Tools/migrar-para-syntex.sh             faz a migração
#
# Com os três apps FECHADOS. Nada é apagado: os dois domínios antigos ficam
# como estão, e o que existir do Syntex Utils vai para o backup antes de ser
# substituído.
#
# Como as preferências são montadas:
#   - base: o domínio oficial (com.vorssaint.utils) inteiro;
#   - por cima, do Developer (com.vorssaint.utils.dev), só os cartões de mesa
#     (desktopWidget*), monitorSysCPU e appAppearance;
#   - todo featureAvailable.* fica true, menos o controle de ventoinha: o
#     helper só aceita a assinatura do time oficial, então no fork ele nunca
#     funcionaria (ver SyntexFork.swift);
#   - ficam de fora a chave local do aprendizado da barra de comandos e os
#     resumos feitos com ela (o app gera uma chave nova) e o registro da
#     última falha de atualização, que no fork não se aplica.
# Os dados de ~/Library/Application Support/com.vorssaint.utils (histórico do
# clipboard, scratchpad, prateleira…) são copiados para a pasta do novo id.
set -euo pipefail

OFICIAL="com.vorssaint.utils"
DEVELOPER="com.vorssaint.utils.dev"
SYNTEX="com.syntropylabs.syntex.utils"
SUPPORT="$HOME/Library/Application Support"

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        *) echo "uso: $0 [--dry-run]" >&2; exit 2 ;;
    esac
done

# Um app aberto regrava o próprio domínio ao sair e desfaria a migração.
for proc in Vorssaint VorssaintDeveloper SyntexUtils; do
    if pgrep -x "$proc" >/dev/null 2>&1; then
        echo "✗ $proc está aberto. Feche Vorssaint, Vorssaint (Developer) e Syntex Utils e rode de novo." >&2
        exit 1
    fi
done
if ! /usr/bin/python3 -c 'import plistlib' >/dev/null 2>&1; then
    echo "✗ python3 não está disponível (vem com as Command Line Tools: xcode-select --install)." >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Domínio ausente vira um dicionário vazio, para o resto não precisar de casos.
export_domain() {
    local domain="$1" target="$2"
    if ! defaults export "$domain" "$target" >/dev/null 2>&1; then
        /usr/bin/python3 -c 'import plistlib, sys; plistlib.dump({}, open(sys.argv[1], "wb"))' "$target"
    fi
}
export_domain "$OFICIAL" "$WORK/oficial.plist"
export_domain "$DEVELOPER" "$WORK/developer.plist"
export_domain "$SYNTEX" "$WORK/syntex-atual.plist"

/usr/bin/python3 - "$WORK/oficial.plist" "$WORK/developer.plist" "$WORK/syntex.plist" <<'PY'
import plistlib, sys

oficial_path, developer_path, out_path = sys.argv[1:4]
oficial = plistlib.load(open(oficial_path, "rb"))
developer = plistlib.load(open(developer_path, "rb"))

# Chaves que identificam esta instalação ou só valem para o app oficial.
SKIP = {
    "commandBarQueryHabitKey",   # chave local dos resumos; o app gera outra
    "commandBarQueryHabits",     # resumos feitos com a chave antiga, ilegíveis sem ela
    "updateLastInstallFailure",  # o fork não se atualiza
}
FROM_DEVELOPER = ("monitorSysCPU", "appAppearance")
FAN = "featureAvailable.fanControl"

merged = {}
skipped = []
for key, value in oficial.items():
    if key in SKIP:
        skipped.append(f"{key} (oficial: identidade ou atualização)")
    else:
        merged[key] = value
copied_official = len(merged)

overlay = []
for key, value in developer.items():
    if key.startswith("desktopWidget") or key in FROM_DEVELOPER:
        merged[key] = value
        overlay.append(key)
ignored_developer = len(developer) - len(overlay)

forced = []
for key in sorted(merged):
    if key.startswith("featureAvailable.") and key != FAN and merged[key] is not True:
        merged[key] = True
        forced.append(key)
if FAN in merged:
    del merged[FAN]
    skipped.append(f"{FAN} (o fork não controla ventoinhas; vale o padrão dele, desligado)")

plistlib.dump(merged, open(out_path, "wb"), fmt=plistlib.FMT_BINARY)

print(f"  oficial:   {copied_official} chaves copiadas de {len(oficial)}")
print(f"  developer: {len(overlay)} chaves por cima ({ignored_developer} ignoradas, ficam só no backup)")
for key in sorted(overlay):
    print(f"      + {key}")
print(f"  módulos:   {len(forced)} featureAvailable.* ligados")
for key in forced:
    print(f"      ✓ {key}")
print(f"  de fora:   {len(skipped)}")
for item in skipped:
    print(f"      - {item}")
print(f"  total no Syntex Utils: {len(merged)} chaves")
PY

OLD_DATA="$SUPPORT/$OFICIAL"
NEW_DATA="$SUPPORT/$SYNTEX"
if [[ -d "$OLD_DATA" ]]; then
    echo "  dados:     $OLD_DATA ($(du -sh "$OLD_DATA" | cut -f1)) → $NEW_DATA"
else
    echo "  dados:     $OLD_DATA não existe, nada a copiar"
fi

if (( DRY_RUN )); then
    echo "Simulação: nada foi gravado. Rode sem --dry-run para migrar."
    exit 0
fi

BACKUP="$HOME/Desktop/vorssaint-backup-$(date '+%Y-%m-%d-%H%M%S')"
mkdir -p "$BACKUP"
cp "$WORK/oficial.plist" "$BACKUP/$OFICIAL.plist"
cp "$WORK/developer.plist" "$BACKUP/$DEVELOPER.plist"
cp "$WORK/syntex-atual.plist" "$BACKUP/$SYNTEX-antes.plist"
echo "▸ Backup das preferências em $BACKUP"

defaults import "$SYNTEX" "$WORK/syntex.plist"
echo "▸ Preferências gravadas em $SYNTEX"

if [[ -d "$OLD_DATA" ]]; then
    if [[ -e "$NEW_DATA" ]]; then
        mv "$NEW_DATA" "$BACKUP/$SYNTEX-dados-antes"
        echo "  (a pasta que já existia foi para o backup)"
    fi
    ditto "$OLD_DATA" "$NEW_DATA"
    chmod 700 "$NEW_DATA"
    echo "▸ Dados copiados para $NEW_DATA"
fi
echo "✓ Migração pronta. Abra o Syntex Utils; os dois Vorssaint ficaram intactos."
