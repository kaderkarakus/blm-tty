# BLM-TTY — Mimari ve Uygulama Spesifikasyonu

Windows PuTTY SSH/Telnet istemcisinin native macOS klonu.
Uygulama adı: **BLM-TTY**. Pencere başlığı ekran görüntüsündeki düzeni korur: `BLM-TTY Configuration` / `BLM-TTY Yapılandırması`.

**Yayımlanan uygulama** (bkz. [`README.md`](README.md) ve `dist/`): native AppKit krom, sistem OpenSSH, konsol girişi. Aşağıdaki Win32 piksel kopyası ve native SSH-2 yığını **yayımlanmadı**; bu belge kısmen tarihî spesifikasyondur. Conf anahtarları, oturum dosyası, PPK ve i18n semantiği hâlâ geçerlidir.

Güncel ürün özeti:

- Yapılandırma düğmesi **Connect** / **Bağlan** (eski Open / Aç değil)
- Kayıtlı oturumu seçmek formu doldurur; Connect/Bağlan veya çift tık o oturumu hemen açar
- Terminal başlık çubuğuna sağ tık: New Session / Duplicate Session / Restart Session
- Konsol sağ tık: yapıştır
- Scrollback: tekerlek, kaydırma çubuğu, PgUp/PgDn; Terminal.app benzeri 6 pt kenar

---

## 1. Hedef

- Ekran görüntüsündeki **PuTTY Configuration** penceresinin piksel-seviyesinde kopyası (Windows 10 Win32 dialog görünümü).
- Tüm kategori panelleri, diyaloglar, menüler, butonlar, giriş alanları, sekmeler, renk paleti, yazı tipleri ve yerleşim.
- Anında **Türkçe / English** dil değiştirici: menü, etiket, tooltip, hata, yardım.
- Orijinal PuTTY ile aynı bağlantı türleri ve ileri seçenekler: SSH, Telnet, Rlogin, Serial, Raw.
- Oturum kaydet / yükle / sil; Default Settings.
- Terminal öykünmesi, SSH kimlik doğrulama, port/X11 yönlendirme, log, proxy, seri, PPK ve oturum dosyası uyumu.
- Swift + AppKit (yapılandırma penceresi özel çizimli Windows görünümü). SwiftUI yalnızca About/Help gibi yardımcı sahnelerde.
- Komut satırı semantiği `putty` / `plink` ile uyumlu.

Lisans: orijinal Swift kodu. PuTTY MIT lisanslıdır; kaynak kopyalanmaz, davranış ve Conf semantiği eşlenir.

---

## 2. Piksel-seviyesi UI (ekran görüntüsü)

### 2.1 Pencere kromu

Windows 10 klasik iletişim kutusu; macOS Aqua kullanılmaz.

| Özellik | Değer |
|---|---|
| İçerik boyutu | 516 × 434 pt (başlık hariç) |
| Tam dış boyut | 518 × 466 pt |
| Başlık çubuğu | 32 pt, beyaz `#FFFFFF`, alt çizgi `#D9D9D9` |
| Başlık metni | 13 pt, system/Segoe benzeri, `#000000`, sol 12 pt |
| Sağ düğmeler | `?` yardım 16×16, `✕` kapat 46×32 |
| Kapat hover | `#E81123` zemin, beyaz X |
| İstemci zemin | `#F0F0F0` |
| Kenar | 1 px `#ADADAD` |
| Varsayılan yazı | 11 px (`NSFont.systemFont(ofSize: 11)`); Segoe UI 9pt varsa onu kullan |
| Vurgu rengi | `#0078D7` |
| Devre dışı metin | `#6D6D6D` |

Özel `WinChromeWindow` (`NSWindow` + `NSWindowStyleMask.borderless` + gölge). Sürüklenebilir başlık.

Başlık:

- EN: `BLM-TTY Configuration`
- TR: `BLM-TTY Yapılandırması`

### 2.2 Ana yerleşim (client koordinatları, y yukarıdan)

```
12,12     Label "Category:" / "Kategori:"
12,30     Tree  150 × 356   (beyaz, 1px `#A0A0A0` çerçeve, sunken)
170,12    Sağ panel  334 × 374
12,400    About  75×23     Help 75×23     [Language combo 100×23]
          Connect / Bağlan (default) 75×23 sağ-alt, Cancel 75×23
