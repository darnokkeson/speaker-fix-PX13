#!/usr/bin/env bash
# Naprawa dźwięku głośników ASUS ProArt PX13 HN7306EAC (Ubuntu 26.04)
# Przywraca przełączniki wzmacniaczy TAS2783 i ustawia głośniki jako domyślne wyjście PipeWire.
# Nie modyfikuje plików ALSA UCM ani konfiguracji systemowej.

set -Eeuo pipefail

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { printf '\nBŁĄD: %s\n' "$*" >&2; exit 1; }

command -v amixer >/dev/null 2>&1 || die "Nie znaleziono amixer. Zainstaluj pakiet alsa-utils."
command -v wpctl  >/dev/null 2>&1 || die "Nie znaleziono wpctl. Sprawdź, czy działa PipeWire."

# Wykryj numer karty ALSA na podstawie nazwy urządzenia.
CARD="$(awk '/Audio Coprocessor/ {print $1; exit}' /proc/asound/cards)"
[[ -n "${CARD:-}" ]] || die "Nie wykryto karty ALSA 'Audio Coprocessor'. Sprawdź: cat /proc/asound/cards"

log "Wykryta karta Audio Coprocessor: ALSA card ${CARD}"

# Sprawdź UCM. Skrypt celowo nie zmienia plików konfiguracyjnych.
UCM_FILE="/usr/share/alsa/ucm2/conf.d/amd-soundwire/ASUSTeKCOMPUTERINC.-ProArtPX13HN7306EAC-1.0-HN7306EAC.conf"
if [[ -r "$UCM_FILE" ]]; then
    FIRST_LINE="$(head -n 1 "$UCM_FILE" | tr -d '\r')"
    if [[ "$FIRST_LINE" == "Syntax 8" ]]; then
        log "ALSA UCM: wykryto Syntax 8."
    else
        printf '\nUWAGA: pierwszy wiersz pliku UCM to: %s\n' "$FIRST_LINE"
        printf 'Oczekiwano: Syntax 8. Skrypt nie zmieni tego pliku automatycznie.\n'
    fi
else
    printf '\nUWAGA: nie znaleziono oczekiwanego pliku UCM:\n%s\n' "$UCM_FILE"
fi

log "Włączanie czterech przełączników głośników TAS2783..."
for control in "Left Spk" "Left Spk2" "Right Spk" "Right Spk2"; do
    if amixer -c "$CARD" scontrols | grep -Fq "Simple mixer control '$control',"; then
        amixer -c "$CARD" sset "$control" on
        printf '  OK: %s = on\n' "$control"
    else
        die "Nie znaleziono kontrolki '$control' na karcie ALSA ${CARD}. Nie wykonano pełnej naprawy."
    fi
done

log "Sprawdzanie, czy PipeWire udostępnia wyjście Audio Coprocessor Speaker..."
STATUS="$(wpctl status 2>&1)" || die "wpctl status nie powiódł się: $STATUS"
SINK_ID="$(printf '%s\\n' "$STATUS" | awk '/Audio Coprocessor Speaker/ { for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+\\.$/) { gsub(/\\./, "", $i); print $i; exit } }')"

if [[ -z "${SINK_ID:-}" ]]; then
    printf '\nPrzełączniki ALSA zostały włączone, ale PipeWire nie pokazuje jeszcze wyjścia\n'
    printf '"Audio Coprocessor Speaker".\n'
    printf 'Otwórz Ustawienia → Dźwięk → Wyjście i wybierz Audio Coprocessor Speaker.\n'
    printf 'Jeśli urządzenia nadal nie ma, sprawdź: wpctl status\n'
    exit 2
fi

log "Ustawianie Audio Coprocessor Speaker (ID ${SINK_ID}) jako domyślnego wyjścia..."
wpctl set-default "$SINK_ID"

log "Gotowe. Aktualny stan wyjść audio:"
wpctl status

printf '\nJeśli aplikacja (np. Firefox) nadal nie odtwarza dźwięku, zamknij i uruchom ją ponownie\n'
printf 'albo wybierz Audio Coprocessor Speaker w Ustawieniach → Dźwięk → Wyjście.\n'
