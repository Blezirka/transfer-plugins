# =====================================================================
# АВТОМАТИЧЕСКИЙ ПЕРЕНОС ПЛАГИНОВ, СКРИПТОВ И СОЗДАНИЕ СИМЛИНКОВ (C: -> D:)
# =====================================================================

# Проверка прав администратора
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ">>> ОШИБКА: Запустите скрипт от имени АДМИНИСТРАТОРА!" -ForegroundColor Red
    Exit
}

$ErrorActionPreference = "Continue"

# Базовые пути
$SoundBase        = "D:\Files For All\Documents\Plugins For All\Sound Plugins"
$VideoBase        = "D:\Files For All\Documents\Plugins For All\Video Plugins"
$ScriptsFolder    = "D:\Files For All\Documents\Scripts For All\Video Scripts\Scripts"
$ScriptExts       = "D:\Files For All\Documents\Scripts For All\Video Scripts\extensions_x86"

# Единая папка восстановления в корне D:\RESTORE
$RestoreFolder    = "D:\RESTORE"
$RegDir           = "$RestoreFolder\Registry_Keys"
$RestoreScriptPath = "$RestoreFolder\restore.ps1"
$TargetUser       = $env:USERNAME

# Создаем базовые директории
if (!(Test-Path $RestoreFolder)) { New-Item -ItemType Directory -Path $RestoreFolder -Force | Out-Null }
if (!(Test-Path $RegDir)) { New-Item -ItemType Directory -Path $RegDir -Force | Out-Null }

# 1. ЖЕСТКОЕ ЗАКРЫТИЕ ВСЕХ ФОНОВЫХ ПРОЦЕССОВ И СЛУЖБ
Write-Host ">>> Завершаем фоновые службы и процессы..." -ForegroundColor Yellow

# Остановка критических служб
$services = @("PACESuiteServices", "WavesLocalServer", "AdobeUpdateService", "AGSService", "Armsvc")
foreach ($svc in $services) {
    Get-Service -Name $svc -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
}

# Расширенный список процессов, часто блокирующих папки AppData/ProgramData
$processes = @(
    "AfterFX", "FL", "FL64", "reaper", "cubase", "node", "AuCamera", "Adobe Premiere Pro",
    "Creative Cloud", "CCLBS", "Adobe Desktop Service", "CoreSync", "CCXProcess", "AdobeIPCBroker",
    "AdobeNotificationClient", "AGMService", "WavesLocalServer", "WavesCentral", 
    "iLokLicenseManager", "PACESuiteServices", "PluginAllianceManager", "eLicenserControl",
    "CEPHtmlEngine", "Sentry", "Hub"
)

foreach ($proc in $processes) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

# 2. ДАМП КЛЮЧЕЙ РЕЕСТРА -> В D:\RESTORE\Registry_Keys
Write-Host ">>> Сохраняем ключи реестра в $RegDir..." -ForegroundColor Yellow