```

Butonlar klasik 75×23. Default (Connect / Bağlan) mavi dış çerçeve `#0078D7` 2 px. Yayımlanan uygulamada düğme metni Open/Aç değildir.

**Language selector** (istenen ek özellik): sol-altta About’un solunda değil; About/Help ile aynı sırada, onların sağında `English ▾` / `Türkçe ▾` WinCombo. Dil değişince tüm ağaç, paneller, butonlar, başlık, tooltip anında yenilenir. Pencere kapanmaz, seçili kategori ve form değerleri korunur.

### 2.3 Session paneli (ekran görüntüsü birebir)

Sağ panel iki grup kutusu + alt radyo grubu.

**Group 1** — `Basic options for your BLM-TTY session` / `BLM-TTY oturumunuz için temel seçenekler`

- Açıklama: `Specify the destination you want to connect to` / `Bağlanmak istediğiniz hedefi belirtin`
- Label `Host Name (or IP address)` / `Ana bilgisayar adı (veya IP adresi)` + edit (geniş)
- Label `Port` / `Bağlantı noktası` + edit 48 px, varsayılan `22`
- Label `Connection type:` / `Bağlantı türü:`
- Radyolar yatay: Raw, Telnet, Rlogin, **SSH** (varsayılan), Serial
- Protokol değişince Port otomatik: Telnet 23, Rlogin 513, SSH 22, Raw 0, Serial port alanı gizlenir/disabled (PuTTY gibi Serial seçilince host/port disable)

**Group 2** — `Load, save or delete a stored session` / `Kayıtlı bir oturumu yükle, kaydet veya sil`

- Label `Saved Sessions` / `Kayıtlı Oturumlar`
- Tek satır edit
- Listbox: ilk satır `Default Settings` / `Varsayılan Ayarlar`, sonra kayıtlı oturumlar
- Sağda dikey: Load / Save / Delete  (`Yükle` / `Kaydet` / `Sil`), 75×23, aralarında 6 px

**Close window on exit** / `Çıkışta pencereyi kapat`

- Always / Never / **Only on clean exit**
- Her zaman / Asla / **Yalnızca temiz çıkışta**

### 2.4 Windows kontrol kiti (zorunlu)

Tüm yapılandırma UI’si bu kit ile çizilir. Native NSButton Aqua görünümü YASAK.

| Kontrol | Sınıf | Görünüm |
|---|---|---|
| Düğme | `WinButton` | `#E1E1E1` dolgu, `#ADADAD` kenar, hover `#E5F1FB`, press `#CCE4F7` |
| Default düğme | `WinButton.isDefault` | ek `#0078D7` 2 px çerçeve |
| Radyo | `WinRadio` | 12 px daire, iç dolgu seçiliyse `#0078D7` |
| Onay | `WinCheckbox` | 13 px kare, check glyph |
| Metin kutusu | `WinTextField` | beyaz, 1 px `#7A7A7A`, focus `#0078D7` |
| Liste | `WinListBox` | beyaz, seçim `#0078D7` + beyaz yazı |
| Ağaç | `WinTreeView` | `+`/`−` kutu 9×9, 16 px satır, seçim mavi |
| Grup | `WinGroupBox` | 1 px `#D0D0D0`, başlık üst çizgiyi keser |
| Combo | `WinComboBox` | edit + 17 px ok |
| Spin | `WinSpinner` | edit + yukarı/aşağı |
| Etiket | `WinLabel` | 11 px |
| Renk hücresi | `WinColorSwatch` | 20×12 + Edit |

Klavye: Tab sırası Windows gibi. Enter = Connect / Bağlan (default). Esc = Cancel. F1 = Help.

---

## 3. Kategori ağacı (tam)

PuTTY 0.81+ ağacı. SSH altında alt düğümler. Seçili düğüm sağ paneli değiştirir. Ağaç durumu (aç/kapa) UserDefaults’ta tutulur.

