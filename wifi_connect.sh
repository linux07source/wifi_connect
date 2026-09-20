#!/bin/bash

# Controlla se lo script viene eseguito con i permessi di root (necessari per gestire il Wi-Fi)
if [ "$EUID" -ne 0 ]; then
  echo "[-] Errore: Questo script deve essere eseguito con i permessi di root (usa sudo)."
  exit 1
fi

echo "[+] Verifica dei tool di rete disponibili..."

# Scegliamo di usare NetworkManager (nmcli) o iwd (iwctl) in base a cosa è installato
if command -v nmcli &>/dev/null; then
  MANAGER="NetworkManager"
  echo "[✔] Trovato NetworkManager (nmcli)."
elif command -v iwctl &>/dev/null; then
  MANAGER="iwd"
  echo "[✔] Trovato iwd (iwctl)."
else
  echo "[-] Errore critico: Nessun gestore di rete supportato trovato (NetworkManager o iwd)."
  echo "    Su Arch Linux puoi installarli con: sudo pacman -S networkmanager oppure iwd"
  echo "[-] Installazione del networkmanager  in corso..."
  sudo pacman -Sy networkmanager
  exit 1
fi

# Attivazione interfaccia di rete (se spenta)
echo "[+] Controllo e accensione dell'interfaccia Wi-Fi..."
if [ "$MANAGER" == "NetworkManager" ]; then
  nmcli radio wifi on
  echo "[+] Scansione delle reti Wi-Fi in corso con NetworkManager..."
  # Esegue la scansione e mostra la lista pulita (SSID e potenza)
  nmcli device wifi rescan 2>/dev/null
  sleep 2

  # Legge le reti disponibili (salvando SSID)
  # Mostriamo un menu chiaro all'utente
  echo "----------------------------------------"
  nmcli -f SSID,SECURITY,BARS device wifi list
  echo "----------------------------------------"

  read -p "Inserisci il nome (SSID) della rete a cui vuoi connetterti: " chosen_ssid

  if [ -z "$chosen_ssid" ]; then
    echo "[-] Nome rete non valido."
    exit 1
  fi

  # Chiede se la rete è protetta
  read -sp "Inserisci la password della rete (premi Invio se è aperta): " wifi_password
  echo ""

  echo "[+] Connessione a '$chosen_ssid' in corso..."
  if [ -z "$wifi_password" ]; then
    nmcli device wifi connect "$chosen_ssid"
  else
    nmcli device wifi connect "$chosen_ssid" password "$wifi_password"
  fi

elif [ "$MANAGER" == "iwd" ]; then
  echo "[+] Usando iwd. Assicurati che il servizio iwd sia attivo."
  # Mostra i dispositivi wireless disponibili con iwd
  echo "Dispositivi iwd disponibili:"
  iwctl device list

  read -p "Inserisci il nome della scheda di rete (es. wlan0): " wifi_device

  if [ -z "$wifi_device" ]; then
    echo "[-] Scheda non inserita."
    exit 1
  fi

  echo "[+] Scansione delle reti con $wifi_device..."
  iwctl station "$wifi_device" scan
  sleep 2

  iwctl station "$wifi_device" get-networks

  read -p "Inserisci il nome (SSID) della rete a cui vuoi connetterti: " chosen_ssid

  read -sp "Inserisci la password (lascia vuoto se aperta): " wifi_password
  echo ""

  if [ -z "$wifi_password" ]; then
    iwctl station "$wifi_device" connect "$chosen_ssid"
  else
    iwctl station "$wifi_device" connect "$chosen_ssid" --passphrase "$wifi_password"
  fi
fi

# Controllo finale della connessione a Internet
echo "[+] Verifica dello stato della connessione a Internet..."
if ping -c 1 8.8.8.8 &>/dev/null; then
  echo "[✔] Connessione riuscita! Sei online."
else
  echo "[!] La connessione sembra non rispondere. Controlla la password o il segnale."
fi