$RegKeys = @(
    "HKCU\Software\FabFilter", "HKCU\Software\Image-Line", "HKCU\Software\Xfer",
    "HKCU\Software\iZotope", "HKCU\Software\Valhalla DSP, LLC", "HKCU\Software\Plugin Alliance",
    "HKCU\Software\Neural DSP", "HKCU\Software\Adobe", "HKCU\Software\Spectrasonics",
    "HKCU\Software\XLN Audio", "HKCU\Software\SoundToys", "HKCU\Software\u-he",
    "HKCU\Software\IK Multimedia", "HKCU\Software\Positive Grid", "HKCU\Software\Cytomic",
    "HKLM\SOFTWARE\FabFilter", "HKLM\SOFTWARE\Image-Line", "HKLM\SOFTWARE\iZotope", 
    "HKLM\SOFTWARE\Native Instruments", "HKLM\SOFTWARE\Waves", "HKLM\SOFTWARE\Spectrasonics",
    "HKLM\SOFTWARE\XLN Audio", "HKLM\SOFTWARE\SoundToys", "HKLM\SOFTWARE\Positive Grid",
    # 32-битные плагины на 64-битной Windows часто пишут ключи не в HKLM\SOFTWARE\...,
    # а в HKLM\SOFTWARE\WOW6432Node\... — Test-Path просто пропустит, если ключа нет.
    "HKLM\SOFTWARE\WOW6432Node\FabFilter", "HKLM\SOFTWARE\WOW6432Node\Image-Line",
    "HKLM\SOFTWARE\WOW6432Node\iZotope", "HKLM\SOFTWARE\WOW6432Node\Native Instruments",
    "HKLM\SOFTWARE\WOW6432Node\Waves", "HKLM\SOFTWARE\WOW6432Node\Spectrasonics",
    "HKLM\SOFTWARE\WOW6432Node\XLN Audio", "HKLM\SOFTWARE\WOW6432Node\SoundToys",
    "HKLM\SOFTWARE\WOW6432Node\Positive Grid",

    # --- Добавлено под новые папки из $Mapping (BIAS, Digidesign, BorisFX, Red Giant, Maxon, ProductionCrate, RubberMonkey, RWBYTE/Rowbyte, redshift) ---
    "HKCU\Software\BIAS", "HKCU\Software\Digidesign", "HKCU\Software\BorisFX",
    "HKCU\Software\Red Giant", "HKCU\Software\Maxon", "HKCU\Software\ProductionCrate",
    "HKCU\Software\RubberMonkey", "HKCU\Software\RWBYTE", "HKCU\Software\Rowbyte",
    "HKCU\Software\redshift", "HKCU\Software\Otoy",

    "HKLM\SOFTWARE\BIAS", "HKLM\SOFTWARE\Digidesign", "HKLM\SOFTWARE\BorisFX",
    "HKLM\SOFTWARE\Red Giant", "HKLM\SOFTWARE\Maxon", "HKLM\SOFTWARE\ProductionCrate",
    "HKLM\SOFTWARE\RubberMonkey", "HKLM\SOFTWARE\RWBYTE", "HKLM\SOFTWARE\Rowbyte",
    "HKLM\SOFTWARE\redshift", "HKLM\SOFTWARE\Otoy",

    "HKLM\SOFTWARE\WOW6432Node\BIAS", "HKLM\SOFTWARE\WOW6432Node\Digidesign",
    "HKLM\SOFTWARE\WOW6432Node\BorisFX", "HKLM\SOFTWARE\WOW6432Node\Red Giant",
    "HKLM\SOFTWARE\WOW6432Node\Maxon", "HKLM\SOFTWARE\WOW6432Node\ProductionCrate",
    "HKLM\SOFTWARE\WOW6432Node\RubberMonkey", "HKLM\SOFTWARE\WOW6432Node\RWBYTE",
    "HKLM\SOFTWARE\WOW6432Node\Rowbyte", "HKLM\SOFTWARE\WOW6432Node\redshift",
    "HKLM\SOFTWARE\WOW6432Node\Otoy",

    # --- Добавлено по результатам просмотра реального реестра (скриншоты HKCU/HKLM/WOW6432Node) ---
    "HKCU\Software\AirMusicTech", "HKCU\Software\Cableguys", "HKCU\Software\aescripts.com",
    "HKCU\Software\Sonic Charge", "HKCU\Software\SonicCat", "HKCU\Software\Roland Cloud",
    "HKCU\Software\Voukoder", "HKCU\Software\Synchro Arts", "HKCU\Software\RedGiantSoftware",
    "HKCU\Software\Lexicon", "HKCU\Software\Arturia", "HKCU\Software\XferRecords",
    "HKCU\Software\Frischluft", "HKCU\Software\Imagineer Systems Ltd",
    "HKCU\Software\Antares", "HKCU\Software\Avid", "HKCU\Software\D16 Group",
    "HKCU\Software\FXhome", "HKCU\Software\FilmConvert", "HKCU\Software\GenArts",
    "HKCU\Software\Slate Digital", "HKCU\Software\VideoCopilot", "HKCU\Software\Wavesfactory",
    "HKCU\Software\dSONIQ", "HKCU\Software\illformed", "HKCU\Software\kiloHearts",
    "HKCU\Software\oeksound", "HKCU\Software\vital", "HKCU\Software\GVST",
    "HKCU\Software\Maag Audio", "HKCU\Software\Textevo", "HKCU\Software\Zynaptiq",
    "HKCU\Software\AudioUTOPiA",

    "HKLM\SOFTWARE\AirMusicTech", "HKLM\SOFTWARE\Cableguys",
    "HKLM\SOFTWARE\RedGiantSoftware", "HKLM\SOFTWARE\Roland Cloud", "HKLM\SOFTWARE\Voukoder",
    "HKLM\SOFTWARE\Synchro Arts", "HKLM\SOFTWARE\Lexicon", "HKLM\SOFTWARE\Arturia",
    "HKLM\SOFTWARE\RE:Vision Effects", "HKLM\SOFTWARE\XferRecords", "HKLM\SOFTWARE\WIBU-SYSTEMS",
    "HKLM\SOFTWARE\Blace Plugins", "HKLM\SOFTWARE\Frischluft", "HKLM\SOFTWARE\Imagineer Systems Ltd",
    "HKLM\SOFTWARE\Antares", "HKLM\SOFTWARE\Avid", "HKLM\SOFTWARE\D16 Group",
    "HKLM\SOFTWARE\FXhome", "HKLM\SOFTWARE\FilmConvert", "HKLM\SOFTWARE\GenArts",
    "HKLM\SOFTWARE\Slate Digital", "HKLM\SOFTWARE\VideoCopilot", "HKLM\SOFTWARE\Wavesfactory",
    "HKLM\SOFTWARE\dSONIQ", "HKLM\SOFTWARE\illformed", "HKLM\SOFTWARE\kiloHearts",
    "HKLM\SOFTWARE\oeksound", "HKLM\SOFTWARE\vital", "HKLM\SOFTWARE\GVST",
    "HKLM\SOFTWARE\Maag Audio", "HKLM\SOFTWARE\Textevo", "HKLM\SOFTWARE\Zynaptiq",
    "HKLM\SOFTWARE\AudioUTOPiA",

    "HKLM\SOFTWARE\WOW6432Node\AirMusicTech", "HKLM\SOFTWARE\WOW6432Node\Cableguys",
    "HKLM\SOFTWARE\WOW6432Node\RedGiantSoftware",
    "HKLM\SOFTWARE\WOW6432Node\Roland Cloud", "HKLM\SOFTWARE\WOW6432Node\Voukoder",
    "HKLM\SOFTWARE\WOW6432Node\Synchro Arts", "HKLM\SOFTWARE\WOW6432Node\Lexicon",
    "HKLM\SOFTWARE\WOW6432Node\Arturia", "HKLM\SOFTWARE\WOW6432Node\REvision",
    "HKLM\SOFTWARE\WOW6432Node\XferRecords", "HKLM\SOFTWARE\WOW6432Node\WIBU-SYSTEMS",
    "HKLM\SOFTWARE\WOW6432Node\Sonic Charge", "HKLM\SOFTWARE\WOW6432Node\SonicCat",
    "HKLM\SOFTWARE\WOW6432Node\Frischluft", "HKLM\SOFTWARE\WOW6432Node\Imagineer Systems Ltd",
    "HKLM\SOFTWARE\WOW6432Node\Antares", "HKLM\SOFTWARE\WOW6432Node\Avid",
    "HKLM\SOFTWARE\WOW6432Node\D16 Group", "HKLM\SOFTWARE\WOW6432Node\FXhome",
    "HKLM\SOFTWARE\WOW6432Node\FilmConvert", "HKLM\SOFTWARE\WOW6432Node\GenArts",
    "HKLM\SOFTWARE\WOW6432Node\Slate Digital", "HKLM\SOFTWARE\WOW6432Node\VideoCopilot",
    "HKLM\SOFTWARE\WOW6432Node\Wavesfactory", "HKLM\SOFTWARE\WOW6432Node\dSONIQ",
    "HKLM\SOFTWARE\WOW6432Node\illformed", "HKLM\SOFTWARE\WOW6432Node\kiloHearts",
    "HKLM\SOFTWARE\WOW6432Node\oeksound", "HKLM\SOFTWARE\WOW6432Node\vital",
    "HKLM\SOFTWARE\WOW6432Node\GVST", "HKLM\SOFTWARE\WOW6432Node\Maag Audio",
    "HKLM\SOFTWARE\WOW6432Node\Textevo", "HKLM\SOFTWARE\WOW6432Node\Zynaptiq",
    "HKLM\SOFTWARE\WOW6432Node\AudioUTOPiA",

    # --- Доп. страховка: продукт-папки/скрипт-тулзы, у которых регистр может отличаться от Mapping ---
    "HKCU\Software\Rubber_Monkey_Software", "HKCU\Software\VoukoderPro",
    "HKCU\Software\Valhalla DSP", "HKCU\Software\Waves Audio", "HKCU\Software\Realphones",
    "HKCU\Software\Sixth Sample", "HKCU\Software\AEViewer", "HKCU\Software\DuAEF",
    "HKCU\Software\BattleAxe", "HKCU\Software\MDS", "HKCU\Software\Motion tools",
    "HKCU\Software\JerryFlow", "HKCU\Software\JerrySFX", "HKCU\Software\MisterHorse",
    "HKCU\Software\LooksBuilder", "HKCU\Software\MaxonApp"
)