```
Session                         Oturum
  Logging                       Günlük
Terminal                        Terminal
  Keyboard                      Klavye
  Bell                          Zil
  Features                      Özellikler
Window                          Pencere
  Appearance                    Görünüm
  Behaviour                     Davranış
  Translation                   Dönüşüm
  Selection                     Seçim
  Colours                       Renkler
Connection                      Bağlantı
  Data                          Veri
  Proxy                         Vekil
  Telnet                        Telnet
  Rlogin                        Rlogin
  SSH                           SSH
    Kex                         Kex
    Host Keys                   Ana Makine Anahtarları
    Cipher                      Şifre
    Auth                        Kimlik Doğrulama
      GSSAPI                    GSSAPI
    TTY                         TTY
    X11                         X11
    Tunnels                     Tüneller
    Bugs                        Hatalar
    More Bugs                   Diğer Hatalar
  Serial                        Seri
```

Her düğümün paneli ayrı `ConfigPanel` alt sınıfı. Panel değişince mevcut Conf nesnesi paylaşılır (tek kaynak).

---

## 4. Panel alanları (PuTTY semantiği)

Conf anahtarları orijinal isimlerle (`host`, `port`, `protocol`, …). Varsayılanlar PuTTY ile aynı.

### 4.1 Session

- `host`, `port`, `protocol` (`raw=0 telnet=1 rlogin=2 ssh=3 serial=4 serial=4`)
- `addressfamily` (Auto / IPv4 / IPv6)
- kayıtlı oturum listesi
- `close_on_exit` (`always=0 never=1 clean=2`)

### 4.2 Logging

- `logtype`: None (−1), Printable (0), All session output (1), SSH packets (2), SSH packets and raw data (3)
- `logfilename` (`&Y&M&D&T` makro)
- `logxfovr`: ask / append / overwrite
- `logflush`, `logheader`, `logomitpass`, `logomitdata`

### 4.3 Terminal

- `wrap_mode`, `dec_om`, `lfhascr`, `crhaslf`
- `bce`, `blinktext`, `answerback`
- `localecho`, `localedit` (Auto / Force on / Force off)
- `printer`

### 4.4 Keyboard

