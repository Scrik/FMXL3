unit LauncherSettings;

interface

const
  // Путь в %APPDATA%:
  LocalWorkingFolder: string = '.FMXL3';

  // Путь в реестре, где будут храниться настройки (HKCU//Software//RegistryPath):
  RegistryPath: string = 'FMXL3';

  // Путь к рабочей папке на сервере (там, где лежит веб-часть):
  ServerWorkingFolder: string = 'http://froggystyle.ru/WebFMX3/';

  // Ключ шифрования (должен совпадать с ключом в веб-части!):
  EncryptionKey: AnsiString = 'FMXL3';

  // Интервал между обновлением данных мониторинга в миллисекундах:
  MonitoringInterval: Integer = 450;

  // Версия лаунчера:
  LauncherVersion: Integer = 3;


implementation

end.
