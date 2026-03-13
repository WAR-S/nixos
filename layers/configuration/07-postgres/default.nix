{ config, pkgs, lib, ... }:
let
  pgDataDir = "/var/lib/postgres/data";
  pgInitSql = pkgs.writeText "postgres-init.sql" ''
    CREATE ROLE test LOGIN PASSWORD 'qwerty123';
    CREATE DATABASE "test-data-base" OWNER test ENCODING 'UTF8'
      LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template1;
    \connect "test-data-base"
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  '';
in
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    dataDir = pgDataDir;
    # автоинициализация кластера с нужной локалью/кодировкой
    enableTCPIP = true;
    authentication = ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    postgres        postgres        10.10.10.1/32          md5
      host    all             all             127.0.0.1/32           trust
      host    test-data-base   test            0.0.0.0/0              md5
      local   replication     all                                     trust
      host    replication     all             127.0.0.1/32           trust
      host    replication     all             ::1/128                trust
    '';
    settings = {
      # Строгий бинд только на IP точки доступа
      listen_addresses = lib.mkForce "10.10.10.1";
      max_connections = 100;
      shared_buffers = "128MB";
      dynamic_shared_memory_type = "posix";
      max_wal_size = "1GB";
      min_wal_size = "80MB";
      logging_collector = true;
      log_directory = "logs";  # относительно dataDir, Postgres создаст при первом запуске
      log_filename = "postgresql-%a.log";
      log_rotation_age = "1d";
      log_rotation_size = 0;
      log_truncate_on_rotation = true;
      log_timezone = "UTC";
      datestyle = "iso, mdy";
      timezone = "UTC";
      # НЕ трогаем lc_*, пусть Postgres берёт то, что есть в окружении
      # lc_messages = "en_US.UTF-8";
      # lc_monetary = "en_US.UTF-8";
      # lc_numeric  = "en_US.UTF-8";
      # lc_time     = "en_US.UTF-8";

      default_text_search_config = "pg_catalog.english";
      shared_preload_libraries = "pg_stat_statements";
      "pg_stat_statements.track" = "all";
    };
    # начальная инициализация: создаём базу/пользователя/расширение
    initialScript = pgInitSql;
  };

  # Создаём dataDir до старта postgresql (иначе NAMESPACE: No such file or directory). Пустой каталог — pre-start сделает initdb.
  systemd.tmpfiles.rules = [
    ''d /var/lib/postgres 0750 postgres postgres -''
    ''d ${pgDataDir} 0700 postgres postgres -''
  ];

  # Бинд на 10.10.10.1 — постгрес стартует после появления IP (без лишней связи с postgresql-setup, чтобы не было цикла).
  systemd.services.postgresql = {
    after = [ "wifi-ap-wait-ip.service" ];
    wants = [ "wifi-ap-wait-ip.service" ];
    requires = [ "wifi-ap-wait-ip.service" ];
  };

}