- `bksp_is_delete` (Control-H vs 127)
- `rxvt_homeend`
- `funky_type` (ESC[n~ / Linux / Xterm R6 / VT400 / VT100+ / SCO / Xterm 216+)
- `no_applic_c` / keypad
- `alt_metabit`, `alt_compose`, `alt_holds`
- `ctrlaltkeys`

### 4.5 Bell

- `beep`: None / Visual / System default sound / Play specified / Visual + sound
- `beep_overloaded`, `bellovl`, `bellovl_n`, `bellovl_t`, `bellovl_s`
- `bell_style`

### 4.6 Features

Uzak uygulama özellikleri: uygulama imleci, keypad, fare raporlama, pencere başlığı, font değişimi, boyutlandırma, alt-ekran, vs. Hepsi Conf bayrakları.

### 4.7 Window

- `width` 80, `height` 24
- `resize_action` (rows/cols, font, disabled)
- `scrollbar`, `scrollbar_in_fullscreen`
- `scroll_on_disp`, `scroll_on_key`, `erase_to_scrollback`
- `savelines` 2000

### 4.8 Appearance

- `font` (varsayılan: Menlo 10, PuTTY’deki Courier New karşılığı)
- `font_quality`
- `logoidle`, `gap`
- `cursor_type` (block/underline/line), `blink_cur`
- `wintitle`, `separate_config_wintitle`

### 4.9 Behaviour

- `fullscronaltenter`, `alwaysontop`, `skip_alt_tab` (macOS’ta Cmd-Tab skip analogu)
- `warn_on_close`
- `window_closable`, `window_minimizable`, `window_maximizable`
- `alt_only`, `scroll_key`, `mouse`

### 4.10 Translation

- `line_codepage` (UTF-8 varsayılan; ISO-8859-1, CP437, CP1254, KOI8-R, …)
- `cjk_utf8_allow`, `utf8_override`
- `vtmode` (line drawing)

### 4.11 Selection

- `mouse_is_xterm`, `rect_select`, `mouseautoselect`
- `mousepaste`, `mousepaste_mode`
- `character_class`
- `rtf_paste`, `rawcnp`, `rtf_paste`

### 4.12 Colours

- `try_palette`, `system_colour`, `ansi_colour`, `xterm_256_colour`, `true_colour`
- `bold_style` (renk / font / ikisi)
- 22 renk: Default FG/BG, Cursor, ANSI 0–15, Bold FG/BG
- PuTTY varsayılan paleti birebir (ör. Default FG 187,187,187; BG 0,0,0; Cursor 0,255,0; ANSI black 0,0,0 …)

### 4.13 Connection

- `ping_interval` (saniye, 0=off)
- `tcp_nodelay`, `tcp_keepalives`
- `loghost`
- `ssh_no_shell` değil burada; reconnect yok (PuTTY de yok — tekrar bağlanma yok)

### 4.14 Data

- `username`, `username_from_env`
- `termtype` `xterm`, `termspeed` `38400,38400`
- `environmt` liste (VAR=value)

### 4.15 Proxy

- `proxy_type`: None, SOCKS4, SOCKS5, HTTP, Telnet, Local, SSH to proxy
- `proxy_host`, `proxy_port`, `proxy_username`, `proxy_password`
- `proxy_exclude_list`, `proxy_dns`, `even_proxy_localhost`
- `proxy_telnet_command`

### 4.16 Telnet

- `term_old` (old Telnet vs new)
- `telnet_keyboard`, `telnet_passive`
- `telnet_newline`

### 4.17 Rlogin

- `localusername`

### 4.18 SSH

- `remote_cmd`, `remote_cmd2`, `ssh_subsys`
- `nopty`, `compression`
- `sshprot` (2 only; SSH1 sunulmaz — modern PuTTY gibi SSH-2)
- `ssh_connection_sharing`

### 4.19 SSH/Kex

- algoritma sırası: `curve25519-sha256`, `ecdh-sha2-nistp256`, `ecdh-sha2-nistp384`, `diffie-hellman-group-exchange-sha256`, `diffie-hellman-group14-sha256`, `diffie-hellman-group14-sha1`, GSSAPI (varsa)
- `ssh_rekey_time` 60 dk, `ssh_rekey_data` 1G

### 4.20 SSH/Host Keys

- sıra: `ssh-ed25519`, `ecdsa-sha2-nistp256`, `rsa-sha2-256`, `rsa-sha2-512`, `ssh-rsa`
- known-host önbelleği yönetimi

### 4.21 SSH/Cipher

- sıra: `aes256-gcm`, `aes128-gcm`, `chacha20-poly1305`, `aes256-ctr`, `aes128-ctr`, `3des-cbc`
- `ssh2_des_cbc` (eski, kapalı)

### 4.22 SSH/Auth

- `tryagent`, `agentfwd`
- `try_tis_auth`, `try_ki_auth`
- `ssh_no_userauth`
- `keyfile` (.ppk / OpenSSH)
- `change_username`
- sertifika: `ssh_cert_agent`, OpenSSH cert / PuTTY cert alanları

### 4.23 SSH/Auth/GSSAPI

- macOS GSSAPI/Kerberos varsa; yoksa panel görünür ama “desteklenmiyor” disable.

### 4.24 SSH/TTY

- `nopty`
- `ttymodes` (INTR, QUIT, ERASE, … değerleri: Auto / None / Force)

### 4.25 SSH/X11

- `x11_forward`, `x11_display`, `x11_auth` (MIT-Magic-Cookie)
- macOS’ta XQuartz `$DISPLAY` varsayılan

### 4.26 SSH/Tunnels

- Local / Remote / Dynamic
- `Lport dest` listesi
- `lport_acceptall`, `rport_acceptall`

### 4.27 SSH/Bugs + More Bugs

PuTTY’nin `sshbug_*` auto/off/on anahtarlarının tümü.

### 4.28 Serial

- `serline` (`/dev/cu.usbserial` …)
- `serspeed` 9600, `serdatabits` 8, `serstopbits` 1
- `serparity` none/odd/even/mark/space
- `serflow` none/XON/XOFF/RTS/CTS/DSR/DTR

---

## 5. Yazılım mimarisi

```
┌──────────────────────────────────────────────────────────┐
│  AppKit UI                                               │
│  WinChromeWindow  ConfigWindowController  TerminalWindow │
│  Win* controls    ConfigPanel(s)          Auth/HostKey   │
│  L10n.shared                                             │
└──────────────┬─────────────────────────────┬─────────────┘
               │ Conf / SessionStore         │ TerminalView
┌──────────────▼─────────────┐  ┌────────────▼─────────────┐
│  Session / Conf            │  │  TerminalEmulator        │
│  SessionConfig (Conf)      │  │  UTF-8, VT/xterm, sel.   │
│  SessionStore              │  │  palette, bell, log      │
│  PuTTYSessionFile          │  └────────────┬─────────────┘
│  KnownHosts                │               │ bytes in/out
└──────────────┬─────────────┘  ┌────────────▼─────────────┐
               │                │  ConnectionEngine        │
               │                │  Raw Telnet Rlogin SSH   │
               │                │  Serial  Proxy           │
               └────────────────┤  SSH2Client  PPKKey      │
                                │  Agent  Forwarding  X11  │
                                └──────────────────────────┘
```

Katmanlar birbirini UIKit/AppKit üzerinden tanımaz. `ConnectionEngine` sadece `BytePump` (async byte stream) sunar. Terminal emülatörü byte pompalar. UI Conf’u değiştirir, Connect/Bağlan deyince oturum başlar. Yayımlanan uygulamada native SSH-2 `SessionRunner` yoktur; SSH sistem OpenSSH’dir.

### 5.1 Modüller (hedef klasör)

```
BLM-TTY/
  ARCHITECTURE.md
  README.md
  Package.swift                    (opsiyonel SPM; asıl Xcode projesi)
  BLM-TTY.xcodeproj/
  BLM-TTY/
    App/
      main.swift
      AppDelegate.swift
      AppMenu.swift
    I18n/
      L10n.swift
      en.json
      tr.json
    Theme/
      WinPalette.swift
      WinFont.swift
    Controls/
      WinButton.swift
      WinRadio.swift
      WinCheckbox.swift
      WinTextField.swift
      WinListBox.swift
      WinTreeView.swift
      WinGroupBox.swift
      WinComboBox.swift
      WinSpinner.swift
      WinLabel.swift
      WinColorSwatch.swift
      WinChromeWindow.swift
    ConfigUI/
      ConfigWindowController.swift
      ConfigCategory.swift
      ConfigPanel.swift
      Panels/*.swift               (her kategori)
    TerminalUI/
      TerminalWindowController.swift
      TerminalView.swift
      TerminalBell.swift
    Dialogs/
      AboutDialog.swift
      HelpWindow.swift
      HostKeyDialog.swift
      PasswordDialog.swift
      PassphraseDialog.swift
      AuthBannerDialog.swift
      EventLogWindow.swift
      ChangeSettingsWindow.swift
      PuTTYGenWindow.swift
    Conf/
      SessionConfig.swift
      ConfKeys.swift
      SessionStore.swift
      PuTTYSessionFile.swift
      KnownHostsStore.swift
    Terminal/
      TerminalEmulator.swift
      TerminalBuffer.swift
      EscapeParser.swift
      Charset.swift
    Net/
      ConnectionEngine.swift
      ProxyNegotiator.swift
      RawConnection.swift
      TelnetConnection.swift
      RloginConnection.swift
      SerialConnection.swift
    SSH/
      SSHClient.swift
      SSHTransport.swift
      SSHKex.swift
      SSHAuth.swift
      SSHChannel.swift
      SSHAgent.swift
      SSHForwarding.swift
      SSHX11.swift
      PPKKey.swift
      OpenSSHKey.swift
    Log/
      SessionLogger.swift
    CLI/
      CLI.swift
    Resources/
      Assets.xcassets
      Info.plist
      Help/en/*.html
      Help/tr/*.html
      AppIcon
  BLM-TTYTests/
```

Bundle ID: `com.blmtty.app`
Deployment: macOS 13.0+
Swift 5.9
Entitlements: `com.apple.security.network.client`, `com.apple.security.device.usb` (seri), App Sandbox KAPALI (seri port + ssh-agent socket için).

---

## 6. Conf ve oturum dosyası

### 6.1 SessionConfig

Tek sınıf, `class SessionConfig: NSCopying`. Tüm alanlar PuTTY `conf_enum` / `conf_int` / `conf_str` / `conf_filename` / `conf_font` karşılığı. Bilinmeyen anahtarlar round-trip için `extra: [String:String]` içinde saklanır.

Serileştirme (Unix PuTTY):

```
HostName=example.com
PortNumber=22
Protocol=ssh
CloseOnExit=2
UserName=
...
```

Dosya adı: oturum adı URL-encode (`%20` boşluk). `Default%20Settings`.

### 6.2 Disk yerleri

| Veri | Yol |
|---|---|
| Oturumlar | `~/Library/Application Support/BLM-TTY/sessions/` |
| Host keys | `~/Library/Application Support/BLM-TTY/sshhostkeys` |
| Random seed | `~/Library/Application Support/BLM-TTY/randomseed` |
| Ayar (dil, pencere) | `~/Library/Preferences/com.blmtty.app.plist` |

İçe aktarma sırası (açılışta, yoksa):

1. `~/.putty/sessions/` (Unix PuTTY / KiTTY uyumu)
2. Kullanıcının verdiği `.reg` (`HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions`)

Dışa aktarma: aynı Unix formatı — orijinal PuTTY (Linux) ve manyak Windows kullanıcıları için `.reg` export.

`Default Settings` silinemez; Save üzerine yazar.

### 6.3 Host key formatı

PuTTY formatı:

```
ssh-ed25519@22:example.com 0x...hex...
```

Host key diyaloğu: PuTTY metinleri (EN/TR), fingerprint SHA256 + MD5, Accept / Connect once / Cancel.

---

## 7. PPK ve anahtarlar

`PPKKey` okur/yazar:

- **PPK2**: `PuTTY-User-Key-File-2:`, AES-256-CBC, MAC SHA-1
- **PPK3**: `PuTTY-User-Key-File-3:`, Argon2id, AES-256-CBC, MAC SHA-256

Desteklenen türler: `ssh-ed25519`, `ecdsa-sha2-nistp256/384/521`, `ssh-rsa`.

Açık anahtar OpenSSH `id_ed25519` / `id_rsa` (PKCS#8 / RFC4716) da yüklenir.

PuTTYgen penceresi (menü: Conversion / Anahtar Üreteci):

- üret, yükle, kaydet .ppk, OpenSSH export, fingerprint, comment, passphrase değiştir

Pageant-style ajan:

- Uygulama içi `BLMAgent` (bellekte tutulan anahtarlar)
- `SSH_AUTH_SOCK` üzerindeki OpenSSH ajanına da konuş (unix socket, SSH2 agent protocol)
- `tryagent` açıksa sırayla: BLMAgent → ssh-agent

---

## 8. Protokol motoru

`ConnectionEngine.connect(config:proxy:)` → `ByteChannel`.

### 8.1 Raw

TCP `NWConnection`. Proxy varsa önce proxy.

### 8.2 Telnet (RFC 854/855)

IAC müzakeresi: BINARY, ECHO, SGA, TTYPE, NAWS, NEW-ENVIRON, CHARSET. `term_old` ise müzakere kısıtlı.

### 8.3 Rlogin

Port 513, RFC 1282: `\0localuser\0remoteuser\0term/speed\0`.

### 8.4 Serial

`open()` + `termios` (`/dev/cu.*`). Baud, bits, parity, stop, flow. IOKit ile cihaz listesi.

### 8.5 SSH-2

Kendi Swift SSH-2 yığını + `swift-crypto`. SSH-1 yok.

Minimum algoritma seti:

| Rol | Algoritmalar |
|---|---|
| Kex | `curve25519-sha256`, `ecdh-sha2-nistp256`, `diffie-hellman-group14-sha256` |
| Host | `ssh-ed25519`, `ecdsa-sha2-nistp256`, `rsa-sha2-256` |
| Cipher | `aes256-gcm@openssh.com`, `aes128-gcm@openssh.com`, `chacha20-poly1305@openssh.com`, `aes256-ctr` |
| MAC | `hmac-sha2-256` (CTR için) |
| Comp | `none`, `zlib@openssh.com` (opsiyonel; yoksa none) |

Akış:

1. Version string `SSH-2.0-BLMTTY_1.0`
2. KEXINIT / KEX / NEWKEYS
3. Host key doğrula (KnownHosts + diyalog)
4. USERAUTH: none → publickey (ajan, dosya) → keyboard-interactive → password
5. CHANNEL session: pty-req (`xterm`, cols/rows), env, shell veya exec/subsystem
6. İsteğe bağlı: `direct-tcpip`, `forwarded-tcpip`, `tcpip-forward`, dynamic SOCKS, `x11-req`

Kanal penceresi, max packet, rekey (`ssh_rekey_time` / data).

Sertifika: OpenSSH `ssh-ed25519-cert-v01@openssh.com` publickey auth içinde.

### 8.6 Proxy

Bağlantı önce proxy’ye. SOCKS5 (RFC 1928, kullanıcı/parola), SOCKS4, HTTP CONNECT, Telnet komut, Local (`proxy_telnet_command` spawn).

---

## 9. Terminal öykünmesi

PuTTY’nin xterm/VT102 karışımı davranışına yaklaşan özgün emülatör.

- 80×24 (Conf), scrollback `savelines`
- UTF-8 + `line_codepage`
- CSI/OSC/DCS: CUP, ED, EL, SGR (16/256/truecolor), private modes (`?1 ?3 ?7 ?25 ?47 ?1049 ?2004`), DECSC/DECRC, charset G0/G1 (line drawing)
- Alternate screen
- Mouse tracking (X10/X11/SGR) Features panelinden kapatılabilir
- Seçim: karakter/kelime/satır, kopya Clipboard + primary analogu (Cmd+C / sağ tık)
- Paste: `bracketed paste` varsa
- Cursor stilleri, blink, bell (görsel flash + NSSound)
- Yeniden boyutlandırınca NAWS / CSI 8

`TerminalView`: `NSView`, Core Text, retina, IM (Türkçe input). Font Conf’tan.

Event Log penceresi: bağlantı adımları, kex, auth (parola logomit).

---

## 10. i18n

`L10n.shared.language = .en | .tr`

- Tüm UI string `L10n.t("session.host")`
- `Notification.Name.blmLanguageChanged` → her panel `reloadTexts()`
- JSON katalogları: `en.json`, `tr.json` — aynı anahtar kümesi
- Eksik anahtar DEBUG’da `??key??`
- Dil UserDefaults `app.language`; ilk açılışta macOS locale `tr` ise TR

Kapsam: menü, paneller, butonlar, tooltip, hata, host-key, auth, help HTML, About, CLI stderr.

Help: iki dilli HTML, kategori bağlamına göre (`Help` o anki paneli açar). `?` başlık düğmesi de Help.

---

## 11. Menüler (macOS menü çubuğu + terminal)

Yapılandırma penceresi açıkken:

```
BLM-TTY
  About BLM-TTY
  Preferences… (aynı config)
  Language ▸ English / Türkçe
  Quit
File
  New Session    ⌘N
  Duplicate Session
  Saved Sessions ▸
  Change Settings…
  Close          ⌘W
Edit
  Copy ⌘C  Paste ⌘V  Select All  Clear Scrollback  Find
Window
  Event Log
  Reset Terminal
  Full Screen
Help
  BLM-TTY Help  ⌘?
```

Terminal oturum menüsü PuTTY’deki özel komutlara denk: Break, SSH special (NOP, ignore, rekey), restart session.

---

## 12. Diyaloglar

| Diyalog | Davranış |
|---|---|
| About | BLM-TTY adı, sürüm 1.0.0, kısa lisans, platform |
| Help | HTML help |
| Host key | PuTTY metni + fingerprint + Accept/Once/Cancel |
| Password | `user@host` parola, göster/gizle |
| Passphrase | PPK |
| Keyboard-interactive | sunucu promptları |
| Banner | SSH banner, Continue |
| Event Log | kaydırılabilir metin, kopyala, kaydet |
| Change Settings | config penceresinin kopyası, Apply canlı |
| Fatal error | Windows benzeri mesaj kutusu |

---

## 13. Komut satırı

Bundle içi executable ve `/usr/local/bin/blm-tty` isteğe bağlı symlink.

PuTTY/plink semantiği:

```
blm-tty [-ssh | -telnet | -rlogin | -raw | -serial]
        [-P port] [-l user] [-pw pass] [-i key.ppk]
        [-L [bind:]port:host:hostport]
        [-R ...] [-D [bind:]port]
        [-X] [-A] [-a] [-C] [-1 | -2]
        [-log log.txt] [-session name]
        [user@]host
```

`-load "Default Settings"` oturumu yükler, CLI bayrakları üzerine yazar.

Çıkış kodları: 0 temiz, 1 hata (plink gibi).

`blm-tty --help` iki dil.

---

## 14. Connect / Bağlan akışı

Yayımlanan davranış:

1. Connect / Bağlan / Enter, veya kayıtlı oturum listesinde **çift tık**
2. Session panelinde bir kayıtlı oturum seçiliyse o oturum forma yüklenir, sonra bağlanır (ayrı Load şart değil). Load hâlâ yalnızca formu doldurur
3. Host boş ve Serial değilse hata: “No host name specified” / “Ana bilgisayar adı belirtilmedi”
4. Serial ise `serline` zorunlu
5. Config penceresi gizlenir; oturum ayrı native `NSWindow`
6. Terminal başlığı `host - BLM-TTY` veya `wintitle`
7. Başlık çubuğuna sağ tık: New Session / Duplicate Session / Restart Session (TR karşılıkları menü anahtarlarından)
8. Konsol içi sağ tık: yapıştır. İçerik alanı başlık menüsünü açmaz
9. SSH: TCP probe → konsolda `login as:` (kullanıcı boşsa) → OpenSSH `password:` aynı TTY’de. macOS parola sheet yok
10. `close_on_exit` kuralı; son terminal kapanınca uygulama çıkar

Aynı anda birden fazla terminal. Her birinin kendi Conf kopyası.

---

## 15. Görsel sabitler (Session paneli)

Windows dialog unit ≈ 1.5 px @ 96dpi; pratik pt:

- Sol ağaç genişliği 150
- Grup içi padding 10
- Kontrol yüksekliği 21 (edit), 23 (button), 16 (radio)
- Radyo aralığı 8
- Load/Save/Delete yığın sağda, listbox onları bırakacak şekilde kısaltılır
- Default Settings her zaman listenin ilk satırı, kalın değil (PuTTY düz)

Port alanı SSH/Telnet/Rlogin/Raw için aktif; Serial’de host+port disable.

---

## 16. Test

- Session file round-trip (tüm Conf anahtarları)
- PPK2/PPK3 load (passphrase’li/passphrasesiz)
- Dil: her anahtar iki katalogda
- Port otomatik değişimi
- Default Settings silinemez
- Host key accept → dosyaya yazılır
- Escape parser: CUP, SGR, alt screen, wrap
- Telnet IAC escape (`0xFF 0xFF`)
- CLI `-load` + `-P`

---

## 17. Uygulama sırası (kod)

1. Xcode/macOS app iskeleti, WinChrome + Session paneli (ekran görüntüsü)
2. Win* kontrol kiti ve tüm Config panelleri (veri bağlı, henüz ağ yok)
3. L10n TR/EN anında geçiş
4. SessionStore + PuTTY dosya formatı
5. TerminalView + emülatör
6. Raw + Telnet + Serial
7. SSH-2 + PPK + password/publickey/agent
8. Tunnels, X11, proxy, logging
9. Diyaloglar, menü, Event Log, Change Settings
10. CLI, PuTTYgen, Help
11. İkon, Info.plist, çalıştırma scripti

---

## 18. Bilinçli sapmalar

- SSH-1 yok (modern PuTTY varsayılanı SSH-2; SSH-1 güvenlik nedeniyle sunulmaz).
- GSSAPI panel görünür; Kerberos yoksa disable.
- Windows registry native yazılmaz; `.reg` import/export vardır.
- Pageant HWND protokolü yok; unix ssh-agent + iç ajan vardır.
- Yazı tipi: Segoe UI yoksa system 11 px (metrikler 11 px’e göre kilitli).
- Uygulama adı ve About metni BLM-TTY; PuTTY markası kullanılmaz.

Bu sapmalar dışında Conf semantiği, oturum dosyası, PPK ve UI yerleşimi orijinalle aynıdır.
