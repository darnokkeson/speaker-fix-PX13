# Naprawa dźwięku — ASUS ProArt PX13 HN7306EAC (Ubuntu)

Ta instrukcja opisuje rozwiązanie sprawdzone na ASUS ProArt PX13 HN7306EAC z AMD Ryzen AI Max+ 395 / Strix Halo, Ubuntu 26.04, PipeWire 1.6.2 i ALSA UCM 1.2.15.3.

W tym przypadku przyczyną braku dźwięku z głośników były wyłączone przełączniki wyjść głośnikowych TAS2783. Po ich włączeniu test ALSA zaczął odtwarzać dźwięk. Następnie należało ustawić `Audio Coprocessor Speaker` jako domyślne wyjście PipeWire w ustawieniach GNOME.

## 1. Najprostsza metoda — uruchom skrypt

Pobierz plik `napraw-dzwiek-px13.sh`, a następnie w terminalu przejdź do katalogu, w którym go zapisano. Jeśli plik znajduje się w `~/Pobrane`, wykonaj:

```bash
cd ~/Pobrane
chmod +x napraw-dzwiek-px13.sh
./napraw-dzwiek-px13.sh
```

Skrypt:
- wykrywa numer karty ALSA `Audio Coprocessor`;
- włącza przełączniki `Left Spk`, `Left Spk2`, `Right Spk` i `Right Spk2`;
- sprawdza, czy PipeWire widzi wyjście `Audio Coprocessor Speaker`;
- ustawia to wyjście jako domyślne;
- wyświetla końcowy status `wpctl`.

Skrypt nie używa `sudo`, nie restartuje usług audio i nie modyfikuje plików systemowych UCM. Jeśli PipeWire nie widzi wyjścia, skrypt poinformuje o tym zamiast wprowadzać kolejne zmiany.

## 2. Ręczna naprawa — krok po kroku

### Krok 1. Sprawdź, czy system wykrywa kartę audio

```bash
cat /proc/asound/cards
```

Powinna być widoczna karta `Audio Coprocessor`.

### Krok 2. Sprawdź konfigurację ALSA UCM

Plik używany w tej konfiguracji:

```bash
/usr/share/alsa/ucm2/conf.d/amd-soundwire/ASUSTeKCOMPUTERINC.-ProArtPX13HN7306EAC-1.0-HN7306EAC.conf
```

Pierwszy wiersz powinien mieć postać:

```text
Syntax 8
```

Sprawdź go poleceniem:

```bash
head -n 1 /usr/share/alsa/ucm2/conf.d/amd-soundwire/ASUSTeKCOMPUTERINC.-ProArtPX13HN7306EAC-1.0-HN7306EAC.conf
```

Konfiguracja UCM powinna udostępniać urządzenie `Speaker`. Można to sprawdzić tak:

```bash
alsaucm -c 1 list _devices/HiFi
```

Jeśli numer karty nie jest równy `1`, użyj numeru przypisanego do `Audio Coprocessor` w `/proc/asound/cards`.

### Krok 3. Włącz przełączniki wzmacniaczy głośników

To był kluczowy krok w opisanym przypadku:

```bash
amixer -c 1 sset 'Left Spk' on
amixer -c 1 sset 'Left Spk2' on
amixer -c 1 sset 'Right Spk' on
amixer -c 1 sset 'Right Spk2' on
```

Ponownie: jeśli `Audio Coprocessor` ma inny numer karty niż `1`, zamień `1` na właściwy numer.

Sprawdź stan jednego z przełączników:

```bash
amixer -c 1 sget 'Left Spk'
```

Wynik powinien zawierać `[on]`. Analogicznie można sprawdzić pozostałe trzy kontrolki.

### Krok 4. Ustaw właściwe wyjście w Ubuntu

Otwórz:

**Ustawienia → Dźwięk → Wyjście**

Wybierz:

**Audio Coprocessor Speaker**

Uwaga: `Speaker` to wyjście audio (głośniki), a `Digital Microphone` to wejście audio (mikrofon). Nie należy wybierać głośników jako urządzenia wejściowego.

### Krok 5. Sprawdź PipeWire

```bash
wpctl status
```

Prawidłowy stan powinien zawierać zbliżone wpisy:

```text
Audio
 ├─ Sinks:
 │  *   83. Audio Coprocessor Speaker
 ├─ Sources:
 │  *   84. Audio Coprocessor Digital Microphone
```

Gwiazdka `*` przy `Audio Coprocessor Speaker` oznacza domyślne wyjście. Numery obiektów mogą się różnić po ponownym uruchomieniu systemu.

W sekcji `Streams` Firefox powinien być podłączony do `Speaker:playback_FL` i `Speaker:playback_FR`.

## 3. Test bez przeglądarki

Jeśli nadal nie ma dźwięku, sprawdź bezpośrednio ALSA:

```bash
speaker-test -D plughw:1,2 -c 2 -t sine -l 1
```

Ten przykład używa karty `1` i urządzenia PCM `2`, zgodnie z konfiguracją sprawdzoną na tym laptopie. Jeśli numer karty się zmienił, dostosuj go. Jeśli test ALSA działa, ale przeglądarka nie, problem jest już na poziomie wyboru wyjścia lub routingu PipeWire, a nie samego toru głośnikowego.

## 4. Jeśli nadal nie działa

Zbierz aktualny stan:

```bash
echo "=== KERNEL ==="
uname -r

echo "=== ALSA CARDS ==="
cat /proc/asound/cards

echo "=== ALSA MIXER SWITCHES ==="
amixer -c 1 sget 'Left Spk'
amixer -c 1 sget 'Left Spk2'
amixer -c 1 sget 'Right Spk'
amixer -c 1 sget 'Right Spk2'

echo "=== PIPEWIRE ==="
wpctl status

echo "=== UCM VERBS ==="
alsaucm -c 1 list _verbs
```

Dostosuj `-c 1`, jeśli numer karty `Audio Coprocessor` jest inny.

Nie zmieniaj ponownie UCM, firmware, kernela ani konfiguracji PipeWire, jeśli nie ma konkretnego błędu wskazującego na tę warstwę. W działającej konfiguracji lepiej ograniczyć naprawę do włączenia czterech przełączników i wybrania właściwego wyjścia.

## 5. Ważne po restarcie

Po ponownym uruchomieniu Ubuntu sprawdź, czy cztery przełączniki nadal mają stan `[on]`. Jeśli wrócą do `[off]`, uruchom ponownie skrypt. Dopiero jeśli problem będzie powtarzał się po każdym starcie, warto skonfigurować automatyczne przywracanie tych przełączników podczas uruchamiania systemu.