foreach ($key in $RegKeys) {
    $psPath = $key -replace 'HKCU', 'HKCU:' -replace 'HKLM', 'HKLM:'
    if (Test-Path $psPath) {
        $safeName = $key -replace '\\', '_' -replace ':', ''
        reg export "$key" "$RegDir\$safeName.reg" /y 2>$null
    }
}
Write-Host "   Дамп реестра завершен." -ForegroundColor Green

# 3. КАРТА ПЕРЕНОСА ПЛАГИНОВ И СКРИПТОВ
$Mapping = @(
    # --- ЗВУКОВЫЕ ПЛАГИНЫ ---
    @{ Source = "C:\Program Files\Common Files\VST3"; Target = "$SoundBase\CommonFiles_VST3" },
    @{ Source = "C:\Program Files\Common Files\VST2"; Target = "$SoundBase\CommonFiles_VST2" },
    @{ Source = "C:\Program Files\Common Files\CLAP"; Target = "$SoundBase\CommonFiles_CLAP" },
    @{ Source = "C:\Program Files\AIR Music Technology"; Target = "$SoundBase\AIR Music Technology" },
    @{ Source = "C:\Program Files\Antares Audio Technologies"; Target = "$SoundBase\Antares Audio Technologies" },
    @{ Source = "C:\Program Files\Arturia";               Target = "$SoundBase\Arturia" },
    @{ Source = "C:\Program Files\CableGuys";             Target = "$SoundBase\CableGuys" },
    @{ Source = "C:\Program Files\Neural DSP";            Target = "$SoundBase\Neural DSP" },
    @{ Source = "C:\Program Files\Plugin Alliance";      Target = "$SoundBase\Plugin Alliance" },
    @{ Source = "C:\Program Files\Sonic Charge";          Target = "$SoundBase\Sonic Charge" },
    @{ Source = "C:\Program Files\Synchro Arts Ltd";      Target = "$SoundBase\Synchro Arts Ltd" },
    @{ Source = "C:\Program Files\Valhalla DSP";          Target = "$SoundBase\Valhalla DSP" },
    @{ Source = "C:\Program Files\Xfer Records";          Target = "$SoundBase\Xfer Records" },
    @{ Source = "C:\Program Files\dSONIQ";                Target = "$SoundBase\dSONIQ" },
    @{ Source = "C:\Program Files\iZotope";               Target = "$SoundBase\iZotope" },

    # --- ЗВУКОВЫЕ ПЛАГИНЫ (x86) ---
    @{ Source = "C:\Program Files (x86)\Waves";                     Target = "$SoundBase\Waves_x86" },
    @{ Source = "C:\Program Files (x86)\BIAS";                      Target = "$SoundBase\BIAS_x86" },
	
	# --- ЗВУКОВЫЕ ПЛАГИНЫ (Common Files) ---
	@{ Source = "C:\Program Files\Common Files\Avid";               Target = "$SoundBase\CommonFiles_Avid" },
    @{ Source = "C:\Program Files\Common Files\Native Instruments"; Target = "$SoundBase\CommonFiles_NativeInstruments" },
    @{ Source = "C:\Program Files\Common Files\Plugin Alliance";    Target = "$SoundBase\CommonFiles_PluginAlliance" },
	@{ Source = "C:\Program Files (x86)\Common Files\BIAS";        Target = "$SoundBase\CommonFiles_BIAS_x86" },
	@{ Source = "C:\Program Files (x86)\Common Files\Digidesign";  Target = "$SoundBase\CommonFiles_Digidesign_x86" },
	@{ Source = "C:\Program Files (x86)\Common Files\WPAPI";       Target = "$SoundBase\CommonFiles_WPAPI_x86" },
	
    # --- ВИДЕО ПЛАГИНЫ ---
    @{ Source = "C:\Program Files\Common Files\OFX";      Target = "$VideoBase\CommonFiles_OFX" },
    @{ Source = "C:\Program Files\Common Files\Adobe\Plug-Ins\CC"; Target = "$VideoBase\Adobe_Plugins_CC" },
    @{ Source = "C:\Program Files\BorisFX";               Target = "$VideoBase\BorisFX" },
    @{ Source = "C:\Program Files\FilmConvert";           Target = "$VideoBase\FilmConvert" },
    @{ Source = "C:\Program Files\REVisionEffects";       Target = "$VideoBase\REVisionEffects" },
    @{ Source = "C:\Program Files\Red Giant";             Target = "$VideoBase\Red Giant" },
	@{ Source = "C:\Program Files\ProductionCrate";            Target = "$VideoBase\ProductionCrate" },

    # --- ВИДЕО ПЛАГИНЫ (доп.) ---
    @{ Source = "C:\Program Files\Adobe\Common\Plug-ins\7.0\MediaCore";                          Target = "$VideoBase\Adobe_MediaCore_Plugins" },
    @{ Source = "C:\Program Files\Adobe\Adobe After Effects 2026\Support Files\Plug-ins";        Target = "$VideoBase\AfterEffects_Native_Plugins" },
    @{ Source = "D:\Program Files\Adobe After Effects\Adobe After Effects 2026\Support Files\Plug-ins"; Target = "$VideoBase\AfterEffects_Native_Plugins" },
    @{ Source = "C:\Program Files\Maxon";                     Target = "$VideoBase\Maxon" },
    @{ Source = "C:\Program Files\Maxon Cinema 4D 2026";       Target = "$VideoBase\Maxon Cinema 4D 2026" },
	
    # --- СКРИПТЫ И РАСШИРЕНИЯ AFTER EFFECTS ---
    @{ Source = "C:\Program Files (x86)\Common Files\Adobe\CEP\extensions"; Target = $ScriptExts },
    @{ Source = "C:\Program Files (x86)\aescripts + aeplugins"; Target = "D:\Program Files (x86)\aescripts + aeplugins" },

    # --- PROGRAMDATA ---
    @{ Source = "C:\ProgramData\Adobe";               Target = "D:\ProgramData\Adobe" },
    @{ Source = "C:\ProgramData\Antares";             Target = "D:\ProgramData\Antares" },
    @{ Source = "C:\ProgramData\Arturia";             Target = "D:\ProgramData\Arturia" },
    @{ Source = "C:\ProgramData\Autokroma";           Target = "D:\ProgramData\Autokroma" },
    @{ Source = "C:\ProgramData\BorisFX";             Target = "D:\ProgramData\BorisFX" },
    @{ Source = "C:\ProgramData\D16 Group";           Target = "D:\ProgramData\D16 Group" },
    @{ Source = "C:\ProgramData\FXhome";              Target = "D:\ProgramData\FXhome" },
    @{ Source = "C:\ProgramData\GenArts";             Target = "D:\ProgramData\GenArts" },
    @{ Source = "C:\ProgramData\Maxon";               Target = "D:\ProgramData\Maxon" },
    @{ Source = "C:\ProgramData\Native Instruments"; Target = "D:\ProgramData\Native Instruments" },
    @{ Source = "C:\ProgramData\Neural DSP";          Target = "D:\ProgramData\Neural DSP" },
    @{ Source = "C:\ProgramData\Red Giant";           Target = "D:\ProgramData\Red Giant" },
    @{ Source = "C:\ProgramData\Roland Cloud";        Target = "D:\ProgramData\Roland Cloud" },
    @{ Source = "C:\ProgramData\Slate Digital";       Target = "D:\ProgramData\Slate Digital" },
    @{ Source = "C:\ProgramData\Valhalla DSP, LLC";   Target = "D:\ProgramData\Valhalla DSP, LLC" },
    @{ Source = "C:\ProgramData\VideoCopilot";        Target = "D:\ProgramData\VideoCopilot" },
    @{ Source = "C:\ProgramData\Waves Audio";         Target = "D:\ProgramData\Waves Audio" },
    @{ Source = "C:\ProgramData\XLN Audio";           Target = "D:\ProgramData\XLN Audio" },
    @{ Source = "C:\ProgramData\Zynaptiq";            Target = "D:\ProgramData\Zynaptiq" },
    @{ Source = "C:\ProgramData\aescripts";           Target = "D:\ProgramData\aescripts" },
    @{ Source = "C:\ProgramData\kiloHearts";          Target = "D:\ProgramData\kiloHearts" },
    @{ Source = "C:\ProgramData\oeksound";            Target = "D:\ProgramData\oeksound" },
    @{ Source = "C:\ProgramData\RubberMonkey";                    Target = "D:\ProgramData\RubberMonkey" },
	@{ Source = "C:\ProgramData\RWBYTE";                          Target = "D:\ProgramData\RWBYTE" },
	@{ Source = "C:\ProgramData\redshift";                        Target = "D:\ProgramData\redshift" },
	@{ Source = "C:\ProgramData\ValhallaDelay";                Target = "D:\ProgramData\ValhallaDelay" },
    @{ Source = "C:\ProgramData\ValhallaFutureVerb";           Target = "D:\ProgramData\ValhallaFutureVerb" },
    @{ Source = "C:\ProgramData\ValhallaPlate";                Target = "D:\ProgramData\ValhallaPlate" },
    @{ Source = "C:\ProgramData\ValhallaRoom";                 Target = "D:\ProgramData\ValhallaRoom" },
    @{ Source = "C:\ProgramData\ValhallaRoomPreferences";      Target = "D:\ProgramData\ValhallaRoomPreferences" },
    @{ Source = "C:\ProgramData\ValhallaShimmer";              Target = "D:\ProgramData\ValhallaShimmer" },
    @{ Source = "C:\ProgramData\ValhallaUberMod";              Target = "D:\ProgramData\ValhallaUberMod" },
    @{ Source = "C:\ProgramData\ValhallaVintageVerb";          Target = "D:\ProgramData\ValhallaVintageVerb" },
    @{ Source = "C:\ProgramData\ValhallaVintageVerbPreferences"; Target = "D:\ProgramData\ValhallaVintageVerbPreferences" },
    @{ Source = "C:\ProgramData\AudioUTOPiA";                  Target = "D:\ProgramData\AudioUTOPiA" },
    @{ Source = "C:\ProgramData\Sixth Sample";                 Target = "D:\ProgramData\Sixth Sample" },
    @{ Source = "C:\ProgramData\com.aescripts.zxpinstaller";   Target = "D:\ProgramData\com.aescripts.zxpinstaller" },
    @{ Source = "C:\ProgramData\IK Multimedia";                Target = "D:\ProgramData\IK Multimedia" },
    @{ Source = "C:\ProgramData\iZotope";                      Target = "D:\ProgramData\iZotope" },
    @{ Source = "C:\ProgramData\Positive Grid";                Target = "D:\ProgramData\Positive Grid" },
    @{ Source = "C:\ProgramData\SoundToys";                    Target = "D:\ProgramData\SoundToys" },
    @{ Source = "C:\ProgramData\Cytomic";                      Target = "D:\ProgramData\Cytomic" },

    # --- APPDATA ROAMING ---
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\AEViewer";           Target = "D:\Users\$TargetUser\AppData\Roaming\AEViewer" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Adobe";              Target = "D:\Users\$TargetUser\AppData\Roaming\Adobe" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Antares";            Target = "D:\Users\$TargetUser\AppData\Roaming\Antares" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Autokroma";          Target = "D:\Users\$TargetUser\AppData\Roaming\Autokroma" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\BattleAxe";          Target = "D:\Users\$TargetUser\AppData\Roaming\BattleAxe" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\BorisFX";            Target = "D:\Users\$TargetUser\AppData\Roaming\BorisFX" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Cableguys";          Target = "D:\Users\$TargetUser\AppData\Roaming\Cableguys" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\D16 Group";          Target = "D:\Users\$TargetUser\AppData\Roaming\D16 Group" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\DuAEF";              Target = "D:\Users\$TargetUser\AppData\Roaming\DuAEF" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\FabFilter";          Target = "D:\Users\$TargetUser\AppData\Roaming\FabFilter" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\GenArts";            Target = "D:\Users\$TargetUser\AppData\Roaming\GenArts" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\IK Multimedia";      Target = "D:\Users\$TargetUser\AppData\Roaming\IK Multimedia" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Maxon";              Target = "D:\Users\$TargetUser\AppData\Roaming\Maxon" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Motion tools";       Target = "D:\Users\$TargetUser\AppData\Roaming\Motion tools" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Neural DSP";         Target = "D:\Users\$TargetUser\AppData\Roaming\Neural DSP" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Plugin Alliance";     Target = "D:\Users\$TargetUser\AppData\Roaming\Plugin Alliance" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Realphones";         Target = "D:\Users\$TargetUser\AppData\Roaming\Realphones" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Red Giant";          Target = "D:\Users\$TargetUser\AppData\Roaming\Red Giant" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Rowbyte";            Target = "D:\Users\$TargetUser\AppData\Roaming\Rowbyte" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Textevo";            Target = "D:\Users\$TargetUser\AppData\Roaming\Textevo" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Valhalla DSP, LLC";  Target = "D:\Users\$TargetUser\AppData\Roaming\Valhalla DSP, LLC" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\VideoCopilot";       Target = "D:\Users\$TargetUser\AppData\Roaming\VideoCopilot" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Wavesfactory";      Target = "D:\Users\$TargetUser\AppData\Roaming\Wavesfactory" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Xfer";               Target = "D:\Users\$TargetUser\AppData\Roaming\Xfer" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Zynaptiq";           Target = "D:\Users\$TargetUser\AppData\Roaming\Zynaptiq" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\aescripts";          Target = "D:\Users\$TargetUser\AppData\Roaming\aescripts" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\iZotope";            Target = "D:\Users\$TargetUser\AppData\Roaming\iZotope" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\vital";              Target = "D:\Users\$TargetUser\AppData\Roaming\vital" },
	@{ Source = "C:\Users\$TargetUser\AppData\Roaming\com.aescripts.updater";     Target = "D:\Users\$TargetUser\AppData\Roaming\com.aescripts.updater" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Glitch2";                   Target = "D:\Users\$TargetUser\AppData\Roaming\Glitch2" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\MDS";                       Target = "D:\Users\$TargetUser\AppData\Roaming\MDS" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\SonicCat";                  Target = "D:\Users\$TargetUser\AppData\Roaming\SonicCat" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Waves Audio";               Target = "D:\Users\$TargetUser\AppData\Roaming\Waves Audio" },
	@{ Source = "C:\Users\$TargetUser\AppData\Roaming\ValhallaDelay";                Target = "D:\Users\$TargetUser\AppData\Roaming\ValhallaDelay" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\ValhallaFutureVerb";           Target = "D:\Users\$TargetUser\AppData\Roaming\ValhallaFutureVerb" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\ValhallaPlate";                Target = "D:\Users\$TargetUser\AppData\Roaming\ValhallaPlate" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\ValhallaRoom";                 Target = "D:\Users\$TargetUser\AppData\Roaming\ValhallaRoom" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\ValhallaRoomPreferences";      Target = "D:\Users\$TargetUser\AppData\Roaming\ValhallaRoomPreferences" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\ValhallaShimmer";              Target = "D:\Users\$TargetUser\AppData\Roaming\ValhallaShimmer" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\ValhallaUberMod";              Target = "D:\Users\$TargetUser\AppData\Roaming\ValhallaUberMod" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\ValhallaVintageVerb";          Target = "D:\Users\$TargetUser\AppData\Roaming\ValhallaVintageVerb" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\ValhallaVintageVerbPreferences"; Target = "D:\Users\$TargetUser\AppData\Roaming\ValhallaVintageVerbPreferences" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\productioncrate";              Target = "D:\Users\$TargetUser\AppData\Roaming\productioncrate" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\boris-fx-direct";              Target = "D:\Users\$TargetUser\AppData\Roaming\boris-fx-direct" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\.com.uwu2x-pro-9.0.cep";       Target = "D:\Users\$TargetUser\AppData\Roaming\.com.uwu2x-pro-9.0.cep" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\XLN Audio";        Target = "D:\Users\$TargetUser\AppData\Roaming\XLN Audio" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\SoundToys";        Target = "D:\Users\$TargetUser\AppData\Roaming\SoundToys" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\u-he";             Target = "D:\Users\$TargetUser\AppData\Roaming\u-he" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Cytomic";          Target = "D:\Users\$TargetUser\AppData\Roaming\Cytomic" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\illformed";       Target = "D:\Users\$TargetUser\AppData\Roaming\illformed" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\GVST";             Target = "D:\Users\$TargetUser\AppData\Roaming\GVST" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Lexicon";          Target = "D:\Users\$TargetUser\AppData\Roaming\Lexicon" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Maag Audio";       Target = "D:\Users\$TargetUser\AppData\Roaming\Maag Audio" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\Positive Grid";    Target = "D:\Users\$TargetUser\AppData\Roaming\Positive Grid" },
    @{ Source = "C:\Users\$TargetUser\AppData\Roaming\dSONIQ";           Target = "D:\Users\$TargetUser\AppData\Roaming\dSONIQ" },


    # --- APPDATA LOCAL ---
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Adobe";                Target = "D:\Users\$TargetUser\AppData\Local\Adobe" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\iZotope";              Target = "D:\Users\$TargetUser\AppData\Local\iZotope" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Native Instruments";    Target = "D:\Users\$TargetUser\AppData\Local\Native Instruments" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Waves Audio";           Target = "D:\Users\$TargetUser\AppData\Local\Waves Audio" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Arturia";              Target = "D:\Users\$TargetUser\AppData\Local\Arturia" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Plugin Alliance";      Target = "D:\Users\$TargetUser\AppData\Local\Plugin Alliance" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Roland Cloud";         Target = "D:\Users\$TargetUser\AppData\Local\Roland Cloud" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\XLN Audio";            Target = "D:\Users\$TargetUser\AppData\Local\XLN Audio" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Kontakt 8";            Target = "D:\Users\$TargetUser\AppData\Local\Kontakt 8" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Voukoder";             Target = "D:\Users\$TargetUser\AppData\Local\Voukoder" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\VoukoderPro";          Target = "D:\Users\$TargetUser\AppData\Local\VoukoderPro" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\MisterHorse";          Target = "D:\Users\$TargetUser\AppData\Local\MisterHorse" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\LooksBuilder";         Target = "D:\Users\$TargetUser\AppData\Local\LooksBuilder" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\com.redgiant.Colorista-IV";     Target = "D:\Users\$TargetUser\AppData\Local\com.redgiant.Colorista-IV" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\com.redgiant.MBS_Film_AE";      Target = "D:\Users\$TargetUser\AppData\Local\com.redgiant.MBS_Film_AE" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\com.redgiant.MBS_Mojo_II_AE";   Target = "D:\Users\$TargetUser\AppData\Local\com.redgiant.MBS_Mojo_II_AE" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\com.redgiant.MagicBulletLooks"; Target = "D:\Users\$TargetUser\AppData\Local\com.redgiant.MagicBulletLooks" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\aescripts.com";        Target = "D:\Users\$TargetUser\AppData\Local\aescripts.com" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\RubberMonkey";        Target = "D:\Users\$TargetUser\AppData\Local\RubberMonkey" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Rubber_Monkey_Software"; Target = "D:\Users\$TargetUser\AppData\Local\Rubber_Monkey_Software" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\ValhallaDelay";                Target = "D:\Users\$TargetUser\AppData\Local\ValhallaDelay" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\ValhallaFutureVerb";           Target = "D:\Users\$TargetUser\AppData\Local\ValhallaFutureVerb" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\ValhallaPlate";                Target = "D:\Users\$TargetUser\AppData\Local\ValhallaPlate" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\ValhallaRoom";                 Target = "D:\Users\$TargetUser\AppData\Local\ValhallaRoom" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\ValhallaRoomPreferences";      Target = "D:\Users\$TargetUser\AppData\Local\ValhallaRoomPreferences" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\ValhallaShimmer";              Target = "D:\Users\$TargetUser\AppData\Local\ValhallaShimmer" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\ValhallaUberMod";              Target = "D:\Users\$TargetUser\AppData\Local\ValhallaUberMod" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\ValhallaVintageVerb";          Target = "D:\Users\$TargetUser\AppData\Local\ValhallaVintageVerb" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\ValhallaVintageVerbPreferences"; Target = "D:\Users\$TargetUser\AppData\Local\ValhallaVintageVerbPreferences" },
	@{ Source = "C:\Users\$TargetUser\AppData\Local\BorisFX";                     Target = "D:\Users\$TargetUser\AppData\Local\BorisFX" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\FlowframesInstallerTemp";     Target = "D:\Users\$TargetUser\AppData\Local\FlowframesInstallerTemp" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Maxon";                       Target = "D:\Users\$TargetUser\AppData\Local\Maxon" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\MaxonApp";                    Target = "D:\Users\$TargetUser\AppData\Local\MaxonApp" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Red Giant";                   Target = "D:\Users\$TargetUser\AppData\Local\Red Giant" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\VideoCopilot";                Target = "D:\Users\$TargetUser\AppData\Local\VideoCopilot" },
    @{ Source = "C:\Users\$TargetUser\AppData\Local\Xfer";                        Target = "D:\Users\$TargetUser\AppData\Local\Xfer" },

    # --- СКРИПТЫ И РАСШИРЕНИЯ AFTER EFFECTS (доп. — 64-битный CEP, UXP, автозапуск) ---
    # ВАЖНО: переносим только ScriptUI Panels и Startup (сюда кладут файлы сторонние авторы),
    # а не всю папку Scripts целиком — внутри неё лежит ещё и "Sample Scripts" от самой Adobe,
    # которые лучше не трогать симлинком (риск при repair-install/деинсталляции AE).
    @{ Source = "D:\Program Files\Adobe After Effects\Adobe After Effects 2026\Support Files\Scripts\ScriptUI Panels"; Target = "$ScriptsFolder\ScriptUI Panels" },
    @{ Source = "C:\Program Files\Adobe\Adobe After Effects 2026\Support Files\Scripts\ScriptUI Panels";               Target = "$ScriptsFolder\ScriptUI Panels" },
    @{ Source = "D:\Program Files\Adobe After Effects\Adobe After Effects 2026\Support Files\Scripts\Startup"; Target = "$ScriptsFolder\Startup" },
    @{ Source = "C:\Program Files\Adobe\Adobe After Effects 2026\Support Files\Scripts\Startup";               Target = "$ScriptsFolder\Startup" },
    @{ Source = "C:\Program Files\Common Files\Adobe\CEP\extensions";       Target = "D:\Files For All\Documents\Scripts For All\Video Scripts\extensions" },
    @{ Source = "C:\Program Files\Common Files\Adobe\UXP\extensions";       Target = "D:\Files For All\Documents\Scripts For All\Video Scripts\UXP extensions" },
    @{ Source = "C:\Program Files\Common Files\Adobe\Startup Scripts CC";   Target = "D:\Files For All\Documents\Scripts For All\Video Scripts\Startup Scripts CC" },

    # --- DOCUMENTS ---
    @{ Source = "C:\Users\$TargetUser\Documents\Red Giant";  Target = "D:\Users\$TargetUser\Documents\Red Giant" },
    @{ Source = "C:\Users\$TargetUser\Documents\Zynaptiq";   Target = "D:\Users\$TargetUser\Documents\Zynaptiq" },
    @{ Source = "C:\Users\$TargetUser\Documents\JerryFlow";  Target = "D:\Users\$TargetUser\Documents\JerryFlow" },
    @{ Source = "C:\Users\$TargetUser\Documents\JerrySFX";   Target = "D:\Users\$TargetUser\Documents\JerrySFX" },
    @{ Source = "C:\Users\$TargetUser\Documents\u-he";       Target = "D:\Users\$TargetUser\Documents\u-he" },
    @{ Source = "C:\Users\$TargetUser\.ProductionCrate";     Target = "D:\Users\$TargetUser\.ProductionCrate" },
    @{ Source = "C:\Users\$TargetUser\Lockdown";             Target = "D:\Users\$TargetUser\Lockdown" },
    @{ Source = "C:\Users\Public\Documents";                 Target = "D:\Users\Public\Documents" },
	@{ Source = "C:\Users\Public\Waves Audio";                    Target = "D:\Users\Public\Waves Audio" },
	@{ Source = "C:\Users\Public\Documents\Native Instruments";    Target = "D:\Users\Public\Documents\Native Instruments" },
	@{ Source = "C:\Users\Public\Documents\NI Resources";          Target = "D:\Users\Public\Documents\NI Resources" },
	@{ Source = "C:\Users\Public\Documents\Soundtoys";             Target = "D:\Users\Public\Documents\Soundtoys" }
)

# 3.5. ДИНАМИЧЕСКИЙ ПОИСК И ОСТАНОВКА СЛУЖБ, ЧЬИ ФАЙЛЫ ЛЕЖАТ В ПЕРЕНОСИМЫХ ПАПКАХ
# (решает проблему с Red Giant Service, Maxon Service и любыми другими похожими службами:
#  их бинарник блокирует файл во время robocopy /MOVE, из-за чего Junction не создаётся.
#  Вместо жёстко прописанных имён служб ищем ЛЮБУЮ службу, чей путь к exe начинается
#  с одного из $Mapping.Source — и просто останавливаем её перед переносом.
#  После создания Junction реестр службы (ImagePath) не меняется и продолжает указывать
#  на C:\..., а NTFS reparse point прозрачно перенаправляет на D:\... — переустановка не нужна.)
Write-Host "`n>>> Ищем службы, чьи файлы лежат в переносимых папках..." -ForegroundColor Yellow

$StoppedServices = @()
$AllServices = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName }

foreach ($item in $Mapping) {
    $src = $item.Source.TrimEnd('\')
    foreach ($svc in $AllServices) {
        # PathName может быть в кавычках и содержать аргументы — берём только путь к exe
        $exePath = $svc.PathName
        if ($exePath -match '^"([^"]+)"') { $exePath = $Matches[1] } else { $exePath = ($exePath -split ' -')[0].Trim() }

        if ($exePath -like "$src\*" -or $exePath -eq $src) {
            if ($svc.State -eq 'Running') {
                Write-Host "  [SERVICE] Останавливаю $($svc.Name) ($($svc.DisplayName)) — использует $src" -ForegroundColor Cyan
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                $StoppedServices += $svc.Name
            }
        }
    }
}

if ($StoppedServices.Count -eq 0) {
    Write-Host "   Служб, привязанных к переносимым папкам, не найдено." -ForegroundColor Green
} else {
    Write-Host "   Остановлено служб: $($StoppedServices.Count)" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# 4. ПЕРЕНОС И СОЗДАНИЕ СИМЛИНКОВ
Write-Host "`n>>> Переносим папки и создаем Junction-симлинки..." -ForegroundColor Yellow

$RestoreCommands = @()
$RestoreCommands += '# Автоматический скрипт восстановления'
$RestoreCommands += '$OutputEncoding = [System.Text.Encoding]::UTF8'
$RestoreCommands += 'if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {'
$RestoreCommands += '    Write-Host ">>> Запустите restore.ps1 от имени АДМИНИСТРАТОРА!" -ForegroundColor Red; Exit'
$RestoreCommands += '}'
$RestoreCommands += '$TargetUser = $env:USERNAME'
$RestoreCommands += 'Write-Host ">>> Импорт ключей реестра..." -ForegroundColor Yellow'
$RestoreCommands += 'Get-ChildItem "$PSScriptRoot\Registry_Keys\*.reg" -ErrorAction SilentlyContinue | ForEach-Object { reg import $_.FullName }'
$RestoreCommands += 'Write-Host ">>> Восстановление Junction-симлинков..." -ForegroundColor Yellow'

foreach ($item in $Mapping) {
    $src = $item.Source.TrimEnd('\')
    $tgt = $item.Target.TrimEnd('\')

    if (Test-Path $src) {
        $itemObj = Get-Item $src
        if ($itemObj.Attributes -match "ReparsePoint") {
            # Папка уже симлинк (создан вручную или другим инструментом раньше).
            # Не трогаем её, но узнаём, куда она РЕАЛЬНО ведёт, и всё равно
            # записываем восстановление — иначе на новой системе эта симлинка
            # просто потеряется, т.к. этот прогон её формально не обрабатывал.
            $realTarget = $null
            try { $realTarget = ($itemObj.Target | Select-Object -First 1) } catch {}
            if (-not $realTarget) {
                try { $realTarget = (Get-Item $src).LinkTarget } catch {}
            }

            if ($realTarget) {
                Write-Host " [SKIP] $src уже симлинк -> $realTarget (записываю в restore)." -ForegroundColor Gray

                $userSrcPattern = [regex]::Escape("C:\Users\$TargetUser\")
                $userTgtPattern = [regex]::Escape("D:\Users\$TargetUser\")

                $restoreSrc = $src -replace "^$userSrcPattern", 'C:\Users\$TargetUser\'
                $restoreTgt = $realTarget.TrimEnd('\') -replace "^$userTgtPattern", 'D:\Users\$TargetUser\'

                $cmd  = "if (Test-Path `"$restoreTgt`") { "
                $cmd +=     "if (Test-Path `"$restoreSrc`") { Remove-Item -Path `"$restoreSrc`" -Recurse -Force -ErrorAction SilentlyContinue }; "
                $cmd +=     "New-Item -ItemType Directory -Path (Split-Path `"$restoreSrc`") -Force -ErrorAction SilentlyContinue | Out-Null; "
                $cmd +=     "New-Item -ItemType Junction -Path `"$restoreSrc`" -Target `"$restoreTgt`" -ErrorAction SilentlyContinue | Out-Null "
                $cmd += "} else { Write-Host `" [SKIP] Назначение $restoreTgt не найдено на D:`" -ForegroundColor Yellow }"

                $RestoreCommands += $cmd
            } else {
                Write-Host " [SKIP] $src уже является симлинком (цель не определена)." -ForegroundColor Gray
            }
            continue
        }

        Write-Host " [MOVE] $src -> $tgt" -ForegroundColor Cyan
        
        # Создаем целевую папку при необходимости
        $parentTgt = Split-Path $tgt
        if (!(Test-Path $parentTgt)) { New-Item -ItemType Directory -Path $parentTgt -Force | Out-Null }

        # Перенос файла через Robocopy
        robocopy "$src" "$tgt" /E /MOVE /BYTES /R:1 /W:1 /NJH /NJS /NDL /NC /NS | Out-Null
        
        # Проверка кода завершения Robocopy (от 0 до 7 — успех)
        if ($LASTEXITCODE -lt 8) {
            # Пробуем удалить оставшуюся пустую папки источника
            if (Test-Path $src) {
                Remove-Item -Path $src -Recurse -Force -ErrorAction SilentlyContinue
            }

            # Создаем Junction только при успешном удалении оригинала
            if (!(Test-Path $src)) {
                New-Item -ItemType Junction -Path $src -Target $tgt -ErrorAction Stop | Out-Null
            } else {
                Write-Host " [WARNING] В $src остались заблокированные файлы. Симлинк не создан." -ForegroundColor Red
                $remaining = Get-ChildItem -Path $src -Recurse -File -ErrorAction SilentlyContinue
                if ($remaining) {
                    Write-Host "   Не удалось удалить (вероятно, заняты другим процессом):" -ForegroundColor DarkYellow
                    foreach ($f in $remaining) {
                        Write-Host "     - $($f.FullName)" -ForegroundColor DarkYellow
                    }
                }
                continue
            }
        } else {
            Write-Host " [ERROR] Ошибка переноса Robocopy для $src (код $LASTEXITCODE)." -ForegroundColor Red
            continue
        }
        
        # Безопасная замена имени пользователя в путях восстановления
        $userSrcPattern = [regex]::Escape("C:\Users\$TargetUser\")
        $userTgtPattern = [regex]::Escape("D:\Users\$TargetUser\")
        
        $restoreSrc = $src -replace "^$userSrcPattern", 'C:\Users\$TargetUser\'
        $restoreTgt = $tgt -replace "^$userTgtPattern", 'D:\Users\$TargetUser\'
        
        $cmd  = "if (Test-Path `"$restoreTgt`") { "
        $cmd +=     "if (Test-Path `"$restoreSrc`") { Remove-Item -Path `"$restoreSrc`" -Recurse -Force -ErrorAction SilentlyContinue }; "
        $cmd +=     "New-Item -ItemType Directory -Path (Split-Path `"$restoreSrc`") -Force -ErrorAction SilentlyContinue | Out-Null; "
        $cmd +=     "New-Item -ItemType Junction -Path `"$restoreSrc`" -Target `"$restoreTgt`" -ErrorAction SilentlyContinue | Out-Null "
        $cmd += "} else { Write-Host `" [SKIP] Назначение $restoreTgt не найдено на D:`" -ForegroundColor Yellow }"

        $RestoreCommands += $cmd
    }
}

# 5. АУДИТ: поиск папок, не попавших ни под один Source (в т.ч. "безымянные" вроде .com.xxx.cep)
Write-Host "`n>>> Ищем папки, не охваченные списком переноса (аудит)..." -ForegroundColor Yellow

$AuditBases = @(
    "C:\Program Files",
    "C:\Program Files (x86)",
    "C:\Program Files\Common Files",
    "C:\Program Files (x86)\Common Files",
    "C:\Program Files\Common Files\Adobe",
    "C:\ProgramData",
    "C:\Users\$TargetUser",
    "C:\Users\$TargetUser\AppData\Roaming",
    "C:\Users\$TargetUser\AppData\Local",
    "C:\Users\$TargetUser\Documents",
    "C:\Users\Public",
    "C:\Users\Public\Documents"
)

# Известные системные/не относящиеся к плагинам папки — не выводим их в отчет, чтобы не засорять лог
$ExcludePatterns = @(
    'Windows*','Microsoft*','WindowsApps','WindowsPowerShell','PowerShell','Reference Assemblies',
    'NVIDIA*','AMD*','AMD_Common','ASUS*','Realtek','Intel','Docker*','Internet Explorer','Windows Mail',
    'Windows NT','Windows Photo Viewer','Windows Sidebar','Windows Defender*','MSBuild','dotnet',
    'PackageManagement','Package Cache','Packages','WSL','Hyper-V','Uninstall Information',
    '_uninstaller','VS Revo Group','ModifiableWindowsApps','Application Data','Templates',
    'Start Menu','SoftwareDistribution','USOPrivate','USOShared','Whesvc','chocolatey',
    'ChocolateyHttpCache','ssh','shimgen','ntuser.pol','boost_interprocess','VirtualStore',
    'Temp','Temporary Internet Files','CrashDumps','History','Comms','ConnectedDevicesPlatform',
    'D3DSCache','CEF','CefSharp','State','Programs','Publishers','PlaceholderTileLogoFolder',
    'ToastNotificationManagerCompat','User Data','SquirrelTemp','Discord','BraveSoftware',
    'Waterfox*','GitHub CLI','Postman','MongoDB*','AWSToolkit','Everything','VMware',
    'Cloudflare','com.cloudflare','GHelper','Stardock','Radmin VPN','Mozilla*','Application Verifier',
    'Windows Kits','Microsoft.NET','Microsoft SDKs','Microsoft Visual Studio','ATI','ESET',
    '{*}','npm-cache','pip','uv','winutil','nwjs','Talon','Steam','Roblox','qBittorrent','obs-studio*',
    'Goldberg SteamEmu Saves','FACEIT*',
    # стандартные папки профиля Windows — не плагины, не выводим в отчет
    'AppData','Documents','Desktop','Downloads','Music','Pictures','Videos',
    'Favorites','Links','Contacts','Saved Games','Searches','OneDrive*',
    '3D Objects','NetHood','PrintHood','SendTo','Cookies','IntelGraphicsProfiles',
    'Local Settings','My Documents','Recent','Start Menu'
)

$knownSources = $Mapping.Source | ForEach-Object { $_.TrimEnd('\') }

$UnmappedReport = @()
foreach ($base in $AuditBases) {
    if (!(Test-Path $base)) { continue }
    Get-ChildItem -Path $base -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $full = $_.FullName.TrimEnd('\')
        $isKnown = $knownSources -contains $full
        $isExcluded = $false
        foreach ($pat in $ExcludePatterns) {
            if ($_.Name -like $pat) { $isExcluded = $true; break }
        }
        if (-not $isKnown -and -not $isExcluded) {
            $UnmappedReport += $full
        }
    }
}

$AuditLogPath = "$RestoreFolder\unmapped_folders.log"
if ($UnmappedReport.Count -gt 0) {
    $UnmappedReport | Sort-Object -Unique | Out-File -FilePath $AuditLogPath -Encoding UTF8
    Write-Host "   [!] Найдено $($UnmappedReport.Count) папок вне списка переноса (не тронуты, только для проверки)." -ForegroundColor Magenta
    Write-Host "       Список: $AuditLogPath" -ForegroundColor Magenta
} else {
    Write-Host "   Все папки покрыты списком переноса." -ForegroundColor Green
}

# 6. СОЗДАНИЕ СКРИПТА ВОССТАНОВЛЕНИЯ RESTORE.PS1
$RestoreCommands += 'Write-Host "`n[УСПЕХ] Все ключи и симлинки успешно восстановлены!" -ForegroundColor Green'
$RestoreCommands += 'Write-Host "[ИНФО] Рекомендуется перезагрузить компьютер для применения всех ключей реестра." -ForegroundColor Yellow'
[System.IO.File]::WriteAllLines($RestoreScriptPath, $RestoreCommands, [System.Text.Encoding]::UTF8)

# 7. ЗАПУСК ОБРАТНО СЛУЖБ, ОСТАНОВЛЕННЫХ НА ШАГЕ 3.5
# Junction уже создан, ImagePath службы не менялся — можно просто запускать как раньше.
if ($StoppedServices.Count -gt 0) {
    Write-Host "`n>>> Запускаем обратно ранее остановленные службы..." -ForegroundColor Yellow
    foreach ($svcName in ($StoppedServices | Select-Object -Unique)) {
        try {
            Start-Service -Name $svcName -ErrorAction Stop
            Write-Host "   [OK] $svcName запущена." -ForegroundColor Green
        } catch {
            Write-Host "   [WARN] Не удалось запустить $svcName автоматически — возможно, запускается вручную или при первом обращении. Проверь после перезагрузки." -ForegroundColor DarkYellow
        }
    }
}

Write-Host "`n=======================================================" -ForegroundColor Green
Write-Host " ВСЁ ГОТОВО! Перенос завершен успешно." -ForegroundColor Green
Write-Host " Папка восстановления: $RestoreFolder" -ForegroundColor Yellow
Write-Host "   - Файл: $RestoreScriptPath" -ForegroundColor Yellow
Write-Host "   - Реестр: $RegDir" -ForegroundColor Yellow
if ($UnmappedReport.Count -gt 0) {
    Write-Host "   - Непокрытые папки (проверь вручную): $AuditLogPath" -ForegroundColor Magenta
}
Write-Host "=======================================================" -ForegroundColor Green